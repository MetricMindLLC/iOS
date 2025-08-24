import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var storeKit = StoreKitManager()
    @EnvironmentObject var authManager: FirebaseAuthManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if storeKit.isLoading {
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        subscriptionOptions
                    }
                    
                    if let error = storeKit.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    restoreButton
                }
                .padding()
            }
            .navigationTitle("Choose Your Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            await storeKit.loadProducts()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Upgrade Your Coaching")
                .font(.title)
                .fontWeight(.bold)
            
            if let user = authManager.currentUser, user.subscriptionLevel == .trial {
                Text("\(user.trialDaysRemaining) days left in trial")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    private var subscriptionOptions: some View {
        VStack(spacing: 16) {
            ForEach(storeKit.products, id: \.id) { product in
                SubscriptionOptionView(
                    product: product,
                    isSelected: false,
                    onPurchase: {
                        Task {
                            await storeKit.purchase(product)
                        }
                    }
                )
            }
        }
    }
    
    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task {
                await storeKit.restorePurchases()
            }
        }
        .foregroundColor(.blue)
    }
}

struct SubscriptionOptionView: View {
    let product: Product
    let isSelected: Bool
    let onPurchase: () -> Void
    
    var subscriptionLevel: SubscriptionLevel {
        if product.id.contains("pro") {
            return .pro
        } else {
            return .premium
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(subscriptionLevel.displayName)
                        .font(.headline)
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Button("Subscribe", action: onPurchase)
                    .buttonStyle(.borderedProminent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(subscriptionLevel.features, id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                        Text(feature)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}