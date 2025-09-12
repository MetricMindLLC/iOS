import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Foundation
import Combine

// MARK: - Permission Cache Models (FIXED)
struct UserPermissionCache {
    let userUID: String
    var teamRoles: [UUID: AccessLevel]  // FIXED: Changed from 'let' to 'var'
    var editablePlayerIds: [UUID: [UUID]]  // FIXED: Changed from 'let' to 'var'
    let cacheTimestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(cacheTimestamp) > 3600 // Expire after 1 hour
    }
}

@MainActor
class TeamManager: ObservableObject {
    @Published var teams: [Team] = []
    @Published var selectedTeam: Team?
    @Published var isLoading = false
    @Published var isOnline = true
    @Published var errorMessage: String?
    @Published var pendingChanges: [String: PendingChange] = [:]
    @Published var appSettings = AppSettings()
    @Published var isReconnecting = false
    @Published var lastSavedDate: Date?
    
    // MARK: - Permission Caching (NEW)
    @Published private var permissionCache: UserPermissionCache?
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    
    let firebaseManager = FirebaseManager.shared
    var authManager: FirebaseAuthManager? // ADDED - Reference to auth manager
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    private let teamsFileName = "teams.json"
    private let backupFileName = "teams_backup.json"
    private let pendingChangesFileName = "pending_changes.json"
    private let settingsFileName = "app_settings.json"
    
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounceTime: TimeInterval = 0.5
    private var cancellables = Set<AnyCancellable>()
    private var firebaseUpdateWorkItems: [UUID: DispatchWorkItem] = [:]
    private let firebaseUpdateDebounceTime: TimeInterval = 1.5 // Shorter debounce for semi-live updates
    private var gameStateUpdateWorkItems: [UUID: DispatchWorkItem] = [:]
    private var lastSaveTime: [UUID: Date] = [:]
    private let minimumSaveInterval: TimeInterval = 2.0
    private let gameStateUpdateDebounceTime: TimeInterval = 10.0 // Game state updates every 10 seconds
    private var pendingUpdates: [UUID: Team] = [:]
    private var batchUpdateTimer: Timer?
    private var activeListeners: Set<UUID> = []
    private var cachedTeamOwnership: [UUID: Bool] = [:]
    private var teamOwnershipCacheTimestamp: Date?
    private let teamOwnershipCacheExpiration: TimeInterval = 3600 // 1 hour
    init() {
        // IMPORTANT: Don't load local data immediately - wait for auth state
        loadAppSettings()
        setupNetworkMonitoring()
        setupAuthStateListener()
        
        // Listen for clear data notification
        NotificationCenter.default.publisher(for: Notification.Name("ClearLocalData"))
            .sink { [weak self] _ in
                self?.clearAllLocalData()
            }
            .store(in: &cancellables)
        
        // ADDED: Listen for force load teams notification
        NotificationCenter.default.publisher(for: Notification.Name("ForceLoadTeams"))
            .sink { [weak self] _ in
                Task {
                    await self?.forceLoadTeamsFromFirebase()
                }
            }
            .store(in: &cancellables)
        
        // ADDED: Migrate existing teams to include TTL fields
        // This will run after teams are loaded via auth state change
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.migrateTeamsForTTL()
        }
    }
    
