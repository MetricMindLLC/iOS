import SwiftUI
import FirebaseAuth

struct MainAppView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var firebaseManager: FirebaseManager

    var body: some View {
        Group {
            if authManager.isLoading {
                loadingView
            } else if authManager.isAuthenticated {
                // User is authenticated - check if they need membership selection
                if authManager.needsMembershipSelection {
                    // Show recovery view for stuck accounts
                    MembershipSelectionRecoveryView()
                        .environmentObject(authManager)
                        .environmentObject(teamManager)
                } else {
                    // User has completed setup - show main app
                    mainAppContent
                }
            } else {
                // User is not authenticated - show onboarding
                OnboardingView()
                    .environmentObject(authManager)
                    .environmentObject(teamManager)
            }
        }
        .onAppear {
            // Set auth manager reference in team manager
            teamManager.setAuthManager(authManager)
            
            // Check authentication status on appear
            authManager.checkAuthenticationStatus()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var mainAppContent: some View {
        TabView {
            ContentView()
                .environmentObject(teamManager)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            // Events Tab
            UpcomingEventsListView()
                .environmentObject(teamManager)
                .tabItem {
                    Image(systemName: "calendar.circle.fill")
                    Text("Calendar")
                }

            EnhancedQuickStatsView()
                .environmentObject(teamManager)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }

            ProfileSettingsView()
                .environmentObject(authManager)
                .environmentObject(teamManager)
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
        }
        .accentColor(Color(red: 0.13, green: 0.47, blue: 0.25))
        .overlay(
            // Loading overlay for network reconnection
            Group {
                if teamManager.isReconnecting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        
                        Text("Reconnecting...")
                            .font(.headline)
                            .padding(.top)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        )
    }
}

// MARK: - Membership Selection Recovery View
struct MembershipSelectionRecoveryView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var teamManager: TeamManager
    @State private var showingInviteCodeEntry = false
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Complete Your Setup")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your account was created but setup wasn't completed. Please choose how you'll use Coach Caddie.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 60)
            
            // Options
            VStack(spacing: 16) {
                // Head Coach Option
                Button(action: completeAsHeadCoach) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("I want to create teams")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Start with a free trial and create your own teams")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.05, green: 0.15, blue: 0.35))
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                // Invite Code Option
                Button(action: { showingInviteCodeEntry = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "ticket.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("I have an invite code")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Join an existing team with a code from your coach")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.13, green: 0.47, blue: 0.25))
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal)
            
            // Sign Out Option
            VStack(spacing: 8) {
                Text("Wrong account?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Sign Out") {
                    authManager.signOutUser()
                }
                .font(.footnote)
                .foregroundColor(.red)
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .sheet(isPresented: $showingInviteCodeEntry) {
            InviteCodeEntryView(inviteCode: $inviteCode) { code, accessLevel in
                completeWithInviteCode(code, accessLevel: accessLevel)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Actions
    private func completeAsHeadCoach() {
        isLoading = true
        
        Task {
            do {
                // Update membership type and subscription
                try await authManager.updateMembershipTypeAndSubscription(
                    membershipType: .coach,
                    subscriptionLevel: .trial
                )
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func completeWithInviteCode(_ code: String, accessLevel: AccessLevel) {
        isLoading = true
        
        Task {
            do {
                // Validate invite code and join team
                let membershipType: MembershipType = accessLevel == .parent ? .parent : .viewer
                
                try await authManager.updateMembershipTypeAndSubscription(
                    membershipType: membershipType,
                    subscriptionLevel: .sharedAccess
                )
                
                // Join the team with the invite code
                await teamManager.joinTeamWithCode(code)
                
                await MainActor.run {
                    isLoading = false
                    showingInviteCodeEntry = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Invite Code Entry View
struct InviteCodeEntryView: View {
    @Binding var inviteCode: String
    var onComplete: (String, AccessLevel) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedAccessLevel: AccessLevel = .viewer
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Enter Invite Code")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("INVITE CODE")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter 6-character code", text: $inviteCode)
                        .textCase(.uppercase)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .font(.system(.title3, design: .monospaced))
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR ROLE")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Access Level", selection: $selectedAccessLevel) {
                        Text("Parent").tag(AccessLevel.parent)
                        Text("Viewer").tag(AccessLevel.viewer)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    onComplete(inviteCode, selectedAccessLevel)
                }) {
                    Text("Join Team")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(inviteCode.count == 6 ? Color(red: 0.13, green: 0.47, blue: 0.25) : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(inviteCode.count != 6)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
