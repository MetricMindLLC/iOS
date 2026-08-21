import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var teamManager: TeamManager
    @State private var showingSignIn = false
    @State private var showingSignUp = false
    @State private var showingInviteFlow = false
    @State private var isLoadingApple = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemGroupedBackground),
                        Color(.systemBackground)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // App Logo and Title
                    appLogoSection
                    
                    Spacer()
                    
                    // Login Options
                    VStack(spacing: 16) {
                        // Join with Invite Code (Top Priority)
                        Button(action: { showingInviteFlow = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "ticket.fill")
                                Text("Join with Invite Code")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.13, green: 0.47, blue: 0.25))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            Text("or")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal)
                        
                        // Sign in with Apple
                        VStack(spacing: 8) {
                            Button(action: signInWithApple) {
                                HStack(spacing: 12) {
                                    if isLoadingApple {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "apple.logo")
                                            .font(.system(size: 20, weight: .semibold))
                                        
                                        Text("Sign in with Apple")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.black)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            .disabled(isLoadingApple)
                            
                            // Policy disclaimer for Apple Sign-In
                            HStack(spacing: 12) {
                                Link("Terms", destination: URL(string: "https://www.metric-mind.com/coachcaddieterms")!)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Link("Privacy", destination: URL(string: "https://www.metric-mind.com/coachcaddieprivacy")!)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Sign In
                        Button(action: { showingSignIn = true }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Sign in with Email")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.13, green: 0.47, blue: 0.25), lineWidth: 2)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Sign Up
                        Button(action: { showingSignUp = true }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.05, green: 0.15, blue: 0.35), lineWidth: 2)
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
            }
            .sheet(isPresented: $showingSignIn) {
                SignInView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showingInviteFlow) {
                InviteCodeFlowView()
                    .environmentObject(authManager)
                    .environmentObject(teamManager)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowInviteFlow"))) { _ in
                showingInviteFlow = true
            }
        }
    }
    
    private var appLogoSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 4) {
                    Image(systemName: "sportscourt.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 1) {
                        Text("COACH")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("CADDIE")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
            
            VStack(spacing: 8) {
                Text("Welcome to")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Coach Caddie")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            Text("Your complete soccer team management solution")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // Apple Sign-In method
    private func signInWithApple() {
        isLoadingApple = true
        
        Task {
            do {
                try await authManager.signInWithApple()
                
                await MainActor.run {
                    isLoadingApple = false
                }
            } catch {
                await MainActor.run {
                    isLoadingApple = false
                    // Don't show error for user cancellation
                    if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                        return
                    }
                    errorMessage = error.localizedDescription
                    showError = true
                    print("Apple Sign-In Error: \(error)")
                }
            }
        }
    }
}
// MARK: - Invite Code Flow View (Google Sign-In Removed)
struct InviteCodeFlowView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentStep: InviteFlowStep = .enterCode
    @State private var inviteCode = ""
    @State private var validatedInvite: TeamInvite?
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var isLoadingApple = false
    
    enum InviteFlowStep {
        case enterCode
        case chooseAuth
        case signIn
        case createAccount
        case joiningTeam
    }
    
    var body: some View {
        NavigationView {
            Group {
                switch currentStep {
                case .enterCode:
                    enterCodeView
                case .chooseAuth:
                    chooseAuthView
                case .signIn:
                    inviteSignInView
                case .createAccount:
                    createAccountView
                case .joiningTeam:
                    joiningTeamView
                }
            }
            .navigationTitle("Join Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Step 1: Enter Code
    private var enterCodeView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                
                Text("Enter Invite Code")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Enter the 6-character code shared with you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(spacing: 16) {
                HStack {
                    TextField("ABCDEF", text: $inviteCode)
                        .textCase(.uppercase)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .font(.system(.title2, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .onChange(of: inviteCode) { newValue in
                            if newValue.count > 6 {
                                inviteCode = String(newValue.prefix(6))
                            }
                        }
                    
                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if validatedInvite != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                } else if let invite = validatedInvite {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Valid invite for: \(invite.teamName)")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Text("Access Level: \(invite.accessLevel.displayName)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: validateCode) {
                    Text(validatedInvite != nil ? "Continue" : "Validate Code")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(inviteCode.count == 6 ? Color(red: 0.13, green: 0.47, blue: 0.25) : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(inviteCode.count != 6 || isValidating)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Choose Authentication (Google Sign-In Removed)
    private var chooseAuthView: some View {
        VStack(spacing: 24) {
            if let invite = validatedInvite {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Ready to Join")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("You're about to join \(invite.teamName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
            }
            
            VStack(spacing: 16) {
                Text("Create your account to continue:")
                    .font(.headline)
                
                Button(action: { currentStep = .createAccount }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Create Account with Email")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.13, green: 0.47, blue: 0.25))
                    .cornerRadius(12)
                }
                
                // Apple Sign-In option with policy links
                VStack(spacing: 12) {
                    Button(action: signInWithAppleForInvite) {
                        HStack(spacing: 12) {
                            if isLoadingApple {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 20, weight: .semibold))
                                
                                Text("Create Account with Apple")
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                    .disabled(isLoadingApple)
                    
                    // Policy links for Apple Sign-In in invite flow
                    VStack(spacing: 4) {
                        Text("By creating an account, you agree to our")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            Link("Terms and Conditions", destination: URL(string: "https://www.metric-mind.com/coachcaddieterms")!)
                                .font(.caption2)
                                .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                                .underline()
                            
                            Text("and")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Link("Privacy Policy", destination: URL(string: "https://www.metric-mind.com/coachcaddieprivacy")!)
                                .font(.caption2)
                                .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                                .underline()
                        }
                    }
                    .padding(.top, 8)
                }

                Divider()
                    .padding(.vertical, 4)

                Text("Already have an account?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: { currentStep = .signIn }) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                        Text("Sign In Instead")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.05, green: 0.15, blue: 0.35), lineWidth: 1.5)
                    )
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Sign In View (for existing users joining via invite)
    private var inviteSignInView: some View {
        Group {
            if let invite = validatedInvite {
                InviteSignInView(
                    validatedInvite: invite,
                    inviteCode: inviteCode,
                    onSuccess: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
                .environmentObject(authManager)
            }
        }
    }

    // MARK: - Step 3: Create Account
    private var createAccountView: some View {
        InviteCreateAccountView(
            validatedInvite: validatedInvite!,
            inviteCode: inviteCode,
            onSuccess: {
                currentStep = .joiningTeam
                joinTeamAfterAuth()
            }
        )
        .environmentObject(authManager)
    }
    
    // MARK: - Step 4: Joining Team
    private var joiningTeamView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2.0)
            
            Text("Joining \(validatedInvite?.teamName ?? "team")...")
                .font(.headline)
            
            Text("Please wait while we add you to the team")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Functions
    private func validateCode() {
        guard inviteCode.count == 6 else { return }
        
        if validatedInvite != nil {
            currentStep = .chooseAuth
            return
        }
        
        isValidating = true
        validationError = nil
        
        Task {
            do {
                // Validate without authentication - just check if invite exists and is valid
                let invite = try await validateInviteCodeWithoutAuth(inviteCode.uppercased())
                
                await MainActor.run {
                    self.validatedInvite = invite
                    self.isValidating = false
                    self.currentStep = .chooseAuth
                }
            } catch {
                await MainActor.run {
                    self.validationError = "Invalid or expired invite code"
                    self.isValidating = false
                }
            }
        }
    }
    
    private func validateInviteCodeWithoutAuth(_ code: String) async throws -> TeamInvite {
        // Firestore rules require authentication to read invite documents.
        // Sign in anonymously as a temporary bridge — the session is replaced when the
        // user creates an account or signs in for real.
        if Auth.auth().currentUser == nil {
            try await Auth.auth().signInAnonymously()
            print("🔐 Signed in anonymously to validate invite code")
        }
        let db = Firestore.firestore()
        let inviteDoc = try await db.collection("invites").document(code).getDocument()
        
        guard inviteDoc.exists else {
            throw FirebaseError.invalidInviteCode
        }
        
        let invite = try inviteDoc.data(as: TeamInvite.self)
        
        if invite.expiresAt < Date() {
            throw FirebaseError.expiredInviteCode
        }
        
        if invite.usedCount >= invite.maxUses {
            throw FirebaseError.expiredInviteCode
        }
        
        return invite
    }
    
    // MARK: - Apple Sign-In for Invite Flow
    private func signInWithAppleForInvite() {
        guard let invite = validatedInvite else { return }
        
        isLoadingApple = true
        
        Task {
            do {
                try await authManager.signUpWithAppleAndInvite(
                    inviteCode: inviteCode.uppercased(),
                    inviteAccessLevel: invite.accessLevel
                )
                
                await MainActor.run {
                    isLoadingApple = false
                    currentStep = .joiningTeam
                    joinTeamAfterAuth()
                }
            } catch {
                await MainActor.run {
                    isLoadingApple = false
                    // Don't show error for user cancellation
                    if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                        return
                    }
                    print("Apple Sign-In Error for invite: \(error)")
                }
            }
        }
    }
    
    private func joinTeamAfterAuth() {
        guard let invite = validatedInvite else { return }
        
        Task {
            do {
                let team = try await teamManager.firebaseManager.joinTeamWithCode(inviteCode.uppercased())
                
                await MainActor.run {
                    // Force reload teams
                    NotificationCenter.default.post(name: Notification.Name("ForceLoadTeams"), object: nil)
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("Failed to join team: \(error)")
                // Handle error appropriately
            }
        }
    }
}

// MARK: - Create Account for Invite
struct InviteCreateAccountView: View {
    let validatedInvite: TeamInvite
    let inviteCode: String
    let onSuccess: () -> Void
    
    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var agreedToTerms = false
    @State private var showingTerms = false
    
    var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        !displayName.isEmpty &&
        password == confirmPassword &&
        password.count >= 6 &&
        agreedToTerms
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Join \(validatedInvite.teamName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("John Doe", text: $displayName)
                            .autocapitalization(.words)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("your@email.com", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Password (6+ characters)", text: $password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Confirm Password", text: $confirmPassword)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        
                        if !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Passwords don't match")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Terms and Privacy Agreement Section
                    Button(action: { agreedToTerms.toggle() }) {
                        HStack(spacing: 8) {
                            Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                .foregroundColor(agreedToTerms ? Color(red: 0.13, green: 0.47, blue: 0.25) : .gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 0) {
                                    Text("I agree to the ")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    
                                    Button("Terms and Conditions") {
                                        showingTerms = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                                    .underline()
                                }
                                
                                HStack(spacing: 0) {
                                    Text("and ")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    
                                    Link("Privacy Policy", destination: URL(string: "https://www.metric-mind.com/coachcaddieprivacy")!)
                                        .font(.caption)
                                        .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                                        .underline()
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: createAccount) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Create Account & Join Team")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isFormValid ? Color(red: 0.13, green: 0.47, blue: 0.25) : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!isFormValid || isLoading)
            }
            .padding(.horizontal)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showingTerms) {
            TermsAndConditionsView()
        }
    }
    
    private func createAccount() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signUpWithInvite(
                    email: email,
                    password: password,
                    displayName: displayName,
                    inviteCode: inviteCode,
                    inviteAccessLevel: validatedInvite.accessLevel
                )
                
                await MainActor.run {
                    isLoading = false
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Sign In for Invite (existing users joining a team via invite code)
struct InviteSignInView: View {
    let validatedInvite: TeamInvite
    let inviteCode: String
    let onSuccess: () -> Void

    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var canSubmit: Bool { !email.isEmpty && !password.isEmpty && !isLoading }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Sign In to Join")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Join \(validatedInvite.teamName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("your@email.com", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }

                    Button(action: signInAndJoin) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Sign In & Join Team")
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSubmit ? Color(red: 0.13, green: 0.47, blue: 0.25) : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!canSubmit)
                }
                .padding(.horizontal)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }

    private func signInAndJoin() {
        isLoading = true
        Task {
            do {
                try await authManager.signInAndJoinTeam(email: email, password: password, inviteCode: inviteCode)
                await MainActor.run {
                    isLoading = false
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Sign Up View (Google Sign-In Removed)
struct SignUpView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var confirmEmail = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var coachName = ""
    @State private var isLoading = false
    @State private var isLoadingApple = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var agreedToTerms = false
    @State private var legacyCode = ""
    @State private var showingLegacyField = false
    @State private var showingTerms = false
    @State private var showingMembershipChoice = false
    @State private var selectedMembershipIntent: MembershipIntent = .headCoach
    @State private var showingEmailConfirmation = false
    
    enum MembershipIntent {
        case headCoach
        case assistantWithInvite
    }
    
    var emailsMatch: Bool {
        !email.isEmpty && !confirmEmail.isEmpty && email.lowercased() == confirmEmail.lowercased()
    }
    
    var passwordsMatch: Bool {
        !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }
    
    var isFormValid: Bool {
        !email.isEmpty &&
        !confirmEmail.isEmpty &&
        emailsMatch &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        passwordsMatch &&
        !coachName.isEmpty &&
        password.count >= 6 &&
        agreedToTerms
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    
                    // Apple Sign-In option at top with policy links
                    VStack(spacing: 12) {
                        Text("Quick Sign Up")
                            .font(.headline)
                            .padding(.top)
                        
                        Button(action: signUpWithApple) {
                            HStack(spacing: 12) {
                                if isLoadingApple {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 20, weight: .semibold))
                                    
                                    Text("Sign up with Apple")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(12)
                        }
                        .disabled(isLoadingApple)
                        
                        // Policy links for Apple Sign-In
                        VStack(spacing: 4) {
                            Text("By signing up with Apple, you agree to our")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 16) {
                                Link("Terms and Conditions", destination: URL(string: "https://www.metric-mind.com/coachcaddieterms")!)
                                    .font(.caption2)
                                    .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                                    .underline()
                                
                                Text("and")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Link("Privacy Policy", destination: URL(string: "https://www.metric-mind.com/coachcaddieprivacy")!)
                                    .font(.caption2)
                                    .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                                    .underline()
                            }
                        }
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            Text("or")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                    }
                    .padding(.horizontal)
                    
                    formSection
                    submitButton
                    Spacer()
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingTerms) {
                TermsAndConditionsView()
            }
            .alert("Confirm Your Email", isPresented: $showingEmailConfirmation) {
                Button("Edit Email") {
                    // Just dismiss the alert to go back and edit
                }
                Button("Looks Good!", role: .cancel) {
                    showingMembershipChoice = true
                }
            } message: {
                Text("Please confirm your email is correct:\n\n\(email)\n\nYou'll use this email to sign in to your account.")
            }
            .alert("How will you use Coach Caddie?", isPresented: $showingMembershipChoice) {
                Button("I'll create my own teams") {
                    selectedMembershipIntent = .headCoach
                    signUp()
                }
                Button("I have an invite code") {
                    // Redirect to invite flow without creating account
                    presentationMode.wrappedValue.dismiss()
                    // Post notification to show invite flow
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: Notification.Name("ShowInviteFlow"), object: nil)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Choose based on your role. Head coaches create and manage teams. Assistant coaches and parents should use invite codes from their head coach.")
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
            
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Join Coach Caddie today")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }
    
    private var formSection: some View {
        VStack(spacing: 16) {
            nameField
            emailFields
            passwordFields
            legacyCodeSection
            termsSection
        }
        .padding(.horizontal)
    }
    
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coach Name")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "person")
                    .foregroundColor(.gray)
                TextField("John Doe", text: $coachName)
                    .autocapitalization(.words)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var emailFields: some View {
        VStack(spacing: 16) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !email.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Double-check spelling")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.gray)
                    TextField("coach@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                if !email.isEmpty {
                    Text("⚠️ Please verify your email is spelled correctly. You'll use this to sign in.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Confirm Email Field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Confirm Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !confirmEmail.isEmpty {
                        emailMatchIndicator
                    }
                }
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.gray)
                    TextField("Re-enter email", text: $confirmEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            !confirmEmail.isEmpty ? (emailsMatch ? Color.green : Color.red) : Color.clear,
                            lineWidth: 1
                        )
                )
                
                if !confirmEmail.isEmpty && !emailsMatch {
                    Text("Please make sure both email addresses match exactly")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private var emailMatchIndicator: some View {
        HStack(spacing: 4) {
            if emailsMatch {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                Text("Match!")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                Text("Emails don't match")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var passwordFields: some View {
        VStack(spacing: 16) {
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                    SecureField("Password (6+ characters)", text: $password)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            
            // Confirm Password Field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Confirm Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !confirmPassword.isEmpty {
                        passwordMatchIndicator
                    }
                }
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                    SecureField("Confirm Password", text: $confirmPassword)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            !confirmPassword.isEmpty ? (passwordsMatch ? Color.green : Color.red) : Color.clear,
                            lineWidth: 1
                        )
                )
                
                if !confirmPassword.isEmpty && !passwordsMatch {
                    Text("Passwords don't match")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private var passwordMatchIndicator: some View {
        Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.caption)
            .foregroundColor(passwordsMatch ? .green : .red)
    }
    
    private var legacyCodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    showingLegacyField.toggle()
                }
            }) {
                HStack {
                    Text("Have a legacy code?")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: showingLegacyField ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                .padding(.horizontal, 4)
            }
            
            if showingLegacyField {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Legacy Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "key")
                            .foregroundColor(.gray)
                        TextField("Enter legacy code", text: $legacyCode)
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Text("Legacy codes provide unlimited free access for friends and family")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }
    
    private var termsSection: some View {
        Button(action: { agreedToTerms.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                    .foregroundColor(agreedToTerms ? Color(red: 0.13, green: 0.47, blue: 0.25) : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("I agree to the ")
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Button("Terms and Conditions") {
                            showingTerms = true
                        }
                        .font(.caption)
                        .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                        .underline()
                    }
                    
                    HStack(spacing: 0) {
                        Text("and ")
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Link("Privacy Policy", destination: URL(string: "https://www.metric-mind.com/coachcaddieprivacy")!)
                            .font(.caption)
                            .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                            .underline()
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var submitButton: some View {
        Button(action: {
            if isFormValid {
                showingEmailConfirmation = true
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Continue")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isFormValid ? Color(red: 0.13, green: 0.47, blue: 0.25) : Color.gray)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .disabled(!isFormValid || isLoading)
    }
    
    // MARK: - Methods
    
    // Apple Sign-Up method
    private func signUpWithApple() {
        isLoadingApple = true
        
        Task {
            do {
                try await authManager.signInWithApple()
                
                await MainActor.run {
                    isLoadingApple = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoadingApple = false
                    // Don't show error for user cancellation
                    if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                        return
                    }
                    errorMessage = error.localizedDescription
                    showError = true
                    print("Apple Sign-Up Error: \(error)")
                }
            }
        }
    }
    
    private func signUp() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signUp(
                    name: coachName,
                    email: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    legacyCode: legacyCode.isEmpty ? nil : legacyCode
                )
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Sign In View (Google Sign-In Removed)
struct SignInView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isLoadingApple = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingForgotPassword = false
    @State private var showingAccountRecovery = false
    @State private var showingInviteCodeEntry = false
    @State private var recoveryInviteCode = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                        
                        Text("Welcome Back")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Sign in to continue")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Apple Sign-In option
                    VStack(spacing: 12) {
                        Button(action: signInWithApple) {
                            HStack(spacing: 12) {
                                if isLoadingApple {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 20, weight: .semibold))
                                    
                                    Text("Sign in with Apple")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(12)
                        }
                        .disabled(isLoadingApple)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            Text("or")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Form
                    VStack(spacing: 16) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.gray)
                                TextField("coach@example.com", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.gray)
                                SecureField("Password", text: $password)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        // Forgot Password
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                showingForgotPassword = true
                            }
                            .font(.caption)
                            .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Sign In Button
                    Button(action: signIn) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(email.isEmpty || password.isEmpty ? Color.gray : Color(red: 0.13, green: 0.47, blue: 0.25))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    
                    Spacer()
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
            }
            .alert("Complete Your Account Setup", isPresented: $showingAccountRecovery) {
                Button("I want to create teams") {
                    completeAccountAsHeadCoach()
                }
                Button("I have an invite code") {
                    showingInviteCodeEntry = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your account was created but setup wasn't completed. Please choose how you'll use Coach Caddie.")
            }
            .alert("Enter Invite Code", isPresented: $showingInviteCodeEntry) {
                TextField("6-character code", text: $recoveryInviteCode)
                    .textCase(.uppercase)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                
                Button("Join Team") {
                    if recoveryInviteCode.count == 6 {
                        completeAccountWithInvite()
                    }
                }
                Button("Cancel", role: .cancel) {
                    recoveryInviteCode = ""
                }
            } message: {
                Text("Enter the invite code from your head coach to join their team.")
            }
        }
    }
    
    // Apple Sign-In method
    private func signInWithApple() {
        isLoadingApple = true
        
        Task {
            do {
                try await authManager.signInWithApple()
                
                await MainActor.run {
                    isLoadingApple = false
                    // Check if account needs recovery (membership type is nil)
                    if authManager.needsMembershipSelection {
                        // Account is stuck - show recovery options
                        showingAccountRecovery = true
                    } else {
                        // Normal successful sign in
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingApple = false
                    // Don't show error for user cancellation
                    if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                        return
                    }
                    errorMessage = error.localizedDescription
                    showError = true
                    print("Apple Sign-In Error: \(error)")
                }
            }
        }
    }
    
    private func signIn() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
                
                // Check if account needs recovery (membership type is nil)
                await MainActor.run {
                    if authManager.needsMembershipSelection {
                        // Account is stuck - show recovery options
                        isLoading = false
                        showingAccountRecovery = true
                    } else {
                        // Normal successful sign in
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func completeAccountAsHeadCoach() {
        isLoading = true
        
        Task {
            do {
                // Set membership type to coach with trial subscription
                try await authManager.updateMembershipTypeAndSubscription(
                    membershipType: .coach,
                    subscriptionLevel: .trial
                )
                
                await MainActor.run {
                    isLoading = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to complete setup: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func completeAccountWithInvite() {
        isLoading = true
        
        Task {
            do {
                // First validate the invite code
                let invite = try await teamManager.firebaseManager.validateInviteCode(recoveryInviteCode.uppercased())
                
                // Determine membership type based on invite access level
                let membershipType: MembershipType = invite.accessLevel == .coach ? .coach : .teamInvite
                
                // Update membership type with shared access subscription
                try await authManager.updateMembershipTypeAndSubscription(
                    membershipType: membershipType,
                    subscriptionLevel: .sharedAccess
                )
                
                // Join the team
                let _ = try await teamManager.firebaseManager.joinTeamWithCode(recoveryInviteCode.uppercased())
                
                await MainActor.run {
                    isLoading = false
                    // Force reload teams
                    NotificationCenter.default.post(name: Notification.Name("ForceLoadTeams"), object: nil)
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Invalid invite code or failed to join team: \(error.localizedDescription)"
                    showError = true
                    recoveryInviteCode = ""
                }
            }
        }
    }
}

struct ForgotPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                    
                    Text("Reset Password")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your email and we'll send you instructions to reset your password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.gray)
                        TextField("coach@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: resetPassword) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Text("Send Reset Instructions")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(red: 0.05, green: 0.15, blue: 0.35))
                    .cornerRadius(14)
                }
                .disabled(email.isEmpty || isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Reset Instructions Sent", isPresented: $showingSuccess) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Check your email at \(email) for password reset instructions. If you don't see it, please check your spam folder.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func resetPassword() {
        // Validate email format
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
                
                await MainActor.run {
                    isLoading = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    
                    // Parse Firebase error for user-friendly message
                    if let authError = error as NSError? {
                        switch authError.code {
                        case AuthErrorCode.invalidEmail.rawValue:
                            errorMessage = "Invalid email address format"
                        case AuthErrorCode.userNotFound.rawValue:
                            // For security, we still show success to prevent email enumeration
                            showingSuccess = true
                            return
                        case AuthErrorCode.invalidRecipientEmail.rawValue:
                            errorMessage = "Invalid email address"
                        case AuthErrorCode.networkError.rawValue:
                            errorMessage = "Network error. Please check your connection and try again"
                        default:
                            errorMessage = "Unable to send reset email. Please try again later"
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    showingError = true
                }
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
