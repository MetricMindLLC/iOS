import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var storeKit: StoreKitManager
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingConfirmation = false
    @State private var selectedProduct: Product?
    @State private var isDowngrade = false
    
    // Initialize with auth manager reference
    init() {
        self._storeKit = StateObject(wrappedValue: StoreKitManager())
    }
    
    var currentSubscriptionLevel: SubscriptionLevel {
        authManager.currentUser?.subscriptionLevel ?? .trial
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if storeKit.isLoading {
                        loadingSection
                    } else if storeKit.products.isEmpty {
                        emptyStateSection
                    } else {
                        currentPlanSection
                        availablePlansSection
                    }
                    
                    if let error = storeKit.errorMessage {
                        errorSection(error)
                    }
                    
                    if !storeKit.products.isEmpty {
                        manageSubscriptionSection
                        restoreSection
                    }
                }
                .padding()
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            // Set the auth manager reference and refresh products
            storeKit.setAuthManager(authManager)
            Task {
                await storeKit.loadProducts()
                // updatePurchasedProducts is called automatically in StoreKitManager's init
            }
        }
        .alert("Subscription Updated!", isPresented: $showingSuccessAlert) {
            Button("Great!") { dismiss() }
        } message: {
            Text(successMessage)
        }
        .confirmationDialog(
            isDowngrade ? "Confirm Downgrade" : "Confirm Upgrade",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button(isDowngrade ? "Downgrade" : "Upgrade", role: isDowngrade ? .destructive : nil) {
                if let product = selectedProduct {
                    Task {
                        await purchaseProduct(product)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                selectedProduct = nil
                isDowngrade = false
            }
        } message: {
            if let product = selectedProduct {
                if isDowngrade {
                    Text("Are you sure you want to downgrade to \(getSubscriptionName(for: product))? This change will take effect at the end of your current billing period.")
                } else {
                    Text("Upgrade to \(getSubscriptionName(for: product)) for \(product.displayPrice)?")
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Manage Subscription")
                .font(.title)
                .fontWeight(.bold)
            
            if let user = authManager.currentUser {
                subscriptionStatusView(for: user)
            }
        }
    }
    
    private var currentPlanSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Plan")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentSubscriptionLevel.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let activeProduct = getCurrentlyActiveProduct() {
                            Text(activeProduct.displayPrice)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if activeProduct.subscription?.subscriptionPeriod.unit == .year {
                                Label("Annual billing", systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else if activeProduct.subscription?.subscriptionPeriod.unit == .month {
                                Label("Monthly billing", systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        } else if currentSubscriptionLevel == .trial {
                            Text("Free trial - \(authManager.currentUser?.trialDaysRemaining ?? 0) days remaining")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundColor(.green)
                }
                
                // Current plan features
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(currentSubscriptionLevel.features.prefix(5), id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(feature)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green, lineWidth: 2)
            )
        }
    }
    
    private var availablePlansSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Plans")
                .font(.headline)
            
            ForEach(storeKit.products.sorted(by: sortProducts), id: \.id) { product in
                SubscriptionPlanCard(
                    product: product,
                    currentLevel: currentSubscriptionLevel,
                    isCurrentPlan: isCurrentPlan(product),
                    isPurchased: storeKit.isProductPurchased(product.id),
                    isLoading: storeKit.purchaseInProgress,
                    onSelect: {
                        handlePlanSelection(product)
                    }
                )
            }
        }
    }
    
    private var manageSubscriptionSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            Button(action: openSubscriptionManagement) {
                HStack {
                    Image(systemName: "gear")
                    Text("Manage in Settings")
                        .font(.subheadline)
                }
            }
            .foregroundColor(.blue)
            
            Text("Cancel or change billing in your device's subscription settings")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func subscriptionStatusView(for user: User) -> some View {
        VStack(spacing: 8) {
            if user.subscriptionLevel == .trial {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("\(user.trialDaysRemaining) days left in trial")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else if user.subscriptionLevel == .cancelled {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Subscription cancelled")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(storeKit.purchaseInProgress ? "Processing change..." : "Loading subscription options...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Unable to Load Subscriptions")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Please check your internet connection and try again.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    await storeKit.loadProducts()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
                .foregroundColor(.red)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    await storeKit.loadProducts()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var restoreSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                Task {
                    await storeKit.restorePurchases()
                }
            }) {
                HStack {
                    if storeKit.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text("Restore Purchases")
                }
            }
            .disabled(storeKit.isLoading)
            .foregroundColor(.blue)
            
            Text("Tap if you previously purchased on another device")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentlyActiveProduct() -> Product? {
        // Find the product that matches the current subscription
        return storeKit.products.first { product in
            storeKit.isProductPurchased(product.id) &&
            getSubscriptionLevel(for: product) == currentSubscriptionLevel
        }
    }
    
    private func isCurrentPlan(_ product: Product) -> Bool {
        let productLevel = getSubscriptionLevel(for: product)
        return productLevel == currentSubscriptionLevel && storeKit.isProductPurchased(product.id)
    }
    
    private func getSubscriptionLevel(for product: Product) -> SubscriptionLevel? {
        if product.id.contains("pro") {
            return .pro
        } else if product.id.contains("premium") {
            return .premium
        } else if product.id.contains("club") {
            return .club
        }
        return nil
    }
    
    private func getSubscriptionName(for product: Product) -> String {
        if product.id.contains("pro") {
            return "Pro"
        } else if product.id.contains("premium") {
            return "Premium"
        } else if product.id.contains("club") {
            return "Club"
        }
        return "Unknown"
    }
    
    private func sortProducts(_ p1: Product, _ p2: Product) -> Bool {
        let level1 = getSubscriptionLevel(for: p1) ?? .trial
        let level2 = getSubscriptionLevel(for: p2) ?? .trial
        
        if level1 != level2 {
            return level1.sortOrder < level2.sortOrder
        }
        
        // Same level - sort monthly before yearly
        if p1.id.contains("monthly") && p2.id.contains("yearly") {
            return true
        }
        if p1.id.contains("yearly") && p2.id.contains("monthly") {
            return false
        }
        return p1.price < p2.price
    }
    
    private func handlePlanSelection(_ product: Product) {
        guard !isCurrentPlan(product) else { return }
        
        selectedProduct = product
        
        // Determine if this is a downgrade
        if let productLevel = getSubscriptionLevel(for: product) {
            isDowngrade = productLevel.sortOrder < currentSubscriptionLevel.sortOrder
        } else {
            isDowngrade = false
        }
        
        showingConfirmation = true
    }
    
    private func purchaseProduct(_ product: Product) async {
        await storeKit.purchase(product)
        
        // Check if purchase was successful
        if storeKit.errorMessage == nil {
            await MainActor.run {
                if let level = getSubscriptionLevel(for: product) {
                    successMessage = isDowngrade ?
                        "Your plan will change to \(level.displayName) at the end of your current billing period." :
                        "Successfully upgraded to \(level.displayName)!"
                }
                showingSuccessAlert = true
            }
        }
    }
    
    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Subscription Plan Card
struct SubscriptionPlanCard: View {
    let product: Product
    let currentLevel: SubscriptionLevel
    let isCurrentPlan: Bool
    let isPurchased: Bool
    let isLoading: Bool
    let onSelect: () -> Void
    
    private var subscriptionLevel: SubscriptionLevel {
        if product.id.contains("pro") {
            return .pro
        } else if product.id.contains("premium") {
            return .premium
        } else if product.id.contains("club") {
            return .club
        } else {
            return .trial
        }
    }
    
    private var isUpgrade: Bool {
        subscriptionLevel.sortOrder > currentLevel.sortOrder
    }
    
    private var isDowngrade: Bool {
        subscriptionLevel.sortOrder < currentLevel.sortOrder
    }
    
    private var buttonText: String {
        if isCurrentPlan {
            return "Current Plan"
        } else if isUpgrade {
            return "Upgrade"
        } else if isDowngrade {
            return "Downgrade"
        } else {
            return "Select"
        }
    }
    
    private var buttonColor: Color {
        if isCurrentPlan {
            return .gray
        } else if isUpgrade {
            return .green
        } else if isDowngrade {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(subscriptionLevel.displayName)
                            .font(.headline)
                        
                        if isCurrentPlan {
                            Text("CURRENT")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        
                        // Billing period indicator
                        if let period = product.subscription?.subscriptionPeriod {
                            Text(period.unit == .year ? "Yearly" : "Monthly")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if product.subscription?.subscriptionPeriod.unit == .year {
                        Text("Save 17% vs monthly")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Button(action: onSelect) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Text(buttonText)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(buttonColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isCurrentPlan || isLoading)
            }
            
            // Features for this level
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(subscriptionLevel.features.prefix(3).enumerated()), id: \.offset) { _, feature in
                    HStack {
                        Image(systemName: "checkmark")
                            .foregroundColor(isCurrentPlan ? .green : .secondary)
                            .font(.caption)
                        Text(feature)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if subscriptionLevel.features.count > 3 {
                    Text("+ \(subscriptionLevel.features.count - 3) more features")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(isCurrentPlan ? Color.green.opacity(0.05) : Color(.systemGray6))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentPlan ? Color.green : Color(.systemGray4), lineWidth: isCurrentPlan ? 2 : 1)
        )
        .cornerRadius(12)
    }
}
