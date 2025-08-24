import SwiftUI
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import Network

// MARK: - Firebase Manager
class FirebaseManager: NSObject, ObservableObject {
    static let shared = FirebaseManager()
    
    @Published var isOnline = true
    @Published var pendingSyncItems = 0
    @Published var isReconnecting = false
    
    private let db = Firestore.firestore()
    private var teamListeners: [String: ListenerRegistration] = [:]
    private var chatListeners: [String: ListenerRegistration] = [:]
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private func reconnectFirebaseListeners() {
        isReconnecting = true
        
        // Restart any active listeners
        for (teamId, _) in teamListeners {
            print("Reconnecting listener for team: \(teamId)")
            // The existing listeners will automatically reconnect, but we can log this
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isReconnecting = false
        }
    }
    
    override init() {
        super.init()
        setupNetworkMonitoring()
        setupMessaging()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        // Add debouncing to prevent frequent state changes
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // 500ms debounce
                let isOnline = path.status == .satisfied
                if self?.isOnline != isOnline {
                    self?.isOnline = isOnline
                    print("Network status changed: \(isOnline ? "Online" : "Offline")")
                    
                    if isOnline {
                        // Reconnect Firebase listeners after network comes back
                        self?.reconnectFirebaseListeners()
                    }
                }
            }
        }
        monitor.start(queue: queue)
        
        // Also check Firebase Auth connection
        _ = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if user != nil {
                // User is signed in, assume we're online unless Network framework says otherwise
                if self?.monitor.currentPath.status == .satisfied {
                    DispatchQueue.main.async {
                        self?.isOnline = true
                    }
                }
            }
        }
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Team Management
    func saveTeam(_ team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        // Create a mutable copy of the team
        var teamToSave = team
        
        // Set the coachUID if it's not already set (for backward compatibility)
        if teamToSave.coachUID == nil {
            teamToSave.coachUID = user.uid
        }
        
        let teamData = try Firestore.Encoder().encode(teamToSave)
        let teamRef = db.collection("teams").document(team.id.uuidString)
        
        try await teamRef.setData(teamData)
        
        // Save team reference under user's document
        let userRef = db.collection("users").document(user.uid)
        try await userRef.setData([
            "teams": FieldValue.arrayUnion([team.id.uuidString]),
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    func loadTeams(for userUID: String) async throws -> [Team] {
        // First try to get teams from user document
        let userDoc = try await db.collection("users").document(userUID).getDocument()
        
        var teamIDs: [String] = []
        
        if let userData = userDoc.data(),
           let userTeamIDs = userData["teams"] as? [String] {
            teamIDs = userTeamIDs
        }
        
        // If no teams in user document, try to find teams where this user is the coach
        if teamIDs.isEmpty {
            let teamsQuery = try await db.collection("teams")
                .whereField("coachUID", isEqualTo: userUID)
                .getDocuments()
            
            teamIDs = teamsQuery.documents.map { $0.documentID }
        }
        
        // Fetch all teams
        var teams: [Team] = []
        for teamID in teamIDs {
            do {
                let teamDoc = try await db.collection("teams").document(teamID).getDocument()
                if let teamData = teamDoc.data() {
                    let team = try Firestore.Decoder().decode(Team.self, from: teamData)
                    teams.append(team)
                }
            } catch {
                print("Error loading team \(teamID): \(error)")
            }
        }
        
        return teams
    }
    
    func deleteTeam(_ team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        // Delete team document
        try await db.collection("teams").document(team.id.uuidString).delete()
        
        // Remove team reference from user document
        let userRef = db.collection("users").document(user.uid)
        try await userRef.updateData([
            "teams": FieldValue.arrayRemove([team.id.uuidString])
        ])
        
        // Stop listening to this team
        stopListening(to: team)
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
                let updatedTeam = try Firestore.Decoder().decode(Team.self, from: data)
                completion(updatedTeam)
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
    
    // MARK: - Invite Code Management
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
    
    // MARK: - Invite Limit Enforcement
    func countActiveInvites(for teamId: String, accessLevel: AccessLevel) async throws -> Int {
        let query = db.collection("invites")
            .whereField("teamId", isEqualTo: teamId)
            .whereField("accessLevel", isEqualTo: accessLevel.rawValue)
            .whereField("expiresAt", isGreaterThan: Date()) // Only count non-expired invites
        
        let snapshot = try await query.getDocuments()
        
        // Count invites that still have remaining uses
        let activeInvites = snapshot.documents.compactMap { doc -> TeamInvite? in
            guard let invite = try? doc.data(as: TeamInvite.self) else { return nil }
            return invite.usedCount < invite.maxUses ? invite : nil
        }
        
        return activeInvites.count
    }
    
    /// Get remaining invites for a user's team and access level
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
            print("❌ Error getting remaining invites, falling back to subscription limits: \(error)")
            
            // FALLBACK: If query fails (like missing index), return max allowed for legacy accounts
            if user.subscriptionLevel == .free {
                // Legacy accounts have unlimited, so return a high number
                return 999
            }
            
            // For other subscription levels, return their max (assuming 0 used since we can't query)
            switch accessLevel {
            case .coach: return user.effectiveMaxCoachInvites
            case .parent: return user.effectiveMaxParentInvites
            case .viewer: return user.effectiveMaxViewerInvites
            }
        }
    }
    
    /// Check if user can generate an invite for the specified access level
    func canGenerateInvite(for team: Team, accessLevel: AccessLevel, user: User) async throws -> Bool {
        let remaining = try await getRemainingInvites(for: team, accessLevel: accessLevel, user: user)
        return remaining > 0
    }
    
    /// Enhanced invite generation with subscription limit enforcement
    func generateInviteCodeWithLimits(for team: Team, accessLevel: AccessLevel, user: User) async throws -> TeamInvite {
        // First check if user can generate this type of invite
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
        
        // Generate the invite code
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
            maxUses: 1 // Each invite can only be used once
        )
        
        let inviteData = try Firestore.Encoder().encode(invite)
        try await db.collection("invites").document(invite.id).setData(inviteData)
        
        print("✅ Generated invite with limits enforcement: \(inviteCode) for \(accessLevel.rawValue)")
        return invite
    }
    
    /// Clean up expired invites (call this periodically or on app startup)
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
        
        // Find invite with this code
        let inviteDoc = try await db.collection("invites").document(code.uppercased()).getDocument()
        
        guard inviteDoc.exists else {
            print("❌ Invite document does not exist for code: \(code.uppercased())")
            throw FirebaseError.invalidInviteCode
        }
        
        print("✅ Found invite document")
        
        let invite = try inviteDoc.data(as: TeamInvite.self)
        
        print("📋 Invite details: accessLevel=\(invite.accessLevel.rawValue), expired=\(invite.expiresAt < Date()), uses=\(invite.usedCount)/\(invite.maxUses)")
        
        // Check if invite is expired
        if invite.expiresAt < Date() {
            print("❌ Invite is expired")
            throw FirebaseError.expiredInviteCode
        }
        
        // Check if max uses exceeded
        if invite.usedCount >= invite.maxUses {
            print("❌ Invite uses exceeded")
            throw FirebaseError.expiredInviteCode
        }
        
        // Get the team
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
            "usedCount": invite.usedCount + 1
        ])
        
        print("✅ Successfully joined team and updated invite usage")
        
        return team
    }
    
    // MARK: - Team Member Management
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
        
        // ADDED: Also add team to user's teams array so it shows up in their teams list
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
    
    // MARK: - Messaging Setup
    private func setupMessaging() {
        Messaging.messaging().delegate = self
        
        // Get FCM token
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
            senderName: currentFirebaseUser.displayName ?? currentFirebaseUser.email ?? "User",
            message: text,
            timestamp: Date(),
            isCoach: false  // You can determine this based on user role
        )
        
        let messageData = try Firestore.Encoder().encode(message)
        let chatRef = db.collection("teams").document(team.id.uuidString)
            .collection("messages").document(message.id)
        
        try await chatRef.setData(messageData)
    }
    
    // MARK: - Player Management
    func updatePlayer(_ player: Player, in team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        // Update the team with the modified player
        var updatedTeam = team
        if let index = updatedTeam.players.firstIndex(where: { $0.id == player.id }) {
            updatedTeam.players[index] = player
            try await saveTeam(updatedTeam)
        }
    }
    
    func deletePlayer(_ player: Player, from team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        // Remove player from team
        var updatedTeam = team
        updatedTeam.players.removeAll { $0.id == player.id }
        try await saveTeam(updatedTeam)
    }
    
    // MARK: - Game Management
    func updateGame(_ game: Game, in team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        // Update the team with the modified game
        var updatedTeam = team
        if let index = updatedTeam.games.firstIndex(where: { $0.id == game.id }) {
            updatedTeam.games[index] = game
            try await saveTeam(updatedTeam)
        }
    }
    
    /// Get all members of a team with their access levels
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

    /// Revoke access for a team member
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
    func deleteGame(_ game: Game, from team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        // Remove game from team
        var updatedTeam = team
        updatedTeam.games.removeAll { $0.id == game.id }
        try await saveTeam(updatedTeam)
    }
    
    // MARK: - Practice Management
    func updatePractice(_ practice: Practice, in team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        // Update the team with the modified practice
        var updatedTeam = team
        if let index = updatedTeam.practices.firstIndex(where: { $0.id == practice.id }) {
            updatedTeam.practices[index] = practice
            try await saveTeam(updatedTeam)
        }
    }
    
    func deletePractice(_ practice: Practice, from team: Team) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        // Remove practice from team
        var updatedTeam = team
        updatedTeam.practices.removeAll { $0.id == practice.id }
        try await saveTeam(updatedTeam)
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
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        if team.useSubcollections {
            // FAST: Update only the practice subcollection document
            let practiceRef = db.collection("teams").document(team.id.uuidString)
                .collection("practices").document(practiceId.uuidString)
            
            try await practiceRef.updateData([
                "playerRSVPs.\(playerId.uuidString)": status.rawValue
            ])
        } else {
            // FALLBACK: Use existing method
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
        
        // Migrate data to subcollections
        let teamRef = db.collection("teams").document(team.id.uuidString)
        
        // Save players to subcollection
        for player in team.players {
            let playerRef = teamRef.collection("players").document(player.id.uuidString)
            let playerData = try Firestore.Encoder().encode(player)
            try await playerRef.setData(playerData)
        }
        
        // Save games to subcollection
        for game in team.games {
            let gameRef = teamRef.collection("games").document(game.id.uuidString)
            let gameData = try Firestore.Encoder().encode(game)
            try await gameRef.setData(gameData)
        }
        
        // Save practices to subcollection
        for practice in team.practices {
            let practiceRef = teamRef.collection("practices").document(practice.id.uuidString)
            let practiceData = try Firestore.Encoder().encode(practice)
            try await practiceRef.setData(practiceData)
        }
        
        // Update team to use subcollections
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
        guard team.useSubcollections else { return team.games }
        
        let gamesRef = db.collection("teams").document(team.id.uuidString).collection("games")
        let snapshot = try await gamesRef.getDocuments()
        
        var games: [Game] = []
        for document in snapshot.documents {
            let game = try Firestore.Decoder().decode(Game.self, from: document.data())
            games.append(game)
        }
        
        return games
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

    // MARK: - Individual Subcollection Updates
    func savePlayerToSubcollection(_ player: Player, in team: Team) async throws {
        guard team.useSubcollections else { return }
        
        let playerRef = db.collection("teams").document(team.id.uuidString)
            .collection("players").document(player.id.uuidString)
        
        let playerData = try Firestore.Encoder().encode(player)
        try await playerRef.setData(playerData)
    }

    func saveGameToSubcollection(_ game: Game, in team: Team) async throws {
        guard team.useSubcollections else { return }
        
        let gameRef = db.collection("teams").document(team.id.uuidString)
            .collection("games").document(game.id.uuidString)
        
        let gameData = try Firestore.Encoder().encode(game)
        try await gameRef.setData(gameData)
    }

    func savePracticeToSubcollection(_ practice: Practice, in team: Team) async throws {
        guard team.useSubcollections else { return }
        
        let practiceRef = db.collection("teams").document(team.id.uuidString)
            .collection("practices").document(practice.id.uuidString)
        
        let practiceData = try Firestore.Encoder().encode(practice)
        try await practiceRef.setData(practiceData)
    }
    
    func validateInviteCode(_ code: String) async throws -> TeamInvite {
        print("🔍 Validating invite code: \(code)")
        
        let inviteDoc = try await db.collection("invites").document(code).getDocument()
        
        guard inviteDoc.exists else {
            print("❌ Invite document does not exist for code: \(code)")
            throw FirebaseError.invalidInviteCode
        }
        
        let invite = try inviteDoc.data(as: TeamInvite.self)
        
        // Check if invite is expired
        if invite.expiresAt < Date() {
            print("❌ Invite is expired")
            throw FirebaseError.expiredInviteCode
        }
        
        // Check if max uses exceeded
        if invite.usedCount >= invite.maxUses {
            print("❌ Invite uses exceeded")
            throw FirebaseError.expiredInviteCode
        }
        
        print("✅ Invite code is valid")
        return invite
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
