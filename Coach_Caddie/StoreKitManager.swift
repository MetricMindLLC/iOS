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
    
    // Updated with Club subscription product IDs
    private let productIDs = [
        "com.coachcaddie.pro.monthly",
        "com.coachcaddie.pro.yearly",
        "com.coachcaddie.premium.monthly",
        "com.coachcaddie.premium.yearly",
        "com.coachcaddie.club.monthly",
        "com.coachcaddie.club.yearly"
    ]
    
    private var updateListenerTask: Task<Void, Error>?
    
    init(authManager: FirebaseAuthManager? = nil) {
        self.authManager = authManager
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func setAuthManager(_ authManager: FirebaseAuthManager) {
        self.authManager = authManager
        
        // CRITICAL FIX: Reset processed transactions when user changes
        let newUserUID = authManager.currentUser?.firebaseUID
        if newUserUID != currentUserUID {
            print("🔄 User changed from \(currentUserUID ?? "none") to \(newUserUID ?? "none") - clearing processed transactions")
            processedTransactionsForCurrentUser.removeAll()
            currentUserUID = newUserUID
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
            await syncSubscriptionStatus()
            
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
                    
                    // FIXED: Only process if not already processed for CURRENT USER
                    if !self.processedTransactionsForCurrentUser.contains(transaction.id) {
                        print("🔄 Processing new transaction for current user: \(transaction.id)")
                        await self.handleSuccessfulPurchase(transaction)
                        self.processedTransactionsForCurrentUser.insert(transaction.id)
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
        
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Only include non-revoked transactions
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                    seenTransactionIDs.insert(transaction.id)
                    print("📦 Found active entitlement: \(transaction.productID) (ID: \(transaction.id))")
                }
            } catch {
                print("❌ Failed to verify entitlement: \(error)")
            }
        }
        
        // FIXED: Only update processed transactions for current user
        if !seenTransactionIDs.isEmpty {
            processedTransactionsForCurrentUser.formUnion(seenTransactionIDs)
        }
        
        self.purchasedProductIDs = purchasedIDs
        print("✅ Updated purchased product IDs: \(purchasedIDs)")
        print("📝 Tracking \(processedTransactionsForCurrentUser.count) processed transactions for current user")
    }
    
    // FIXED: New method that uses the correct product ID instead of transaction's product ID
    private func handleSuccessfulPurchaseWithCorrectProduct(_ transaction: StoreKit.Transaction, intendedProductID: String) async {
        print("🎯 Processing purchase: intended=\(intendedProductID), transaction=\(transaction.productID) (ID: \(transaction.id))")
        
        guard let authManager = self.authManager else {
            print("❌ No auth manager available - cannot update subscription")
            errorMessage = "Unable to update subscription. Please restart the app and restore purchases."
            return
        }
        
        do {
            // CRITICAL FIX: Use the intended product ID, not the transaction's product ID
            guard let subscriptionLevel = getSubscriptionLevel(for: intendedProductID) else {
                print("❌ Unknown intended product ID: \(intendedProductID)")
                return
            }
            
            print("⬆️ Setting subscription to \(subscriptionLevel.rawValue) based on intended purchase: \(intendedProductID)")
            try await authManager.updateSubscriptionLevel(subscriptionLevel, transactionId: String(transaction.id))
            await updatePurchasedProducts()
            print("✅ Successfully updated subscription to \(subscriptionLevel.rawValue) in Firebase")
            
        } catch {
            print("❌ Failed to update subscription in Firebase: \(error)")
            errorMessage = "Purchase successful but failed to update account. Please contact support."
        }
    }
    
    // Keep the original method for background transaction updates
    private func handleSuccessfulPurchase(_ transaction: StoreKit.Transaction) async {
        print("🎯 Processing successful purchase: \(transaction.productID) (Transaction ID: \(transaction.id))")
        
        guard let authManager = self.authManager else {
            print("❌ No auth manager available - cannot update subscription")
            errorMessage = "Unable to update subscription. Please restart the app and restore purchases."
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
    
    private func syncSubscriptionStatus() async {
        print("🔄 Syncing subscription status with Firebase...")
        
        guard let authManager = self.authManager else {
            print("❌ No auth manager available for sync")
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
            return .pro
        case "com.coachcaddie.premium.monthly", "com.coachcaddie.premium.yearly":
            return .premium
        case "com.coachcaddie.club.monthly", "com.coachcaddie.club.yearly":
            return .club
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
        case .pro: return 1
        case .premium: return 2
        case .club: return 3
        case .free: return 4
        case .sharedAccess: return 5
        case .cancelled: return 6
        case .expired: return 7
        }
    }
}
