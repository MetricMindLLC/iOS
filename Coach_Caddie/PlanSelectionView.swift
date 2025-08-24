import SwiftUI
import StoreKit

struct PlanSelectionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPlan: SubscriptionLevel = .trial
    
    let onPlanSelected: (SubscriptionLevel) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Choose Your Plan")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Start managing your team with the perfect plan for you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Plan Cards
                    VStack(spacing: 16) {
                        // Free Trial Card
                        PlanCard(
                            plan: .trial,
                            isSelected: selectedPlan == .trial,
                            isPopular: false,
                            onSelect: { selectedPlan = .trial }
                        )
                        
                        // Pro Plan Card
                        PlanCard(
                            plan: .pro,
                            isSelected: selectedPlan == .pro,
                            isPopular: true,
                            onSelect: { selectedPlan = .pro }
                        )
                        
                        // Premium Plan Card
                        PlanCard(
                            plan: .premium,
                            isSelected: selectedPlan == .premium,
                            isPopular: false,
                            onSelect: { selectedPlan = .premium }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Continue Button
                    Button(action: handleContinue) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(selectedPlan == .trial ? "Start Free Trial" : "Subscribe & Continue")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Terms & Privacy
                    VStack(spacing: 8) {
                        Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if selectedPlan != .trial {
                            Text("Cancel anytime. Auto-renewal can be turned off in your Apple ID settings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            subscriptionManager.loadProducts()
        }
    }
    
    private func handleContinue() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        if selectedPlan == .trial {
            // Start free trial immediately
            onPlanSelected(.trial)
            isLoading = false
        } else {
            // Purchase subscription
            Task {
                do {
                    let success = try await subscriptionManager.purchase(plan: selectedPlan)
                    await MainActor.run {
                        if success {
                            onPlanSelected(selectedPlan)
                        } else {
                            errorMessage = "Purchase failed. Please try again."
                        }
                        isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Purchase error: \(error.localizedDescription)"
                        isLoading = false
                    }
                }
            }
        }
    }
}

struct PlanCard: View {
    let plan: SubscriptionLevel
    let isSelected: Bool
    let isPopular: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with price and popular badge
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plan.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if isPopular {
                                Text("POPULAR")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(plan.monthlyPrice)
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        if plan != .trial {
                            Text("or \(plan.yearlyPrice) yearly")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                
                // Features List
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plan.features, id: \.self) { feature in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.green)
                                .frame(width: 12)
                            
                            Text(feature)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: isSelected ? Color.blue.opacity(0.2) : Color.black.opacity(0.1), 
                           radius: isSelected ? 8 : 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchaseState: PurchaseState = .idle
    
    private var productIds: Set<String> = [
        "com.coachcaddie.pro.monthly",
        "com.coachcaddie.pro.yearly", 
        "com.coachcaddie.premium.monthly",
        "com.coachcaddie.premium.yearly"
    ]
    
    enum PurchaseState {
        case idle
        case purchasing
        case purchased
        case failed(Error)
    }
    
    func loadProducts() {
        Task {
            do {
                let products = try await Product.products(for: productIds)
                await MainActor.run {
                    self.products = products.sorted { $0.price < $1.price }
                }
            } catch {
                print("Failed to load products: \(error)")
            }
        }
    }
    
    func purchase(plan: SubscriptionLevel) async throws -> Bool {
        guard let product = getProduct(for: plan) else {
            throw SubscriptionError.productNotFound
        }
        
        purchaseState = .purchasing
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    purchaseState = .purchased
                    return true
                case .unverified:
                    purchaseState = .failed(SubscriptionError.unverifiedTransaction)
                    return false
                }
            case .userCancelled:
                purchaseState = .idle
                return false
            case .pending:
                purchaseState = .idle
                return false
            @unknown default:
                purchaseState = .failed(SubscriptionError.unknownError)
                return false
            }
        } catch {
            purchaseState = .failed(error)
            throw error
        }
    }
    
    private func getProduct(for plan: SubscriptionLevel) -> Product? {
        let productId: String
        
        switch plan {
        case .pro:
            productId = "com.coachcaddie.pro.monthly" // Default to monthly
        case .premium:
            productId = "com.coachcaddie.premium.monthly" // Default to monthly
        default:
            return nil
        }
        
        return products.first { $0.id == productId }
    }
}

enum SubscriptionError: LocalizedError {
    case productNotFound
    case unverifiedTransaction
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .unverifiedTransaction:
            return "Transaction could not be verified"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

#Preview {
    PlanSelectionView { plan in
        print("Selected plan: \(plan)")
    }
}