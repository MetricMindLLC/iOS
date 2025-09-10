import SwiftUI
import StoreKit

// MARK: - Expired Trial Upgrade View
struct ExpiredTrialUpgradeView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @StateObject private var storeKit = StoreKitManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProduct: Product?
    @State private var showingPurchase = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("Continue with Coach Caddie")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Your trial has ended. Choose a plan to keep using all features.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Subscription Options
                    if storeKit.isLoading {
                        ProgressView("Loading plans...")
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(storeKit.products, id: \.id) { product in
                                UpgradeOptionCard(
                                    product: product,
                                    isSelected: selectedProduct?.id == product.id,
                                    onSelect: {
                                        selectedProduct = product
                                    }
                                )
                            }
                        }
                    }
                    
                    // Continue Button
                    if let product = selectedProduct {
                        Button("Continue with \(product.displayName)") {
                            purchaseProduct(product)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .disabled(storeKit.purchaseInProgress)
                    }
                    
                    // Info text about access
                    VStack(spacing: 8) {
                        Text("You can still:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("View your existing team data")
                                Spacer()
                            }
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Join teams using invite codes")
                                Spacer()
                            }
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Export your data")
                                Spacer()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Upgrade Required")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Later") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            storeKit.setAuthManager(authManager)
            Task {
                await storeKit.loadProducts()
            }
        }
    }
    
    private func purchaseProduct(_ product: Product) {
        showingPurchase = true
        
        Task {
            await storeKit.purchase(product)
            
            await MainActor.run {
                if storeKit.errorMessage == nil {
                    // Purchase successful, dismiss modal
                    dismiss()
                }
                showingPurchase = false
            }
        }
    }
}

// MARK: - Upgrade Option Card
struct UpgradeOptionCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var subscriptionLevel: SubscriptionLevel? {
        switch product.id {
        case let id where id.contains("pro"): return .pro
        case let id where id.contains("premium"): return .premium
        case let id where id.contains("club"): return .club
        default: return nil
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if product.id.contains("premium") {
                            Text("POPULAR")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(product.price.formatted(.currency(code: "USD")))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    if let level = subscriptionLevel {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(level.features.prefix(3)), id: \.self) { feature in
                                HStack {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text(feature)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Feature Restriction View
struct FeatureRestrictionView: View {
    let featureName: String
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("\(featureName) Requires Upgrade")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Your trial has ended. Upgrade to continue using this feature.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("View Plans") {
                onUpgrade()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(8)
        }
        .padding()
    }
}
