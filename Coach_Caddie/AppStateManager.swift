import SwiftUI
import Combine

@MainActor
class AppStateManager: ObservableObject {
    @Published var isOffline = false
    @Published var pendingSyncItems = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var teamManager: TeamManager?
    
    init() {
        setupNetworkMonitoring()
        restoreActiveGameOnLaunch()
    }
    
    func configure(with teamManager: TeamManager) {
        self.teamManager = teamManager
        
        // Monitor pending changes - now properly on MainActor
        teamManager.$pendingChanges
            .map { $0.count }
            .assign(to: &$pendingSyncItems)
    }
    
    private func setupNetworkMonitoring() {
        // Monitor network status from FirebaseManager
        FirebaseManager.shared.$isOnline
            .map { !$0 }
            .assign(to: &$isOffline)
    }
    
    private func restoreActiveGameOnLaunch() {
        // Check if there's a persisted active game that should be restored
        if let activeGameData = UserDefaults.standard.data(forKey: "ActiveGameState"),
           let activeGameState = try? JSONDecoder().decode(PersistedActiveGameState.self, from: activeGameData) {
            
            // Restore the game state in GameStateManager
            GameStateManager.shared.restoreActiveGameState(from: activeGameState)
            
            print("✅ Restored active game: \(activeGameState.opponent)")
        }
    }
    
    func triggerSync() {
        // Since syncPendingChanges is private, we need to trigger a sync differently
        // We can force a data reload which will trigger the sync if online
        // Now properly called on MainActor
        teamManager?.loadData()
    }
}
