import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import FirebaseCore
import StoreKit
import Foundation
import AuthenticationServices
import CryptoKit

class FirebaseAuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentCoach: Coach?
    @Published var needsMembershipSelection = false

    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    // OPTIMIZATION: Prevent duplicate profile loads
    private var isLoadingProfile = false
    private var lastLoadedUserUID: String?
    
    // Apple Sign-In properties
    private var currentNonce: String?
    private var appleContinuation: CheckedContinuation<Void, Error>?
    private var pendingInviteCode: String?
    private var pendingInviteAccessLevel: AccessLevel?
    private var isHandlingInviteSignup = false

    override init() {
        print("🔥 FirebaseAuthManager: Initializing")
        super.init()
        setupAuthStateListener()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func setupAuthStateListener() {
        print("🔥 FirebaseAuthManager: Setting up auth state listener")
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            print("🔥 FirebaseAuthManager: Auth state changed - user: \(firebaseUser?.uid ?? "nil")")
            
            DispatchQueue.main.async {
                if let firebaseUser = firebaseUser {
                    print("🔥 FirebaseAuthManager: User found, isAnonymous: \(firebaseUser.isAnonymous)")
                    // Only authenticate if user is NOT anonymous
                    if !firebaseUser.isAnonymous {
                        print("🔥 FirebaseAuthManager: Loading user profile for non-anonymous user")
                        Task {
                            await self?.loadUserProfile(for: firebaseUser)
                        }
                    } else {
                        // If user is anonymous, sign them out and reset state
                        print("🔥 FirebaseAuthManager: Signing out anonymous user")
                        self?.signOutUser()
                    }
                } else {
                    print("🔥 FirebaseAuthManager: No user found, clearing state")
                    self?.isAuthenticated = false
                    self?.currentUser = nil
                    self?.currentCoach = nil
                    self?.needsMembershipSelection = false
                }
                
                // Post notification for other parts of the app
                NotificationCenter.default.post(name: Notification.Name("AuthStateDidChange"), object: nil)
            }
        }
    }

    func checkAuthenticationStatus() {
        print("🔥 FirebaseAuthManager: Checking authentication status")
        if let firebaseUser = Auth.auth().currentUser {
            print("🔥 FirebaseAuthManager: Current user found: \(firebaseUser.uid), isAnonymous: \(firebaseUser.isAnonymous)")
            // Only proceed if user is NOT anonymous
            if !firebaseUser.isAnonymous {
                Task {
                    await loadUserProfile(for: firebaseUser)
                }
            } else {
                // Sign out anonymous users
                print("🔥 FirebaseAuthManager: Signing out anonymous user")
                signOutUser()
            }
        } else {
            print("🔥 FirebaseAuthManager: No current user found")
        }
    }

    // MARK: - Sign In Methods
    
    func signIn(email: String, password: String) async throws {
        print("🔥 FirebaseAuthManager: Starting email sign in")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ FirebaseAuthManager: Signed in with email: \(result.user.uid)")
            await loadUserProfile(for: result.user)
        } catch {
            print("❌ FirebaseAuthManager: Email sign in failed: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        print("🔥 FirebaseAuthManager: Starting Google sign in")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Get the clientID from Firebase
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                print("❌ FirebaseAuthManager: No client ID found")
                throw NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No client ID found"])
            }
            
            print("🔥 FirebaseAuthManager: Client ID found, configuring Google Sign-In")
            
            // Configure Google Sign-In
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // Perform sign in
            print("🔥 FirebaseAuthManager: Presenting Google Sign-In")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            
            print("🔥 FirebaseAuthManager: Google Sign-In completed, getting tokens")
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ FirebaseAuthManager: Failed to get ID token")
                throw NSError(domain: "GoogleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to get ID token"])
            }
            
            let accessToken = result.user.accessToken.tokenString
            
            // Create Firebase credential
            print("🔥 FirebaseAuthManager: Creating Firebase credential")
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            // Sign in with Firebase
            print("🔥 FirebaseAuthManager: Signing in with Firebase")
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ FirebaseAuthManager: Signed in with Google: \(authResult.user.uid)")
            
            await loadUserProfile(for: authResult.user)
        } catch {
            print("❌ FirebaseAuthManager: Google sign in failed: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Apple Sign-In Methods
    
    func signInWithApple() async throws {
        print("🍎 FirebaseAuthManager: Starting Apple sign in")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let nonce = randomNonceString()
            currentNonce = nonce
            
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.appleContinuation = continuation
                authorizationController.performRequests()
            }
        } catch {
            print("❌ FirebaseAuthManager: Apple sign in failed: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // MARK: - Legacy Invite Codes
    private let legacyInviteCodes = [
        "COACHJHUTCH2689",     // For friends and family
    ]

    private func checkForLegacyInviteCode(_ code: String) -> Bool {
        return legacyInviteCodes.contains(code.uppercased())
    }

    func signUp(name: String, email: String, password: String, legacyCode: String? = nil) async throws {
        print("🔥 FirebaseAuthManager: Starting sign up")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Create Firebase user
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("✅ FirebaseAuthManager: Created user account: \(result.user.uid)")
            
            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            
            // Determine subscription level AND membership type based on legacy code
            let subscriptionLevel: SubscriptionLevel
            let membershipType: MembershipType?

            if let code = legacyCode, checkForLegacyInviteCode(code) {
                subscriptionLevel = .free  // Legacy unlimited account
                membershipType = .coach    // Set them as a coach so they can create teams
                print("🎉 Legacy invite code used: \(code) - Granting unlimited access")
            } else {
                subscriptionLevel = .trial  // Regular trial account
                membershipType = nil       // This will trigger membership selection
            }

            // Create user profile
            let user = User(
                id: UUID(),
                firebaseUID: result.user.uid,
                email: email,
                membershipType: membershipType,  // Use determined membership type
                dateJoined: Date(),
                subscriptionLevel: subscriptionLevel
            )
            
            try await saveUserProfile(user)
            await loadUserProfile(for: result.user)
            
        } catch {
            print("❌ FirebaseAuthManager: Sign up failed: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Membership Type Management (FIXED FOR SWIFT 6)
    
    func updateMembershipType(_ membershipType: MembershipType) async throws {
        print("🔥 FirebaseAuthManager: Updating membership type to: \(membershipType.rawValue)")
        guard let firebaseUser = Auth.auth().currentUser,
              let currentUser = currentUser else {
            print("❌ FirebaseAuthManager: No current user for membership update")
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        
        // Create updated user object (immutable)
        let updatedUser = User(
            id: currentUser.id,
            firebaseUID: currentUser.firebaseUID,
            email: currentUser.email,
            membershipType: membershipType,  // Set the new membership type
            dateJoined: currentUser.dateJoined,
            subscriptionLevel: currentUser.subscriptionLevel,
            trialStartDate: currentUser.trialStartDate,
            cancellationDate: currentUser.cancellationDate,
            dataRetentionEndDate: currentUser.dataRetentionEndDate
        )
        
        // Save to Firebase
        try await saveUserProfile(updatedUser)
        print("✅ FirebaseAuthManager: Saved membership type to Firebase")
        
        // Update local state on main actor
        await MainActor.run {
            print("🔥 FirebaseAuthManager: Updating local auth state")
            self.currentUser = updatedUser
            self.needsMembershipSelection = false
            self.isAuthenticated = true
            self.isLoading = false
            
            // Update legacy coach object
            self.currentCoach = Coach(
                id: updatedUser.id,
                firebaseUID: updatedUser.firebaseUID,
                name: firebaseUser.displayName ?? updatedUser.email ?? "User",
                email: updatedUser.email ?? "",
                phone: "",
                teams: [],
                subscriptionLevel: updatedUser.subscriptionLevel,
                dateJoined: updatedUser.dateJoined
            )
            
            print("✅ FirebaseAuthManager: Membership type updated successfully")
            print("🔥 Final state - isAuthenticated: \(self.isAuthenticated), needsMembershipSelection: \(self.needsMembershipSelection)")
        }
    }
    
    func updateMembershipTypeAndSubscription(
        membershipType: MembershipType,
        subscriptionLevel: SubscriptionLevel
    ) async throws {
        guard let firebaseUser = Auth.auth().currentUser,  // ADD THIS LINE
              let currentUser = currentUser else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        
        // NEW: Check trial eligibility before allowing trial selection
        if subscriptionLevel == .trial && currentUser.hasUsedTrial {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Trial already used. Please select a paid plan."])
        }
        
        // NEW: Mark trial as used when starting trial
        let hasUsedTrial = currentUser.hasUsedTrial || (subscriptionLevel == .trial)
        
        let updatedUser = User(
            id: currentUser.id,
            firebaseUID: currentUser.firebaseUID,
            email: currentUser.email,
            membershipType: membershipType,
            dateJoined: currentUser.dateJoined,
            subscriptionLevel: subscriptionLevel,
            trialStartDate: subscriptionLevel == .trial ? Date() : currentUser.trialStartDate,
            subscriptionEndDate: currentUser.subscriptionEndDate,
            cancellationDate: currentUser.cancellationDate,
            dataRetentionEndDate: currentUser.dataRetentionEndDate,
            hasUsedTrial: hasUsedTrial  // NEW
        )
        
        // Save to Firebase
        try await saveUserProfile(updatedUser)
        print("✅ FirebaseAuthManager: Saved membership type and subscription to Firebase")
        
        // Update local state on main actor
        await MainActor.run {
            print("🔥 FirebaseAuthManager: Updating local auth state")
            self.currentUser = updatedUser
            self.needsMembershipSelection = false
            self.isAuthenticated = true
            self.isLoading = false
            
            // Update legacy coach object
            self.currentCoach = Coach(
                id: updatedUser.id,
                firebaseUID: updatedUser.firebaseUID,
                name: firebaseUser.displayName ?? updatedUser.email ?? "User",
                email: updatedUser.email ?? "",
                phone: "",
                teams: [],
                subscriptionLevel: updatedUser.subscriptionLevel,
                dateJoined: updatedUser.dateJoined
            )
            
            print("✅ FirebaseAuthManager: Membership type and subscription updated successfully")
            print("🔥 Final state - isAuthenticated: \(self.isAuthenticated), needsMembershipSelection: \(self.needsMembershipSelection)")
        }
    }
    
    func loadUserProfile(for firebaseUser: FirebaseAuth.User) async {
        print("🔥 FirebaseAuthManager: Loading user profile for: \(firebaseUser.uid)")
        
        // OPTIMIZATION: Prevent duplicate loads
        if isLoadingProfile && lastLoadedUserUID == firebaseUser.uid {
            print("⏭️ Skipping duplicate profile load for: \(firebaseUser.uid)")
            return
        }
        
        // Don't run during invite signup — signUpWithInvite / signUpWithAppleAndInvite
        // save the profile with the correct membershipType themselves; running this
        // concurrently would overwrite with membershipType = nil and flash MembershipSelectionView.
        guard !isHandlingInviteSignup else {
            await MainActor.run { self.isLoading = false }
            return
        }

        // Anonymous users are only used as a bridge to read invite codes from Firestore before
        // the user has created an account. Never treat them as real signed-in users.
        guard !firebaseUser.isAnonymous else {
            await MainActor.run { self.isLoading = false }
            return
        }

        isLoadingProfile = true
        lastLoadedUserUID = firebaseUser.uid
        defer {
            isLoadingProfile = false
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            print("🔥 FirebaseAuthManager: Fetching user document from Firestore")
            // OPTIMIZATION: Use cache-first strategy instead of forcing server read
            let doc = try await db.collection("users")
                .document(firebaseUser.uid)
                .getDocument(source: .default)  // ✅ Cache-first, then server if needed
            
            if doc.exists {
                print("🔥 FirebaseAuthManager: User document exists, decoding")
                // Load existing user
                let user = try doc.data(as: User.self)
                print("🔥 FirebaseAuthManager: User decoded - email: \(user.email ?? "nil"), membershipType: \(user.membershipType?.rawValue ?? "nil")")
                
                await MainActor.run {
                    self.currentUser = user
                    
                    // Check if user needs to select membership type
                    if user.membershipType == nil {
                        print("🔥 FirebaseAuthManager: User needs membership selection")
                        self.needsMembershipSelection = true
                        // IMPORTANT: Keep them authenticated so they can fix their account
                        self.isAuthenticated = true  // Changed from false
                    } else {
                        print("🔥 FirebaseAuthManager: User has membership type, authenticating")
                        self.needsMembershipSelection = false
                        self.isAuthenticated = true
                        
                        // Create legacy coach object for compatibility
                        self.currentCoach = Coach(
                            id: user.id,
                            firebaseUID: user.firebaseUID,
                            name: firebaseUser.displayName ?? user.email ?? "User",
                            email: user.email ?? "",
                            phone: "",
                            teams: [],
                            subscriptionLevel: user.subscriptionLevel,
                            dateJoined: user.dateJoined
                        )
                    }
                    
                    self.isLoading = false
                    print("🔥 FirebaseAuthManager: Profile loaded - isAuthenticated: \(self.isAuthenticated), needsMembershipSelection: \(self.needsMembershipSelection)")
                }
                
                // NEW: Auto-check trial status after loading profile
                if user.subscriptionLevel == .trial {
                    print("🔥 FirebaseAuthManager: User has trial subscription, checking expiration status")
                    do {
                        try await checkTrialStatus()
                        print("🔥 FirebaseAuthManager: Trial status check completed")
                    } catch {
                        print("⚠️ FirebaseAuthManager: Failed to check trial status: \(error)")
                        // Don't throw - this is just a background check
                    }
                }
                
            } else {
                print("🔥 FirebaseAuthManager: User document doesn't exist, creating new user")
                // Create new user profile without membership type
                let user = User(
                    id: UUID(),
                    firebaseUID: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    membershipType: nil, // Will trigger membership selection
                    dateJoined: Date(),
                    subscriptionLevel: .trial
                )
                
                try await saveUserProfile(user)
                print("✅ FirebaseAuthManager: New user profile created")
                
                await MainActor.run {
                    self.currentUser = user
                    self.needsMembershipSelection = true
                    self.isAuthenticated = true  // Keep them authenticated
                    self.isLoading = false
                    print("🔥 FirebaseAuthManager: New user state - isAuthenticated: \(self.isAuthenticated), needsMembershipSelection: \(self.needsMembershipSelection)")
                }
            }
        } catch {
            print("❌ FirebaseAuthManager: Failed to load user profile: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - NEW METHOD: Refresh Current User
    func refreshCurrentUser() async {
        guard let firebaseUser = Auth.auth().currentUser else {
            print("❌ FirebaseAuthManager: No Firebase user to refresh")
            return
        }
        
        print("🔄 FirebaseAuthManager: Refreshing current user profile")
        await loadUserProfile(for: firebaseUser)
    }

    private func saveUserProfile(_ user: User) async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            print("❌ FirebaseAuthManager: No Firebase user for profile save")
            return
        }
        
        print("🔥 FirebaseAuthManager: Saving user profile to Firestore")
        let data = try Firestore.Encoder().encode(user)
        try await db.collection("users").document(firebaseUser.uid).setData(data)
        print("✅ FirebaseAuthManager: User profile saved successfully")
    }
    
    // MARK: - Sign Out
    
    func signOutUser() {
        print("🔥 FirebaseAuthManager: Signing out user")
        do {
            try Auth.auth().signOut()
            self.isAuthenticated = false
            self.currentUser = nil
            self.currentCoach = nil
            self.needsMembershipSelection = false
            
            // Clear local data when signing out
            NotificationCenter.default.post(name: Notification.Name("ClearLocalData"), object: nil)
            
            print("✅ FirebaseAuthManager: User signed out successfully and local data cleared")
        } catch {
            print("❌ FirebaseAuthManager: Sign out failed: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }
    
    func signUpWithInvite(email: String, password: String, displayName: String, inviteCode: String, inviteAccessLevel: AccessLevel) async throws {
        print("🔥 FirebaseAuthManager: Starting sign up with invite")
        isHandlingInviteSignup = true
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // 1. Create the account
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("✅ FirebaseAuthManager: Created user account: \(result.user.uid)")
            
            // 2. Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            
            // 3. FIXED: Determine subscription level based on invite access level
            let subscriptionLevel: SubscriptionLevel
            switch inviteAccessLevel {
            case .coach:
                subscriptionLevel = .sharedAccess  // Coaches get shared access to specific teams
                print("🎉 Coach invite - granting shared access subscription")
            case .parent, .viewer:
                subscriptionLevel = .sharedAccess  // FIXED: Parents and viewers also get shared access, not trial
                print("🎉 Parent/Viewer invite - granting shared access subscription")
            }
            
            // 4. Create user profile with appropriate membership type
            let membershipType: MembershipType = inviteAccessLevel == .coach ? .coach : .teamInvite
            
            let user = User(
                id: UUID(),
                firebaseUID: result.user.uid,
                email: email,
                membershipType: membershipType,
                dateJoined: Date(),
                subscriptionLevel: subscriptionLevel  // Use determined subscription level
            )
            
            try await saveUserProfile(user)
            
            // 5. Join the team using the invite code
            let firebaseManager = FirebaseManager.shared
            let _ = try await firebaseManager.joinTeamWithCode(inviteCode)
            
            // 6. Set up local state - user is fully authenticated
            await MainActor.run {
                self.isHandlingInviteSignup = false
                self.currentUser = user
                self.needsMembershipSelection = false
                self.isAuthenticated = true
                self.isLoading = false

                // Create legacy coach object for compatibility
                self.currentCoach = Coach(
                    id: user.id,
                    firebaseUID: user.firebaseUID,
                    name: displayName,
                    email: email,
                    phone: "",
                    teams: [],
                    subscriptionLevel: user.subscriptionLevel,
                    dateJoined: user.dateJoined
                )

                print("✅ FirebaseAuthManager: User signed up and joined team with \(subscriptionLevel.rawValue) access")
            }

        } catch {
            print("❌ FirebaseAuthManager: Sign up with invite failed: \(error)")
            await MainActor.run {
                self.isHandlingInviteSignup = false
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Sign In existing user and join team
    func signInAndJoinTeam(email: String, password: String, inviteCode: String) async throws {
        print("🔥 FirebaseAuthManager: Signing in existing user and joining team")
        await MainActor.run { isLoading = true; errorMessage = nil }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ FirebaseAuthManager: Signed in, now joining team")
            let _ = try await FirebaseManager.shared.joinTeamWithCode(inviteCode)
            print("✅ FirebaseAuthManager: Joined team, loading profile")
            await loadUserProfile(for: result.user)
            await MainActor.run {
                NotificationCenter.default.post(name: Notification.Name("ForceLoadTeams"), object: nil)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }

    // MARK: - Apple Sign-In with Invite
    func signUpWithAppleAndInvite(inviteCode: String, inviteAccessLevel: AccessLevel) async throws {
        print("🍎 FirebaseAuthManager: Starting Apple sign up with invite")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let nonce = randomNonceString()
            currentNonce = nonce
            
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            
            // Store invite info for use in Apple callback
            self.pendingInviteCode = inviteCode
            self.pendingInviteAccessLevel = inviteAccessLevel
            self.isHandlingInviteSignup = true
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.appleContinuation = continuation
                authorizationController.performRequests()
            }
        } catch {
            print("❌ FirebaseAuthManager: Apple sign up with invite failed: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - NEW METHOD: Update Membership Type Only (Preserve Existing Subscription)
    func updateMembershipTypeOnly(_ membershipType: MembershipType) async throws {
        print("🔥 FirebaseAuthManager: Updating membership type only to: \(membershipType.rawValue), preserving existing subscription")
        guard let firebaseUser = Auth.auth().currentUser,
              let currentUser = currentUser else {
            print("❌ FirebaseAuthManager: No current user for membership update")
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        
        // CRITICAL: Create updated user object preserving existing subscription level
        let updatedUser = User(
            id: currentUser.id,
            firebaseUID: currentUser.firebaseUID,
            email: currentUser.email,
            membershipType: membershipType,  // Update membership type
            dateJoined: currentUser.dateJoined,
            subscriptionLevel: currentUser.subscriptionLevel,  // PRESERVE existing subscription
            trialStartDate: currentUser.trialStartDate,  // PRESERVE existing trial start
            cancellationDate: currentUser.cancellationDate,  // PRESERVE existing cancellation
            dataRetentionEndDate: currentUser.dataRetentionEndDate  // PRESERVE existing retention
        )
        
        print("✅ Preserving existing subscription level: \(currentUser.subscriptionLevel.rawValue)")
        
        // Save to Firebase
        try await saveUserProfile(updatedUser)
        print("✅ FirebaseAuthManager: Saved membership type to Firebase (subscription preserved)")
        
        // Update local state on main actor
        await MainActor.run {
            print("🔥 FirebaseAuthManager: Updating local auth state")
            self.currentUser = updatedUser
            self.needsMembershipSelection = false
            self.isAuthenticated = true
            self.isLoading = false
            
            // Update legacy coach object
            self.currentCoach = Coach(
                id: updatedUser.id,
                firebaseUID: updatedUser.firebaseUID,
                name: firebaseUser.displayName ?? updatedUser.email ?? "User",
                email: updatedUser.email ?? "",
                phone: "",
                teams: [],
                subscriptionLevel: updatedUser.subscriptionLevel,
                dateJoined: updatedUser.dateJoined
            )
            
            print("✅ FirebaseAuthManager: Membership type updated successfully (subscription level preserved)")
            print("🔥 Final state - isAuthenticated: \(self.isAuthenticated), needsMembershipSelection: \(self.needsMembershipSelection)")
        }
    }
    
    // MARK: - Subscription Management (UPDATED)
    
    /// Update subscription level after successful StoreKit purchase
    func updateSubscriptionLevel(_ level: SubscriptionLevel, transactionId: String? = nil) async throws {
        print("🔥 FirebaseAuthManager: Updating subscription level to: \(level.rawValue)")
        guard let currentUser = currentUser else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        
        // Create updated user object
        let updatedUser = User(
            id: currentUser.id,
            firebaseUID: currentUser.firebaseUID,
            email: currentUser.email,
            membershipType: currentUser.membershipType,
            dateJoined: currentUser.dateJoined,
            subscriptionLevel: level,
            trialStartDate: currentUser.subscriptionLevel == .trial ? Date() : currentUser.trialStartDate,
            cancellationDate: nil,
            dataRetentionEndDate: nil
        )
        
        // Store transaction ID for future reference
        if let transactionId = transactionId {
            print("🔥 FirebaseAuthManager: Recording transaction ID: \(transactionId)")
            // You could add a transactionHistory field to User model if needed
        }
        
        // Save to Firebase
        try await saveUserProfile(updatedUser)
        print("✅ FirebaseAuthManager: Updated subscription level to \(level.rawValue)")
        
        // CRITICAL: Refresh the user profile from Firestore to ensure UI updates
        await refreshCurrentUser()
        
        // Post notification for other parts of the app
        await MainActor.run {
            self.currentUser = updatedUser
            NotificationCenter.default.post(
                name: Notification.Name("SubscriptionUpdated"),
                object: nil,
                userInfo: ["newLevel": level.rawValue]
            )
        }
    }
    /// Handle subscription purchase result from StoreKit (UPDATED)
        func handlePurchaseResult(_ transaction: StoreKit.Transaction) async throws {
            print("🔥 FirebaseAuthManager: Handling purchase result for product: \(transaction.productID)")
            
            let subscriptionLevel: SubscriptionLevel
            
            switch transaction.productID {
            case "com.coachcaddie.pro.monthly", "com.coachcaddie.pro.yearly":
                subscriptionLevel = .coach
            case "com.coachcaddie.premium.monthly", "com.coachcaddie.premium.yearly":
                subscriptionLevel = .proCoach
            default:
                print("❌ Unknown product ID: \(transaction.productID)")
                throw NSError(domain: "Subscription", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown subscription product"])
            }
            
            // Update the user's subscription level
            try await updateSubscriptionLevel(subscriptionLevel, transactionId: String(transaction.id))
            
            print("✅ FirebaseAuthManager: Successfully processed purchase for \(subscriptionLevel.rawValue)")
        }

        /// Check if user can upgrade to a specific level
        func canUpgradeToLevel(_ targetLevel: SubscriptionLevel) -> Bool {
            guard let user = currentUser else { return false }
            
            let currentLevel = user.subscriptionLevel
            
            // Define upgrade hierarchy
            switch currentLevel {
            case .trial:
                return targetLevel == .coach || targetLevel == .proCoach
            case .coach:
                return targetLevel == .proCoach
            case .proCoach, .free:
                return false // Already at top level or legacy free
            case .sharedAccess:
                return targetLevel == .coach || targetLevel == .proCoach
            case .cancelled, .expired:
                return true // Can reactivate to any level
            }
        }

        /// Get upgrade pricing info (for UI display)
        func getUpgradeInfo(from currentLevel: SubscriptionLevel, to targetLevel: SubscriptionLevel) -> String? {
            switch (currentLevel, targetLevel) {
            case (.trial, .coach):
                return "Upgrade to Coach for $4.99/month"
            case (.trial, .proCoach):
                return "Upgrade to Pro Coach for $9.99/month"
            case (.coach, .proCoach):
                return "Upgrade to Pro Coach for $5/month more"
            default:
                return nil
            }
        }
    
    // FIXED: Cancel subscription method
    func cancelSubscription() async throws {
        guard let currentUser = currentUser else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        
        // Create updated user object
        let updatedUser = User(
            id: currentUser.id,
            firebaseUID: currentUser.firebaseUID,
            email: currentUser.email,
            membershipType: currentUser.membershipType,
            dateJoined: currentUser.dateJoined,
            subscriptionLevel: .cancelled,
            trialStartDate: currentUser.trialStartDate,
            cancellationDate: Date(),
            dataRetentionEndDate: Calendar.current.date(byAdding: .day, value: 180, to: Date())
        )
        
        // Void all invite codes for this user's teams
        try await voidUserInviteCodes(for: currentUser.firebaseUID)
        
        // Save updated user
        try await saveUserProfile(updatedUser)
        
        await MainActor.run {
            self.currentUser = updatedUser
        }
    }

    func reactivateSubscription(_ level: SubscriptionLevel) async throws {
        guard let currentUser = currentUser else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        
        // NEW: Prevent trial re-use during reactivation
        if level == .trial && currentUser.hasUsedTrial {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Trial already used. Please select a paid plan."])
        }
        
        // Create updated user object
        let updatedUser = User(
            id: currentUser.id,
            firebaseUID: currentUser.firebaseUID,
            email: currentUser.email,
            membershipType: currentUser.membershipType,
            dateJoined: currentUser.dateJoined,
            subscriptionLevel: level,
            trialStartDate: currentUser.trialStartDate,
            cancellationDate: nil,
            dataRetentionEndDate: nil
        )
        
        // Save updated user
        try await saveUserProfile(updatedUser)
        
        // Refresh user after reactivation
        await refreshCurrentUser()
        
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("SubscriptionUpdated"),
                object: nil,
                userInfo: ["newLevel": level.rawValue]
            )
        }
    }

    func checkTrialStatus() async throws {
        guard let currentUser = currentUser else { return }
        
        // Simply mark trial as used when expired, but DON'T auto-upgrade
        if currentUser.subscriptionLevel == .trial && currentUser.isTrialExpired && !currentUser.hasUsedTrial {
            print("🔄 Trial expired - marking as used (no auto-upgrade)")
            
            // Only update hasUsedTrial flag, keep subscription as trial
            let updatedUser = User(
                id: currentUser.id,
                firebaseUID: currentUser.firebaseUID,
                email: currentUser.email,
                membershipType: currentUser.membershipType,
                dateJoined: currentUser.dateJoined,
                subscriptionLevel: .expired,  // Keep as trial - don't auto-upgrade!
                trialStartDate: currentUser.trialStartDate,
                cancellationDate: currentUser.cancellationDate,
                dataRetentionEndDate: currentUser.dataRetentionEndDate,
                hasUsedTrial: true  // Mark trial as used
            )
            
            try await saveUserProfile(updatedUser)
            
            await MainActor.run {
                self.currentUser = updatedUser
            }
            
            // Notify UI that trial has expired (for showing upgrade modal)
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Notification.Name("TrialExpired"),
                    object: nil
                )
            }
        }
    }
    
    // NEW: Helper method to show trial expiration notification
    private func showTrialExpiredNotification() async {
        // You can implement this to show a notification or alert to the user
        // For example, post a notification that your UI can listen for
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("TrialExpiredAutoConverted"),
                object: nil,
                userInfo: ["newSubscriptionLevel": SubscriptionLevel.coach.rawValue]
            )
        }
    }

    func checkDataRetention() async throws {
        guard let user = currentUser else { return }
        
        // Check if data should be hard deleted
        if user.shouldDeleteData {
            try await hardDeleteUserData(for: user.firebaseUID)
        }
    }

    private func voidUserInviteCodes(for userUID: String) async throws {
        // Get all teams created by this user
        let teamsQuery = db.collection("teams").whereField("coachUID", isEqualTo: userUID)
        let teamDocs = try await teamsQuery.getDocuments()
        
        // Get all invite codes for these teams
        for teamDoc in teamDocs.documents {
            let teamId = teamDoc.documentID
            let invitesQuery = db.collection("invites").whereField("teamId", isEqualTo: teamId)
            let inviteDocs = try await invitesQuery.getDocuments()
            
            // Mark all invites as expired
            for inviteDoc in inviteDocs.documents {
                try await db.collection("invites").document(inviteDoc.documentID).updateData([
                    "expiresAt": Date(timeIntervalSince1970: 0), // Set to past date
                    "isVoided": true
                ])
            }
        }
        
        print("✅ Voided all invite codes for user: \(userUID)")
    }

    func hardDeleteAccount() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user to delete"])
        }
        
        let userUID = currentUser.uid
        print("🗑️ Starting hard delete for user: \(userUID)")
        
        // First delete all user data from Firestore
        do {
            try await hardDeleteUserData(for: userUID)
        } catch {
            print("⚠️ Error deleting user data: \(error)")
            throw error
        }
        
        // Try to delete the Firebase Auth account
        do {
            try await currentUser.delete()
            print("✅ Firebase Auth account deleted")
        } catch let error as NSError {
            if error.code == 17014 { // ERROR_REQUIRES_RECENT_LOGIN
                print("⚠️ Recent authentication required - signing out user instead")
                // Data is already deleted, just sign out
            } else {
                print("⚠️ Error deleting Firebase Auth account: \(error)")
                throw error
            }
        }
        
        // Clear local state and sign out regardless
        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
            self.currentCoach = nil
            self.needsMembershipSelection = false
            
            NotificationCenter.default.post(name: Notification.Name("ClearLocalData"), object: nil)
            print("✅ Account data deleted and user signed out")
        }
    }

    private func hardDeleteUserData(for userUID: String) async throws {
        print("🗑️ Hard deleting all data for user: \(userUID)")
        
        // Delete user document
        try await db.collection("users").document(userUID).delete()
        
        // Delete all teams created by this user
        let teamsQuery = db.collection("teams").whereField("coachUID", isEqualTo: userUID)
        let teamDocs = try await teamsQuery.getDocuments()
        
        for teamDoc in teamDocs.documents {
            let teamId = teamDoc.documentID
            
            // Delete all invites for this team
            let invitesQuery = db.collection("invites").whereField("teamId", isEqualTo: teamId)
            let inviteDocs = try await invitesQuery.getDocuments()
            
            for inviteDoc in inviteDocs.documents {
                try await db.collection("invites").document(inviteDoc.documentID).delete()
            }
            
            // Delete the team
            try await db.collection("teams").document(teamId).delete()
        }
        
        // Remove user from any teams they were invited to
        let allTeamsQuery = db.collection("teams")
        let allTeamDocs = try await allTeamsQuery.getDocuments()
        
        for teamDoc in allTeamDocs.documents {
            var teamData = teamDoc.data()
            if var members = teamData["members"] as? [[String: Any]] {
                members.removeAll { member in
                    (member["userId"] as? String) == userUID
                }
                teamData["members"] = members
                try await db.collection("teams").document(teamDoc.documentID).setData(teamData)
            }
        }
        
        print("✅ Hard deleted all data for user: \(userUID)")
    }
}

// MARK: - Apple Sign-In Delegate
extension FirebaseAuthManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available")
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let nonce = currentNonce else {
            print("❌ Invalid state: A login callback was received, but no login request was sent.")
            appleContinuation?.resume(throwing: NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid state"]))
            return
        }
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("❌ Unable to fetch identity token")
            appleContinuation?.resume(throwing: NSError(domain: "AppleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"]))
            return
        }
        
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: appleIDCredential.fullName)
        
        Task {
            do {
                let result = try await Auth.auth().signIn(with: credential)
                print("✅ FirebaseAuthManager: Signed in with Apple: \(result.user.uid)")
                
                // Check if this is an invite-based signup
                if let inviteCode = pendingInviteCode,
                   let accessLevel = pendingInviteAccessLevel {
                    
                    // Handle invite-based signup
                    let membershipType: MembershipType = accessLevel == .coach ? .coach : .teamInvite
                    let subscriptionLevel: SubscriptionLevel = .sharedAccess
                    
                    // Get display name from Apple ID credential
                    var displayName = result.user.displayName
                    if displayName == nil || displayName?.isEmpty == true {
                        if let fullName = appleIDCredential.fullName {
                            let formatter = PersonNameComponentsFormatter()
                            displayName = formatter.string(from: fullName)
                        }
                    }
                    
                    // Create user profile
                    let user = User(
                        id: UUID(),
                        firebaseUID: result.user.uid,
                        email: result.user.email ?? "",
                        membershipType: membershipType,
                        dateJoined: Date(),
                        subscriptionLevel: subscriptionLevel
                    )
                    
                    try await saveUserProfile(user)
                    
                    // Join the team
                    let firebaseManager = FirebaseManager.shared
                    let _ = try await firebaseManager.joinTeamWithCode(inviteCode)
                    
                    await MainActor.run {
                        self.isHandlingInviteSignup = false
                        self.currentUser = user
                        self.needsMembershipSelection = false
                        self.isAuthenticated = true
                        self.isLoading = false

                        // Create legacy coach object
                        self.currentCoach = Coach(
                            id: user.id,
                            firebaseUID: user.firebaseUID,
                            name: displayName ?? user.email ?? "User",
                            email: user.email ?? "",
                            phone: "",
                            teams: [],
                            subscriptionLevel: user.subscriptionLevel,
                            dateJoined: user.dateJoined
                        )

                        // Clear pending invite info
                        self.pendingInviteCode = nil
                        self.pendingInviteAccessLevel = nil

                        print("✅ FirebaseAuthManager: Apple user signed up and joined team with \(subscriptionLevel.rawValue) access")
                    }
                } else {
                    // Regular Apple sign-in
                    await loadUserProfile(for: result.user)
                }

                appleContinuation?.resume()
                appleContinuation = nil

            } catch {
                print("❌ FirebaseAuthManager: Apple sign in failed: \(error)")
                await MainActor.run {
                    self.isHandlingInviteSignup = false
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                appleContinuation?.resume(throwing: error)
                appleContinuation = nil
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign-In failed: \(error)")
        
        Task {
            await MainActor.run {
                self.isLoading = false
                
                // Handle user cancellation gracefully
                if let authError = error as? ASAuthorizationError {
                    switch authError.code {
                    case .canceled:
                        self.errorMessage = nil // Don't show error for user cancellation
                    case .unknown:
                        self.errorMessage = "Apple Sign-In failed. Please try again."
                    case .invalidResponse:
                        self.errorMessage = "Invalid response from Apple. Please try again."
                    case .notHandled:
                        self.errorMessage = "Apple Sign-In not handled. Please try again."
                    case .failed:
                        self.errorMessage = "Apple Sign-In failed. Please try again."
                    @unknown default:
                        self.errorMessage = "An unknown error occurred with Apple Sign-In."
                    }
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        
        appleContinuation?.resume(throwing: error)
        appleContinuation = nil
    }
}

// MARK: - Legacy Coach Support
struct Coach: Identifiable, Codable, Equatable {
    var id: UUID
    var firebaseUID: String
    var name: String
    var email: String
    var phone: String
    var teams: [UUID]
    var subscriptionLevel: SubscriptionLevel
    var dateJoined: Date
}
