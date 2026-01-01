import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseMessaging
import Network

@MainActor
class FirebaseManager: NSObject, ObservableObject {
    static let shared = FirebaseManager()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - Published Properties
    @Published var isLoadingTeams = false
    @Published var error: String?
    @Published var lastSyncDate: Date?
    @Published var isOnline = true
    @Published var pendingSyncItems = 0
    @Published var isReconnecting = false
    
    // Keep track of active listeners
    private var teamListeners: [String: ListenerRegistration] = [:]
    private var chatListeners: [String: ListenerRegistration] = [:]
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var activeOperations: Set<String> = []
    private let operationQueue = DispatchQueue(label: "com.app.firebase.operations", attributes: .concurrent)
    private var subcollectionCache: [String: (data: Any, timestamp: Date)] = [:]
    private let cacheExpiration: TimeInterval = 300
    private var activeLoadOperations: Set<String> = []
    
    override init() {
        super.init()
        
        // Enable Firestore offline persistence
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024)) // 100MB cache
        db.settings = settings
        
        setupNetworkMonitoring()
        setupMessaging()
    }
    
    deinit {
        monitor.cancel()
    }
    
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // 500ms debounce
                let isOnline = path.status == .satisfied
                if self?.isOnline != isOnline {
                    self?.isOnline = isOnline
                    print("Network status changed: \(isOnline ? "Online" : "Offline")")
                    
                    if isOnline {
                        self?.reconnectFirebaseListeners()
                    }
                }
            }
        }
        monitor.start(queue: queue)
        
        // Also check Firebase Auth connection
        _ = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if user != nil {
                if self?.monitor.currentPath.status == .satisfied {
                    DispatchQueue.main.async {
                        self?.isOnline = true
                    }
                }
            }
        }
    }
    
    private func reconnectFirebaseListeners() {
        isReconnecting = true
        
        // Restart any active listeners
        for (teamId, _) in teamListeners {
            print("Reconnecting listener for team: \(teamId)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isReconnecting = false
        }
    }
    
    func saveTeam(_ team: Team, onlyNewGames: Bool = false) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        print("🔥 saveTeam called for team: \(team.name)")
        print("🔥 Team ID: \(team.id.uuidString)")
        print("🔥 useSubcollections: \(team.useSubcollections)")
        print("🔥 onlyNewGames: \(onlyNewGames)")
        
        let teamRef = db.collection("teams").document(team.id.uuidString)
        
        if team.useSubcollections {
            // Create a copy of team without the large arrays
            var teamDataForFirebase = team
            teamDataForFirebase.players = []
            teamDataForFirebase.games = []
            teamDataForFirebase.practices = []
            
            // Save the main team document
            let teamData = try Firestore.Encoder().encode(teamDataForFirebase)
            try await teamRef.setData(teamData)
            
            // Save players to subcollection
            let playersRef = teamRef.collection("players")
            for player in team.players {
                let playerData = try Firestore.Encoder().encode(player)
                try await playersRef.document(player.id.uuidString).setData(playerData)
            }
            
            // Save games to subcollection with optimization for new games only
            let gamesRef = teamRef.collection("games")
            
            let gamesToSave: [Game]
            if onlyNewGames {
                // Get existing game IDs to avoid unnecessary writes
                let existingGameIds = try await getExistingGameIds(for: team.id.uuidString)
                gamesToSave = team.games.filter { !existingGameIds.contains($0.id.uuidString) }
                print("🎯 Saving only \(gamesToSave.count) NEW games instead of all \(team.games.count)")
            } else {
                gamesToSave = team.games
                print("📦 Saving all \(team.games.count) games")
            }
            
            for game in gamesToSave {
                let gameRef = gamesRef.document(game.id.uuidString)
                
                // IMPORTANT: Save the nested subcollections FIRST before modifying the game
                
                // Save audit log entries to nested subcollection
                if let auditLog = game.auditLog, !auditLog.isEmpty {
                    let auditLogRef = gameRef.collection("auditLog")
                    // First delete existing entries
                    let existingAuditDocs = try await auditLogRef.getDocuments()
                    for doc in existingAuditDocs.documents {
                        try await doc.reference.delete()
                    }
                    // Then save new entries
                    for (index, auditEntry) in auditLog.enumerated() {
                        let auditData = try Firestore.Encoder().encode(auditEntry)
                        try await auditLogRef.document(String(index)).setData(auditData)
                    }
                    print("📝 Saved \(auditLog.count) audit log entries for game vs \(game.opponent)")
                }
                
                // Save player stats to nested subcollection
                if !game.playerStats.isEmpty {
                    let playerStatsRef = gameRef.collection("playerStats")
                    // First delete existing stats
                    let existingStatsDocs = try await playerStatsRef.getDocuments()
                    for doc in existingStatsDocs.documents {
                        try await doc.reference.delete()
                    }
                    // Then save new stats
                    for stats in game.playerStats {
                        let statsData = try Firestore.Encoder().encode(stats)
                        try await playerStatsRef.document(stats.playerId.uuidString).setData(statsData)
                    }
                    print("📊 Saved \(game.playerStats.count) player stats for game vs \(game.opponent)")
                }
                
                // Save current lineup to nested subcollection
                if let actualStartingLineup = game.actualStartingLineup, !actualStartingLineup.isEmpty {
                    let currentLineupRef = gameRef.collection("currentLineup")
                    // First delete existing lineup
                    let existingLineupDocs = try await currentLineupRef.getDocuments()
                    for doc in existingLineupDocs.documents {
                        try await doc.reference.delete()
                    }
                    // Then save new lineup
                    for (index, position) in actualStartingLineup.enumerated() {
                        let positionData = try Firestore.Encoder().encode(position)
                        try await currentLineupRef.document(String(index)).setData(positionData)
                    }
                    print("📋 Saved \(actualStartingLineup.count) lineup positions for game vs \(game.opponent)")
                }
                
                var gameDataForFirebase = game
                gameDataForFirebase.auditLog = []  // Clear the array, not nil
                gameDataForFirebase.playerStats = []
                gameDataForFirebase.actualStartingLineup = []  // Clear the array, not nil

                let gameData = try Firestore.Encoder().encode(gameDataForFirebase)
                try await gameRef.setData(gameData)
            }
            
            // Save practices to subcollection
            let practicesRef = teamRef.collection("practices")
            for practice in team.practices {
                let practiceData = try Firestore.Encoder().encode(practice)
                try await practicesRef.document(practice.id.uuidString).setData(practiceData)
            }
            
            print("✅ Team saved with subcollections successfully")
            
        } else {
            // Save everything as embedded arrays in the main document
            let teamData = try Firestore.Encoder().encode(team)
            try await teamRef.setData(teamData)
            print("✅ Team saved with embedded data successfully")
        }
        
        // Save team reference under user's document
        let userRef = db.collection("users").document(user.uid)
        try await userRef.setData([
            "teams": FieldValue.arrayUnion([team.id.uuidString]),
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
        
        lastSyncDate = Date()
    }

    // Add this helper method to get existing game IDs
    private func getExistingGameIds(for teamId: String) async throws -> Set<String> {
        let gamesRef = db.collection("teams").document(teamId).collection("games")
        let snapshot = try await gamesRef.getDocuments()
        return Set(snapshot.documents.map { $0.documentID })
    }
    
    func loadTeam(teamId: String) async throws -> Team? {
        let teamDoc = try await db.collection("teams").document(teamId).getDocument()
        
        guard teamDoc.exists else { return nil }
        
        var team = try teamDoc.data(as: Team.self)
        
        // If using subcollections, load data from them
        if team.useSubcollections {
            team.players = try await loadPlayersFromSubcollection(for: team)
            team.games = try await loadGamesWithSubcollections(for: team)
            team.practices = try await loadPracticesFromSubcollection(for: team)
        }
        
        return team
    }

    func deserializePlannedPositionChanges(from gameData: [String: Any]) -> [PlannedPositionChange] {
        print("🔍 DESERIALIZING: Checking for plannedPositionChanges in game data")
        print("   Game data keys: \(gameData.keys.sorted())")
        
        guard let posChangesArray = gameData["plannedPositionChanges"] as? [[String: Any]] else {
            print("❌ No plannedPositionChanges found in game data")
            return []
        }
        
        print("✅ Found \(posChangesArray.count) position changes to deserialize")
        
        let results: [PlannedPositionChange] = posChangesArray.compactMap { changeData -> PlannedPositionChange? in
            guard let idString = changeData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let playerIdString = changeData["playerId"] as? String,
                  let playerId = UUID(uuidString: playerIdString),
                  let fromPositionRaw = changeData["fromPosition"] as? String,
                  let fromPosition = Position(rawValue: fromPositionRaw),
                  let toPositionRaw = changeData["toPosition"] as? String,
                  let toPosition = Position(rawValue: toPositionRaw),
                  let plannedMinute = changeData["plannedMinute"] as? Int else {
                return nil
            }
            
            var positionChange = PlannedPositionChange(
                playerId: playerId,
                fromPosition: fromPosition,
                toPosition: toPosition,
                plannedMinute: plannedMinute
            )
            
            positionChange.isExecuted = changeData["isExecuted"] as? Bool ?? false
            positionChange.actualMinute = changeData["actualMinute"] as? Int
            positionChange.subGroupIndex = changeData["subGroupIndex"] as? Int
            
            return positionChange
        }
        
        print("✅ Successfully deserialized \(results.count) position changes")
        return results
    }
    /// Saves only the specified game's data to Firebase subcollections - used during live games
    func saveActiveGameData(_ game: Game, in team: Team) async throws {
        guard team.useSubcollections else {
            // Fallback to full team save for non-subcollection teams
            try await saveTeam(team)
            return
        }
        
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        print("🎯 Saving ONLY active game data for: \(game.opponent) (ID: \(game.id))")
        
        let gameRef = db.collection("teams").document(team.id.uuidString)
            .collection("games").document(game.id.uuidString)
        
        // Save nested subcollections FIRST
        
        // Save audit log entries
        if let auditLog = game.auditLog, !auditLog.isEmpty {
            let auditLogRef = gameRef.collection("auditLog")
            let existingAuditDocs = try await auditLogRef.getDocuments()
            for doc in existingAuditDocs.documents {
                try await doc.reference.delete()
            }
            for (index, auditEntry) in auditLog.enumerated() {
                let auditData = try Firestore.Encoder().encode(auditEntry)
                try await auditLogRef.document(String(index)).setData(auditData)
            }
            print("📝 Saved \(auditLog.count) audit log entries for ACTIVE game vs \(game.opponent)")
        }
        
        // Save player stats
        if !game.playerStats.isEmpty {
            let playerStatsRef = gameRef.collection("playerStats")
            let existingStatsDocs = try await playerStatsRef.getDocuments()
            for doc in existingStatsDocs.documents {
                try await doc.reference.delete()
            }
            for stats in game.playerStats {
                let statsData = try Firestore.Encoder().encode(stats)
                try await playerStatsRef.document(stats.playerId.uuidString).setData(statsData)
            }
            print("📊 Saved \(game.playerStats.count) player stats for ACTIVE game vs \(game.opponent)")
        }
        
        // Save current lineup
        if let actualStartingLineup = game.actualStartingLineup, !actualStartingLineup.isEmpty {
            let currentLineupRef = gameRef.collection("currentLineup")
            let existingLineupDocs = try await currentLineupRef.getDocuments()
            for doc in existingLineupDocs.documents {
                try await doc.reference.delete()
            }
            for (index, position) in actualStartingLineup.enumerated() {
                let positionData = try Firestore.Encoder().encode(position)
                try await currentLineupRef.document(String(index)).setData(positionData)
            }
            print("📋 Saved \(actualStartingLineup.count) lineup positions for ACTIVE game vs \(game.opponent)")
        }
        
        // NOW save the main game document WITHOUT nested arrays
        var gameDataForFirebase = game
        gameDataForFirebase.auditLog = []  // Clear the array, not nil
        gameDataForFirebase.playerStats = []
        gameDataForFirebase.actualStartingLineup = []  // Clear the array, not nil
        
        let gameData = try Firestore.Encoder().encode(gameDataForFirebase)
        try await gameRef.setData(gameData, merge: true)
        
        print("✅ ACTIVE game saved successfully: \(game.opponent)")
    }

    /// Updates only the main team document without touching subcollections - used for team-level changes during games
    func saveTeamMainDocumentOnly(_ team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        print("📄 Saving ONLY main team document for: \(team.name)")
        
        let teamRef = db.collection("teams").document(team.id.uuidString)
        
        if team.useSubcollections {
            // Create team data without nested collections
            var teamDataForFirebase = team
            teamDataForFirebase.players = []  // Will be in subcollections
            teamDataForFirebase.games = []    // Will be in subcollections
            teamDataForFirebase.practices = [] // Will be in subcollections
            
            let teamData = try Firestore.Encoder().encode(teamDataForFirebase)
            try await teamRef.setData(teamData)
            print("✅ Main team document updated (subcollections unchanged)")
        } else {
            // Save everything as embedded arrays in the main document
            let teamData = try Firestore.Encoder().encode(team)
            try await teamRef.setData(teamData)
            print("✅ Team saved with embedded data")
        }
        
        // Save team reference under user's document
        let userRef = db.collection("users").document(user.uid)
        try await userRef.setData([
            "teams": FieldValue.arrayUnion([team.id.uuidString]),
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    func loadTeams(for userId: String) async throws -> [Team] {
        isLoadingTeams = true
        defer { isLoadingTeams = false }
        
        // First try to get teams from user document
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        var teamIDs: [String] = []
        
        if let userData = userDoc.data(),
           let userTeamIDs = userData["teams"] as? [String] {
            teamIDs = userTeamIDs
        }
        
        // If no teams in user document, try to find teams where this user is the coach
        if teamIDs.isEmpty {
            let teamsQuery = try await db.collection("teams")
                .whereField("coachUID", isEqualTo: userId)
                .getDocuments()
            
            teamIDs = teamsQuery.documents.map { $0.documentID }
        }
        
        // Fetch all teams
        var teams: [Team] = []
        for teamID in teamIDs {
            do {
                let teamDoc = try await db.collection("teams").document(teamID).getDocument()
                if let teamData = teamDoc.data() {
                    var team = try Firestore.Decoder().decode(Team.self, from: teamData)
                    
                    // If team uses subcollections, load them
                    if team.useSubcollections {
                        team.players = try await loadPlayersFromSubcollection(for: team)
                        team.games = try await loadGamesWithSubcollections(for: team)
                        team.practices = try await loadPracticesFromSubcollection(for: team)
                    }
                    
                    teams.append(team)
                }
            } catch {
                print("Error loading team \(teamID): \(error)")
            }
        }
        
        lastSyncDate = Date()
        return teams
    }
    
    func deleteTeam(_ team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        guard team.coachUID == user.uid else {
            throw FirebaseError.accessDenied
        }
        
        let teamRef = db.collection("teams").document(team.id.uuidString)
        
        if team.useSubcollections {
            // Delete all players
            let playersSnapshot = try await teamRef.collection("players").getDocuments()
            for doc in playersSnapshot.documents {
                try await doc.reference.delete()
            }
            
            // Delete all games and their nested subcollections
            let gamesSnapshot = try await teamRef.collection("games").getDocuments()
            for gameDoc in gamesSnapshot.documents {
                let auditLogSnapshot = try await gameDoc.reference.collection("auditLog").getDocuments()
                for doc in auditLogSnapshot.documents {
                    try await doc.reference.delete()
                }
                
                let playerStatsSnapshot = try await gameDoc.reference.collection("playerStats").getDocuments()
                for doc in playerStatsSnapshot.documents {
                    try await doc.reference.delete()
                }
                
                let currentLineupSnapshot = try await gameDoc.reference.collection("currentLineup").getDocuments()
                for doc in currentLineupSnapshot.documents {
                    try await doc.reference.delete()
                }
                
                try await gameDoc.reference.delete()
            }
            
            // Delete all practices
            let practicesSnapshot = try await teamRef.collection("practices").getDocuments()
            for doc in practicesSnapshot.documents {
                try await doc.reference.delete()
            }
        }
        
        // Delete team document
        try await teamRef.delete()
        
        // Remove team reference from user document
        let userRef = db.collection("users").document(user.uid)
        try await userRef.updateData([
            "teams": FieldValue.arrayRemove([team.id.uuidString])
        ])
        
        // Stop listening to this team
        stopListening(to: team)
    }
    
    // ADD this new method - doesn't replace anything
    func loadGamesBasicInfo(for team: Team) async throws -> [Game] {
        guard team.useSubcollections else { return team.games }
        
        let gamesRef = db.collection("teams").document(team.id.uuidString).collection("games")
        let snapshot = try await gamesRef.getDocuments()
        
        var games: [Game] = []
        for document in snapshot.documents {
            var game = try Firestore.Decoder().decode(Game.self, from: document.data())
            // Initialize empty arrays instead of loading subcollections
            game.auditLog = []
            game.playerStats = []
            game.actualStartingLineup = []
            games.append(game)
        }
        
        print("📄 Loaded \(games.count) games (basic info only)")
        return games
    }

    // ADD this new method for loading full game data when needed
    func loadFullGameData(_ game: Game, for team: Team) async throws -> Game {
        guard team.useSubcollections else { return game }
        
        var fullGame = game
        let gameRef = db.collection("teams").document(team.id.uuidString)
            .collection("games").document(game.id.uuidString)
        
        // Load all subcollections (use your existing subcollection loading code here)
        // This is only called when user actually opens the game details
        
        return fullGame
    }
    
    // MARK: - Real-time Listeners
    func startListening(to team: Team, completion: @escaping (Team) -> Void) {
        let teamRef = db.collection("teams").document(team.id.uuidString)
        
        let listener = teamRef.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("Firebase listener error: \(error)")
                
                // Try to reconnect after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.startListening(to: team, completion: completion)
                }
                return
            }
            
            guard let data = snapshot?.data() else { return }
            
            do {
                var updatedTeam = try Firestore.Decoder().decode(Team.self, from: data)
                
                // If using subcollections, load them
                if updatedTeam.useSubcollections {
                    Task {
                        updatedTeam.players = try await self?.loadPlayersFromSubcollection(for: updatedTeam) ?? []
                        updatedTeam.games = try await self?.loadGamesWithSubcollections(for: updatedTeam) ?? []
                        updatedTeam.practices = try await self?.loadPracticesFromSubcollection(for: updatedTeam) ?? []
                        
                        await MainActor.run {
                            completion(updatedTeam)
                        }
                    }
                } else {
                    completion(updatedTeam)
                }
            } catch {
                print("Error decoding team: \(error)")
            }
        }
        
        teamListeners[team.id.uuidString] = listener
    }
    
    func stopListening(to team: Team) {
        teamListeners[team.id.uuidString]?.remove()
        teamListeners.removeValue(forKey: team.id.uuidString)
    }
    
    func updatePlayer(_ player: Player, in team: Team) async throws {
        guard team.coachUID == Auth.auth().currentUser?.uid else {
            throw FirebaseError.accessDenied
        }
        
        if team.useSubcollections {
            try await savePlayerToSubcollection(player, in: team)
        } else {
            // CHANGED: Don't call saveTeam directly - let TeamManager handle routing
            // The calling TeamManager method should handle the save
            print("⚠️ updatePlayer: Non-subcollection team - TeamManager should handle save")
        }
    }
    
    func deletePlayer(_ player: Player, from team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        if team.useSubcollections {
            // For subcollection teams, only delete the player document
            let playerRef = db.collection("teams")
                .document(team.id.uuidString)
                .collection("players")
                .document(player.id.uuidString)
            
            try await playerRef.delete()
            print("✅ Deleted player from subcollection: \(player.name)")
        } else {
            // For non-subcollection teams, update the full team document
            var updatedTeam = team
            updatedTeam.players.removeAll { $0.id == player.id }
            
            let teamData = try Firestore.Encoder().encode(updatedTeam)
            try await db.collection("teams").document(team.id.uuidString).setData(teamData)
            print("✅ Updated team document after player deletion")
        }
    }
    
    func updateGame(_ game: Game, in team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        if team.useSubcollections {
            try await saveGameWithSubcollections(game, in: team)
        } else {
            // CHANGED: Don't call saveTeam directly - let TeamManager handle routing
            print("⚠️ updateGame: Non-subcollection team - TeamManager should handle save")
        }
    }
    
    func deleteGame(_ game: Game, from team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        if team.useSubcollections {
            // Delete the game document and its subcollections
            let gameRef = db.collection("teams")
                .document(team.id.uuidString)
                .collection("games")
                .document(game.id.uuidString)
            
            // Delete subcollections first
            let collections = ["auditLog", "playerStats", "currentLineup"]
            for collection in collections {
                let docs = try await gameRef.collection(collection).getDocuments()
                for doc in docs.documents {
                    try await doc.reference.delete()
                }
            }
            
            // Delete the game document itself
            try await gameRef.delete()
            print("✅ Deleted game \(game.opponent) and its subcollections from Firebase")
            
            // FIXED: Don't save the entire team - just clear the cache
            clearSubcollectionCache(for: team.id)
        } else {
            // For non-subcollection teams, we need to update the full team document
            // Create updated team without the deleted game
            var updatedTeam = team
            updatedTeam.games.removeAll { $0.id == game.id }
            
            // Save only the main team document (without subcollections since it doesn't use them)
            let teamData = try Firestore.Encoder().encode(updatedTeam)
            try await db.collection("teams").document(team.id.uuidString).setData(teamData)
            print("✅ Updated team document after game deletion")
        }
    }
    
    func saveGameWithSubcollections(_ game: Game, in team: Team) async throws {
        guard team.useSubcollections else { return }

        let gameRef = db.collection("teams").document(team.id.uuidString)
            .collection("games").document(game.id.uuidString)
        
        // Save nested subcollections FIRST
        
        // Save audit log entries
        if let auditLog = game.auditLog, !auditLog.isEmpty {
            let auditLogRef = gameRef.collection("auditLog")
            let existingAuditDocs = try await auditLogRef.getDocuments()
            for doc in existingAuditDocs.documents {
                try await doc.reference.delete()
            }
            for (index, auditEntry) in auditLog.enumerated() {
                let auditData = try Firestore.Encoder().encode(auditEntry)
                try await auditLogRef.document(String(index)).setData(auditData)
            }
        }
        
        // Save player stats
        if !game.playerStats.isEmpty {
            let playerStatsRef = gameRef.collection("playerStats")
            let existingStatsDocs = try await playerStatsRef.getDocuments()
            for doc in existingStatsDocs.documents {
                try await doc.reference.delete()
            }
            for stats in game.playerStats {
                let statsData = try Firestore.Encoder().encode(stats)
                try await playerStatsRef.document(stats.playerId.uuidString).setData(statsData)
            }
        }
        
        // Save current lineup
        if let actualStartingLineup = game.actualStartingLineup, !actualStartingLineup.isEmpty {
            let currentLineupRef = gameRef.collection("currentLineup")
            let existingLineupDocs = try await currentLineupRef.getDocuments()
            for doc in existingLineupDocs.documents {
                try await doc.reference.delete()
            }
            for (index, position) in actualStartingLineup.enumerated() {
                let positionData = try Firestore.Encoder().encode(position)
                try await currentLineupRef.document(String(index)).setData(positionData)
            }
        }
        
        // NOW save the main game document WITHOUT nested arrays
        var gameDataForFirebase = game
        gameDataForFirebase.auditLog = []  // Use empty array, not nil
        gameDataForFirebase.playerStats = []
        gameDataForFirebase.actualStartingLineup = []  // Use empty array, not nil
        
        let gameData = try Firestore.Encoder().encode(gameDataForFirebase)
        try await gameRef.setData(gameData)
    }
    
    func saveGamePlanningOnly(_ game: Game, in team: Team) async throws {
        guard team.useSubcollections else {
            try await saveTeam(team)
            return
        }
        
        let gameRef = db.collection("teams").document(team.id.uuidString)
            .collection("games").document(game.id.uuidString)
        
        // Create update dictionary manually to match Firebase structure
        var planningUpdate: [String: Any] = [:]
        
        // Convert LineupPosition array to Firebase format
        if let startingLineup = game.startingLineup {
            let lineupArray = startingLineup.map { lineupPosition in
                return [
                    "playerId": lineupPosition.playerId?.uuidString ?? "",
                    "position": lineupPosition.position.rawValue,
                    "fieldPosition": [lineupPosition.fieldPosition.x, lineupPosition.fieldPosition.y]
                ]
            }
            planningUpdate["startingLineup"] = lineupArray
        } else {
            planningUpdate["startingLineup"] = []
        }
        
        if let actualStartingLineup = game.actualStartingLineup {
            let actualLineupArray = actualStartingLineup.map { lineupPosition in
                return [
                    "playerId": lineupPosition.playerId?.uuidString ?? "",
                    "position": lineupPosition.position.rawValue,
                    "fieldPosition": [lineupPosition.fieldPosition.x, lineupPosition.fieldPosition.y]
                ]
            }
            planningUpdate["actualStartingLineup"] = actualLineupArray
        } else {
            planningUpdate["actualStartingLineup"] = []
        }
        
        // Formation - simple string
        if let formation = game.formation {
            planningUpdate["formation"] = formation.rawValue
        }
        
        
        let plannedSubsArray = game.plannedSubstitutions.map { sub in
            return [
                "id": sub.id.uuidString,
                "playerIn": sub.playerIn.uuidString,
                "playerOut": sub.playerOut.uuidString,
                "plannedMinute": sub.plannedMinute,
                "reason": sub.reason.rawValue,
                "targetPosition": sub.targetPosition.rawValue,
                "isExecuted": sub.isExecuted,
                "subGroupIndex": sub.subGroupIndex ?? 0
            ]
        }
        planningUpdate["plannedSubstitutions"] = plannedSubsArray
        
        // Always ensure plannedPositionChanges field exists, even if empty
        if game.plannedPositionChanges.isEmpty {
            planningUpdate["plannedPositionChanges"] = []
        } else {
            let posChangesArray = game.plannedPositionChanges.map { change in
                return [
                    "id": change.id.uuidString,
                    "playerId": change.playerId.uuidString,
                    "fromPosition": change.fromPosition.rawValue,
                    "toPosition": change.toPosition.rawValue,
                    "plannedMinute": change.plannedMinute,
                    "isExecuted": change.isExecuted,
                    "actualMinute": change.actualMinute ?? 0,
                    "subGroupIndex": change.subGroupIndex ?? 0
                ]
            }
            planningUpdate["plannedPositionChanges"] = posChangesArray
        }
        
        // Simple fields
        planningUpdate["useAutoSubstitutions"] = game.useAutoSubstitutions
        planningUpdate["substitutionNotes"] = game.substitutionNotes

        // DEBUG: Print what we're about to save
        print("🔍 About to save to Firebase:")
        print("   plannedSubstitutions count: \(game.plannedSubstitutions.count)")
        print("   plannedPositionChanges count: \(game.plannedPositionChanges.count)")
        print("   Keys being saved: \(planningUpdate.keys.sorted())")
        if !game.plannedPositionChanges.isEmpty {
            print("   First position change: \(game.plannedPositionChanges[0])")
        }

        try await gameRef.updateData(planningUpdate)
        print("✅ Updated planning fields including position changes in game document")
        clearSubcollectionCache(for: team.id)
    }
    
    
    func updatePractice(_ practice: Practice, in team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        if team.useSubcollections {
            try await savePracticeToSubcollection(practice, in: team)
        } else {
            // CHANGED: Don't call saveTeam directly - let TeamManager handle routing
            print("⚠️ updatePractice: Non-subcollection team - TeamManager should handle save")
        }
    }
    // Replace your existing savePractice method with this:
    func savePractice(_ practice: Practice, to team: Team) async throws {
        if team.useSubcollections {
            // For subcollection teams, save practice as separate document
            let practiceRef = db.collection("teams")
                .document(team.id.uuidString)
                .collection("practices")
                .document(practice.id.uuidString)
            
            let practiceData = try Firestore.Encoder().encode(practice)
            try await practiceRef.setData(practiceData)
            print("✅ Saved practice to subcollection")
        } else {
            // For non-subcollection teams, update the entire team document
            var updatedTeam = team
            if let existingIndex = updatedTeam.practices.firstIndex(where: { $0.id == practice.id }) {
                updatedTeam.practices[existingIndex] = practice
            } else {
                updatedTeam.practices.append(practice)
            }
            
            let teamData = try Firestore.Encoder().encode(updatedTeam)
            try await db.collection("teams").document(team.id.uuidString).setData(teamData)
            print("✅ Updated team document with practice")
        }
    }
    
    func deletePractice(_ practice: Practice, from team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        if team.useSubcollections {
            // Delete the practice document from subcollection
            let practiceRef = db.collection("teams")
                .document(team.id.uuidString)
                .collection("practices")
                .document(practice.id.uuidString)
            
            // Delete the practice document
            try await practiceRef.delete()
            print("✅ Deleted practice from Firebase subcollection")
            
            // Clear the cache for this team (like deleteGame does)
            clearSubcollectionCache(for: team.id)
        } else {
            // For non-subcollection teams, update the full team document
            var updatedTeam = team
            updatedTeam.practices.removeAll { $0.id == practice.id }
            
            // Save only the main team document (like deleteGame does)
            let teamData = try Firestore.Encoder().encode(updatedTeam)
            try await db.collection("teams").document(team.id.uuidString).setData(teamData)
            print("✅ Updated team document after practice deletion")
        }
    }
    
    func updateGameRSVP(gameId: UUID, playerId: UUID, status: RSVPStatus, in team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        if team.useSubcollections {
            // FAST: Update only the game subcollection document
            let gameRef = db.collection("teams").document(team.id.uuidString)
                .collection("games").document(gameId.uuidString)
            
            try await gameRef.updateData([
                "playerRSVPs.\(playerId.uuidString)": status.rawValue
            ])
        } else {
            // FALLBACK: Use existing method
            if let game = team.games.first(where: { $0.id == gameId }) {
                var updatedGame = game
                updatedGame.playerRSVPs[playerId] = status
                try await updateGame(updatedGame, in: team)
            }
        }
    }
    
    func updatePracticeRSVP(practiceId: UUID, playerId: UUID, status: RSVPStatus, in team: Team) async throws {
        if team.useSubcollections {
            let practiceRef = db.collection("teams").document(team.id.uuidString)
                .collection("practices").document(practiceId.uuidString)
            
            try await practiceRef.updateData([
                "playerRSVPs.\(playerId.uuidString)": status.rawValue
            ])
        } else {
            if let practice = team.practices.first(where: { $0.id == practiceId }) {
                var updatedPractice = practice
                updatedPractice.playerRSVPs[playerId] = status
                try await updatePractice(updatedPractice, in: team)
            }
        }
    }
    
    // MARK: - Subcollection Management
    func enableSubcollections(for team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        var updatedTeam = team
        updatedTeam.useSubcollections = true
        updatedTeam.lastSyncDate = Date()
        
        try await saveTeam(updatedTeam)
    }
    
    // MARK: - Load Data from Subcollections
    func loadPlayersFromSubcollection(for team: Team) async throws -> [Player] {
        guard team.useSubcollections else { return team.players }
        
        let playersRef = db.collection("teams").document(team.id.uuidString).collection("players")
        let snapshot = try await playersRef.getDocuments()
        
        var players: [Player] = []
        for document in snapshot.documents {
            let player = try Firestore.Decoder().decode(Player.self, from: document.data())
            players.append(player)
        }
        
        return players
    }
    
    func loadGamesFromSubcollection(for team: Team) async throws -> [Game] {
        return try await loadGamesWithSubcollections(for: team)
    }
    
    func loadGamesWithSubcollections(for team: Team) async throws -> [Game] {
        guard team.useSubcollections else { return team.games }
        
        // Check cache first (KEEP YOUR EXISTING CACHE CODE)
        let cacheKey = "games-\(team.id.uuidString)"
        if let cached = subcollectionCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration,
           let cachedGames = cached.data as? [Game] {
            print("📦 Using cached games for team: \(team.name)")
            return cachedGames
        }
        
        // Check if this is duplicate load (KEEP YOUR EXISTING CODE)
        let operationId = "load-games-\(team.id.uuidString)"
        if activeLoadOperations.contains(operationId) {
            print("⚠️ Skipping duplicate load for team: \(team.name)")
            return team.games
        }
        
        activeLoadOperations.insert(operationId)
        defer { activeLoadOperations.remove(operationId) }
        
        // YOUR EXISTING LOADING CODE STAYS THE SAME FROM HERE...
        let gamesRef = db.collection("teams").document(team.id.uuidString).collection("games")
        let snapshot = try await gamesRef.getDocuments()
        
        var games: [Game] = []
        
        for document in snapshot.documents {
            var game = try Firestore.Decoder().decode(Game.self, from: document.data())
            game.plannedPositionChanges = deserializePlannedPositionChanges(from: document.data())
            let gameRef = gamesRef.document(document.documentID)
            
            // Load audit log subcollection
            do {
                let auditLogSnapshot = try await gameRef.collection("auditLog").getDocuments()
                var auditLog: [GameAuditEntry] = []
                
                for auditDoc in auditLogSnapshot.documents {
                    let auditEntry = try Firestore.Decoder().decode(GameAuditEntry.self, from: auditDoc.data())
                    auditLog.append(auditEntry)
                }
                
                auditLog.sort { $0.realTime < $1.realTime }
                game.auditLog = auditLog
                print("✅ Loaded \(auditLog.count) audit log entries for game vs \(game.opponent)")
            } catch {
                print("⚠️ Could not load audit log for game \(game.id): \(error)")
                game.auditLog = []
            }
            
            // Load player stats subcollection
            do {
                let playerStatsSnapshot = try await gameRef.collection("playerStats").getDocuments()
                var playerStats: [PlayerGameStats] = []
                
                for statsDoc in playerStatsSnapshot.documents {
                    let stats = try Firestore.Decoder().decode(PlayerGameStats.self, from: statsDoc.data())
                    playerStats.append(stats)
                }
                
                game.playerStats = playerStats
                print("✅ Loaded \(playerStats.count) player stats for game vs \(game.opponent)")
            } catch {
                print("⚠️ Could not load player stats for game \(game.id): \(error)")
                game.playerStats = []
            }
            
            // Load current lineup subcollection
            do {
                let currentLineupSnapshot = try await gameRef.collection("currentLineup").getDocuments()
                var currentLineup: [LineupPosition] = []
                
                var positionsByIndex: [String: LineupPosition] = [:]
                
                for lineupDoc in currentLineupSnapshot.documents {
                    let position = try Firestore.Decoder().decode(LineupPosition.self, from: lineupDoc.data())
                    positionsByIndex[lineupDoc.documentID] = position
                }
                
                let sortedKeys = positionsByIndex.keys.sorted { key1, key2 in
                    (Int(key1) ?? 0) < (Int(key2) ?? 0)
                }
                
                for key in sortedKeys {
                    if let position = positionsByIndex[key] {
                        currentLineup.append(position)
                    }
                }
                
                game.actualStartingLineup = currentLineup
                print("✅ Loaded \(currentLineup.count) lineup positions for game vs \(game.opponent)")
            } catch {
                print("⚠️ Could not load lineup for game \(game.id): \(error)")
                game.actualStartingLineup = []
            }
            
            games.append(game)
        }
        
        // Cache the loaded games
        subcollectionCache[cacheKey] = (games, Date())
        
        print("🎯 Successfully loaded \(games.count) games with full subcollection data")
        return games
    }

    // Add this method to clear cache when data changes
    func clearSubcollectionCache(for teamId: UUID) {
        let keysToRemove = ["games-\(teamId.uuidString)",
                            "players-\(teamId.uuidString)",
                            "practices-\(teamId.uuidString)"]
        
        for key in keysToRemove {
            subcollectionCache.removeValue(forKey: key)
        }
        print("🗑️ Cleared subcollection cache for team: \(teamId)")
    }
    
    func recalculateSeasonStatsFromGames(for team: Team) -> Team {
        var updatedTeam = team
        
        for index in updatedTeam.players.indices {
            updatedTeam.players[index].seasonStats = PlayerStats()
        }
        
        for game in updatedTeam.games where game.isCompleted {
            for gamePlayerStats in game.playerStats {
                if let playerIndex = updatedTeam.players.firstIndex(where: { $0.id == gamePlayerStats.playerId }) {
                    updatedTeam.players[playerIndex].seasonStats.goals += gamePlayerStats.goals
                    updatedTeam.players[playerIndex].seasonStats.assists += gamePlayerStats.assists
                    updatedTeam.players[playerIndex].seasonStats.saves += gamePlayerStats.saves
                    updatedTeam.players[playerIndex].seasonStats.goalsConceded += gamePlayerStats.goalsConceded
                    updatedTeam.players[playerIndex].seasonStats.yellowCards += gamePlayerStats.yellowCards
                    updatedTeam.players[playerIndex].seasonStats.redCards += gamePlayerStats.redCards
                    updatedTeam.players[playerIndex].seasonStats.minutesPlayed += gamePlayerStats.minutesPlayed
                    
                    if gamePlayerStats.minutesPlayed > 0 {
                        updatedTeam.players[playerIndex].seasonStats.gamesPlayed += 1
                    }
                }
            }
        }
        
        print("🏆 Recalculated season stats after subcollection load")
        return updatedTeam
    }
    
    // Add alias for compatibility
    func recalculateSeasonStatsAfterSubcollectionLoad(for team: Team) -> Team {
        return recalculateSeasonStatsFromGames(for: team)
    }
    
    func loadPracticesFromSubcollection(for team: Team) async throws -> [Practice] {
        guard team.useSubcollections else { return team.practices }
        
        let practicesRef = db.collection("teams").document(team.id.uuidString).collection("practices")
        let snapshot = try await practicesRef.getDocuments()
        
        var practices: [Practice] = []
        for document in snapshot.documents {
            let practice = try Firestore.Decoder().decode(Practice.self, from: document.data())
            practices.append(practice)
        }
        
        return practices
    }
    
    func savePlayerToSubcollection(_ player: Player, in team: Team) async throws {
        guard team.useSubcollections else { return }
        
        let playerRef = db.collection("teams").document(team.id.uuidString)
            .collection("players").document(player.id.uuidString)
        
        let playerData = try Firestore.Encoder().encode(player)
        try await playerRef.setData(playerData)
        
        print("✅ Saved player \(player.name) to subcollection with updated stats")
    }
    
    func saveGameToSubcollection(_ game: Game, in team: Team) async throws {
        try await saveGameWithSubcollections(game, in: team)
    }
    
    func savePracticeToSubcollection(_ practice: Practice, in team: Team) async throws {
        guard team.useSubcollections else { return }
        
        let practiceRef = db.collection("teams").document(team.id.uuidString)
            .collection("practices").document(practice.id.uuidString)
        
        let practiceData = try Firestore.Encoder().encode(practice)
        try await practiceRef.setData(practiceData)
    }
    
    // MARK: - Team Member Management
    func getTeamMembers(for teamId: String) async throws -> [TeamMemberInfo] {
        let membersRef = db.collection("teams").document(teamId).collection("members")
        let snapshot = try await membersRef.getDocuments()
        
        var members: [TeamMemberInfo] = []
        for document in snapshot.documents {
            let data = document.data()
            if let userId = data["userId"] as? String,
               let email = data["email"] as? String,
               let accessLevelString = data["accessLevel"] as? String,
               let accessLevel = AccessLevel(rawValue: accessLevelString),
               let joinedAtTimestamp = data["joinedAt"] as? Timestamp {
                
                let member = TeamMemberInfo(
                    userId: userId,
                    email: email,
                    accessLevel: accessLevel,
                    joinedAt: joinedAtTimestamp.dateValue()
                )
                members.append(member)
            }
        }
        
        return members
    }
    
    func revokeTeamAccess(userId: String, teamId: String) async throws {
        // Remove from team members
        try await db.collection("teams")
            .document(teamId)
            .collection("members")
            .document(userId)
            .delete()
        
        // Remove team from user's teams array
        let userRef = db.collection("users").document(userId)
        try await userRef.updateData([
            "teams": FieldValue.arrayRemove([teamId])
        ])
        
        print("✅ Revoked access for user \(userId) from team \(teamId)")
    }
    
    func addUserToTeam(userId: String, teamId: String, accessLevel: AccessLevel, userEmail: String) async throws {
        let memberData: [String: Any] = [
            "userId": userId,
            "email": userEmail,
            "accessLevel": accessLevel.rawValue,
            "joinedAt": Timestamp(date: Date())
        ]
        
        try await db.collection("teams")
            .document(teamId)
            .collection("members")
            .document(userId)
            .setData(memberData)
        
        // Also add team to user's teams array
        let userRef = db.collection("users").document(userId)
        try await userRef.setData([
            "teams": FieldValue.arrayUnion([teamId]),
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
        
        print("✅ Added team \(teamId) to user \(userId) teams array")
    }
    
    func getUserRole(for teamId: String, userId: String) async throws -> AccessLevel {
        let memberDoc = try await db.collection("teams")
            .document(teamId)
            .collection("members")
            .document(userId)
            .getDocument()
        
        guard let data = memberDoc.data(),
              let accessLevelString = data["accessLevel"] as? String,
              let accessLevel = AccessLevel(rawValue: accessLevelString) else {
            throw FirebaseError.accessDenied
        }
        
        return accessLevel
    }
    
    func canUserEditPlayer(_ playerId: UUID, in teamId: String, userId: String, userEmail: String) async throws -> Bool {
        let userRole = try await getUserRole(for: teamId, userId: userId)
        
        switch userRole {
        case .coach:
            return true
        case .parent:
            let teamDoc = try await db.collection("teams").document(teamId).getDocument()
            guard let team = try? teamDoc.data(as: Team.self) else { return false }
            
            guard let player = team.players.first(where: { $0.id == playerId }) else { return false }
            
            let parentEmail = player.parentInfo.parentEmail.lowercased()
            let secondParentEmail = player.parentInfo.secondParentEmail.lowercased()
            let currentUserEmail = userEmail.lowercased()
            
            return parentEmail == currentUserEmail || secondParentEmail == currentUserEmail
        case .viewer:
            return false
        }
    }
    
    // MARK: - Invite Management
    func validateInviteCode(_ code: String) async throws -> TeamInvite {
        print("🔍 Validating invite code: \(code)")
        
        let inviteDoc = try await db.collection("invites").document(code).getDocument()
        
        guard inviteDoc.exists else {
            print("❌ Invite document does not exist for code: \(code)")
            throw FirebaseError.invalidInviteCode
        }
        
        let invite = try inviteDoc.data(as: TeamInvite.self)
        
        if invite.expiresAt < Date() {
            print("❌ Invite is expired")
            throw FirebaseError.expiredInviteCode
        }
        
        if invite.usedCount >= invite.maxUses {
            print("❌ Invite uses exceeded")
            throw FirebaseError.expiredInviteCode
        }
        
        print("✅ Invite code is valid")
        return invite
    }
    
    func generateInviteCode(for team: Team, accessLevel: AccessLevel) async throws -> TeamInvite {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        let inviteCode = generateShortCode()
        let invite = TeamInvite(
            id: inviteCode,
            teamId: team.id.uuidString,
            teamName: team.name,
            accessLevel: accessLevel,
            createdBy: user.uid,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            usedCount: 0,
            maxUses: 10
        )
        
        let inviteData = try Firestore.Encoder().encode(invite)
        try await db.collection("invites").document(invite.id).setData(inviteData)
        
        return invite
    }
    
    func countActiveInvites(for teamId: String, accessLevel: AccessLevel) async throws -> Int {
        let query = db.collection("invites")
            .whereField("teamId", isEqualTo: teamId)
            .whereField("accessLevel", isEqualTo: accessLevel.rawValue)
            .whereField("expiresAt", isGreaterThan: Date())
        
        let snapshot = try await query.getDocuments()
        
        let activeInvites = snapshot.documents.compactMap { doc -> TeamInvite? in
            guard let invite = try? doc.data(as: TeamInvite.self) else { return nil }
            return invite.usedCount < invite.maxUses ? invite : nil
        }
        
        return activeInvites.count
    }
    
    func getRemainingInvites(for team: Team, accessLevel: AccessLevel, user: User) async throws -> Int {
        do {
            let activeCount = try await countActiveInvites(for: team.id.uuidString, accessLevel: accessLevel)
            
            let maxAllowed: Int
            switch accessLevel {
            case .coach: maxAllowed = user.effectiveMaxCoachInvites
            case .parent: maxAllowed = user.effectiveMaxParentInvites
            case .viewer: maxAllowed = user.effectiveMaxViewerInvites
            }
            
            return max(0, maxAllowed - activeCount)
            
        } catch {
            print("❌ Error getting remaining invites: \(error)")
            
            if user.subscriptionLevel == .free {
                return 999
            }
            
            switch accessLevel {
            case .coach: return user.effectiveMaxCoachInvites
            case .parent: return user.effectiveMaxParentInvites
            case .viewer: return user.effectiveMaxViewerInvites
            }
        }
    }
    
    func canGenerateInvite(for team: Team, accessLevel: AccessLevel, user: User) async throws -> Bool {
        let remaining = try await getRemainingInvites(for: team, accessLevel: accessLevel, user: user)
        return remaining > 0
    }
    
    func generateInviteCodeWithLimits(for team: Team, accessLevel: AccessLevel, user: User) async throws -> TeamInvite {
        let canGenerate = try await canGenerateInvite(for: team, accessLevel: accessLevel, user: user)
        
        guard canGenerate else {
            throw NSError(
                domain: "InviteLimit",
                code: 403,
                userInfo: [
                    NSLocalizedDescriptionKey: "You've reached the maximum number of \(accessLevel.rawValue) invites for your \(user.subscriptionLevel.displayName) plan."
                ]
            )
        }
        
        let inviteCode = generateShortCode()
        let invite = TeamInvite(
            id: inviteCode,
            teamId: team.id.uuidString,
            teamName: team.name,
            accessLevel: accessLevel,
            createdBy: user.firebaseUID,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            usedCount: 0,
            maxUses: 1
        )
        
        let inviteData = try Firestore.Encoder().encode(invite)
        try await db.collection("invites").document(invite.id).setData(inviteData)
        
        print("✅ Generated invite with limits enforcement: \(inviteCode)")
        return invite
    }
    
    func cleanupExpiredInvites() async throws {
        let query = db.collection("invites")
            .whereField("expiresAt", isLessThan: Date())
        
        let snapshot = try await query.getDocuments()
        
        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        try await batch.commit()
        print("🧹 Cleaned up \(snapshot.documents.count) expired invites")
    }
    
    func joinTeamWithCode(_ code: String) async throws -> Team {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        print("🔍 Attempting to join team with code: \(code.uppercased())")
        
        let inviteDoc = try await db.collection("invites").document(code.uppercased()).getDocument()
        
        guard inviteDoc.exists else {
            print("❌ Invite document does not exist")
            throw FirebaseError.invalidInviteCode
        }
        
        let invite = try inviteDoc.data(as: TeamInvite.self)
        
        if invite.expiresAt < Date() {
            print("❌ Invite is expired")
            throw FirebaseError.expiredInviteCode
        }
        
        if invite.usedCount >= invite.maxUses {
            print("❌ Invite uses exceeded")
            throw FirebaseError.expiredInviteCode
        }
        
        let teamDoc = try await db.collection("teams").document(invite.teamId).getDocument()
        guard let team = try? teamDoc.data(as: Team.self) else {
            print("❌ Team not found for ID: \(invite.teamId)")
            throw FirebaseError.teamNotFound
        }
        
        print("✅ Successfully found team: \(team.name)")
        
        // Add user to team with specified role
        try await addUserToTeam(
            userId: user.uid,
            teamId: invite.teamId,
            accessLevel: invite.accessLevel,
            userEmail: user.email ?? ""
        )
        
        // Update invite usage count
        try await db.collection("invites").document(invite.id).updateData([
            "usedCount": FieldValue.increment(Int64(1))
        ])
        
        print("✅ Successfully joined team and updated invite usage")
        
        return team
    }
    
    // MARK: - Messaging Setup
    private func setupMessaging() {
        Messaging.messaging().delegate = self
        
        Task {
            do {
                let token = try await Messaging.messaging().token()
                saveFCMToken(token)
            } catch {
                print("Error getting FCM token: \(error)")
            }
        }
    }
    
    private func saveFCMToken(_ token: String) {
        guard let user = Auth.auth().currentUser else { return }
        
        let userRef = db.collection("users").document(user.uid)
        userRef.setData([
            "fcmToken": token,
            "lastTokenUpdate": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    // MARK: - Chat Management
    func startListeningToChat(for team: Team, completion: @escaping ([ChatMessage]) -> Void) {
        let chatRef = db.collection("teams").document(team.id.uuidString)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(to: 100)
        
        let listener = chatRef.addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching chat messages: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            let messages = documents.compactMap { doc -> ChatMessage? in
                try? doc.data(as: ChatMessage.self)
            }
            
            completion(messages)
        }
        
        chatListeners[team.id.uuidString] = listener
    }
    
    func stopListeningToChat(for team: Team) {
        chatListeners[team.id.uuidString]?.remove()
        chatListeners.removeValue(forKey: team.id.uuidString)
    }
    
    func sendMessage(_ text: String, to team: Team, from user: User) async throws {
        guard let currentFirebaseUser = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        let message = ChatMessage(
            id: UUID().uuidString,
            teamId: team.id.uuidString,
            senderId: user.id.uuidString,
            senderName: currentFirebaseUser.displayName ?? currentFirebaseUser.email ?? "Unknown",
            message: text,
            timestamp: Date(),
            isCoach: team.coachUID == user.firebaseUID
        )
        
        let messageData = try Firestore.Encoder().encode(message)
        try await db.collection("teams").document(team.id.uuidString)
            .collection("messages").document(message.id).setData(messageData)
    }
    
    // MARK: - Utility Functions
    private func generateShortCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}

// MARK: - Messaging Delegate
extension FirebaseManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        saveFCMToken(token)
    }
}
// MARK: - TeamManager Extension (FIXED)
extension TeamManager {
    
    /// Generate invite code with subscription limits enforcement
    func generateInviteCodeWithLimits(for team: Team, accessLevel: AccessLevel) async -> String? {
        guard let user = authManager?.currentUser else {
            print("❌ Not authenticated. Please sign in again.")
            return nil
        }
        
        do {
            let invite = try await firebaseManager.generateInviteCodeWithLimits(
                for: team,
                accessLevel: accessLevel,
                user: user
            )
            return invite.id
        } catch {
            print("❌ Failed to generate invite with limits: \(error)")
            return nil
        }
    }
    
    /// Get remaining invites for current user and team
    func getRemainingInvites(for team: Team, accessLevel: AccessLevel) async -> Int {
        guard let user = authManager?.currentUser else { return 0 }
        
        do {
            return try await firebaseManager.getRemainingInvites(
                for: team,
                accessLevel: accessLevel,
                user: user
            )
        } catch {
            print("❌ Failed to get remaining invites: \(error)")
            return 0
        }
    }
    
}
