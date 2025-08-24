import SwiftUI
import FirebaseAuth
import StoreKit

struct MembershipSelectionView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var selectedMembershipType: MembershipType = .coach
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCOPPAAgreement = false
    @State private var showingPlanSelection = false
    @State private var showingInviteRequired = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                
                Text("Are You Creating a Team?")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Choose based on what you want to do")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Main Options
            VStack(spacing: 16) {
                // Head Coach Option (Creates Teams)
                MembershipOptionCardUpdated(
                    title: "Head Coach",
                    subtitle: "I want to create and manage my own teams",
                    description: "Create teams, add players, manage games and practices. Requires subscription.",
                    icon: "person.badge.key.fill",
                    isSelected: selectedMembershipType == .coach
                ) {
                    selectedMembershipType = .coach
                }
                
                // Assistant/Invited Member Option
                MembershipOptionCardUpdated(
                    title: "Assistant Coach, Parent, or Viewer",
                    subtitle: "I was invited to join someone else's team",
                    description: "Join existing teams with invite codes. Free access to shared teams.",
                    icon: "ticket.fill",
                    isSelected: false,
                    isInviteOption: true
                ) {
                    showingInviteRequired = true
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Error Message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            // Continue Button (only for head coach)
            if selectedMembershipType == .coach {
                Button(action: handleContinue) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(isLoading ? "Setting up..." : "Continue as Head Coach")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.05, green: 0.15, blue: 0.35))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                .padding(.horizontal)
            }
            
            // Helper text
            VStack(spacing: 8) {
                Text("Not sure which to choose?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("If someone gave you an invite code, choose the second option. If you're starting fresh with your own team, choose Head Coach.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingCOPPAAgreement) {
            COPPACoachAgreementView(
                onAccept: {
                    showingCOPPAAgreement = false
                    // FIXED: Check if user already has a paid subscription before proceeding
                    checkSubscriptionStatusAndProceed()
                },
                onDecline: {
                    showingCOPPAAgreement = false
                }
            )
        }
        .sheet(isPresented: $showingPlanSelection) {
            StoreKitPlanSelectionView()
                .environmentObject(authManager)
        }
        .alert("Use Invite Code Instead", isPresented: $showingInviteRequired) {
            Button("Got It") {
                // Sign out and return to onboarding where they can use invite code
                authManager.signOutUser()
            }
        } message: {
            Text("To join as an assistant coach, parent, or viewer, please use the 'Join with Invite Code' option from the main sign-in screen. Ask your team's head coach for an invite code.")
        }
    }
    
    private func handleContinue() {
        // Only head coaches get here - show COPPA agreement then check subscription
        showingCOPPAAgreement = true
    }
    
    // FIXED: New method to check subscription status before overriding
    private func checkSubscriptionStatusAndProceed() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Check current user's subscription level
                let currentSubscriptionLevel = authManager.currentUser?.subscriptionLevel ?? .trial
                
                print("🔍 Current subscription level before membership update: \(currentSubscriptionLevel.rawValue)")
                
                // If user already has a paid subscription (not trial), preserve it
                if currentSubscriptionLevel != .trial {
                    print("✅ User has existing paid subscription (\(currentSubscriptionLevel.rawValue)), preserving it")
                    // Only update membership type, keep existing subscription
                    try await authManager.updateMembershipTypeAndSubscription(
                        membershipType: .coach,
                        subscriptionLevel: currentSubscriptionLevel // Preserve existing subscription
                    )
                } else {
                    print("📱 User has trial subscription, showing plan selection")
                    await MainActor.run {
                        self.isLoading = false
                        self.showingPlanSelection = true
                    }
                    return
                }
                
                await MainActor.run {
                    self.isLoading = false
                    // Don't show plan selection if they already paid
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func saveMembershipType(with subscriptionLevel: SubscriptionLevel) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.updateMembershipTypeAndSubscription(
                    membershipType: .coach, // Only head coaches get here
                    subscriptionLevel: subscriptionLevel
                )
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - StoreKit Plan Selection View (RENAMED TO AVOID CONFLICT)
struct StoreKitPlanSelectionView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var storeKit = StoreKitManager()
    @State private var selectedOption: SubscriptionOption = .startTrial
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingSubscriptionChoice = false
    @State private var currentSubscriptionType = ""
    
    enum SubscriptionOption {
        case startTrial
        case subscribePro
        case subscribePremium
        case subscribeClub
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)
                        
                        Text("Choose Your Plan")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Start with a free trial or select a paid plan")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    if storeKit.isLoading {
                        ProgressView("Loading subscription options...")
                            .padding()
                    } else {
                        // Plan Options
                        VStack(spacing: 16) {
                            // Trial Option
                            PlanSelectionCard(
                                title: "Free Trial",
                                price: "Free for 7 days",
                                features: [
                                    "1 team",
                                    "Up to 20 players",
                                    "Basic game & practice management",
                                    "Formation planning",
                                    "Limited team sharing"
                                ],
                                isRecommended: false,
                                isSelected: selectedOption == .startTrial,
                                badgeText: nil
                            ) {
                                selectedOption = .startTrial
                            }
                            
                            // Pro Plans
                            if let proMonthly = storeKit.products.first(where: { $0.id == "com.coachcaddie.pro.monthly" }),
                               let proYearly = storeKit.products.first(where: { $0.id == "com.coachcaddie.pro.yearly" }) {
                                PlanSelectionCard(
                                    title: "Pro",
                                    price: "\(proMonthly.displayPrice)/mo or \(proYearly.displayPrice)/yr",
                                    features: [
                                        "3 teams",
                                        "Up to 30 players per team",
                                        "Full game & practice management",
                                        "Advanced statistics",
                                        "5 coach invites",
                                        "10 parent invites"
                                    ],
                                    isRecommended: true,
                                    isSelected: selectedOption == .subscribePro,
                                    badgeText: "MOST POPULAR"
                                ) {
                                    selectedOption = .subscribePro
                                }
                            }
                            
                            // Premium Plans
                            if let premiumMonthly = storeKit.products.first(where: { $0.id == "com.coachcaddie.premium.monthly" }),
                               let premiumYearly = storeKit.products.first(where: { $0.id == "com.coachcaddie.premium.yearly" }) {
                                PlanSelectionCard(
                                    title: "Premium",
                                    price: "\(premiumMonthly.displayPrice)/mo or \(premiumYearly.displayPrice)/yr",
                                    features: [
                                        "10 teams",
                                        "Unlimited players",
                                        "Everything in Pro",
                                        "Season planning",
                                        "15 coach invites",
                                        "50 parent invites",
                                        "Priority support"
                                    ],
                                    isRecommended: false,
                                    isSelected: selectedOption == .subscribePremium,
                                    badgeText: nil
                                ) {
                                    selectedOption = .subscribePremium
                                }
                            }
                            
                            // Club Plans
                            if let clubMonthly = storeKit.products.first(where: { $0.id == "com.coachcaddie.club.monthly" }),
                               let clubYearly = storeKit.products.first(where: { $0.id == "com.coachcaddie.club.yearly" }) {
                                PlanSelectionCard(
                                    title: "Club",
                                    price: "\(clubMonthly.displayPrice)/mo or \(clubYearly.displayPrice)/yr",
                                    features: [
                                        "Unlimited teams",
                                        "Unlimited players",
                                        "Everything in Premium",
                                        "Unlimited invites",
                                        "Club-wide management",
                                        "Custom branding",
                                        "Dedicated support"
                                    ],
                                    isRecommended: false,
                                    isSelected: selectedOption == .subscribeClub,
                                    badgeText: "BEST VALUE"
                                ) {
                                    selectedOption = .subscribeClub
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Continue Button
                    Button(action: handleContinue) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Text(buttonText)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.05, green: 0.15, blue: 0.35))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing || storeKit.isLoading)
                    .padding(.horizontal)
                    
                    // Terms text
                    VStack(spacing: 4) {
                        if selectedOption == .startTrial {
                            Text("No credit card required for trial")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("After 7 days, you'll need to choose a paid plan to continue")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("You can change or cancel your plan anytime")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Billed through the App Store")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Select Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            storeKit.setAuthManager(authManager)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .sheet(isPresented: $showingSubscriptionChoice) {
            SubscriptionChoiceView(
                subscriptionType: currentSubscriptionType,
                storeKit: storeKit,
                authManager: authManager,
                onComplete: {
                    dismiss()
                }
            )
        }
    }
    
    private var buttonText: String {
        switch selectedOption {
        case .startTrial:
            return "Start Free Trial"
        case .subscribePro:
            return "Continue with Pro"
        case .subscribePremium:
            return "Continue with Premium"
        case .subscribeClub:
            return "Continue with Club"
        }
    }
    
    private func handleContinue() {
        switch selectedOption {
        case .startTrial:
            // Start trial - just set membership and trial subscription
            startFreeTrial()
            
        case .subscribePro:
            currentSubscriptionType = "pro"
            showingSubscriptionChoice = true
            
        case .subscribePremium:
            currentSubscriptionType = "premium"
            showingSubscriptionChoice = true
            
        case .subscribeClub:
            currentSubscriptionType = "club"
            showingSubscriptionChoice = true
        }
    }
    
    private func startFreeTrial() {
        isProcessing = true
        
        Task {
            do {
                // Set membership type as coach with trial subscription
                try await authManager.updateMembershipTypeAndSubscription(
                    membershipType: .coach,
                    subscriptionLevel: .trial
                )
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Subscription Choice View (Monthly vs Yearly)
struct SubscriptionChoiceView: View {
    let subscriptionType: String
    let storeKit: StoreKitManager
    let authManager: FirebaseAuthManager
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    private var monthlyProduct: Product? {
        storeKit.products.first { $0.id == "com.coachcaddie.\(subscriptionType).monthly" }
    }
    
    private var yearlyProduct: Product? {
        storeKit.products.first { $0.id == "com.coachcaddie.\(subscriptionType).yearly" }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Choose Billing Cycle")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("\(subscriptionType.capitalized) Subscription")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Options
                VStack(spacing: 16) {
                    if let monthly = monthlyProduct {
                        Button(action: { purchaseProduct(monthly) }) {
                            VStack(spacing: 8) {
                                Text("Monthly")
                                    .font(.headline)
                                Text(monthly.displayPrice)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                                Text("per month")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if let yearly = yearlyProduct {
                        Button(action: { purchaseProduct(yearly) }) {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Yearly")
                                        .font(.headline)
                                    Text("SAVE 17%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                                Text(yearly.displayPrice)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                                Text("per year")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .disabled(isProcessing)
                
                if isProcessing {
                    ProgressView("Processing purchase...")
                        .padding()
                }
                
                Spacer()
                
                // Terms
                Text("Subscriptions auto-renew until cancelled. Manage in Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .navigationTitle("Billing Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Purchase failed")
        }
    }
    
    private func purchaseProduct(_ product: Product) {
        isProcessing = true
        
        Task {
            // FIXED: Don't set membership type here - let the purchase handle the subscription update
            // Then StoreKit will automatically update the subscription level through its transaction handler
            
            // Process the purchase
            await storeKit.purchase(product)
            
            await MainActor.run {
                isProcessing = false
                
                if let error = storeKit.errorMessage {
                    errorMessage = error
                    showingError = true
                } else {
                    // Purchase successful - now set membership type to coach
                    // The subscription level has already been set by StoreKit transaction handler
                    Task {
                        do {
                            // Just set membership type, preserving the subscription that was just purchased
                            try await authManager.updateMembershipTypeAndSubscription(
                                membershipType: .coach,
                                subscriptionLevel: authManager.currentUser?.subscriptionLevel ?? .trial
                            )
                            await MainActor.run {
                                dismiss()
                                onComplete()
                            }
                        } catch {
                            await MainActor.run {
                                errorMessage = error.localizedDescription
                                showingError = true
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Plan Selection Card Component
struct PlanSelectionCard: View {
    let title: String
    let price: String
    let features: [String]
    let isRecommended: Bool
    let isSelected: Bool
    let badgeText: String?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with badge
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .primary)
                        
                        Text(price)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : Color(red: 0.05, green: 0.15, blue: 0.35))
                    }
                    
                    Spacer()
                    
                    if let badge = badgeText {
                        Text(badge)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isRecommended ? Color.green : Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .gray)
                }
                
                // Features list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.9) : .green)
                            
                            Text(feature)
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(red: 0.05, green: 0.15, blue: 0.35) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(red: 0.05, green: 0.15, blue: 0.35) : (isRecommended ? Color.green.opacity(0.5) : Color(.systemGray4)),
                        lineWidth: isSelected || isRecommended ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - COPPA Coach Agreement View (Original implementation)
struct COPPACoachAgreementView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @State private var hasReadAgreement = false
    @State private var acknowledgeResponsibility = false
    @Environment(\.presentationMode) var presentationMode
    
    var canProceed: Bool {
        hasReadAgreement && acknowledgeResponsibility
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Coach Responsibility Agreement")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Please review your responsibilities as a team coach")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                    
                    // Agreement Content
                    VStack(alignment: .leading, spacing: 20) {
                        AgreementSection(
                            title: "Your Role as Team Coach",
                            content: """
                            As a team coach using Coach Caddie, you will:
                            
                            • Manage team information and player data
                            • Input player names, contact information, and team details
                            • Communicate with parents about team activities
                            • Maintain team privacy and data security
                            """,
                            icon: "person.badge.shield.checkmark"
                        )
                        
                        AgreementSection(
                            title: "Data Protection Commitment",
                            content: """
                            Coach Caddie is designed with privacy in mind:
                            
                            • Only essential team management data is collected
                            • No sensitive personal information (birth dates, SSN, etc.)
                            • All data remains private to team members only
                            • Automatic deletion after 180 days of inactivity
                            • No commercial use or third-party sharing
                            """,
                            icon: "lock.shield"
                        )
                        
                        AgreementSection(
                            title: "Your Responsibilities",
                            content: """
                            By using Coach Caddie as a coach, you agree to:
                            
                            • Use appropriate judgment when inputting player information
                            • Communicate with parents about team management activities
                            • Respect player and family privacy
                            • Only collect information necessary for team management
                            • Ensure parents are aware of digital team organization
                            """,
                            icon: "checkmark.shield"
                        )
                        
                        AgreementSection(
                            title: "Implied Consent Model",
                            content: """
                            Coach Caddie uses an industry-standard approach:
                            
                            • Coaches manage team data as part of their team authority
                            • Minimal data collection (names, positions, contact info)
                            • Parents are informed about team management tools
                            • Similar to other sports team management platforms
                            • Focus on essential team coordination only
                            """,
                            icon: "hand.raised.fill"
                        )
                    }
                    
                    // Acknowledgment Checkboxes
                    VStack(spacing: 16) {
                        Divider()
                        
                        Button(action: { hasReadAgreement.toggle() }) {
                            HStack {
                                Image(systemName: hasReadAgreement ? "checkmark.square.fill" : "square")
                                    .foregroundColor(hasReadAgreement ? .blue : .gray)
                                Text("I have read and understand the information above")
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .foregroundColor(.primary)
                        }
                        
                        Button(action: { acknowledgeResponsibility.toggle() }) {
                            HStack {
                                Image(systemName: acknowledgeResponsibility ? "checkmark.square.fill" : "square")
                                    .foregroundColor(acknowledgeResponsibility ? .blue : .gray)
                                Text("I acknowledge my responsibility for appropriate team data management and parent communication")
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: onAccept) {
                            Text("Accept & Continue as Coach")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canProceed ? Color.blue : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!canProceed)
                        
                        Button(action: onDecline) {
                            Text("Choose Different Role")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding()
            }
            .navigationTitle("Coach Agreement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Agreement Section Component
struct AgreementSection: View {
    let title: String
    let content: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Updated card component for the new flow
struct MembershipOptionCardUpdated: View {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let isSelected: Bool
    let isInviteOption: Bool
    let onTap: () -> Void
    
    init(title: String, subtitle: String, description: String, icon: String, isSelected: Bool, isInviteOption: Bool = false, onTap: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.icon = icon
        self.isSelected = isSelected
        self.isInviteOption = isInviteOption
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : (isInviteOption ? Color(red: 0.13, green: 0.47, blue: 0.25) : Color(red: 0.05, green: 0.15, blue: 0.35)))
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .primary)
                        
                        Text(subtitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                    }
                    
                    Spacer()
                    
                    if !isInviteOption {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isSelected ? .white : .gray)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(red: 0.05, green: 0.15, blue: 0.35) : (isInviteOption ? Color(red: 0.13, green: 0.47, blue: 0.25).opacity(0.1) : Color(.systemBackground)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(red: 0.05, green: 0.15, blue: 0.35) : (isInviteOption ? Color(red: 0.13, green: 0.47, blue: 0.25) : Color(.systemGray4)),
                        lineWidth: isSelected || isInviteOption ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