var teamsICreated: [Team] {
    guard let currentUser = Auth.auth().currentUser else { return [] }
    
    // Don't refresh cache if there are no teams
    guard !teams.isEmpty else { return [] }
    
    // Check if cache is still valid
    if let cacheTime = teamOwnershipCacheTimestamp,
       Date().timeIntervalSince(cacheTime) < teamOwnershipCacheExpiration,
       !cachedTeamOwnership.isEmpty {
        // Use cached results
        let created = teams.filter { cachedTeamOwnership[$0.id] == true }
        return created
    }
    
    // Cache is expired or empty, recalculate and cache
    cachedTeamOwnership.removeAll()
    
    for team in teams {
        let isOwner = team.coachUID == currentUser.uid
        cachedTeamOwnership[team.id] = isOwner
    }
    
    teamOwnershipCacheTimestamp = Date()
    
    let created = teams.filter { cachedTeamOwnership[$0.id] == true }
    
    // Only log when cache is actually refreshed
    print("🔍 Team ownership cache refreshed: \(created.count) out of \(teams.count) total teams")
    
    return created
}

    var teamsIWasInvitedTo: [Team] {
        guard let currentUser = Auth.auth().currentUser else { return [] }
        
        // Use cached ownership data if available
        if let cacheTime = teamOwnershipCacheTimestamp,
           Date().timeIntervalSince(cacheTime) < teamOwnershipCacheExpiration,
           !cachedTeamOwnership.isEmpty {
            return teams.filter { cachedTeamOwnership[$0.id] == false }
        }
        
        // Fallback to direct calculation if cache not available
        return teams.filter { $0.coachUID != currentUser.uid }
    }
    
    func canCreateMoreTeams() -> Bool {
        guard let user = authManager?.currentUser else { return false }
        
        // Shared access users can't create teams at all
        if user.subscriptionLevel == .sharedAccess {
            return false
        }
        
        // Only count teams the user CREATED (where they are the original coachUID)
        let createdTeamsCount = teamsICreated.count
        let maxAllowed = user.maxTeamsAllowed
        
        print("🔍 canCreateMoreTeams check: created=\(createdTeamsCount), max=\(maxAllowed), subscription=\(user.subscriptionLevel.rawValue)")
        
        return createdTeamsCount < maxAllowed
    }
    
    // ADDED: Method to set auth manager reference
    func setAuthManager(_ authManager: FirebaseAuthManager) {
        self.authManager = authManager
    }
    
    private func clearTeamOwnershipCache() {
        cachedTeamOwnership.removeAll()
        teamOwnershipCacheTimestamp = nil
    }

    // Add method to refresh cache on demand (for app startup)
    func refreshTeamOwnershipCache() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        cachedTeamOwnership.removeAll()
        
        for team in teams {
            let isOwner = team.coachUID == currentUser.uid
            cachedTeamOwnership[team.id] = isOwner
        }
        
        teamOwnershipCacheTimestamp = Date()
        print("🔍 Team ownership cache manually refreshed")
    }
    
    func deletePractice(from team: Team, practiceId: UUID) {
        print("🗑️ TeamManager.deletePractice called for practice ID: \(practiceId)")
        
        guard let teamIndex = teams.firstIndex(where: { $0.id == team.id }) else {
            print("🗑️ ERROR: Team not found in teams array")
            return
        }
        
        guard let practiceIndex = teams[teamIndex].practices.firstIndex(where: { $0.id == practiceId }) else {
            print("🗑️ ERROR: Practice not found in team.practices array")
            return
        }
        
        // Get the practice object before removing it
        let practiceToDelete = teams[teamIndex].practices[practiceIndex]
        
        // Remove from local array first
        teams[teamIndex].practices.remove(at: practiceIndex)
        print("🗑️ Practice removed from local array, remaining practices: \(teams[teamIndex].practices.count)")
        
        // Save locally immediately (don't call updateTeam!)
        debouncedSave()
        
        // Handle Firebase deletion - DON'T call updateTeam()
        if isOnline {
            Task {
                do {
                    // Ensure authentication before Firebase operation
                    guard await self.ensureAuthentication() else { return }
                    
                    // Use the specific deletePractice method from FirebaseManager
                    try await firebaseManager.deletePractice(practiceToDelete, from: team)
                    print("✅ Practice deleted from Firebase successfully")
                } catch {
                    await MainActor.run {
                        self.setError("Failed to delete practice from cloud: \(error.localizedDescription)")
                        // Add to pending changes as fallback
                        self.addToPendingChanges("delete_practice_\(practiceId.uuidString)", action: "delete_practice", teamId: team.id.uuidString)
                    }
                }
            }
        } else {
            // Add to pending changes for offline deletion
            addToPendingChanges("delete_practice_\(practiceId.uuidString)", action: "delete_practice", teamId: team.id.uuidString)
        }
    }
    
    private func handleNetworkReconnection() async {
        do {
            // Only reload if user is properly authenticated (not anonymous)
            if let currentUser = Auth.auth().currentUser, !currentUser.isAnonymous {
                await loadTeamsFromFirebase()
            }
        } catch {
            await MainActor.run {
                self.setError("Network reconnection failed: \(error.localizedDescription)")
            }
        }
    }
    
    func batchUpdateTeams() {
        // Cancel any existing batch timer
        batchUpdateTimer?.invalidate()
        
        // Schedule batch update
        batchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            Task {
                await self.processBatchUpdates()
            }
        }
    }

    private func processBatchUpdates() async {
        let teamsToUpdate = pendingUpdates.values
        pendingUpdates.removeAll()
        
        guard !teamsToUpdate.isEmpty else { return }
        
        print("📦 Processing batch update for \(teamsToUpdate.count) teams")
        
        for team in teamsToUpdate {
            do {
                try await firebaseManager.saveTeam(team)
            } catch {
                print("❌ Failed to save team in batch: \(error)")
            }
        }
    }
    
    // UPDATED: Fixed setupAuthStateListener to avoid "Publishing changes from within view updates"
    private func setupAuthStateListener() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            // Use DispatchQueue.main.async instead of Task/MainActor.run to avoid the publishing error
            DispatchQueue.main.async {
                if user != nil {
                    print("🔐 Auth state changed - user signed in, loading teams...")
                    // Move async operations outside of the main queue callback
                    Task {
                        await self?.loadTeamsFromLocal() // Load local first
                        await self?.loadAllUserPermissions() // Then load permissions
                    }
                } else {
                    print("🔒 No authenticated user - not loading local data")
                    self?.teams = []
                    self?.clearPermissionCache()
                    self?.clearTeamOwnershipCache()
                }
            }
        }
    }
    
    // UPDATED: Handle auth state changes properly
    private func handleAuthStateChange() async {
        if let currentUser = Auth.auth().currentUser, !currentUser.isAnonymous {
            // User is authenticated - load their data
            loadLocalData()
            await loadTeamsFromFirebase()
            // NEW: Load permissions after teams are loaded
            await loadUserPermissions()
        } else {
            // User is not authenticated - clear all data
            clearAllLocalData()
            clearPermissionCache() // NEW: Clear permission cache
        }
    }
    
    private func setupNetworkMonitoring() {
        firebaseManager.$isOnline
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main) // Debounce changes
            .sink { [weak self] isOnline in
                self?.isOnline = isOnline
                
                if isOnline {
                    self?.isReconnecting = true
                    Task {
                        await self?.handleNetworkReconnection()
                        await MainActor.run {
                            self?.isReconnecting = false
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func updateTeam(_ team: Team, activeGameId: UUID? = nil) {
        print("🔥 updateTeam called for team: \(team.name)")
        print("🔥 Called from: \(Thread.callStackSymbols[1])")
        print("🔥 Team ID: \(team.id)")
        print("🔥 Current user UID: \(Auth.auth().currentUser?.uid ?? "nil")")
        print("🔥 Team coachUID: \(team.coachUID ?? "nil")")
        print("🔥 isOnline: \(firebaseManager.isOnline)")
        print("🔥 Active Game ID: \(activeGameId?.uuidString ?? "none")")
        
        // Update local array first
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index] = team
            debouncedSave() // This is your existing local save method
        }
        
        // Cancel any existing work item for this team
        firebaseUpdateWorkItems[team.id]?.cancel()
        
        // Route to appropriate save method based on whether we have an active game
        if let activeGameId = activeGameId,
           let activeGame = team.games.first(where: { $0.id == activeGameId }) {
            print("🔥 Routing to ACTIVE GAME specific save for game: \(activeGame.opponent)")
            updateActiveGameWithDebounce(team, activeGame: activeGame)
        } else {
            print("🔥 Routing to FULL TEAM save (will process all games)")
            updateTeamWithDebounce(team, debounceTime: 1.5)
        }
    }
    
    private var teamListeners: [UUID: ListenerRegistration] = [:]

    // Add this method to temporarily disable listeners
    func pauseRealTimeListeners(for teamId: UUID) {
        if let listener = teamListeners[teamId] {
            listener.remove()
            teamListeners.removeValue(forKey: teamId)
            print("🔇 Paused real-time listener for team")
        }
    }

    // Add this method to resume listeners
    func resumeRealTimeListeners(for teamId: UUID) {
        // Resume listener after a delay to ensure our save completes first
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            // Re-setup listener here (you'll need to call your existing listener setup code)
            print("🔊 Resumed real-time listener for team")
        }
    }

    private func updateTeamForLiveGame(_ team: Team) {
        // Cancel any pending regular update
        firebaseUpdateWorkItems[team.id]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { [weak self] in
                await self?.saveTeamToFirebaseLive(team)
            }
        }
        
        firebaseUpdateWorkItems[team.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + firebaseUpdateDebounceTime, execute: workItem)
    }

    private func updateTeamWithDebounce(_ team: Team, debounceTime: TimeInterval) {
        // Cancel any pending update for this team
        firebaseUpdateWorkItems[team.id]?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            Task { [weak self] in
                await self?.saveTeamToFirebase(team)
            }
        }
        
        firebaseUpdateWorkItems[team.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceTime, execute: workItem)
    }

    // MARK: - Live Game Firebase Save (maintains real-time listeners)
    private func saveTeamToFirebaseLive(_ team: Team) async {
        print("🔥 LIVE saveTeamToFirebase called for team: \(team.name)")
        
        guard await ensureAuthentication() else {
            print("❌ ensureAuthentication failed")
            return
        }
        
        do {
            try await firebaseManager.saveTeam(team)
            print("✅ LIVE Firebase save completed - parents/viewers will see updates")
            
            await MainActor.run {
                self.removePendingChange("team_\(team.id.uuidString)")
                self.firebaseUpdateWorkItems.removeValue(forKey: team.id)
            }
        } catch {
            print("❌ LIVE Firebase save failed: \(error)")
            await MainActor.run {
                self.setError("Failed to save team: \(error.localizedDescription)")
                self.addToPendingChanges("team_\(team.id.uuidString)", action: "update", teamId: team.id.uuidString)
                self.firebaseUpdateWorkItems.removeValue(forKey: team.id)
            }
        }
    }
    
    private func updateActiveGameWithDebounce(_ team: Team, activeGame: Game) {
        // Cancel any pending update for this team
        firebaseUpdateWorkItems[team.id]?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            Task { [weak self] in
                await self?.saveActiveGameToFirebaseLive(team, activeGame: activeGame)
            }
        }
        
        firebaseUpdateWorkItems[team.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + firebaseUpdateDebounceTime, execute: workItem)
    }


    private func saveActiveGameToFirebaseLive(_ team: Team, activeGame: Game) async {
        print("🎯 LIVE saveActiveGameToFirebase called for game: \(activeGame.opponent)")
        
        guard await ensureAuthentication() else {
            print("❌ ensureAuthentication failed")
            return
        }
        
        do {
            // Use the specific active game save method instead of full team save
            try await firebaseManager.saveActiveGameData(activeGame, in: team)
            print("✅ LIVE Active Game save completed - parents/viewers will see updates")
            
            await MainActor.run {
                self.removePendingChange("team_\(team.id.uuidString)")
                self.firebaseUpdateWorkItems.removeValue(forKey: team.id)
            }
        } catch {
            print("❌ LIVE Active Game save failed: \(error)")
            await MainActor.run {
                self.setError("Failed to save active game: \(error.localizedDescription)")
                self.addToPendingChanges("team_\(team.id.uuidString)", action: "update", teamId: team.id.uuidString)
                self.firebaseUpdateWorkItems.removeValue(forKey: team.id)
            }
        }
    }
    
    func updateTeamImmediatelyForActiveGame(_ team: Team, activeGameId: UUID) async {
        print("🚨 CRITICAL EVENT - immediate sync for live view")
        
        // Cancel any pending debounced updates
        firebaseUpdateWorkItems[team.id]?.cancel()
        firebaseUpdateWorkItems.removeValue(forKey: team.id)
        
        // Update local state
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index] = team
            debouncedSave()
        }
        
        // Get the active game
        guard let activeGame = team.games.first(where: { $0.id == activeGameId }) else {
            print("❌ Active game not found, falling back to full team save")
            await updateTeamImmediately(team)
            return
        }
        
        // Save only the active game data immediately
        if isOnline {
            await saveActiveGameToFirebaseLive(team, activeGame: activeGame)
        } else {
            addToPendingChanges("team_\(team.id.uuidString)", action: "update", teamId: team.id.uuidString)
        }
    }

    // MARK: - Regular Firebase Save (no refresh call for performance)
    private func saveTeamToFirebase(_ team: Team) async {
        print("🔥 saveTeamToFirebase called for team: \(team.name)")
        
        guard await ensureAuthentication() else {
            print("❌ ensureAuthentication failed")
            return
        }
        
        do {
            try await firebaseManager.saveTeam(team)
            print("✅ Firebase save completed successfully")
            
            // REMOVED: The refresh call that was causing extra latency
            // await refreshTeamData(team.id) // <-- STILL REMOVED
            
            await MainActor.run {
                self.removePendingChange("team_\(team.id.uuidString)")
                self.firebaseUpdateWorkItems.removeValue(forKey: team.id)
            }
        } catch {
            print("❌ Firebase save failed: \(error)")
            await MainActor.run {
                self.setError("Failed to save team: \(error.localizedDescription)")
                self.addToPendingChanges("team_\(team.id.uuidString)", action: "update", teamId: team.id.uuidString)
                self.firebaseUpdateWorkItems.removeValue(forKey: team.id)
            }
        }
    }

    // MARK: - Immediate Save Method (for critical updates that need instant sync)
    func updateTeamImmediately(_ team: Team) async {
        print("🚨 IMMEDIATE team update requested")
        
        // Cancel any pending debounced update
        firebaseUpdateWorkItems[team.id]?.cancel()
        firebaseUpdateWorkItems.removeValue(forKey: team.id)
        
        // Update local state
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index] = team
            debouncedSave()
        }
        
        // Save immediately to Firebase for real-time sync
        if isOnline {
            await saveTeamToFirebaseLive(team)
        } else {
            addToPendingChanges("team_\(team.id.uuidString)", action: "update", teamId: team.id.uuidString)
        }
    }

    // MARK: - Game State Sync (separate from team updates for better performance)
    func syncGameStateForLiveView(_ gameState: ActiveGameState) {
        guard let team = teams.first(where: { $0.id == gameState.teamId }) else { return }
        
        // Cancel any pending game state update
        gameStateUpdateWorkItems[team.id]?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            Task { [weak self] in
                // Only sync critical game state info (time, score, current events)
                await self?.syncMinimalGameState(gameState, for: team)
            }
        }
        
        gameStateUpdateWorkItems[team.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + gameStateUpdateDebounceTime, execute: workItem)
        
        print("⏱️ Scheduled game state sync in \(gameStateUpdateDebounceTime) seconds")
    }

    private func syncMinimalGameState(_ gameState: ActiveGameState, for team: Team) async {
        // Sync only essential game state data for live view
        // This could be a separate Firebase document or a lightweight update
        print("⏱️ Syncing minimal game state for live view")
        
        // Implementation would depend on your Firebase structure
        // This keeps the real-time experience while reducing data transfer
    }
    
    // MARK: - Authentication Helper
    private func ensureAuthentication() async -> Bool {
        // Check if user is already authenticated (and not anonymous)
        if let currentUser = Auth.auth().currentUser, !currentUser.isAnonymous {
            return true
        }
        
        // Don't automatically sign in anonymously - require proper authentication
        await MainActor.run {
            self.setError("Authentication required. Please sign in.")
        }
        return false
    }
    
    // MARK: - FIXED Permission Caching System
    
    var currentUserUID: String? {
        return Auth.auth().currentUser?.uid
    }
    
    private var loggedCoachStatus: Set<String> = []
    
    func getCurrentUserRole(for team: Team) -> AccessLevel {
        guard let currentUserUID = currentUserUID else {
            print("⚠️ No current user UID available")
            return .viewer
        }
        
        // Check if user is the team coach first (this is always reliable)
        if team.coachUID == currentUserUID {
            // Only log once per team per session
            let logKey = "\(team.id)-\(currentUserUID)"
            if !loggedCoachStatus.contains(logKey) {
                print("✅ User is team coach for \(team.name)")
                loggedCoachStatus.insert(logKey)
            }
            
            // FIXED: Only update cache if it's not already cached correctly
            if let cache = permissionCache,
               let existingRole = cache.teamRoles[team.id],
               existingRole == .coach {
                // Cache already has correct info, don't update again
                return .coach
            }
            
            // FIXED: Use DispatchQueue.main.async to avoid "Publishing changes from within view updates"
            DispatchQueue.main.async {
                self.updateCacheForTeam(team.id, role: .coach, playerIds: team.players.map { $0.id })
            }
            
            return .coach
        }

        // Return cached role if available
        if let cache = permissionCache,
           !cache.isExpired,
           let role = cache.teamRoles[team.id] {
            print("🎯 CACHE HIT: Role for team \(team.name): \(role.displayName)")
            return role
        }
        
        print("⚠️ CACHE MISS: No cached role for team \(team.name)")
        
        // For new users with no cache, trigger an async refresh but return reasonable default
        Task {
            await refreshPermissions(for: team)
        }
        
        // For immediate return, check if user is in starting lineup (likely a coach-created team)
        if team.coachUID == currentUserUID ||
           (team.coachUID == nil && !team.players.isEmpty) { // Legacy team with no coachUID
            return .coach
        }
        
        return .viewer // Safe default for new users
    }

    /// FIXED: Update cache for a specific team - now safe for synchronous calls
    private func updateCacheForTeam(_ teamId: UUID, role: AccessLevel, playerIds: [UUID]) {
        guard let currentUserUID = currentUserUID else { return }
        
        if var existingCache = permissionCache, existingCache.userUID == currentUserUID {
            // Update existing cache
            existingCache.teamRoles[teamId] = role
            existingCache.editablePlayerIds[teamId] = playerIds
            permissionCache = UserPermissionCache(
                userUID: existingCache.userUID,
                teamRoles: existingCache.teamRoles,
                editablePlayerIds: existingCache.editablePlayerIds,
                cacheTimestamp: Date()
            )
        } else {
            // Create new cache
            permissionCache = UserPermissionCache(
                userUID: currentUserUID,
                teamRoles: [teamId: role],
                editablePlayerIds: [teamId: playerIds],
                cacheTimestamp: Date()
            )
        }
        
        print("✅ Updated cache for team: \(role.displayName)")
    }
    /// Get editable player IDs for team (synchronous, uses cache and email matching)
    /// FIXED: Now includes email matching for parents with sharedAccess subscription
    func getEditablePlayerIds(for team: Team) -> [UUID] {
        // First check cache
        if let cache = permissionCache,
           !cache.isExpired,
           let playerIds = cache.editablePlayerIds[team.id] {
            print("🎯 CACHE HIT: \(playerIds.count) editable players for team \(team.name)")
            
            // FIXED: Always check email matching for parents (including sharedAccess members)
            let role = getCurrentUserRole(for: team)
            if role == .parent || shouldCheckEmailMatching() {
                if let userEmail = Auth.auth().currentUser?.email?.lowercased() {
                    var allEditableIds = Set(playerIds)
                    for player in team.players {
                        let parentEmail = player.parentInfo.parentEmail.lowercased()
                        let secondParentEmail = player.parentInfo.secondParentEmail.lowercased()
                        
                        if parentEmail == userEmail || secondParentEmail == userEmail {
                            allEditableIds.insert(player.id)
                        }
                    }
                    return Array(allEditableIds)
                }
            }
            
            return playerIds
        }
        
        // If no cache, calculate based on role and email matching
        let role = getCurrentUserRole(for: team)
        
        switch role {
        case .coach:
            // Coaches can edit all players
            return team.players.map { $0.id }
            
        case .parent:
            // Parents can edit players where their email matches
            if let userEmail = Auth.auth().currentUser?.email?.lowercased() {
                return team.players.compactMap { player in
                    let parentEmail = player.parentInfo.parentEmail.lowercased()
                    let secondParentEmail = player.parentInfo.secondParentEmail.lowercased()
                    
                    if parentEmail == userEmail || secondParentEmail == userEmail {
                        return player.id
                    }
                    return nil
                }
            }
            return []
            
        case .viewer:
            // Viewers cannot edit any players
            return []
        }
    }
    
    /// Helper method to check if we should check email matching
    /// FIXED: Check for sharedAccess subscription instead of specific membership type
    private func shouldCheckEmailMatching() -> Bool {
        // Check if user has sharedAccess subscription (parents who joined via invite)
        if let authManager = authManager,
           let currentUser = authManager.currentUser {
            // Users with sharedAccess subscription should have email matching checked
            return currentUser.subscriptionLevel == .sharedAccess
        }
        return false
    }
    
    /// Check if user can edit specific player (synchronous, uses cache and email matching)
    /// FIXED: Now checks email matching for parents and sharedAccess members
    func canCurrentUserEdit(player: Player, in team: Team) -> Bool {
        let role = getCurrentUserRole(for: team)
        
        // Coaches can edit all players
        if role == .coach {
            return true
        }
        
        // Parents and sharedAccess members can edit players where their email matches
        if role == .parent || shouldCheckEmailMatching() {
            // First check cached editable player IDs
            let editableIds = getEditablePlayerIds(for: team)
            if editableIds.contains(player.id) {
                return true
            }
            
            // FIXED: Also check email matching
            if let userEmail = Auth.auth().currentUser?.email?.lowercased() {
                let parentEmail = player.parentInfo.parentEmail.lowercased()
                let secondParentEmail = player.parentInfo.secondParentEmail.lowercased()
                
                // If parent's email matches either parent email field, they can edit
                if parentEmail == userEmail || secondParentEmail == userEmail {
                    return true
                }
            }
        }
        
        // Viewers cannot edit
        return false
    }
    
    /// NEW: Synchronous version that uses cache
    func canCurrentUserEditTeam(_ team: Team) -> Bool {
        let role = getCurrentUserRole(for: team)
        return role == .coach
    }
    
    /// FIXED: Load all user permissions with better new user handling
    func loadAllUserPermissions() async {
        guard let currentUserUID = currentUserUID else {
            print("❌ No current user UID for permission loading")
            return
        }
        
        print("🔄 Loading ALL user permissions for UID: \(currentUserUID)")
        
        var teamRoles: [UUID: AccessLevel] = [:]
        var editablePlayerIds: [UUID: [UUID]] = [:]
        
        // Use async/await for better error handling
        await withTaskGroup(of: (UUID, AccessLevel, [UUID]).self) { group in
            for team in teams {
                group.addTask {
                    let role = await self.fetchUserRoleFromFirebase(userUID: currentUserUID, team: team)
                    let playerIds = await self.fetchEditablePlayerIdsFromFirebase(userUID: currentUserUID, team: team, role: role)
                    return (team.id, role, playerIds)
                }
            }
            
            for await (teamId, role, playerIds) in group {
                teamRoles[teamId] = role
                editablePlayerIds[teamId] = playerIds
            }
        }
        
        // Cache the results
        let newCache = UserPermissionCache(
            userUID: currentUserUID,
            teamRoles: teamRoles,
            editablePlayerIds: editablePlayerIds,
            cacheTimestamp: Date()
        )
        
        await MainActor.run {
            self.permissionCache = newCache
            print("✅ Cached permissions for \(teamRoles.count) teams")
            
            // Debug output with better formatting
            for (teamId, role) in teamRoles {
                if let team = teams.first(where: { $0.id == teamId }) {
                    print("   📋 \(team.name): \(role.displayName) (\(editablePlayerIds[teamId]?.count ?? 0) editable players)")
                }
            }
        }
    }
    
    /// Load all permissions for current user (call once at app startup) - LEGACY NAME
    func loadUserPermissions() async {
        await loadAllUserPermissions()
    }
    
    /// Refresh permissions for specific team (FIXED)
    func refreshPermissions(for team: Team) async {
        guard let currentUserUID = currentUserUID else { return }
        
        print("🔄 Refreshing permissions for team: \(team.name)")
        
        let role = await fetchUserRoleFromFirebase(userUID: currentUserUID, team: team)
        let playerIds = await fetchEditablePlayerIdsFromFirebase(userUID: currentUserUID, team: team, role: role)
        
        await MainActor.run {
            // Update cache - create new cache object instead of modifying
            if let existingCache = self.permissionCache {
                // Create new cache with updated values
                let newCache = UserPermissionCache(
                    userUID: existingCache.userUID,
                    teamRoles: existingCache.teamRoles.merging([team.id: role]) { _, new in new },
                    editablePlayerIds: existingCache.editablePlayerIds.merging([team.id: playerIds]) { _, new in new },
                    cacheTimestamp: Date()
                )
                self.permissionCache = newCache
            } else {
                // Create new cache
                self.permissionCache = UserPermissionCache(
                    userUID: currentUserUID,
                    teamRoles: [team.id: role],
                    editablePlayerIds: [team.id: playerIds],
                    cacheTimestamp: Date()
                )
            }
            
            print("✅ Updated permissions cache for team \(team.name)")
            print("   📋 Role: \(role.displayName)")
            print("   👥 Editable players: \(playerIds.count)")
        }
    }
    
    /// Clear permission cache (call on logout)
    func clearPermissionCache() {
        permissionCache = nil
        print("🗑️ Permission cache cleared")
    }
    
    /// Check if cache needs refresh
    func shouldRefreshPermissions() -> Bool {
        guard let cache = permissionCache else { return true }
        return cache.isExpired
    }
    
    /// FIXED: Auto-refresh permissions for new users when they create their first team
    func refreshPermissionsForNewCoach(team: Team) async {
        guard let currentUserUID = currentUserUID else { return }
        
        print("🔄 Refreshing permissions for new coach - Team: \(team.name)")
        
        // Immediately set coach role in cache
        updateCacheForTeam(team.id, role: .coach, playerIds: team.players.map { $0.id })
        
        // Also refresh from Firebase to ensure consistency
        await refreshPermissions(for: team)
    }
    
    // ADDED: For compatibility - call loadTeamsFromLocal instead of loadLocalData directly
    private func loadTeamsFromLocal() async {
        loadLocalData()
    }
    
    // Update both methods to use "members" and "accessLevel"
    private func fetchUserRoleFromFirebase(userUID: String, team: Team) async -> AccessLevel {
        do {
            print("🔍 Firebase read: Fetching role for team \(team.name)")
            
            // First check if user is the team creator/coach
            if team.coachUID == userUID {
                return .coach
            }
            
            // Then check the members subcollection for assigned role
            let memberDoc = try await Firestore.firestore().collection("teams")
                .document(team.id.uuidString)
                .collection("members")  // ← Fixed collection name
                .document(userUID)
                .getDocument()
            
            if let data = memberDoc.data(),
               let roleString = data["accessLevel"] as? String,  // ← Fixed field name
               let role = AccessLevel(rawValue: roleString) {
                return role
            }
            
            // FIXED: Check if user has sharedAccess subscription and their email matches a parent
            if shouldCheckEmailMatching() {
                if let userEmail = Auth.auth().currentUser?.email?.lowercased() {
                    for player in team.players {
                        let parentEmail = player.parentInfo.parentEmail.lowercased()
                        let secondParentEmail = player.parentInfo.secondParentEmail.lowercased()
                        
                        if parentEmail == userEmail || secondParentEmail == userEmail {
                            // User's email matches a parent email, grant parent access
                            return .parent
                        }
                    }
                }
            }
            
            return .viewer
            
        } catch {
            if let firestoreError = error as NSError?,
               firestoreError.domain == "FIRFirestoreErrorDomain",
               firestoreError.code == 7 {
                print("⚠️ Permission denied reading team member - user likely not a member")
            } else {
                print("❌ Error fetching role: \(error)")
            }
            
            // FIXED: Even on error, check email matching for sharedAccess users
            if shouldCheckEmailMatching() {
                if let userEmail = Auth.auth().currentUser?.email?.lowercased() {
                    for player in team.players {
                        let parentEmail = player.parentInfo.parentEmail.lowercased()
                        let secondParentEmail = player.parentInfo.secondParentEmail.lowercased()
                        
                        if parentEmail == userEmail || secondParentEmail == userEmail {
                            return .parent
                        }
                    }
                }
            }
            
            return .viewer
        }
    }

    /// Fetch editable player IDs from Firebase (FIXED: includes email matching for all parent-role users)
    private func fetchEditablePlayerIdsFromFirebase(userUID: String, team: Team, role: AccessLevel) async -> [UUID] {
        // Coaches can edit all players
        if role == .coach {
            return team.players.map { $0.id }
        }
        
        // For parents (including sharedAccess members with parent role), check Firebase and email matching
        if role == .parent {
            var firebasePlayerIds: [UUID] = []
            
            do {
                print("🔍 Firebase read: Fetching editable players for parent in team \(team.name)")
                
                let memberDoc = try await Firestore.firestore().collection("teams")
                    .document(team.id.uuidString)
                    .collection("members")
                    .document(userUID)
                    .getDocument()
                
                if let data = memberDoc.data(),
                   let playerIdStrings = data["playerIds"] as? [String] {
                    firebasePlayerIds = playerIdStrings.compactMap { UUID(uuidString: $0) }
                }
                
            } catch {
                print("⚠️ Error fetching editable players from Firebase: \(error)")
            }
            
            // FIXED: Always check email matching for ALL users with parent role
            // This includes both regular parents and sharedAccess members
            if let userEmail = Auth.auth().currentUser?.email?.lowercased() {
                var allEditableIds = Set(firebasePlayerIds)
                
                for player in team.players {
                    let parentEmail = player.parentInfo.parentEmail.lowercased()
                    let secondParentEmail = player.parentInfo.secondParentEmail.lowercased()
                    
                    if parentEmail == userEmail || secondParentEmail == userEmail {
                        allEditableIds.insert(player.id)
                    }
                }
                
                let finalIds = Array(allEditableIds)
                print("🔧 Found \(finalIds.count) total editable players (Firebase + email matching) for \(userEmail)")
                return finalIds
            }
            
            return firebasePlayerIds
        }
        
        return []
    }
    
    func initializeUserSession() async {
        print("🚀 Initializing user session...")
        
        loadData()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await loadUserPermissions()
        
        // Refresh team ownership cache after session is initialized
        refreshTeamOwnershipCache()
        
        print("✅ User session initialized")
    }
    
    /// Call this when user logs out
    func cleanupUserSession() {
        clearPermissionCache()
        teams.removeAll()
        print("🧹 User session cleaned up")
    }
    
    func loadData() {
        // UPDATED: Only load local data if user is authenticated
        guard let currentUser = Auth.auth().currentUser, !currentUser.isAnonymous else {
            print("🔒 No authenticated user - not loading local data")
            return
        }
        
        loadLocalData()
        
        // ADDED: Recalculate stats after loading data to ensure they're current
        recalculateAllStatsAfterLoad()
        
        Task {
            await loadTeamsFromFirebase()
        }
    }

    // ADDED: Recalculate all stats after data is loaded
    private func recalculateAllStatsAfterLoad() {
        for teamIndex in teams.indices {
            recalculateStatsForTeam(teamIndex: teamIndex)
        }
        // Don't call updateTeam here to avoid unnecessary saves during startup
    }
    
    private func loadLocalData() {
        guard let currentUser = Auth.auth().currentUser, !currentUser.isAnonymous else {
            print("🔒 No authenticated user - clearing local data")
            teams = []
            selectedTeam = nil
            return
        }
        
        let teamsURL = documentsDirectory.appendingPathComponent(teamsFileName)
        
        guard FileManager.default.fileExists(atPath: teamsURL.path) else {
            teams = []
            return
        }
        
        do {
            let data = try Data(contentsOf: teamsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedTeams = try decoder.decode([Team].self, from: data)
            
            // DON'T FILTER - Load ALL teams (both created and invited)
            teams = loadedTeams
            
            // Set selected team to first team if not set
            if selectedTeam == nil && !teams.isEmpty {
                selectedTeam = teams.first
            }
            
            print("📱 Loaded \(teams.count) teams for user \(currentUser.uid)")
        } catch {
            print("Failed to load teams: \(error)")
            teams = []
        }
    }
    func addTeam(_ team: Team, isDemo: Bool = false) {
        // Enhanced team limits checking with better error messaging
        if let authManager = authManager,
           let currentUser = authManager.currentUser {
            
            // Check if user can create teams at all
            guard currentUser.subscriptionLevel.canCreateTeams else {
                switch currentUser.subscriptionLevel {
                case .sharedAccess:
                    setError("Shared access users cannot create teams. Ask a coach to invite you to their team.")
                case .cancelled, .expired:
                    setError("Your subscription has expired. Please renew your subscription to create teams.")
                default:
                    setError("Your current plan doesn't allow team creation. Please upgrade your subscription.")
                }
                return
            }
            
            // Check team count limits (only for non-demo teams)
            if !isDemo {
                let currentTeams = teamsICreated.count
                let maxTeams = currentUser.maxTeamsAllowed
                
                if currentTeams >= maxTeams {
                    let planName = currentUser.subscriptionLevel.displayName
                    if maxTeams == 1 {
                        setError("You've reached your team limit for the \(planName) plan. Upgrade to create more teams.")
                    } else {
                        setError("You've reached your maximum of \(maxTeams) teams for the \(planName) plan. Upgrade to create more teams.")
                    }
                    return
                }
            }
        }
        
        // CRITICAL FIX: Ensure team has coachUID set
        var teamToAdd = team
        if teamToAdd.coachUID == nil || teamToAdd.coachUID!.isEmpty {
            if let user = Auth.auth().currentUser {
                teamToAdd.coachUID = user.uid
                print("✅ Set coachUID to current user: \(user.uid)")
            }
        }
        
        teams.append(teamToAdd)
        clearTeamOwnershipCache()
        debouncedSave()
        
        // For demo teams or when offline, just save locally
        if isDemo || !isOnline {
            // Demo teams are created locally first
            if !isDemo {
                // Only add to pending changes if not a demo team
                addToPendingChanges("team_\(teamToAdd.id.uuidString)", action: "create", teamId: teamToAdd.id.uuidString)
            }
        } else {
            // Online and not demo - save to Firebase
            Task {
                do {
                    await saveTeamToFirebase(teamToAdd)
                    
                    // ADDED: Automatically add creator as coach member in Firebase
                    if let user = Auth.auth().currentUser {
                        try await firebaseManager.addUserToTeam(
                            userId: user.uid,
                            teamId: teamToAdd.id.uuidString,
                            accessLevel: .coach,
                            userEmail: user.email ?? ""
                        )
                        print("✅ Added creator as coach member in Firebase")
                    }
                } catch {
                    await MainActor.run {
                        // Enhanced error handling for Firebase errors
                        if error.localizedDescription.contains("permission") {
                            self.setError("Team creation failed: You've reached your team limit for your current subscription plan. Please upgrade to create more teams.")
                        } else {
                            self.setError("Failed to save team to cloud: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    func getTeamCreationStatusMessage() -> String? {
        guard let authManager = authManager,
              let currentUser = authManager.currentUser else { return "Please sign in to create teams." }
        
        if !currentUser.subscriptionLevel.canCreateTeams {
            switch currentUser.subscriptionLevel {
            case .sharedAccess:
                return "Shared access users cannot create teams."
            case .cancelled, .expired:
                return "Your subscription has expired."
            default:
                return "Your plan doesn't allow team creation."
            }
        }
        
        let currentTeams = teamsICreated.count
        let maxTeams = currentUser.maxTeamsAllowed
        
        if currentTeams == maxTeams - 1 {
            if maxTeams == 1 {
                return "You've reached your team limit."
            } else {
                return "You've reached your maximum of \(maxTeams) teams."
            }
        }
        
        if currentTeams == maxTeams - 1 {
            return "This will be your last team on the \(currentUser.subscriptionLevel.displayName) plan."
        }
        
        return nil
    }

    // Add this computed property for UI to check team limits
    var teamLimitInfo: (current: Int, max: Int, canCreate: Bool) {
        guard let authManager = authManager,
              let currentUser = authManager.currentUser else {
            return (current: teams.count, max: 0, canCreate: false)
        }
        
        return (
            current: teamsICreated.count,
            max: currentUser.maxTeamsAllowed,
            canCreate: canCreateMoreTeams()
        )
    }
    func deleteTeam(_ team: Team) {
        teams.removeAll { $0.id == team.id }
        
        if selectedTeam?.id == team.id {
            selectedTeam = teams.first
        }
        
        clearTeamOwnershipCache()
        debouncedSave()
        
        if isOnline {
            Task {
                await deleteTeamFromFirebase(team)
            }
        } else {
            addToPendingChanges("team_\(team.id.uuidString)", action: "delete", teamId: team.id.uuidString)
        }
    }
    
    func updatePlayer(in team: Team, player: Player) {
        guard let teamIndex = teams.firstIndex(where: { $0.id == team.id }) else {
            print("⚠️ Team not found for player update")
            return
        }
        
        guard let playerIndex = teams[teamIndex].players.firstIndex(where: { $0.id == player.id }) else {
            print("⚠️ Player not found for update")
            return
        }
        
        // Update local array first
        teams[teamIndex].players[playerIndex] = player
        teams[teamIndex].updateActivityTimestamp()
        
        print("✅ Updated player \(player.name) locally in team \(team.name)")
        
        // Save locally immediately
        debouncedSave()
        
        // Handle Firebase save efficiently based on subcollection support
        if teams[teamIndex].useSubcollections && isOnline {
            // For subcollection teams, save only the updated player
            Task {
                do {
                    guard await ensureAuthentication() else { return }
                    try await firebaseManager.savePlayerToSubcollection(player, in: teams[teamIndex])
                    print("✅ Updated player in subcollection: \(player.name)")
                } catch {
                    await MainActor.run {
                        self.setError("Failed to update player: \(error.localizedDescription)")
                        // Add to pending changes as fallback
                        self.addToPendingChanges("update_player_\(player.id.uuidString)", action: "update_player", teamId: team.id.uuidString)
                    }
                }
            }
        } else {
            // For non-subcollection teams or offline, use full team update
            updateTeam(teams[teamIndex])
        }
    }
    
    func addPlayer(to team: Team, player: Player) {
        guard let teamIndex = teams.firstIndex(where: { $0.id == team.id }) else {
            print("⚠️ Team not found for player addition")
            return
        }
        
        // Add to local array first
        teams[teamIndex].players.append(player)
        teams[teamIndex].updateActivityTimestamp()
        
        print("✅ Added player \(player.name) locally to team \(team.name)")
        
        // Save locally immediately
        debouncedSave()
        
        // Handle Firebase save efficiently based on subcollection support
        if teams[teamIndex].useSubcollections && isOnline {
            // For subcollection teams, save only the new player
            Task {
                do {
                    guard await ensureAuthentication() else { return }
                    try await firebaseManager.savePlayerToSubcollection(player, in: teams[teamIndex])
                    print("✅ Saved new player to subcollection: \(player.name)")
                } catch {
                    await MainActor.run {
                        self.setError("Failed to save new player: \(error.localizedDescription)")
                        // Add to pending changes as fallback
                        self.addToPendingChanges("add_player_\(player.id.uuidString)", action: "add_player", teamId: team.id.uuidString)
                    }
                }
            }
        } else {
            // For non-subcollection teams or offline, use full team update
            updateTeam(teams[teamIndex])
        }
    }
    
    func removePlayer(from team: Team, player: Player) {
        guard let teamIndex = teams.firstIndex(where: { $0.id == team.id }) else {
            print("⚠️ Team not found for player removal")
            return
        }
        
        // Remove from local array first
        teams[teamIndex].players.removeAll { $0.id == player.id }
        teams[teamIndex].updateActivityTimestamp()
        
        print("✅ Removed player \(player.name) locally from team \(team.name)")
        
        // Save locally immediately
        debouncedSave()
        
        // Handle Firebase deletion efficiently based on subcollection support
        if teams[teamIndex].useSubcollections && isOnline {
            // For subcollection teams, delete only this player document
            Task {
                do {
                    guard await ensureAuthentication() else { return }
                    
                    try await firebaseManager.deletePlayer(player, from: team)
                    print("✅ Deleted player from subcollection: \(player.name)")
                } catch {
                    await MainActor.run {
                        self.setError("Failed to delete player: \(error.localizedDescription)")
                        // Add to pending changes as fallback
                        self.addToPendingChanges("delete_player_\(player.id.uuidString)", action: "delete_player", teamId: team.id.uuidString)
                    }
                }
            }
        } else {
            // For non-subcollection teams or offline, use full team update
            updateTeam(teams[teamIndex])
        }
    }
    
    // MARK: - Game Planning Data Management
    func updateGamePlanningData(_ game: Game, in team: Team) {
        print("🔄 Updating game planning data for: \(game.opponent)")
        
        // Update local team data first
        guard let teamIndex = teams.firstIndex(where: { $0.id == team.id }) else {
            print("❌ Team not found for game planning update")
            return
        }
        
        guard let gameIndex = teams[teamIndex].games.firstIndex(where: { $0.id == game.id }) else {
            print("❌ Game not found for planning update")
            return
        }
        
        // Update the game in the local team
        teams[teamIndex].games[gameIndex] = game
        teams[teamIndex].updateActivityTimestamp()
        
        print("✅ Updated planning data locally for game vs \(game.opponent)")
        
        // Save locally immediately for UI responsiveness
        debouncedSave()
        
        // Use the existing updateTeam method for Firebase sync
        // This ensures proper debouncing and real-time updates for other users
        updateTeam(teams[teamIndex])
    }
    
    // MARK: - Lineup-Specific Save
    func updateGameLineupOnly(_ game: Game, in team: Team) {
        print("🏟️ Updating ONLY lineup data for: \(game.opponent)")
        
        // Update local team data first
        guard let teamIndex = teams.firstIndex(where: { $0.id == team.id }) else {
            print("❌ Team not found for lineup update")
            return
        }
        
        guard let gameIndex = teams[teamIndex].games.firstIndex(where: { $0.id == game.id }) else {
            print("❌ Game not found for lineup update")
            return
        }
        
        // Update the game in the local team
        teams[teamIndex].games[gameIndex] = game
        teams[teamIndex].updateActivityTimestamp()
        
        print("✅ Updated lineup data locally for game vs \(game.opponent)")
        
        // Save locally immediately for UI responsiveness
        debouncedSave()
        
        // Save only this specific game's data to Firebase
        if isOnline {
            Task {
                guard await ensureAuthentication() else { return }
                
                do {
                    if team.useSubcollections {
                        // Use the specific game save method for subcollections
                        try await firebaseManager.saveGameWithSubcollections(game, in: team)
                        print("✅ Saved lineup to game subcollection only")
                    } else {
                        // For non-subcollection teams, we still need full team save
                        try await firebaseManager.saveTeam(teams[teamIndex])
                        print("✅ Saved team with lineup data")
                    }
                } catch {
                    await MainActor.run {
                        self.setError("Failed to save lineup: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Game Planning Data Management (Lineup + Substitutions)
    func updateGamePlanningDataOnly(_ game: Game, in team: Team) {  // Added "Only" to the name
        print("🔄 Updating game planning data (lineup + subs) for: \(game.opponent)")
        
        // Update local team data first
        guard let teamIndex = teams.firstIndex(where: { $0.id == team.id }) else {
            print("❌ Team not found for planning update")
            return
        }
        
        guard let gameIndex = teams[teamIndex].games.firstIndex(where: { $0.id == game.id }) else {
            print("❌ Game not found for planning update")
            return
        }
        
        // Update the game in the local team
        teams[teamIndex].games[gameIndex] = game
        teams[teamIndex].updateActivityTimestamp()
        
        print("✅ Updated planning data locally for game vs \(game.opponent)")
        
        // Save locally immediately for UI responsiveness
        debouncedSave()
        
        // Save only planning data to Firebase
        if isOnline {
            Task {
                guard await ensureAuthentication() else { return }
                
                do {
                    if team.useSubcollections {
                        try await firebaseManager.saveGamePlanningOnly(game, in: team)
                    } else {
                        try await firebaseManager.saveTeam(teams[teamIndex])
                    }
                    print("✅ Saved planning data to Firebase")
                } catch {
                    await MainActor.run {
                        self.setError("Failed to save planning data: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func addGame(to team: Team, game: Game) {
        if let teamIndex = teams.firstIndex(where: { $0.id == team.id }) {
            teams[teamIndex].games.append(game)
            
            // Use optimized save for subcollection teams
            if teams[teamIndex].useSubcollections && isOnline {
                Task {
                    do {
                        try await firebaseManager.saveTeam(teams[teamIndex], onlyNewGames: true)
                    } catch {
                        await MainActor.run {
                            self.setError("Failed to save new game: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                updateTeam(teams[teamIndex])
            }
        }
    }
    
    func updateGame(in team: Team, game: Game) {
        print("🎯 TeamManager.updateGame() called")
        print("   Team: \(team.name) (ID: \(team.id))")
        print("   Game: \(game.opponent) (ID: \(game.id))")
        
        if let teamIndex = teams.firstIndex(where: { $0.id == team.id }) {
            print("   ✅ Found team at index \(teamIndex)")
            
            if let gameIndex = teams[teamIndex].games.firstIndex(where: { $0.id == game.id }) {
                print("   ✅ Found game at index \(gameIndex)")
                print("   📝 Updating local game data...")
                
                teams[teamIndex].games[gameIndex] = game
                teams[teamIndex].updateActivityTimestamp()
                
                print("   💾 Saving locally...")
                debouncedSave()
                
                // Handle Firebase save efficiently based on subcollection support
                if teams[teamIndex].useSubcollections && isOnline {
                    // For subcollection teams, save only the updated game
                    Task {
                        do {
                            guard await ensureAuthentication() else { return }
                            print("   🎯 Saving ONLY this game to subcollection (not all 10 games)")
                            try await firebaseManager.saveGameWithSubcollections(game, in: teams[teamIndex])
                            print("   ✅ Updated single game in subcollection: \(game.opponent)")
                        } catch {
                            await MainActor.run {
                                self.setError("Failed to update game: \(error.localizedDescription)")
                                // Add to pending changes as fallback
                                self.addToPendingChanges("update_game_\(game.id.uuidString)", action: "update_game", teamId: team.id.uuidString)
                            }
                        }
                    }
                } else {
                    // For non-subcollection teams or offline, use full team update
                    print("   📦 Using full team save (non-subcollection team or offline)")
                    updateTeam(teams[teamIndex])
                }
                
                print("   ✅ updateGame() completed")
            } else {
                print("   ❌ Game not found in team.games array!")
            }
        } else {
            print("   ❌ Team not found in teams array!")
        }
    }
    
    func removeGame(from team: Team, game: Game) {
        guard let teamIndex = teams.firstIndex(where: { $0.id == team.id }) else {
            print("❌ Team not found for game deletion")
            return
        }
        
        // Remove from local array first
        teams[teamIndex].games.removeAll { $0.id == game.id }
        
        // Recalculate stats after removal
        recalculateStatsForTeam(teamIndex: teamIndex)
        
        // Save locally
        debouncedSave()
        
        // Handle Firebase deletion
        if isOnline {
            Task {
                do {
                    // Use the specific deleteGame method - don't call updateTeam
                    try await firebaseManager.deleteGame(game, from: team)
                    print("✅ Game deleted from Firebase successfully")
                } catch {
                    await MainActor.run {
                        self.setError("Failed to delete game from cloud: \(error.localizedDescription)")
                        // Add to pending changes as fallback
                        self.addToPendingChanges("delete_game_\(game.id.uuidString)", action: "delete_game", teamId: team.id.uuidString)
                    }
                }
            }
        } else {
            // Add to pending changes for offline deletion
            addToPendingChanges("delete_game_\(game.id.uuidString)", action: "delete_game", teamId: team.id.uuidString)
        }
    }
    
    func forceRecalculateAllStats() {
        for teamIndex in teams.indices {
            recalculateStatsForTeam(teamIndex: teamIndex)
            updateTeam(teams[teamIndex])
        }
    }
    
    func recalculateStatsForTeam(teamIndex: Int) {
        let team = teams[teamIndex]
        var updatedTeam = team
        
        // Recalculate each player's season stats from game events
        for playerIndex in updatedTeam.players.indices {
            let playerId = updatedTeam.players[playerIndex].id
            var newStats = PlayerSeasonStats() // Reset to zero
            
            // Count stats from all games
            for game in team.games {
                // Count from game events
                for event in game.gameEvents where event.playerId == playerId {
                    switch event.eventType {
                    case .goal:
                        newStats.goals += 1
                    case .assist:
                        newStats.assists += 1
                    case .shot, .shotOnTarget:
                        newStats.shots += 1
                    case .save:
                        newStats.saves += 1
                    case .goalAgainst:
                        newStats.goalsConceded += 1
                    case .yellowCard:
                        newStats.yellowCards += 1
                    case .redCard:
                        newStats.redCards += 1
                    default:
                        break
                    }
                }
                
                // Calculate presumed minutes
                var updatedGame = game
                updatedGame.updateAllPresumedMinutes(with: updatedTeam)
                
                if let playerGameStats = updatedGame.playerStats.first(where: { $0.playerId == playerId }) {
                    if playerGameStats.minutesPlayed > 0 {
                        newStats.gamesPlayed += 1
                    }
                    newStats.minutesPlayed += playerGameStats.minutesPlayed
                } else {
                    let presumedMinutes = updatedGame.calculatePresumedMinutesPlayed(for: playerId, with: updatedTeam)
                    if presumedMinutes > 0 {
                        newStats.gamesPlayed += 1
                        newStats.minutesPlayed += presumedMinutes
                    }
                }
                
                // Update the game in the team's games array
                if let gameIndex = updatedTeam.games.firstIndex(where: { $0.id == game.id }) {
                    updatedTeam.games[gameIndex] = updatedGame
                }
            }
            
            updatedTeam.players[playerIndex].seasonStats = newStats
        }
        
        // Apply the updated team back
        teams[teamIndex] = updatedTeam
    }
    
    func addPractice(to team: Team, practice: Practice) {
        if let teamIndex = teams.firstIndex(where: { $0.id == team.id }) {
            teams[teamIndex].practices.append(practice)
            updateTeam(teams[teamIndex])
        }
    }
    
    func updatePractice(in team: Team, practice: Practice) {
        if let teamIndex = teams.firstIndex(where: { $0.id == team.id }) {
            if let practiceIndex = teams[teamIndex].practices.firstIndex(where: { $0.id == practice.id }) {
                teams[teamIndex].practices[practiceIndex] = practice
                updateTeam(teams[teamIndex])
            }
        }
    }
    
    func removePractice(from team: Team, practice: Practice) {
        if let teamIndex = teams.firstIndex(where: { $0.id == team.id }) {
            teams[teamIndex].practices.removeAll { $0.id == practice.id }
            updateTeam(teams[teamIndex])
        }
    }

    // MARK: - Demo Data
    func createDemoTeam() {
        // Create a basic demo team - you'll need to implement Team.createDemoTeam() or create manually
        // For now, this is a placeholder
        print("Demo team creation requested - implement Team.createDemoTeam() method")
    }
    
    // MARK: - Team Joining (FIXED)
    func joinTeamWithCode(_ code: String) async -> Bool {
        guard await ensureAuthentication() else { return false }
        
        guard isOnline else {
            setError("Cannot join teams while offline")
            return false
        }
        
        do {
            let team = try await firebaseManager.joinTeamWithCode(code)
            
            await MainActor.run {
                if !self.teams.contains(where: { $0.id == team.id }) {
                    self.teams.append(team)
                    self.clearTeamOwnershipCache()
                    self.saveLocalData()
                    self.setupRealTimeListener(for: team)
                }
            }
            
            // FIXED: Add await for async call
            await refreshPermissions(for: team)
            
            return true
        } catch {
            await MainActor.run {
                self.setError("Failed to join team: \(error.localizedDescription)")
            }
            return false
        }
    }
    
    // MARK: - Invite Code Management (FIXED)
    func generateInviteCode(for team: Team, accessLevel: AccessLevel) async -> String? {
        print("🔍 DEBUG: Generating invite code")
        print("🔍 Team: \(team.name)")
        print("🔍 Team coachUID: \(team.coachUID ?? "nil")")
        print("🔍 Current user UID: \(Auth.auth().currentUser?.uid ?? "nil")")
        print("🔍 Access level requested: \(accessLevel.rawValue)")
        
        // Check if user is team creator
        if team.coachUID == Auth.auth().currentUser?.uid {
            print("✅ User is team creator")
        } else {
            print("❌ User is NOT team creator")
        }
        
        // FIXED: Check user role (using cached version) - handle properly
        let userRole = getCurrentUserRole(for: team)
        print("🔍 User's current role: \(userRole.rawValue)")
        
        guard isOnline else {
            setError("Cannot generate invite codes while offline")
            return nil
        }
        
        // Ensure authentication before Firebase operation
        guard await ensureAuthentication() else { return nil }
        
        do {
            let invite = try await firebaseManager.generateInviteCode(for: team, accessLevel: accessLevel)
            return invite.id
        } catch {
            setError("Failed to generate invite code: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - LEGACY ASYNC METHODS (Keep for backward compatibility)
    
    func getCurrentUserRoleAsync(for team: Team) async -> AccessLevel? {
        // If cache is fresh, return from cache
        if let cache = permissionCache,
           !cache.isExpired,
           let role = cache.teamRoles[team.id] {
            return role
        }
        
        // Otherwise, fetch from Firebase and update cache
        guard let user = Auth.auth().currentUser,
              let authManager = authManager,
              let currentUser = authManager.currentUser else {
            print("❌ No user or auth manager")
            return nil
        }
        
        print("🔍 getCurrentUserRoleAsync DEBUG:")
        print("   Team: \(team.name)")
        print("   User UID: \(user.uid)")
        print("   Team coachUID: \(team.coachUID ?? "nil")")
        
        // If user is the team creator, they're automatically a coach
        if team.coachUID == user.uid {
            print("   ✅ User is team creator - returning .coach")
            return .coach
        }
        
        // Check Firebase for their assigned role in this team
        do {
            let firebaseRole = try await firebaseManager.getUserRole(for: team.id.uuidString, userId: user.uid)
            print("   ✅ Found Firebase role: \(firebaseRole.rawValue)")
            
            // Update cache with this result
            await refreshPermissions(for: team)
            
            return firebaseRole
        } catch {
            print("   ❌ No Firebase role found: \(error)")
            
            // FIXED: Check email matching for sharedAccess users
            if currentUser.subscriptionLevel == .sharedAccess {
                if let userEmail = user.email?.lowercased() {
                    for player in team.players {
                        let parentEmail = player.parentInfo.parentEmail.lowercased()
                        let secondParentEmail = player.parentInfo.secondParentEmail.lowercased()
                        
                        if parentEmail == userEmail || secondParentEmail == userEmail {
                            print("   ✅ Email match found - returning .parent")
                            return .parent
                        }
                    }
                }
            }
            
            // If no Firebase role found, use their default membership type
            print("   📋 Using membership type default: \(currentUser.effectiveMembershipType.defaultAccessLevel.rawValue)")
            return currentUser.effectiveMembershipType.defaultAccessLevel
        }
    }

    func canCurrentUserEditAsync(player: Player, in team: Team) async -> Bool {
        // Use cached version if available
        let cachedResult = canCurrentUserEdit(player: player, in: team)
        if shouldRefreshPermissions() {
            // If cache is stale, refresh in background
            Task {
                await refreshPermissions(for: team)
            }
        }
        return cachedResult
    }

    func canCurrentUserEditTeamAsync(_ team: Team) async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        
        // If user created the team, they can edit it
        if team.coachUID == user.uid {
            return true
        }
        
        // Check their role for this team
        let userRole = await getCurrentUserRoleAsync(for: team)
        return userRole == .coach
    }

    func getEditablePlayerIdsAsync(for team: Team) async -> [UUID] {
        guard let user = Auth.auth().currentUser else { return [] }
        
        // Use cached version if available and fresh
        let cachedIds = getEditablePlayerIds(for: team)
        if !shouldRefreshPermissions() {
            return cachedIds
        }
        
        // Otherwise fetch from Firebase
        let userRole = await getCurrentUserRoleAsync(for: team)
        
        switch userRole {
        case .coach:
            return team.players.map { $0.id }
        case .parent:
            let userEmail = user.email?.lowercased() ?? ""
            return team.players.compactMap { player in
                let parentEmail = player.parentInfo.parentEmail.lowercased()
                let secondParentEmail = player.parentInfo.secondParentEmail.lowercased()
                
                if parentEmail == userEmail || secondParentEmail == userEmail {
                    return player.id
                }
                return nil
            }
        case .viewer:
            return []
        case .none:
            return []
        }
    }
    
    // MARK: - Membership Type Restrictions (NEW)
    func canCreateTeams() -> Bool {
        guard let authManager = authManager,
              let currentUser = authManager.currentUser else { return false }
        return currentUser.effectiveMembershipType.canCreateTeams
    }
    
    // MARK: - RSVP Management
    func updateGameRSVP(gameId: UUID, playerId: UUID, status: RSVPStatus) {
        guard let teamIndex = teams.firstIndex(where: { $0.games.contains(where: { $0.id == gameId }) }) else { return }
        
        var updatedTeam = teams[teamIndex]
        
        // Update local data immediately for UI responsiveness
        if let gameIndex = updatedTeam.games.firstIndex(where: { $0.id == gameId }) {
            updatedTeam.games[gameIndex].playerRSVPs[playerId] = status
            teams[teamIndex] = updatedTeam
            debouncedSave()
        }
        
        // Use fast subcollection update if available
        if isOnline {
            Task {
                // Ensure authentication before Firebase operation
                guard await ensureAuthentication() else { return }
                
                do {
                    try await firebaseManager.updateGameRSVP(
                        gameId: gameId,
                        playerId: playerId,
                        status: status,
                        in: updatedTeam
                    )
                } catch {
                    await MainActor.run {
                        self.setError("Failed to update RSVP: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    internal func saveLocalDataNow() {
        debouncedSave()
    }

    func updatePracticeRSVP(practiceId: UUID, playerId: UUID, status: RSVPStatus) {
        guard let teamIndex = teams.firstIndex(where: { $0.practices.contains(where: { $0.id == practiceId }) }) else { return }
        
        var updatedTeam = teams[teamIndex]
        
        // Update local data immediately for UI responsiveness
        if let practiceIndex = updatedTeam.practices.firstIndex(where: { $0.id == practiceId }) {
            updatedTeam.practices[practiceIndex].playerRSVPs[playerId] = status
            teams[teamIndex] = updatedTeam
            debouncedSave()
        }
        
        // Use fast subcollection update if available
        if isOnline {
            Task {
                // Ensure authentication before Firebase operation
                guard await ensureAuthentication() else { return }
                
                do {
                    try await firebaseManager.updatePracticeRSVP(
                        practiceId: practiceId,
                        playerId: playerId,
                        status: status,
                        in: updatedTeam
                    )
                } catch {
                    await MainActor.run {
                        self.setError("Failed to update RSVP: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func migrateTeamsForTTL() {
        guard !teams.isEmpty else { return }
        
        print("🔄 Migrating \(teams.count) teams for TTL support...")
        
        var migratedCount = 0
        
        for i in teams.indices {
            if teams[i].expirationDate == nil {
                teams[i].updateActivityTimestamp() // FIXED: Use correct method name from your models
                updateTeam(teams[i]) // Save to Firestore
                migratedCount += 1
                print("✅ Migrated team: \(teams[i].name)")
            } else {
                print("⚪ Team already has TTL: \(teams[i].name)")
            }
        }
        
        if migratedCount > 0 {
            print("🎉 Successfully migrated \(migratedCount) teams for automatic deletion")
        } else {
            print("ℹ️ All teams already have TTL configured")
        }
    }
    
    // MARK: - Subcollection Management
    func loadTeamDataWithSubcollections(_ team: Team) async {
        guard team.useSubcollections && isOnline else { return }
        
        // Ensure authentication before Firebase operation
        guard await ensureAuthentication() else { return }
        
        do {
            // Load subcollection data
            async let players = firebaseManager.loadPlayersFromSubcollection(for: team)
            async let games = firebaseManager.loadGamesFromSubcollection(for: team)
            async let practices = firebaseManager.loadPracticesFromSubcollection(for: team)
            
            let (loadedPlayers, loadedGames, loadedPractices) = try await (players, games, practices)
            
            // Recalculate season stats from the loaded game data
            var updatedTeam = team
            updatedTeam.players = loadedPlayers
            updatedTeam.games = loadedGames
            updatedTeam.practices = loadedPractices
            
            // NEW: Recalculate season stats after loading subcollection data
            updatedTeam = firebaseManager.recalculateSeasonStatsAfterSubcollectionLoad(for: updatedTeam)
            
            await MainActor.run {
                if let teamIndex = self.teams.firstIndex(where: { $0.id == team.id }) {
                    self.teams[teamIndex] = updatedTeam
                    self.teams[teamIndex].lastSyncDate = Date()
                    self.saveLocalData()
                    print("🏆 Season stats recalculated for team: \(updatedTeam.name)")
                }
            }
        } catch {
            await MainActor.run {
                self.setError("Failed to load subcollection data: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - App Settings Management
    func loadAppSettings() {
        let settingsURL = documentsDirectory.appendingPathComponent(settingsFileName)
        
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            appSettings = AppSettings()
            return
        }
        
        do {
            let data = try Data(contentsOf: settingsURL)
            appSettings = try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("Failed to load app settings: \(error)")
            appSettings = AppSettings()
        }
    }
    
    func saveAppSettings() {
        let settingsURL = documentsDirectory.appendingPathComponent(settingsFileName)
        
        do {
            let data = try JSONEncoder().encode(appSettings)
            try data.write(to: settingsURL)
        } catch {
            print("Failed to save app settings: \(error)")
        }
    }
    
    // MARK: - Local Data Management
    private func saveLocalData() {
        // UPDATED: Only save if user is authenticated
        guard let currentUser = Auth.auth().currentUser, !currentUser.isAnonymous else {
            print("🔒 No authenticated user - not saving local data")
            return
        }
        
        let teamsURL = documentsDirectory.appendingPathComponent(teamsFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(teams)
            try data.write(to: teamsURL)
            
            lastSavedDate = Date()
            
            // Create backup
            createBackup(data: data)
            
            print("💾 Saved \(teams.count) teams for user \(currentUser.uid)")
        } catch {
            setError("Failed to save teams: \(error.localizedDescription)")
        }
    }
    
    private func createBackup(data: Data) {
        let backupURL = documentsDirectory.appendingPathComponent(backupFileName)
        try? data.write(to: backupURL)
    }
    
    // MARK: - Helper Methods
    private func debouncedSave() {
        saveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveLocalData()
        }
        
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceTime, execute: workItem)
    }
    
    private func setError(_ message: String) {
        errorMessage = message
        print("❌ TeamManager Error: \(message)")
    }
    
    // MARK: - Clear Local Data (ENHANCED)
    func clearAllLocalData() {
        print("🧹 Clearing all local data...")
        
        // Clear in-memory data
        teams = []
        selectedTeam = nil
        pendingChanges = [:]
        clearPermissionCache() // NEW: Clear permission cache
        
        // Clear local files
        let teamsURL = documentsDirectory.appendingPathComponent(teamsFileName)
        let backupURL = documentsDirectory.appendingPathComponent(backupFileName)
        let pendingChangesURL = documentsDirectory.appendingPathComponent(pendingChangesFileName)
        
        // Remove all data files
        try? FileManager.default.removeItem(at: teamsURL)
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.removeItem(at: pendingChangesURL)
        // NOTE: Don't clear app settings as they're user preferences, not user data
        
        print("✅ All local data cleared")
    }
    
    // MARK: - Debug and Fix Methods
    func debugTeamPermissions() {
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user")
            return
        }
        
        print("🔍 Current user UID: \(currentUser.uid)")
        print("🔍 Current user email: \(currentUser.email ?? "No email")")
        
        for team in teams {
            print("🔍 Team: \(team.name)")
            print("   - Team ID: \(team.id)")
            print("   - Coach UID: \(team.coachUID ?? "NIL")")
            print("   - Match: \(team.coachUID == currentUser.uid ? "✅" : "❌")")
            
            // NEW: Show cached permissions
            let role = getCurrentUserRole(for: team)
            print("   - Cached Role: \(role.rawValue)")
        }
    }
    
    // MARK: - Fix Team Ownership (FIXED)
    func fixTeamOwnership() async {
        guard let currentUser = Auth.auth().currentUser else {
            setError("No authenticated user")
            return
        }
        
        print("🔧 Fixing team ownership for user: \(currentUser.uid)")
        
        for i in 0..<teams.count {
            var team = teams[i]
            
            // If team doesn't have coachUID or it's nil, set it to current user
            if team.coachUID == nil || team.coachUID!.isEmpty {
                print("🔧 Fixing team: \(team.name) - setting coachUID to \(currentUser.uid)")
                team.coachUID = currentUser.uid
                teams[i] = team
                
                // Save to Firebase
                if isOnline {
                    do {
                        try await firebaseManager.saveTeam(team)
                        print("✅ Fixed team: \(team.name)")
                        
                        // FIXED: Add await for async call
                        await refreshPermissions(for: team)
                    } catch {
                        print("❌ Failed to fix team \(team.name): \(error)")
                    }
                }
            } else {
                print("✅ Team \(team.name) already has coachUID: \(team.coachUID!)")
            }
        }
        
        // Save locally
        debouncedSave()
    }
    
    func refreshTeamData(_ teamId: UUID) async {
        print("🔄 Refreshing team data from Firebase...")
        
        // Use the existing loadTeamsFromFirebase method
        await loadTeamsFromFirebase()
        
        print("✅ Team data refresh completed")
    }

    private func deleteTeamFromFirebase(_ team: Team) async {
        // Ensure authentication before Firebase operation
        guard await ensureAuthentication() else { return }
        
        do {
            try await firebaseManager.deleteTeam(team)
            await MainActor.run {
                self.removePendingChange("team_\(team.id.uuidString)")
            }
        } catch {
            await MainActor.run {
                self.setError("Failed to delete team: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Firebase Data Loading
    private func loadTeamsFromFirebase() async {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else {
            print("No authenticated user or user is anonymous, skipping Firebase load")
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let firebaseTeams = try await firebaseManager.loadTeams(for: user.uid)
            var fullyLoadedTeams: [Team] = []
            for team in firebaseTeams {
                print("🔍 Team \(team.name) useSubcollections: \(team.useSubcollections)")  // ADD THIS LINE
                
                if team.useSubcollections {
                    // Load subcollection data
                    async let players = firebaseManager.loadPlayersFromSubcollection(for: team)
                    async let games = firebaseManager.loadGamesFromSubcollection(for: team)
                    async let practices = firebaseManager.loadPracticesFromSubcollection(for: team)
                    
                    do {
                        let (loadedPlayers, loadedGames, loadedPractices) = try await (players, games, practices)
                        var updatedTeam = team
                        updatedTeam.players = loadedPlayers
                        updatedTeam.games = loadedGames
                        updatedTeam.practices = loadedPractices
                        fullyLoadedTeams.append(updatedTeam)
                    } catch {
                        print("❌ Error loading subcollection data for team \(team.name): \(error)")
                        fullyLoadedTeams.append(team) // Use team without subcollection data
                    }
                } else {
                    fullyLoadedTeams.append(team)
                }
            }
            
            await MainActor.run {
                let localTeams = self.teams
                let mergedTeams = self.mergeTeams(local: localTeams, remote: fullyLoadedTeams)
                self.teams = mergedTeams
                self.clearTeamOwnershipCache()
                
                // Set selected team if none is selected
                if self.selectedTeam == nil && !self.teams.isEmpty {
                    self.selectedTeam = self.teams.first
                }
                
                self.isLoading = false
                self.saveLocalData()
                
                // Setup real-time listeners for all teams
                for team in self.teams {
                    // Placeholder - implement setupRealTimeListener in FirebaseManager
                    print("Setting up real-time listener for team: \(team.name)")
                }
            }
            
            // Sync any pending changes (moved outside MainActor.run)
            await syncPendingChanges()
        } catch {
            await MainActor.run {
                if !self.teams.isEmpty {
                    // Have local data, show error but don't clear teams
                    self.setError("Failed to sync with cloud: \(error.localizedDescription)")
                } else {
                    self.setError("Failed to load teams: \(error.localizedDescription)")
                }
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Force Load Teams
    func forceLoadTeamsFromFirebase() async {
        await loadTeamsFromFirebase()
    }
    
    // MARK: - Real-time Listeners
    private func setupRealTimeListener(for team: Team) {
        guard !activeListeners.contains(team.id) else {
            print("⚠️ Listener already active for team: \(team.name)")
            return
        }
        
        activeListeners.insert(team.id)
        // Placeholder - implement setupRealTimeListener in FirebaseManager
        print("Real-time listener setup for team: \(team.name)")
    }
    
    // MARK: - Backup and Recovery
    func restoreFromBackup() {
        let backupURL = documentsDirectory.appendingPathComponent(backupFileName)
        
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            setError("No backup file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: backupURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backupTeams = try decoder.decode([Team].self, from: data)
            
            // Find teams in backup that are missing from current teams
            let missingTeams = backupTeams.filter { backupTeam in
                !teams.contains { $0.id == backupTeam.id }
            }
            
            if !missingTeams.isEmpty {
                teams.append(contentsOf: missingTeams)
                saveLocalData()
                print("✅ Restored \(missingTeams.count) teams from backup")
            } else {
                print("ℹ️ No missing teams found in backup")
            }
            
        } catch {
            print("❌ Failed to restore from backup: \(error)")
        }
    }
    
    // MARK: - ADDED: Fix Orphaned Teams (FIXED)
    func fixOrphanedTeams() async {
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user")
            return
        }
        
        print("🔧 Looking for orphaned teams to fix...")
        
        do {
            // Find teams with no coachUID or empty coachUID
            let orphanedTeams = try await Firestore.firestore().collection("teams")
                .whereField("coachUID", isEqualTo: NSNull())
                .getDocuments()
            
            // Also check for empty string coachUID
            let emptyCoachTeams = try await Firestore.firestore().collection("teams")
                .whereField("coachUID", isEqualTo: "")
                .getDocuments()
            
            let allOrphaned = orphanedTeams.documents + emptyCoachTeams.documents
            
            print("🔧 Found \(allOrphaned.count) orphaned teams")
            
            for doc in allOrphaned {
                let data = doc.data()
                let teamName = data["name"] as? String ?? "Unknown"
                
                print("🔧 Fixing team: \(teamName)")
                
                // Update the team with current user as coach
                try await Firestore.firestore().collection("teams").document(doc.documentID).updateData([
                    "coachUID": currentUser.uid
                ])
                
                // Add team to user's teams array
                try await Firestore.firestore().collection("users").document(currentUser.uid).setData([
                    "teams": FieldValue.arrayUnion([doc.documentID]),
                    "lastUpdated": FieldValue.serverTimestamp()
                ], merge: true)
                
                print("✅ Fixed team: \(teamName)")
            }
            
            if !allOrphaned.isEmpty {
                // Reload teams after fixing
                await forceLoadTeamsFromFirebase()
                
                // NEW: Refresh permissions after fixing orphaned teams
                await loadUserPermissions()
            }
            
        } catch {
            print("❌ Error fixing orphaned teams: \(error)")
        }
    }
    
    // MARK: - Pending Changes Management
    struct PendingChange: Codable {
        let action: String
        let teamId: String
        let timestamp: Date
    }
    
    private func addToPendingChanges(_ id: String, action: String, teamId: String) {
        pendingChanges[id] = PendingChange(action: action, teamId: teamId, timestamp: Date())
        savePendingChanges()
    }
    
    private func removePendingChange(_ id: String) {
        pendingChanges.removeValue(forKey: id)
        savePendingChanges()
    }
    
    private func savePendingChanges() {
        let url = documentsDirectory.appendingPathComponent(pendingChangesFileName)
        do {
            let data = try JSONEncoder().encode(pendingChanges)
            try data.write(to: url)
        } catch {
            print("Failed to save pending changes: \(error)")
        }
    }
    
    private func loadPendingChanges() {
        let url = documentsDirectory.appendingPathComponent(pendingChangesFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            pendingChanges = try JSONDecoder().decode([String: PendingChange].self, from: data)
        } catch {
            print("Failed to load pending changes: \(error)")
        }
    }
    
    private func syncPendingChanges() async {
        guard !pendingChanges.isEmpty else { return }
        
        // Ensure authentication before syncing
        guard await ensureAuthentication() else { return }
        
        for (_, change) in pendingChanges {
            if let team = teams.first(where: { $0.id.uuidString == change.teamId }) {
                switch change.action {
                case "create", "update":
                    await saveTeamToFirebase(team)
                case "delete":
                    await deleteTeamFromFirebase(team)
                default:
                    break
                }
            }
        }
    }
    
    func updateTeamImmediatelySync(_ team: Team) {
        print("🚨 FORCING IMMEDIATE SYNC - bypassing debounce")
        
        // Update local state immediately
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index] = team
            debouncedSave() // Still save locally
        }
        
        // Force immediate Firebase save
        Task {
            if isOnline {
                await saveTeamToFirebaseLive(team)
            } else {
                addToPendingChanges("team_\(team.id.uuidString)", action: "update", teamId: team.id.uuidString)
            }
        }
    }
    
    // MARK: - Team Merging
    private func mergeTeams(local: [Team], remote: [Team]) -> [Team] {
        var merged: [Team] = []
        var processedIds: Set<UUID> = []
        
        // Process remote teams (authoritative)
        for remoteTeam in remote {
            merged.append(remoteTeam)
            processedIds.insert(remoteTeam.id)
        }
        
        // Add local teams that aren't in remote
        for localTeam in local {
            if !processedIds.contains(localTeam.id) {
                merged.append(localTeam)
            }
        }
        
        return merged
    }
}

// MARK: - User Team Limits Extension
extension User {
    var maxTeamsAllowed: Int {
        switch subscriptionLevel {
        case .trial: return 1
        case .pro: return 1
        case .premium: return 3
        case .club: return 20
        case .free: return Int.max  // Legacy unlimited
        case .sharedAccess: return 0  // Can't create teams, only join
        case .cancelled, .expired: return 0
        }
    }
}
