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
    private weak var authManager: FirebaseAuthManager?  // CHANGED: Made weak to avoid retain cycles
    
    // Updated with Club subscription product IDs
    private let productIDs = [
        "com.coachcaddie.pro.monthly",
        "com.coachcaddie.pro.yearly",
        "com.coachcaddie.premium.monthly",
        "com.coachcaddie.premium.yearly",
        "com.coachcaddie.club.monthly",        // NEW: Club monthly
        "com.coachcaddie.club.yearly"          // NEW: Club yearly
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
    }
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Try to load real products from App Store Connect
            let loadedProducts = try await Product.products(for: productIDs)
            
            if loadedProducts.isEmpty {
                // No products configured yet - show development message
                products = []
                errorMessage = "Subscription products not yet configured in App Store Connect"
            } else {
                products = loadedProducts.sorted { product1, product2 in
                    // Sort by subscription level (pro < premium < club), then by duration (monthly < yearly)
                    let level1 = getSubscriptionLevel(for: product1.id) ?? .trial
                    let level2 = getSubscriptionLevel(for: product2.id) ?? .trial
                    
                    if level1 != level2 {
                        return level1.sortOrder < level2.sortOrder
                    }
                    
                    // Same level - sort monthly before yearly
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
                
                // CHANGED: Update Firebase subscription status BEFORE finishing transaction
                await handleSuccessfulPurchase(transaction)
                
                // Finish the transaction
                await transaction.finish()
                
                print("🎉 Purchase completed successfully!")
                
            case .userCancelled:
                print("🚫 User cancelled purchase")
                errorMessage = nil // Don't show error for user cancellation
                
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
            
            // Check for any active subscriptions and update Firebase
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
                    print("📬 Received transaction update: \(transaction.productID)")
                    
                    await self.handleSuccessfulPurchase(transaction)
                    await transaction.finish()
                    
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            print("❌ Transaction verification failed")
            throw StoreError.failedVerification
        case .verified(let safe):
            print("✅ Transaction verified successfully")
            return safe
        }
    }
    
    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        print("🔍 Checking current entitlements...")
        
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Only include non-revoked transactions
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                    print("📦 Found active entitlement: \(transaction.productID)")
                }
            } catch {
                print("❌ Failed to verify entitlement: \(error)")
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
        print("✅ Updated purchased product IDs: \(purchasedIDs)")
    }
    
    // CHANGED: Enhanced to properly update Firebase subscription
    private func handleSuccessfulPurchase(_ transaction: StoreKit.Transaction) async {
        print("🎯 Processing successful purchase: \(transaction.productID)")
        
        guard let authManager = self.authManager else {
            print("❌ No auth manager available - cannot update subscription")
            errorMessage = "Unable to update subscription. Please restart the app and restore purchases."
            return
        }
        
        do {
            // CHANGED: Get the subscription level from the product ID
            guard let subscriptionLevel = getSubscriptionLevel(for: transaction.productID) else {
                print("❌ Unknown product ID: \(transaction.productID)")
                return
            }
            
            // CHANGED: Update Firebase with the new subscription level directly
            try await authManager.updateSubscriptionLevel(subscriptionLevel, transactionId: String(transaction.id))
            
            // Update local purchased products
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
                        // CHANGED: Better priority checking
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
                // CHANGED: Update with the specific subscription level
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
        case let id where id.contains("pro"):
            return .pro
        case let id where id.contains("premium"):
            return .premium
        case let id where id.contains("club"):
            return .club
        default:
            return nil
        }
    }
    
    func canUpgrade(from currentLevel: SubscriptionLevel, to product: Product) -> Bool {
        guard let targetLevel = getSubscriptionLevel(for: product.id) else { return false }
        
        switch currentLevel {
        case .trial, .cancelled, .expired:
            return true
        case .pro:
            return targetLevel == .premium || targetLevel == .club
        case .premium:
            return targetLevel == .club
        case .club, .free:
            return false
        case .sharedAccess:
            return targetLevel == .pro || targetLevel == .premium || targetLevel == .club
        }
    }
}

// MARK: - Subscription Level Extensions for Sorting
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

enum StoreError: Error {
    case failedVerification
    case productsNotFound
    case authManagerNotSet
    
    var localizedDescription: String {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .productsNotFound:
            return "No subscription products found"
        case .authManagerNotSet:
            return "Authentication manager not configured"
        }
    }
}
