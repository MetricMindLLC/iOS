import SwiftUI
import StoreKit

struct PlanSelectionView: View {
    @StateObject private var storeKit = StoreKitManager()
    @EnvironmentObject var authManager: FirebaseAuthManager
    
    @State private var selectedPlan: SubscriptionLevel = .trial
    @State private var isYearly: Bool = false  // NEW: Toggle for yearly/monthly
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                    
                    // NEW: Monthly/Yearly Toggle
                    billingPeriodToggle
                    
                    // Plan Cards - Using your existing SubscriptionLevel enum
                    VStack(spacing: 16) {
                        // Only show trial if user is eligible
                        if let user = authManager.currentUser, user.isTrialEligible {
                            // Free Trial Card
                            PlanCard(
                                plan: .trial,
                                isSelected: selectedPlan == .trial,
                                isPopular: false,
                                isYearly: isYearly,
                                onSelect: { selectedPlan = .trial }
                            )
                        }
                        
                        // Coach Plan Card (always show)
                        PlanCard(
                            plan: .coach,
                            isSelected: selectedPlan == .coach,
                            isPopular: true,
                            isYearly: isYearly,
                            onSelect: { selectedPlan = .coach }
                        )
                        
                        // Pro Coach Plan Card (always show)
                        PlanCard(
                            plan: .proCoach,
                            isSelected: selectedPlan == .proCoach,
                            isPopular: false,
                            isYearly: isYearly,
                            onSelect: { selectedPlan = .proCoach }
                        )
                        .padding(.horizontal)
                        
                        // Continue Button
                        Button(action: handleContinue) {
                            HStack {
                                if isLoading || storeKit.purchaseInProgress {
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
                        .disabled(isLoading || storeKit.purchaseInProgress)
                        .padding(.horizontal)
                        
                        // Error Message
                        if let errorMessage = errorMessage ?? storeKit.errorMessage {
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
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            storeKit.setAuthManager(authManager)
            Task {
                await storeKit.loadProducts()
            }
            
            // NEW: Set default plan based on trial eligibility
            if let user = authManager.currentUser, !user.isTrialEligible {
                selectedPlan = .coach  // Default to coach if trial not eligible
            }
        }
    }
    
    // MARK: - Monthly/Yearly Toggle Component
    private var billingPeriodToggle: some View {
        HStack {
            Text("Monthly")
                .font(.subheadline)
                .fontWeight(isYearly ? .regular : .semibold)
                .foregroundColor(isYearly ? .secondary : .primary)
            
            Toggle("", isOn: $isYearly)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .scaleEffect(0.8)
            
            HStack(spacing: 4) {
                Text("Yearly")
                    .font(.subheadline)
                    .fontWeight(isYearly ? .semibold : .regular)
                    .foregroundColor(isYearly ? .primary : .secondary)
                
                if isYearly {
                    Text("(Save 17%)")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: isYearly)
    }
    
    // MARK: - Actions
    private func handleContinue() {
            guard !isLoading && !storeKit.purchaseInProgress else { return }
            
            isLoading = true
            errorMessage = nil
            
            if selectedPlan == .trial {
                // Start free trial immediately - no purchase needed
                onPlanSelected(.trial)
                isLoading = false
            } else {
                // For paid plans, find the matching product and purchase through StoreKit
                Task {
                    await handlePaidPlanPurchase()
                }
            }
        }
        
        func handlePaidPlanPurchase() async {
            // Find the appropriate product for the selected plan and billing period
            let targetProductID: String
            
            switch selectedPlan {
            case .coach:
                targetProductID = isYearly ? "com.coachcaddie.pro.yearly" : "com.coachcaddie.pro.monthly"
            case .proCoach:
                targetProductID = isYearly ? "com.coachcaddie.premium.yearly" : "com.coachcaddie.premium.monthly"
            default:
                errorMessage = "Invalid plan selection"
                isLoading = false
                return
            }
            
            // Find the product in the loaded products
            guard let product = storeKit.products.first(where: { $0.id == targetProductID }) else {
                errorMessage = "Subscription products not available. Please try again later."
                isLoading = false
                return
            }
            
            // Purchase through StoreKit
            await storeKit.purchase(product)
            
            // Check if purchase was successful
            if storeKit.isProductPurchased(product.id) {
                // Purchase successful - complete the flow
                onPlanSelected(selectedPlan)
            }
            
            isLoading = false
        }
    }
    
    struct PlanCard: View {
        let plan: SubscriptionLevel // Using your existing enum!
        let isSelected: Bool
        let isPopular: Bool
        let isYearly: Bool  // NEW: Whether to show yearly pricing
        let onSelect: () -> Void
        
        var body: some View {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with price and popular badge
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(plan.displayName) // Using your existing property!
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
                            
                            // NEW: Show pricing based on isYearly toggle
                            if plan == .trial {
                                Text(plan.monthlyPrice) // Trial is always the same
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            } else {
                                Text(isYearly ? plan.yearlyPrice : plan.monthlyPrice)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                if isYearly {
                                    Text("Save 17% vs monthly")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isSelected ? .blue : .gray)
                    }
                    
                    // Features List - Using your existing features array!
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

#Preview {
    PlanSelectionView { plan in
        print("Selected plan: \(plan)")
    }
}
