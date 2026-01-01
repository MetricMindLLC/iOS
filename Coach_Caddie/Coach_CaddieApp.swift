import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import UserNotifications
import GoogleSignIn

@main
struct Coach_CaddieApp: App {
    @StateObject private var authManager = FirebaseAuthManager()
    @StateObject private var teamManager = TeamManager()
    @StateObject private var appStateManager = AppStateManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var firebaseManager = FirebaseManager.shared

    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Setup Firestore
        setupFirestore()
        
        // Configure Google Sign-In (if needed)
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // FIXED: Proper navigation hierarchy
                if !authManager.isAuthenticated {
                    // Not authenticated - show onboarding
                    OnboardingView()
                        .environmentObject(authManager)
                        .environmentObject(teamManager)
                        .environmentObject(firebaseManager)
                } else if authManager.needsMembershipSelection {
                    // Authenticated but needs membership selection
                    MembershipSelectionView()
                        .environmentObject(authManager)
                        .environmentObject(firebaseManager)
                } else {
                    // Fully authenticated with membership - show main app
                    MainAppView()
                        .environmentObject(authManager)
                        .environmentObject(teamManager)
                        .environmentObject(appStateManager)
                        .environmentObject(firebaseManager)
                        .environmentObject(notificationManager)
                }
            }
            .onAppear {
                setupNotifications()
                authManager.checkAuthenticationStatus()
                appStateManager.configure(with: teamManager)
                teamManager.forceRecalculateAllStats()
            }
            .alert("Error", isPresented: .constant(teamManager.errorMessage != nil)) {
                Button("OK") {
                    teamManager.errorMessage = nil
                }
            } message: {
                if let error = teamManager.errorMessage {
                    Text(error)
                }
            }
            .overlay {
                if teamManager.isLoading {
                    LoadingOverlay()
                }
            }
            .overlay {
                if appStateManager.isOffline {
                    OfflineIndicator(
                        pendingSyncItems: appStateManager.pendingSyncItems,
                        onRetry: {
                            appStateManager.triggerSync()
                        }
                    )
                }
            }
            // Handle incoming notifications
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Refresh data when app becomes active
                teamManager.loadData()
            }
            // Handle Google Sign-In URL - Fixed: removed return value
            .onOpenURL { url in
                _ = GIDSignIn.sharedInstance.handle(url)
            }
        }
    }

    private func setupFirestore() {
        let settings = FirestoreSettings()
        
        // NEW: Use the updated cache settings API
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        
        Firestore.firestore().settings = settings
    }
    
    // MARK: - Notification Setup
    private func setupNotifications() {
        notificationManager.requestPermission()

        let center = UNUserNotificationCenter.current()

        let gameCategory = UNNotificationCategory(
            identifier: "GAME_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let practiceCategory = UNNotificationCategory(
            identifier: "PRACTICE_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([gameCategory, practiceCategory])
    }
}
