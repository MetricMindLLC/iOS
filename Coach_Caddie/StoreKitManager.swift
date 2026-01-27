import StoreKit
import SwiftUI

@MainActor
class StoreKitManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var purchaseInProgress = false
    
    // Reference to your auth manager for subscription updates
    private weak var authManager: FirebaseAuthManager?
    
    // CRITICAL FIX: Track processed transactions PER USER to prevent cross-user conflicts
    private var processedTransactionsForCurrentUser: Set<UInt64> = []
    private var currentUserUID: String?
    
    // NEW: Track if we're in initial load to avoid auto-processing existing transactions
    private var isInitialLoad = true
    private var hasCompletedInitialLoad = false
    
    private let productIDs = [
        "com.coachcaddie.pro.monthly",
        "com.coachcaddie.pro.yearly",
        "com.coachcaddie.premium.monthly",
        "com.coachcaddie.premium.yearly"
    ]
    private var updateListenerTask: Task<Void, Error>?
    
    init(authManager: FirebaseAuthManager? = nil) {
        self.authManager = authManager
        
        // Start listening for transactions
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
            
            // Mark initial load as complete after we've loaded existing purchases
            await MainActor.run {
                self.hasCompletedInitialLoad = true
                self.isInitialLoad = false
            }
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func setAuthManager(_ authManager: FirebaseAuthManager) {
        self.authManager = authManager
        
        let newUserUID = authManager.currentUser?.firebaseUID
        if newUserUID != currentUserUID {
            print("🔄 User changed from \(currentUserUID ?? "none") to \(newUserUID ?? "none") - clearing processed transactions")
            processedTransactionsForCurrentUser.removeAll()
            currentUserUID = newUserUID
            isInitialLoad = true
            
            Task {
                await updatePurchasedProducts()
                await MainActor.run {
                    self.hasCompletedInitialLoad = true
                    self.isInitialLoad = false
                }
            }
        } else {
            // Always update after setting auth manager to ensure fresh data
            Task {
                await updatePurchasedProducts()
            }
        }
    }
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedProducts = try await Product.products(for: productIDs)
            
            if loadedProducts.isEmpty {
                products = []
                errorMessage = "Subscription products not yet configured in App Store Connect"
            } else {
                products = loadedProducts.sorted { product1, product2 in
                    let level1 = getSubscriptionLevel(for: product1.id) ?? .trial
                    let level2 = getSubscriptionLevel(for: product2.id) ?? .trial
                    
                    if level1 != level2 {
                        return level1.sortOrder < level2.sortOrder
                    }
                    
                    if product1.id.contains("monthly") && product2.id.contains("yearly") {
                        return true
                    }
                    if product1.id.contains("yearly") && product2.id.contains("monthly") {
                        return false
                    }
                    return product1.price < product2.price
                }
            }
            
        } catch {
            errorMessage = "Failed to load subscription products: \(error.localizedDescription)"
            products = []
            print("❌ StoreKit product loading failed: \(error)")
        }
        
        isLoading = false
    }
    
    func purchase(_ product: Product) async {
        guard !purchaseInProgress else {
            print("⚠️ Purchase already in progress")
            return
        }
        
        purchaseInProgress = true
        isLoading = true
        errorMessage = nil
        
        print("🛒 Starting purchase for: \(product.displayName) (\(product.id))")
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                print("✅ Purchase successful, verifying transaction...")
                
                let transaction = try checkVerified(verification)
                
                // CRITICAL FIX: Use the original product ID instead of transaction's product ID
                // This fixes sandbox issues where Apple returns wrong product IDs
                print("💳 Processing purchase: intended=\(product.id), transaction=\(transaction.productID)")
                await handleSuccessfulPurchaseWithCorrectProduct(transaction, intendedProductID: product.id)
                processedTransactionsForCurrentUser.insert(transaction.id)
                
                await transaction.finish()
                print("🎉 Purchase completed successfully!")
                
            case .userCancelled:
                print("🚫 User cancelled purchase")
                errorMessage = nil
                
            case .pending:
                print("⏳ Purchase is pending approval")
                errorMessage = "Purchase is pending approval from your payment method"
                
            @unknown default:
                print("❓ Unknown purchase result")
                errorMessage = "Unknown purchase result"
            }
            
        } catch {
            print("❌ Purchase failed: \(error)")
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
        
        purchaseInProgress = false
        isLoading = false
    }
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Restoring purchases...")
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            
            // Only sync subscription status if user is a paying customer
            if let user = authManager?.currentUser {
                // Don't auto-upgrade shared access users during restore
                if user.subscriptionLevel != .sharedAccess {
                    await syncSubscriptionStatus()
                }
            }
            
            print("✅ Purchases restored successfully")
            
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { @MainActor in
            print("👂 Starting transaction listener...")
            
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    print("📬 Received transaction update: \(transaction.productID) (ID: \(transaction.id))")
                    
                    // CRITICAL: Don't process transactions during initial load UNLESS it's a new purchase
                    if self.isInitialLoad && !self.purchaseInProgress {
                        print("⏸️ Skipping transaction during initial load (not a new purchase)")
                        await transaction.finish()
                        continue
                    }
     
                    if let user = self.authManager?.currentUser,
                       user.subscriptionLevel == .sharedAccess,
                       !self.purchaseInProgress {
                        print("⏸️ Skipping auto-processing for shared access user")
                        await transaction.finish()
                        continue
                    }
                    
                    // Only process if not already processed for CURRENT USER
                    if !self.processedTransactionsForCurrentUser.contains(transaction.id) {
                        // Only handle if it's a new purchase or user explicitly restored
                        if self.purchaseInProgress || !self.hasCompletedInitialLoad {
                            print("🔄 Processing new transaction for current user: \(transaction.id)")
                            await self.handleSuccessfulPurchase(transaction)
                            self.processedTransactionsForCurrentUser.insert(transaction.id)
                        } else {
                            print("⏸️ Skipping background transaction (not actively purchasing)")
                        }
                        await transaction.finish()
                    } else {
                        print("⚠️ Transaction \(transaction.id) already processed for current user, skipping")
                        await transaction.finish()
                    }
                    
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        var seenTransactionIDs: Set<UInt64> = []
        
        print("🔍 Checking current entitlements...")
        
        // Don't check entitlements if we're actively purchasing
        if purchaseInProgress {
            print("⏸️ Purchase in progress, skipping entitlement check")
            return
        }
        
        // Don't auto-process for shared access users who aren't actively upgrading
        if let user = authManager?.currentUser,
           user.subscriptionLevel == .sharedAccess {
            print("⏸️ Shared access user, skipping automatic entitlement check")
            self.purchasedProductIDs = []
            return
        }
        
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                    seenTransactionIDs.insert(transaction.id)
                    print("📦 Found active entitlement: \(transaction.productID) (ID: \(transaction.id))")
                }
            } catch {
                print("❌ Failed to verify entitlement: \(error)")
            }
        }
        
        if !seenTransactionIDs.isEmpty {
            processedTransactionsForCurrentUser.formUnion(seenTransactionIDs)
        }
        
        self.purchasedProductIDs = purchasedIDs
        print("✅ Updated purchased product IDs: \(purchasedIDs)")
        print("📝 Tracking \(processedTransactionsForCurrentUser.count) processed transactions for current user")
    }
    
    private func handleSuccessfulPurchaseWithCorrectProduct(_ transaction: StoreKit.Transaction, intendedProductID: String) async {
        print("🎯 Processing purchase: intended=\(intendedProductID), transaction=\(transaction.productID) (ID: \(transaction.id))")
        
        guard let authManager = self.authManager else {
            print("❌ No auth manager available - cannot update subscription")
            errorMessage = "Unable to update subscription. Please restart the app and restore purchases."
            return
        }
        
        do {
            guard let subscriptionLevel = getSubscriptionLevel(for: intendedProductID) else {
                print("❌ Unknown intended product ID: \(intendedProductID)")
                return
            }
            
            print("⬆️ Setting subscription to \(subscriptionLevel.rawValue) based on intended purchase: \(intendedProductID)")
            
            // Update subscription in Firebase
            try await authManager.updateSubscriptionLevel(subscriptionLevel, transactionId: String(transaction.id))
            
            // Force refresh the user from Firebase
            await authManager.refreshCurrentUser()
            
            // CRITICAL: Wait a moment for the refresh to propagate
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Now force a complete re-initialization
            self.currentUserUID = nil
            self.setAuthManager(authManager)
            
            print("✅ Successfully updated subscription to \(subscriptionLevel.rawValue) in Firebase")
            
        } catch {
            print("❌ Failed to update subscription in Firebase: \(error)")
            errorMessage = "Purchase successful but failed to update account. Please contact support."
        }
    }
    
    func clearAllSandboxTransactions() async {
        print("🧹 Clearing all sandbox transactions...")
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                print("Finishing transaction: \(transaction.id)")
                await transaction.finish()
            }
        }
        processedTransactionsForCurrentUser.removeAll()
        purchasedProductIDs.removeAll()
    }
    
    // Keep the original method for background transaction updates
    private func handleSuccessfulPurchase(_ transaction: StoreKit.Transaction) async {
        print("🎯 Processing successful purchase: \(transaction.productID) (Transaction ID: \(transaction.id))")
        
        guard let authManager = self.authManager else {
            print("❌ No auth manager available - cannot update subscription")
            errorMessage = "Unable to update subscription. Please restart the app and restore purchases."
            return
        }
        
        // Don't auto-process for shared access users
        if authManager.currentUser?.subscriptionLevel == .sharedAccess {
            print("⏸️ Not auto-processing transaction for shared access user")
            return
        }
        
        do {
            guard let subscriptionLevel = getSubscriptionLevel(for: transaction.productID) else {
                print("❌ Unknown product ID: \(transaction.productID)")
                return
            }
            
            print("⬆️ Setting subscription to \(subscriptionLevel.rawValue) for current user")
            try await authManager.updateSubscriptionLevel(subscriptionLevel, transactionId: String(transaction.id))
            await updatePurchasedProducts()
            print("✅ Successfully updated subscription to \(subscriptionLevel.rawValue) in Firebase")
            
        } catch {
            print("❌ Failed to update subscription in Firebase: \(error)")
            errorMessage = "Purchase successful but failed to update account. Please contact support."
        }
    }
    
    func clearSandboxTransactions() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
            }
        }
    }
    
    private func syncSubscriptionStatus() async {
        print("🔄 Syncing subscription status with Firebase...")
        
        guard let authManager = self.authManager else {
            print("❌ No auth manager available for sync")
            return
        }
        
        // Don't sync for shared access users
        if authManager.currentUser?.subscriptionLevel == .sharedAccess {
            print("⏸️ Not syncing subscription for shared access user")
            return
        }
        
        // Find the highest tier active subscription
        var activeSubscription: StoreKit.Transaction?
        var highestLevel: SubscriptionLevel?
        
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.revocationDate == nil {
                    if let level = getSubscriptionLevel(for: transaction.productID) {
                        if highestLevel == nil || level.sortOrder > (highestLevel?.sortOrder ?? 0) {
                            activeSubscription = transaction
                            highestLevel = level
                        }
                    }
                }
            } catch {
                print("❌ Failed to verify transaction during sync: \(error)")
            }
        }
        
        if let subscription = activeSubscription, let level = highestLevel {
            print("🎯 Found active subscription: \(subscription.productID) - Level: \(level.rawValue)")
            do {
                try await authManager.updateSubscriptionLevel(level, transactionId: String(subscription.id))
                print("✅ Synced subscription status: \(level.rawValue)")
            } catch {
                print("❌ Failed to sync subscription status: \(error)")
            }
        } else {
            print("ℹ️ No active subscriptions found during restore")
        }
    }
    
    // MARK: - Helper Methods
    
    func isProductPurchased(_ productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
    }
    
    func getSubscriptionLevel(for productID: String) -> SubscriptionLevel? {
        switch productID {
        case "com.coachcaddie.pro.monthly", "com.coachcaddie.pro.yearly":
            return .coach
        case "com.coachcaddie.premium.monthly", "com.coachcaddie.premium.yearly":
            return .proCoach
        default:
            return nil
        }
    }
}

// MARK: - Store Errors
enum StoreError: Error {
    case failedVerification
}

extension SubscriptionLevel {
    var sortOrder: Int {
        switch self {
        case .trial: return 0
        case .coach: return 1
        case .proCoach: return 2
        case .free: return 3
        case .sharedAccess: return 4
        case .cancelled: return 5
        case .expired: return 6
        }
    }
}
