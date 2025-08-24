import StoreKit
import SwiftUI

@MainActor
class StoreKitManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let productIDs = [
        "com.coachcaddie.pro.monthly",
        "com.coachcaddie.pro.yearly", 
        "com.coachcaddie.premium.monthly",
        "com.coachcaddie.premium.yearly"
    ]
    
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }
    
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateSubscriptionStatus(for: transaction)
                await transaction.finish()
                
            case .userCancelled:
                break
                
            case .pending:
                errorMessage = "Purchase is pending approval"
                
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func restorePurchases() async {
        isLoading = true
        
        try? await AppStore.sync()
        await updatePurchasedProducts()
        
        isLoading = false
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateSubscriptionStatus(for: transaction)
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
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
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
    }
    
    private func updateSubscriptionStatus(for transaction: Transaction) async {
        // Convert StoreKit transaction to your subscription level
        let subscriptionLevel: SubscriptionLevel
        
        switch transaction.productID {
        case "com.coachcaddie.pro.monthly", "com.coachcaddie.pro.yearly":
            subscriptionLevel = .pro
        case "com.coachcaddie.premium.monthly", "com.coachcaddie.premium.yearly":
            subscriptionLevel = .premium
        default:
            return
        }
        
        // Update user subscription in Firebase
        // You'll need to inject your FirebaseAuthManager here
        // await authManager.updateSubscriptionLevel(subscriptionLevel)
    }
}

enum StoreError: Error {
    case failedVerification
}