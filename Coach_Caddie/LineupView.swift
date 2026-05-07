import SwiftUI

// MARK: - EventType Extensions (UPDATED with goalAgainst)
extension EventType {
    var systemImage: String {
        switch self {
        case .goal: return "soccerball"
        case .assist: return "arrow.triangle.2.circlepath"
        case .shot: return "scope"
        case .shotOnTarget: return "target"
        case .save: return "hand.raised"
        case .goalAgainst: return "soccerball.inverse"  // NEW
        case .yellowCard: return "rectangle.fill"
        case .redCard: return "rectangle.fill"
        case .penaltyKick: return "circle.dotted"
        case .freeKick: return "arrow.up.circle"
        case .cornerKick: return "arrow.turn.up.right"
        }
    }
    
    var color: Color {
        switch self {
        case .goal: return .green
        case .assist: return .blue
        case .shot: return .orange
        case .shotOnTarget: return .red
        case .save: return .purple
        case .goalAgainst: return .red  // NEW
        case .yellowCard: return .yellow
        case .redCard: return .red
        case .penaltyKick: return .gray
        case .freeKick: return .cyan
        case .cornerKick: return .mint
        }
    }
}

struct LineupView: View {
    @Binding var team: Team
    @Binding var isInGameMode: Bool
    let teamManager: TeamManager
    @State private var selectedFormation: Formation
    @State private var lineupPositions: [LineupPosition] = []
    @State private var showingGameMode = false
    @State private var selectedPlayer: Player? = nil
    @State private var selectedPositionIndex: Int? = nil
    @State private var showingGameSelector = false
    @State private var selectedGame: Game? = nil
    @State private var showingCreateGame = false
    @State private var showingInstructions = false
    @State private var showingEditTimer = false
    @State private var editedMinute: Int = 0
    @State private var editedSecond: Int = 0
    @StateObject private var gameStateManager = GameStateManager.shared
    @State private var gameTimer: Timer?
    @State private var timerTick: Bool = false
    @State private var userRole: AccessLevel?
    @State private var canEditLineup = false
    @State private var showingSubstitutionPlanner = false
    @State private var hasCheckedPermissions = false
    @State private var currentGameMinute: Int = 0
    @State private var hasUnsavedLineupChanges = false
    @State private var isSavingLineup = false
    @State private var hasUnsavedPlanningChanges = false
    @State private var isSavingPlanning = false
    @State private var isSavingGame = false
    @State private var showRetryGameSaveAlert = false
    
    private var isReadOnlyUser: Bool {
        return userRole == .viewer || userRole == .parent
    }
    
    init(team: Binding<Team>, isInGameMode: Binding<Bool>, teamManager: TeamManager) {
        self._team = team
        self._isInGameMode = isInGameMode
        self.teamManager = teamManager
        self._selectedFormation = State(initialValue: team.wrappedValue.defaultFormation)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                headerSection
                mainContentArea(geometry: geometry)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(showingGameMode)
        .overlay {
            readOnlyOverlay
        }
        .overlay {
            if hasUnsavedPlanningChanges && selectedGame != nil && !showingGameMode && canEditLineup {
                VStack {
                    HStack {
                        Spacer()
                            .frame(maxWidth: 125)  // This controls how far left it goes
                        
                        Button(action: savePlanningToFirebase) {
                            HStack(spacing: 6) {
                                if isSavingPlanning {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text(isSavingPlanning ? "Saving..." : "Save")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .disabled(isSavingPlanning)
                        
                        Spacer()
                    }
                    .padding(.top, 0)  // Keep this positive to position below the very top
                    
                    Spacer()
                }
            }
        }
        // Continue with your existing modifiers (.onAppear, .onDisappear, etc.)
        .onAppear {
            checkLineupPermissions()
            loadSavedLineupState()
            checkForActiveGame()
            startGameTimer()
        }
        .onDisappear {
            autoSaveLineupState()
        }
        .onChange(of: lineupPositions) { _ in
            handleLineupPositionChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EnterActiveGameMode"))) { _ in
            enterActiveGameMode()
        }
        .sheet(isPresented: $showingGameSelector) {
            ModernGameSelectorView(
                teamId: team.id,
                selectedGame: $selectedGame,
                showingCreateGame: $showingCreateGame
            )
            .environmentObject(teamManager)
        }
        .sheet(isPresented: $showingCreateGame) {
            SuperEnhancedNewGameView(team: $team)
                .environmentObject(teamManager)
                .onDisappear {
                    if let newGame = team.games.sorted(by: { $0.date > $1.date }).first {
                        selectedGame = newGame
                    }
                }
        }
        .sheet(isPresented: $showingInstructions) {
            LineupInstructionsView()
        }
        .sheet(isPresented: $showingEditTimer) {
            EditTimerView(
                currentMinute: editedMinute,
                currentSecond: editedSecond,
                onSave: { minute, second in
                    gameStateManager.updateGameTime(minute: minute, second: second)
                    showingEditTimer = false
                }
            )
        }
        .sheet(isPresented: $showingSubstitutionPlanner) {
            if let game = selectedGame {
                SubstitutionPlannerView(
                    team: team,
                    game: Binding(
                        get: { selectedGame ?? game },
                        set: { selectedGame = $0 }
                    ),
                    lineupPositions: lineupPositions,
                    onPlanningDataChanged: {
                        hasUnsavedPlanningChanges = true
                    }
                )
            }
        }
        .alert("Save Failed", isPresented: $showRetryGameSaveAlert) {
            Button("Retry Save") {
                retryGameSave()
            }
            Button("Save Later", role: .cancel) {
                // Keep the game data locally, exit game mode
                clearGameStateAndExit()
            }
        } message: {
            Text("Failed to save game data to the cloud. You can retry now or the data will be saved locally and synced later when you're online.")
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            activeGameBanner
            formationSection
            gameControlsSection
        }
    }
    
    @ViewBuilder
    private var activeGameBanner: some View {
        if let activeGame = gameStateManager.activeGameState, !showingGameMode {
            ActiveGameBanner(
                activeGame: activeGame,
                onViewGame: {
                    enterActiveGameMode()
                }
            )
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var formationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            formationHeaderRow
            
            if !showingGameMode {
                formationScrollView
            }
        }
    }
    
    @ViewBuilder
    private var formationHeaderRow: some View {
        HStack {
            Text("Formation")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            headerButtonsRow
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var headerButtonsRow: some View {
        HStack {
            planSubsButton
            clearLineupButton
            instructionsButton
        }
    }
    
    @ViewBuilder
    private var planSubsButton: some View {
        if !showingGameMode && canEditLineup && selectedGame != nil {
            Button(action: { showingSubstitutionPlanner = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "repeat")
                    Text("Plan Subs")
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private var clearLineupButton: some View {
        if canEditLineup && !showingGameMode {
            Button(action: clearLineup) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.caption)
                    Text("Clear")
                        .font(.caption)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }
    
    @ViewBuilder
    private var instructionsButton: some View {
        if selectedGame == nil {
            Button(action: { showingInstructions = true }) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
    }
    
    @ViewBuilder
    private var formationScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(team.format.availableFormations, id: \.self) { formation in
                    ModernFormationButton(
                        formation: formation,
                        isSelected: selectedFormation == formation,
                        playerCount: lineupPositions.filter { $0.playerId != nil }.count,
                        totalPositions: formation.positions.count
                    ) {
                        if canEditLineup {
                            changeFormation(to: formation)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .disabled(isReadOnlyUser)
    }
    
    @ViewBuilder
    private var gameControlsSection: some View {
        if !showingGameMode && canEditLineup {
            VStack(spacing: 12) {
                gameSelectorButton
                startGameButton
            }
        }
    }
    
    @ViewBuilder
    private var gameSelectorButton: some View {
        HStack(spacing: 12) {
            ModernGameSelectorButton(
                selectedGame: selectedGame,
                action: { showingGameSelector = true }
            )
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var startGameButton: some View {
        if selectedGame != nil && !showingGameMode && gameStateManager.activeGameState == nil {
            Button(action: startGameMode) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Start Game Mode")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var saveLineupButton: some View {
        Button(action: saveLineupToFirebase) {
            HStack {
                if isSavingLineup {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                    Text("Saving...")
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: "square.and.arrow.up")
                    Text("Save Lineup")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(isSavingLineup)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var savePlanningButton: some View {
        Button(action: savePlanningToFirebase) {
            HStack {
                if isSavingPlanning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                    Text("Saving...")
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: "square.and.arrow.up")
                    Text("Save Lineup & Subs")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.blue)
            .cornerRadius(12)
        }
        .disabled(isSavingPlanning)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func mainContentArea(geometry: GeometryProxy) -> some View {
        if showingGameMode && selectedGame != nil {
            gameModView
        } else {
            lineupBuilderView(geometry: geometry)
        }
    }
    
    @ViewBuilder
    private var gameModView: some View {
        ModernGameModeView(
            team: $team,
            game: gameBinding,
            lineupPositions: $lineupPositions,
            selectedFormation: selectedFormation,
            showingEditTimer: $showingEditTimer,
            editedMinute: $editedMinute,
            editedSecond: $editedSecond,
            timerTick: timerTick,
            onExitGameMode: exitGameMode,
            onClearGameData: clearAllGameData,
            onEndGame: endGame
        )
        .environmentObject(gameStateManager)
        .environmentObject(teamManager)
    }
    
    @ViewBuilder
    private func lineupBuilderView(geometry: GeometryProxy) -> some View {
        ModernLineupBuilder(
            team: $team,
            selectedFormation: selectedFormation,
            lineupPositions: $lineupPositions,
            selectedPlayer: $selectedPlayer,
            selectedPositionIndex: $selectedPositionIndex,
            availableHeight: geometry.size.height - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom - 525,
            hideAvailablePlayersHeader: selectedGame != nil && !showingGameMode && gameStateManager.activeGameState == nil
        )
        .disabled(isReadOnlyUser)
        .opacity(isReadOnlyUser ? 0.8 : 1.0)
    }
    
    @ViewBuilder
    private var readOnlyOverlay: some View {
        if isReadOnlyUser {
            VStack {
                Spacer()
                HStack {
                    Image(systemName: userRole == .viewer ? "eye.fill" : "person.2.fill")
                    Text(userRole == .viewer ? "View Only Access" : "Parent Access - View Only")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var gameBinding: Binding<Game> {
        Binding(
            get: { selectedGame ?? Game(date: Date(), opponent: "Unknown") },
            set: { newGame in
                selectedGame = newGame
                updateGameInTeam(newGame)
            }
        )
    }
    
    private func savePlanningToFirebase() {
        guard let selectedGame = selectedGame else { return }
        
        isSavingPlanning = true
        
        // Update the game with current lineup
        saveCurrentLineupToGame()
        
        // Use the renamed method to avoid ambiguity
        teamManager.updateGamePlanningDataOnly(selectedGame, in: team)
        
        // Reset unsaved changes flag after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.hasUnsavedPlanningChanges = false
            self.isSavingPlanning = false
        }
    }
    
    private func saveLineupToFirebase() {
        guard let selectedGame = selectedGame else { return }
        
        isSavingLineup = true
        
        // Update the game with current lineup
        saveCurrentLineupToGame()
        
        // Use the lineup-specific save method
        teamManager.updateGameLineupOnly(selectedGame, in: team)
        
        // Reset unsaved changes flag after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.hasUnsavedLineupChanges = false
            self.isSavingLineup = false
        }
    }
    
    private func startGameMode() {
        guard var game = selectedGame else { return }
        
        // Enable local-only mode BEFORE starting the game
        teamManager.enableLocalOnlyMode()
        
        if game.startingLineup == nil || game.startingLineup?.isEmpty == true {
              game.startingLineup = lineupPositions  // Preserve original starting lineup
              print("✅ Saved starting lineup with \(lineupPositions.count) positions")
          } else {
              print("✅ Starting lineup already exists with \(game.startingLineup?.count ?? 0) positions")
          }

        // CRITICAL: Initialize game data structure for subcollections
        game.actualStartingLineup = lineupPositions
        game.formation = selectedFormation
        
        // Initialize player stats for starting lineup
        game.playerStats = []
        for position in lineupPositions {
            if let playerId = position.playerId {
                var playerStats = PlayerGameStats(playerId: playerId)
                playerStats.timeEntries.append(TimeEntry(enteredAt: 0, exitedAt: nil))
                game.playerStats.append(playerStats)
            }
        }
        
        // Initialize audit log and substitutions arrays if needed
        if game.auditLog == nil || game.auditLog?.isEmpty == true {
            game.auditLog = []
        }
        if game.substitutions.isEmpty {
            game.substitutions = []
        }
        
        // Update the game in the team
        if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[gameIndex] = game
        }
        
        selectedGame = game
        
        // Use active game context for initial save (will be local-only due to mode)
        teamManager.updateTeam(team, activeGameId: game.id)
        
        // Start game session
        showingGameMode = true
        isInGameMode = true
        gameStateManager.startGameSession(
            game: game,
            team: team,
            formation: selectedFormation,
            lineupPositions: lineupPositions,
            halfLength: team.defaultHalfLength
        )
        
        gameStateManager.persistActiveGameState()
        checkAndExecutePlannedSubstitutions()
        startGameTimer()
        
        print("Initialized time tracking for \(game.playerStats.count) starting players")
        print("🔒 Started game mode in LOCAL-ONLY mode for game vs \(game.opponent)")
    }
    
    private func exitGameMode() {
        if let _ = gameStateManager.activeGameState {
            gameStateManager.activeGameState?.lineupPositions = lineupPositions
        }
        showingGameMode = false
        isInGameMode = false
        stopGameTimer()
    }
    
    private func handleLineupPositionChange() {
        if showingGameMode && selectedGame != nil {
            // During game mode: Continue auto-saving for real-time updates
            saveCurrentLineupToGame()
            saveLineupToUserDefaults()
            gameStateManager.activeGameState?.lineupPositions = lineupPositions
            teamManager.updateTeam(team, activeGameId: selectedGame?.id)
            print("GAME MODE: Using active game save")
        } else {
            // During lineup planning: Only save locally, mark as unsaved
            saveCurrentLineupToGame()
            saveLineupToUserDefaults()
            hasUnsavedPlanningChanges = true
            print("LINEUP PLANNING: Local save only - marked as unsaved")
        }
    }
    
    private func endGame() {
        let gameId = selectedGame?.id.uuidString ?? "nil"
        print("END GAME ACTION STARTED - Game ID: \(gameId)")
        print("Game has \(selectedGame?.playerStats.count ?? 0) player stats before processing")
        print("Current game isCompleted: \(selectedGame?.isCompleted ?? false)")
        
        // Add game end to audit log
        gameStateManager.addAuditEntry(
            eventType: .gameEnd,
            gameTime: gameStateManager.auditLogTime,
            details: "Game ended"
        )
        print("Added game end to audit log")
        
        // Complete all the critical game saving steps
        guard let currentGame = selectedGame else {
            print("ERROR: selectedGame is nil, cannot process game completion")
            return
        }
        
        var updatedGame = currentGame
        print("Processing game: \(updatedGame.opponent) - \(updatedGame.id)")
        
        // 1. Save final audit log from gameStateManager
        if let activeState = gameStateManager.activeGameState {
            updatedGame.auditLog = activeState.auditLog
            print("Saved \(updatedGame.auditLog?.count ?? 0) audit log entries")
            
            // Save formation from active state
            updatedGame.formation = activeState.formation
            print("Saved formation: \(updatedGame.formation?.rawValue ?? "none")")
        }
        
        // 2. The playerStats and substitutions are already in updatedGame (currentGame)
        // They've been updated throughout the game via updatePlayerStats and executeAutomaticSubstitution
        print("Game has \(updatedGame.playerStats.count) player stats")
        print("Game has \(updatedGame.substitutions.count) substitutions")
        
        // 3. Save starting lineup (if not already saved)
        if updatedGame.startingLineup == nil || updatedGame.startingLineup?.isEmpty == true {
            print("WARNING: startingLineup missing - should have been set at game start!")
        }
        
        // 4. Save actual starting lineup used during game
        updatedGame.actualStartingLineup = lineupPositions
        print("Updated actual current lineup with \(lineupPositions.count) positions")
        
        // 5. CRITICAL: Mark game as completed
        updatedGame.isCompleted = true
        print("Marked game as completed: \(updatedGame.isCompleted)")
        
        // 6. Close out any remaining time entries for players still on field
        let finalMinute = gameStateManager.calculatedMinute
        print("Final game time: \(finalMinute) minutes")
        
        var playersWithOpenTime = 0
        for index in updatedGame.playerStats.indices {
            if let lastEntryIndex = updatedGame.playerStats[index].timeEntries.lastIndex(where: { $0.exitedAt == nil }) {
                updatedGame.playerStats[index].timeEntries[lastEntryIndex].exitedAt = finalMinute
                playersWithOpenTime += 1
            }
            
            // Calculate total minutes played for this player
            let totalMinutes = updatedGame.playerStats[index].timeEntries.reduce(0) { total, entry in
                let exitTime = entry.exitedAt ?? finalMinute
                return total + (exitTime - entry.enteredAt)
            }
            updatedGame.playerStats[index].minutesPlayed = totalMinutes
        }
        print("Closed time entries for \(playersWithOpenTime) players")
        
        // 7. Reset player game stats before recalculating from audit log
        print("Resetting player stats before recalculating from audit log")
        for index in updatedGame.playerStats.indices {
            // Keep minutes played as calculated above
            let savedMinutes = updatedGame.playerStats[index].minutesPlayed
            updatedGame.playerStats[index].goals = 0
            updatedGame.playerStats[index].assists = 0
            updatedGame.playerStats[index].saves = 0
            updatedGame.playerStats[index].goalsConceded = 0
            updatedGame.playerStats[index].yellowCards = 0
            updatedGame.playerStats[index].redCards = 0
            updatedGame.playerStats[index].minutesPlayed = savedMinutes
        }
        
        // Initialize game result if nil
        if updatedGame.result == nil {
            updatedGame.result = GameResult(goalsFor: 0, goalsAgainst: 0)
        }
        updatedGame.result?.goalsFor = 0
        updatedGame.result?.goalsAgainst = 0
        
        // 8. Consolidate stats from audit log to ensure accuracy
        var statsUpdated = 0
        if let auditLog = updatedGame.auditLog {
            print("Processing \(auditLog.count) audit log entries for stats")
            for entry in auditLog {
                guard let playerId = entry.playerId else { continue }
                
                // Find or create player stats for this game
                var playerStatsIndex = updatedGame.playerStats.firstIndex(where: { $0.playerId == playerId })
                if playerStatsIndex == nil {
                    updatedGame.playerStats.append(PlayerGameStats(playerId: playerId))
                    playerStatsIndex = updatedGame.playerStats.count - 1
                }
                
                guard let statsIndex = playerStatsIndex else { continue }
                
                // Update game stats based on audit log
                switch entry.eventType {
                case .goal:
                    updatedGame.playerStats[statsIndex].goals += 1
                    updatedGame.result?.goalsFor += 1
                    statsUpdated += 1
                case .goalAgainst:
                    updatedGame.playerStats[statsIndex].goalsConceded += 1
                    updatedGame.result?.goalsAgainst += 1
                    statsUpdated += 1
                case .assist:
                    updatedGame.playerStats[statsIndex].assists += 1
                    statsUpdated += 1
                case .save:
                    updatedGame.playerStats[statsIndex].saves += 1
                    statsUpdated += 1
                case .yellowCard:
                    updatedGame.playerStats[statsIndex].yellowCards += 1
                    statsUpdated += 1
                case .redCard:
                    updatedGame.playerStats[statsIndex].redCards += 1
                    statsUpdated += 1
                default:
                    break
                }
            }
        }
        print("Updated \(statsUpdated) individual stats from audit log")
        
        // 9. Update season stats for all players who participated
        print("Updating season stats for players")
        var seasonStatsUpdated = 0
        
        // Create a mutable copy of the team
        var updatedTeam = team
        
        for gamePlayerStats in updatedGame.playerStats {
            if let playerIndex = updatedTeam.players.firstIndex(where: { $0.id == gamePlayerStats.playerId }) {
                // Add this game's stats to the player's season stats
                updatedTeam.players[playerIndex].seasonStats.goals += gamePlayerStats.goals
                updatedTeam.players[playerIndex].seasonStats.assists += gamePlayerStats.assists
                updatedTeam.players[playerIndex].seasonStats.saves += gamePlayerStats.saves
                updatedTeam.players[playerIndex].seasonStats.goalsConceded += gamePlayerStats.goalsConceded
                updatedTeam.players[playerIndex].seasonStats.yellowCards += gamePlayerStats.yellowCards
                updatedTeam.players[playerIndex].seasonStats.redCards += gamePlayerStats.redCards
                updatedTeam.players[playerIndex].seasonStats.minutesPlayed += gamePlayerStats.minutesPlayed
                updatedTeam.players[playerIndex].seasonStats.gamesPlayed += 1
                seasonStatsUpdated += 1
                
                print("Updated season stats for \(updatedTeam.players[playerIndex].name)")
            }
        }
        print("Updated season stats for \(seasonStatsUpdated) players")
        
        // 10. Update game in team games array
        if let gameIndex = updatedTeam.games.firstIndex(where: { $0.id == updatedGame.id }) {
            updatedTeam.games[gameIndex] = updatedGame
            print("Updated game in team games array")
        } else {
            print("Could not find game in team games array")
        }
        
        print("Team has \(updatedTeam.games.count) games")
        print("Final game state - isCompleted: \(updatedGame.isCompleted), playerStats: \(updatedGame.playerStats.count), auditLog: \(updatedGame.auditLog?.count ?? 0), substitutions: \(updatedGame.substitutions.count)")
        
        // 11. Update TeamManager's teams array FIRST
        if let teamIndex = teamManager.teams.firstIndex(where: { $0.id == updatedTeam.id }) {
            teamManager.teams[teamIndex] = updatedTeam
            print("Updated TeamManager's teams array at index \(teamIndex)")
        } else {
            print("Could not find team in TeamManager's teams array!")
        }

        // 12. Update local references
        selectedGame = updatedGame
        team = updatedTeam

        // 13. DEBUG: Verify the updated game is in the team
        if let completedGame = updatedTeam.games.first(where: { $0.id == updatedGame.id }) {
            print("DEBUG: Found updated game in team - isCompleted: \(completedGame.isCompleted)")
            print("DEBUG: Game playerStats count: \(completedGame.playerStats.count)")
            print("DEBUG: Game auditLog count: \(completedGame.auditLog?.count ?? 0)")
            print("DEBUG: Game substitutions count: \(completedGame.substitutions.count)")
            print("DEBUG: Game actualStartingLineup count: \(completedGame.actualStartingLineup?.count ?? 0)")
            
            if completedGame.isCompleted && !completedGame.playerStats.isEmpty {
                print("DEBUG: GAME DATA LOOKS GOOD - should save to Firebase")
            } else {
                print("DEBUG: GAME DATA IS MISSING")
            }
        } else {
            print("DEBUG: Could not find updated game in team!")
        }

        // 14. Show saving state UI
        print("Game completed locally, preparing for Firebase sync...")
        isSavingGame = true

        // 15. CRITICAL FIX: Save player season stats AND game data to Firebase
        Task {
            // First, sync the completed game with all its data
            let syncSuccess = await teamManager.disableLocalOnlyModeAndSync(updatedTeam, game: updatedGame)
            
            // CRITICAL FIX: Also save each player's updated season stats
            if syncSuccess {
                print("✅ Game data synced, now saving updated player season stats...")
                
                // Save each player who participated in the game to ensure season stats persist
                for gamePlayerStats in updatedGame.playerStats {
                    if let updatedPlayer = updatedTeam.players.first(where: { $0.id == gamePlayerStats.playerId }) {
                        // Use updatePlayer to ensure season stats are saved to Firebase
                        await MainActor.run {
                            self.teamManager.updatePlayer(in: updatedTeam, player: updatedPlayer)
                        }
                        print("✅ Saved season stats for player: \(updatedPlayer.name)")
                    }
                }
                
                // Give a moment for all player updates to complete
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            
            await MainActor.run {
                self.isSavingGame = false
                
                if syncSuccess {
                    print("✅ Game and player season stats successfully synced to Firebase")
                    // Clear game state and exit
                    self.clearGameStateAndExit()
                } else {
                    print("❌ Failed to sync game to Firebase")
                    self.showRetryGameSaveAlert = true
                }
            }
        }

        print("END GAME ACTION INITIATED - waiting for Firebase sync")
    }

    // MARK: - Helper Methods
    private func enterActiveGameMode() {
        if let activeGame = gameStateManager.activeGameState,
           let game = team.games.first(where: { $0.id == activeGame.gameId }) {
            selectedGame = game
            selectedFormation = activeGame.formation
            lineupPositions = activeGame.lineupPositions
            showingGameMode = true
            isInGameMode = true
            startGameTimer()
        }
    }
    
    private func clearGameStateAndExit() {
        gameStateManager.endGameSession()
        gameStateManager.clearPersistedGameState()
        
        // Clear lineup positions
        for index in lineupPositions.indices {
            lineupPositions[index].playerId = nil
        }
        
        // Remove saved lineup data
        UserDefaults.standard.removeObject(forKey: "SavedLineup_\(team.id)")
        if let gameId = selectedGame?.id {
            UserDefaults.standard.removeObject(forKey: "GameLineup_\(gameId)")
        }
        
        // Exit game mode
        selectedGame = nil
        showingGameMode = false
        isInGameMode = false
        stopGameTimer()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        print("✅ Cleared game state and exited game mode")
    }

    // 4. COMPLETE retryGameSave() method - Add this new method
    private func retryGameSave() {
        guard let currentGame = selectedGame,
              let updatedTeam = teamManager.teams.first(where: { $0.id == team.id }) else { return }
        
        isSavingGame = true
        
        Task {
            let syncSuccess = await teamManager.disableLocalOnlyModeAndSync(updatedTeam, game: currentGame)
            
            // CRITICAL FIX: Also save player season stats on retry
            if syncSuccess {
                print("✅ Game data synced on retry, now saving updated player season stats...")
                
                // Save each player who participated in the game
                for gamePlayerStats in currentGame.playerStats {
                    if let updatedPlayer = updatedTeam.players.first(where: { $0.id == gamePlayerStats.playerId }) {
                        await MainActor.run {
                            self.teamManager.updatePlayer(in: updatedTeam, player: updatedPlayer)
                        }
                        print("✅ Saved season stats for player on retry: \(updatedPlayer.name)")
                    }
                }
                
                // Give a moment for all player updates to complete
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            
            await MainActor.run {
                self.isSavingGame = false
                
                if syncSuccess {
                    print("✅ Retry successful: Game and player season stats synced to Firebase")
                    self.clearGameStateAndExit()
                } else {
                    print("❌ Retry failed")
                    self.showRetryGameSaveAlert = true
                }
            }
        }
    }

    private func clearAllGameData() {
        // Clear game state
        gameStateManager.endGameSession()
        gameStateManager.clearPersistedGameState()
        
        // Reset game data completely
        guard var updatedGame = selectedGame else { return }
        
        // FIXED: Clear all game data including time tracking
        updatedGame.result = nil
        updatedGame.gameEvents = []
        updatedGame.auditLog = []
        updatedGame.startingLineup = []
        updatedGame.actualStartingLineup = []  // Also clear actual starting lineup
        updatedGame.isCompleted = false
        updatedGame.playerStats = []  // This clears all time entries
        updatedGame.substitutions = []
        updatedGame.formation = nil
        updatedGame.notes = nil
        updatedGame.plannedSubstitutions = []
        updatedGame.lineupPhases = []
        
        // Update the game in the team
        if let gameIndex = team.games.firstIndex(where: { $0.id == updatedGame.id }) {
            team.games[gameIndex] = updatedGame
            // FIXED: Use active game context since we're clearing the active game
            teamManager.updateTeam(team, activeGameId: updatedGame.id)
            selectedGame = team.games[gameIndex]
        }
        
        // Clear lineup positions
        for index in lineupPositions.indices {
            lineupPositions[index].playerId = nil
        }
        
        // Remove all saved data
        UserDefaults.standard.removeObject(forKey: "SavedLineup_\(team.id)")
        UserDefaults.standard.removeObject(forKey: "GameLineup_\(updatedGame.id)")
        
        // Exit game mode
        selectedGame = nil
        showingGameMode = false
        isInGameMode = false
        stopGameTimer()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        print("Cleared all game data including time tracking")
    }
    
    private func updateGameInTeam(_ game: Game) {
        if let index = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[index] = game
        }
    }
    
    private func saveCurrentLineupToGame() {
        guard var game = selectedGame else { return }
        
        if isInGameMode {
            // During game, update the actual lineup
            game.actualStartingLineup = lineupPositions
            
            // Ensure player stats exist for all players in lineup
            for position in lineupPositions {
                if let playerId = position.playerId {
                    if !game.playerStats.contains(where: { $0.playerId == playerId }) {
                        var playerStats = PlayerGameStats(playerId: playerId)
                        playerStats.timeEntries.append(TimeEntry(
                            enteredAt: currentGameMinute,
                            exitedAt: nil
                        ))
                        game.playerStats.append(playerStats)
                    }
                }
            }
        } else {
            // Before game, update the planned lineup
            game.startingLineup = lineupPositions
        }
        
        selectedGame = game
        if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[gameIndex] = game
        }
    }
    
    private func autoSaveLineupState() {
        if selectedGame != nil {
            saveCurrentLineupToGame()
        }
        saveLineupToUserDefaults()
    }
    
    private func saveLineupToUserDefaults() {
        let lineupData = LineupState(
            teamId: team.id,
            formation: selectedFormation,
            positions: lineupPositions,
            selectedGameId: selectedGame?.id
        )
        
        if let encoded = try? JSONEncoder().encode(lineupData) {
            UserDefaults.standard.set(encoded, forKey: "SavedLineup_\(team.id)")
        }
    }
    
    private func initializeStartingLineupTime() {
        guard var game = selectedGame else { return }
        
        print("Initializing starting lineup time tracking...")
        
        // Clear any existing time entries to prevent duplicates
        game.playerStats.removeAll()
        
        // Initialize time tracking for starting lineup players
        for position in lineupPositions {
            if let playerId = position.playerId {
                var playerStats = PlayerGameStats(playerId: playerId)
                // Add initial time entry starting at minute 0
                playerStats.timeEntries.append(TimeEntry(enteredAt: 0, exitedAt: nil))
                game.playerStats.append(playerStats)
                
                print("Initialized time tracking for starting player \(getPlayerName(playerId)) from minute 0")
            }
        }
        
        selectedGame = game
        if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[gameIndex] = game
        }
        
        // FIXED: Use active game context for time initialization
        teamManager.updateTeam(team, activeGameId: game.id)
        print("Completed starting lineup time initialization for \(game.playerStats.count) players")
    }
    
    private func clearLineup() {
        for index in lineupPositions.indices {
            lineupPositions[index].playerId = nil
        }
        selectedPlayer = nil
        selectedPositionIndex = nil
        autoSaveLineupState()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func loadSavedLineupState() {
        if let data = UserDefaults.standard.data(forKey: "SavedLineup_\(team.id)"),
           let savedState = try? JSONDecoder().decode(LineupState.self, from: data),
           savedState.teamId == team.id {
            
            selectedFormation = savedState.formation
            lineupPositions = savedState.positions
            
            if let gameId = savedState.selectedGameId,
               let game = team.games.first(where: { $0.id == gameId }) {
                selectedGame = game
            }
        } else {
            // Initialize with default positions for the selected formation
            initializeLineupPositions()
        }
    }
    
    private func initializeLineupPositions() {
        lineupPositions = selectedFormation.positions.enumerated().map { index, position in
            LineupPosition(
                playerId: nil,
                position: position,
                fieldPosition: selectedFormation.fieldPositions(for: CGSize(width: 300, height: 200))[index]
            )
        }
    }
    
    private func changeFormation(to formation: Formation) {
        selectedFormation = formation
        initializeLineupPositions()
        autoSaveLineupState()
    }
    
    private func checkForActiveGame() {
        // Check if there's an active game that should be restored
        if let activeGame = gameStateManager.activeGameState,
           let game = team.games.first(where: { $0.id == activeGame.gameId }) {
            selectedGame = game
            selectedFormation = activeGame.formation
            lineupPositions = activeGame.lineupPositions
            startGameTimer()
        }
    }
    
    private func startGameTimer() {
        // Only initialize time tracking if we don't already have player stats
        if let game = selectedGame, game.playerStats.isEmpty {
            initializeStartingLineupTime()
        }
        
        gameTimer?.invalidate()
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // CRITICAL: Don't use DispatchQueue.main.async for time-sensitive operations
            if gameStateManager.activeGameState?.isRunning == true {
                DispatchQueue.main.async {
                    editedMinute = gameStateManager.calculatedMinute
                    editedSecond = gameStateManager.calculatedSecond
                    timerTick.toggle()
                }
                
                // CRITICAL: Check substitutions on EVERY timer tick, not just at minute boundaries
                // This ensures substitutions execute even if the minute-boundary check is missed
                self.checkAndExecutePlannedSubstitutions()
                
                // Persist state every 30 seconds
                if gameStateManager.calculatedSecond % 30 == 0 {
                    gameStateManager.persistActiveGameState()
                }
            }
        }
        
        RunLoop.current.add(gameTimer!, forMode: .common)
    }
    
    private func stopGameTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }
    
    private func checkLineupPermissions() {
        // Prevent redundant checks
        guard !hasCheckedPermissions else { return }
        hasCheckedPermissions = true
        
        Task {
            userRole = await teamManager.getCurrentUserRole(for: team)
            canEditLineup = userRole == .coach
        }
    }
    
    private func checkAndExecutePlannedSubstitutions() {
        guard let game = selectedGame,
              let activeGameState = gameStateManager.activeGameState else { return }
        
        let currentMinute = gameStateManager.calculatedMinute
        
        guard game.useAutoSubstitutions else { return }

        // CRITICAL: Add background execution logging
        let appState = UIApplication.shared.applicationState
        print("🔄 Checking substitutions at \(currentMinute):\(gameStateManager.calculatedSecond) - App State: \(appState.rawValue)")

        // Get all events for this minute
        let dueSubstitutions = game.plannedSubstitutions.filter {
            !$0.isExecuted && $0.plannedMinute <= currentMinute
        }
        
        let duePositionChanges = game.plannedPositionChanges.filter {
            !$0.isExecuted && $0.plannedMinute <= currentMinute
        }
        
        // CRITICAL: Execute immediately if any are due (don't batch by minute)
        for sub in dueSubstitutions {
            print("🚨 EXECUTING SUBSTITUTION IN BACKGROUND: \(getPlayerName(sub.playerOut)) -> \(getPlayerName(sub.playerIn)) at \(currentMinute)'")
            executeAutomaticSubstitutionBackground(sub)
        }
        
        for posChange in duePositionChanges {
            print("🚨 EXECUTING POSITION CHANGE IN BACKGROUND: \(getPlayerName(posChange.playerId)) to \(posChange.toPosition.abbreviation) at \(currentMinute)'")
            executeAutomaticPositionSwapBackground(posChange)
        }
    }
    
    private func executeAutomaticSubstitutionBackground(_ plannedSub: PlannedSubstitution) {
        guard var game = selectedGame else { return }
        
        let currentMinute = gameStateManager.calculatedMinute
        print("🌙 BACKGROUND SUBSTITUTION: \(getPlayerName(plannedSub.playerOut)) -> \(getPlayerName(plannedSub.playerIn))")
        
        // CRITICAL: All data operations must complete even in background
        
        // 1. Update lineup positions (this is the most critical part)
        if let positionIndex = lineupPositions.firstIndex(where: { $0.playerId == plannedSub.playerOut }) {
            lineupPositions[positionIndex].playerId = plannedSub.playerIn
            print("✅ Updated lineup position in background")
        }
        
        // 2. Track playing time (critical for stats)
        trackPlayerExit(playerId: plannedSub.playerOut, minute: currentMinute)
        trackPlayerEntry(playerId: plannedSub.playerIn, minute: currentMinute)
        
        // 3. Add substitution to game record
        let substitution = Substitution(
            playerIn: plannedSub.playerIn,
            playerOut: plannedSub.playerOut,
            minute: currentMinute,
            reason: plannedSub.reason
        )
        game.substitutions.append(substitution)
        
        // 4. Add to audit log (background safe)
        gameStateManager.addAuditEntry(
            eventType: .substitution,
            gameTime: gameStateManager.auditLogTime,
            playerName: getPlayerName(plannedSub.playerOut),
            playerId: plannedSub.playerOut,
            details: "AUTO: \(getPlayerName(plannedSub.playerOut)) -> \(getPlayerName(plannedSub.playerIn)) (\(plannedSub.reason.rawValue))"
        )
        
        // 5. Mark as executed IMMEDIATELY
        if let subIndex = game.plannedSubstitutions.firstIndex(where: { $0.id == plannedSub.id }) {
            game.plannedSubstitutions[subIndex].isExecuted = true
            game.plannedSubstitutions[subIndex].actualMinute = currentMinute
        }
        
        // 6. Update all game references
        selectedGame = game
        if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[gameIndex] = game
        }
        
        // 7. Update game state manager
        gameStateManager.activeGameState?.lineupPositions = lineupPositions
        
        // 8. Force persistent save (CRITICAL for background)
        gameStateManager.forcePersistActiveGameState()
        
        // 9. Update team manager (local only mode will prevent Firebase sync)
        teamManager.updateTeam(team, activeGameId: game.id)
        
        // 10. Skip haptic feedback in background (would fail anyway)
        if UIApplication.shared.applicationState == .active {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        print("🎉 BACKGROUND SUBSTITUTION COMPLETE!")
    }

    private func executeAutomaticPositionSwapBackground(_ plannedPosChange: PlannedPositionChange) {
        guard var game = selectedGame else { return }
        
        let currentMinute = gameStateManager.calculatedMinute
        print("🌙 BACKGROUND POSITION SWAP: \(getPlayerName(plannedPosChange.playerId))")
        
        // CRITICAL: Check if already executed FIRST
        if plannedPosChange.isExecuted {
            print("SKIP: Position change already executed")
            return
        }
        
        // CRITICAL: Mark as executed IMMEDIATELY to prevent retry loops
        if let posIndex = game.plannedPositionChanges.firstIndex(where: { $0.id == plannedPosChange.id }) {
            game.plannedPositionChanges[posIndex].isExecuted = true
            game.plannedPositionChanges[posIndex].actualMinute = currentMinute
            print("✅ Marked position change as executed to prevent retry loop")
        }
        
        // Find current player position
        guard let currentPlayerIndex = lineupPositions.firstIndex(where: { $0.playerId == plannedPosChange.playerId }) else {
            print("ERROR: Could not find player in lineup - position change marked as executed")
            // Update the game state even if we can't execute to persist the executed flag
            updateGameStateAfterPositionChange(game)
            return
        }
        
        // Find target position player
        guard let targetPlayerIndex = lineupPositions.firstIndex(where: { position in
            position.position == plannedPosChange.toPosition && position.playerId != plannedPosChange.playerId
        }) else {
            print("ERROR: Could not find target position player - position change marked as executed")
            // Update the game state even if we can't execute to persist the executed flag
            updateGameStateAfterPositionChange(game)
            return
        }
        
        guard let targetPlayerId = lineupPositions[targetPlayerIndex].playerId else {
            print("ERROR: Target position empty - position change marked as executed")
            // Update the game state even if we can't execute to persist the executed flag
            updateGameStateAfterPositionChange(game)
            return
        }
        
        // Perform the swap
        let tempPlayerId = lineupPositions[currentPlayerIndex].playerId
        lineupPositions[currentPlayerIndex].playerId = lineupPositions[targetPlayerIndex].playerId
        lineupPositions[targetPlayerIndex].playerId = tempPlayerId
        
        // Add audit entry
        gameStateManager.addAuditEntry(
            eventType: .positionChange,
            gameTime: gameStateManager.auditLogTime,
            playerName: getPlayerName(plannedPosChange.playerId),
            playerId: plannedPosChange.playerId,
            details: "POSITION SWAP: \(getPlayerName(plannedPosChange.playerId)) <-> \(getPlayerName(targetPlayerId)) at \(currentMinute)'"
        )
        
        // Find and mark the paired position change as executed too
        if let pairedChangeIndex = game.plannedPositionChanges.firstIndex(where: { change in
            change.playerId == targetPlayerId &&
            change.plannedMinute == plannedPosChange.plannedMinute &&
            !change.isExecuted
        }) {
            game.plannedPositionChanges[pairedChangeIndex].isExecuted = true
            game.plannedPositionChanges[pairedChangeIndex].actualMinute = currentMinute
            print("PAIRED: Also marked paired position change as executed for \(getPlayerName(targetPlayerId))")
        }
        
        // Update all references
        updateGameStateAfterPositionChange(game)
        
        print("🎉 BACKGROUND POSITION SWAP COMPLETE!")
    }

    // Helper method to consolidate game state updates
    private func updateGameStateAfterPositionChange(_ game: Game) {
        selectedGame = game
        if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[gameIndex] = game
        }
        
        gameStateManager.activeGameState?.lineupPositions = lineupPositions
        gameStateManager.forcePersistActiveGameState()
        teamManager.updateTeam(team, activeGameId: game.id)
    }

    private func executeAutomaticSubstitution(_ plannedSub: PlannedSubstitution) {
        guard var game = selectedGame else { return }
        
        let currentMinute = gameStateManager.calculatedMinute
        
        // Find the position being substituted
        if let positionIndex = lineupPositions.firstIndex(where: { $0.playerId == plannedSub.playerOut }) {
            // Track player exit
            trackPlayerExit(playerId: plannedSub.playerOut, minute: currentMinute)
            
            lineupPositions[positionIndex].playerId = plannedSub.playerIn
            lineupPositions[positionIndex].position = plannedSub.targetPosition
            
            // Track player entry
            trackPlayerEntry(playerId: plannedSub.playerIn, minute: currentMinute)
            
            // Add substitution to game record
            let substitution = Substitution(
                playerIn: plannedSub.playerIn,
                playerOut: plannedSub.playerOut,
                minute: currentMinute,
                reason: plannedSub.reason
            )
            game.substitutions.append(substitution)
            
            // Add audit entry
            gameStateManager.addAuditEntry(
                eventType: .substitution,
                gameTime: gameStateManager.auditLogTime,
                details: "AUTO: \(getPlayerName(plannedSub.playerOut)) (\(plannedSub.targetPosition.abbreviation))” \(getPlayerName(plannedSub.playerIn)) (\(plannedSub.reason.rawValue))"
            )
            
            // Mark as executed
            if let subIndex = game.plannedSubstitutions.firstIndex(where: { $0.id == plannedSub.id }) {
                game.plannedSubstitutions[subIndex].isExecuted = true
                game.plannedSubstitutions[subIndex].actualMinute = currentMinute
            }
            
            // Update game state manager
            gameStateManager.activeGameState?.lineupPositions = lineupPositions
            
            // Update game and team
            selectedGame = game
            if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
                team.games[gameIndex] = game
            }
            
            // FIXED: Use active game context for substitutions
            teamManager.updateTeam(team, activeGameId: game.id)
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
            print("AUTO SUB: \(getPlayerName(plannedSub.playerOut))” \(getPlayerName(plannedSub.playerIn)) at \(currentMinute)'")
        }
    }
    
    private func executeAutomaticPositionSwap(_ plannedPosChange: PlannedPositionChange) {
        guard var game = selectedGame else { return }
        
        let currentMinute = gameStateManager.calculatedMinute
        
        // Check if this position change was already executed as part of a pair
        if plannedPosChange.isExecuted {
            print("SKIP: Position change already executed for \(getPlayerName(plannedPosChange.playerId))")
            return
        }
        
        // Find the player who should be swapped (the one we're moving)
        guard let currentPlayerIndex = lineupPositions.firstIndex(where: { $0.playerId == plannedPosChange.playerId }) else {
            print("ERROR: Could not find player \(getPlayerName(plannedPosChange.playerId)) in current lineup for position swap")
            return
        }
        
        // Find what position this player is currently playing (after any substitutions)
        let actualCurrentPosition = lineupPositions[currentPlayerIndex].position
        
        // Find the player who is currently playing the target position
        guard let targetPlayerIndex = lineupPositions.firstIndex(where: { position in
            position.position == plannedPosChange.toPosition && position.playerId != plannedPosChange.playerId
        }) else {
            print("ERROR: Could not find a player currently playing \(plannedPosChange.toPosition.abbreviation) to swap with")
            return
        }
        
        guard let targetPlayerId = lineupPositions[targetPlayerIndex].playerId else {
            print("ERROR: Target position has no player assigned")
            return
        }
        
        // Perform the actual swap in the lineup array
        let tempPlayerId = lineupPositions[currentPlayerIndex].playerId
        lineupPositions[currentPlayerIndex].playerId = lineupPositions[targetPlayerIndex].playerId
        lineupPositions[targetPlayerIndex].playerId = tempPlayerId
        
        // The positions stay with their lineup slots - don't change position properties
        // The players just move to different physical locations
        
        // Add audit entry for the swap
        let targetPlayerName = getPlayerName(targetPlayerId)
        gameStateManager.addAuditEntry(
            eventType: .positionChange,
            gameTime: gameStateManager.auditLogTime,
            details: "AUTO SWAP: \(getPlayerName(plannedPosChange.playerId))” \(targetPlayerName) (\(actualCurrentPosition.abbreviation)” \(plannedPosChange.toPosition.abbreviation))"
        )
        
        // Mark BOTH position changes as executed (since this is a paired swap)
        if let posChangeIndex = game.plannedPositionChanges.firstIndex(where: { $0.id == plannedPosChange.id }) {
            game.plannedPositionChanges[posChangeIndex].isExecuted = true
            game.plannedPositionChanges[posChangeIndex].actualMinute = currentMinute
        }
        
        // Find and mark the paired position change as executed too
        if let pairedChangeIndex = game.plannedPositionChanges.firstIndex(where: { change in
            change.playerId == targetPlayerId &&
            change.plannedMinute == plannedPosChange.plannedMinute &&
            change.toPosition == actualCurrentPosition &&
            !change.isExecuted
        }) {
            game.plannedPositionChanges[pairedChangeIndex].isExecuted = true
            game.plannedPositionChanges[pairedChangeIndex].actualMinute = currentMinute
            print("PAIRED: Also marked paired position change as executed for \(targetPlayerName)")
        }
        
        // Update game state manager
        gameStateManager.activeGameState?.lineupPositions = lineupPositions
        
        // Update game and team
        selectedGame = game
        if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[gameIndex] = game
        }
        
        teamManager.updateTeam(team, activeGameId: game.id)
        
        print("POSITION SWAP: \(getPlayerName(plannedPosChange.playerId)) ” \(targetPlayerName) at \(currentMinute)'")
    }
    
    private func executeAutomaticPositionChange(_ plannedPosChange: PlannedPositionChange) {
        guard var game = selectedGame else { return }
        
        let currentMinute = gameStateManager.calculatedMinute
        
        // Find the player's current position in the lineup
        if let positionIndex = lineupPositions.firstIndex(where: { $0.playerId == plannedPosChange.playerId }) {
            // Update the player's position in the actual lineup
            lineupPositions[positionIndex].position = plannedPosChange.toPosition
            
            // Add audit entry
            gameStateManager.addAuditEntry(
                eventType: .positionChange,
                gameTime: gameStateManager.auditLogTime,
                details: "AUTO: \(getPlayerName(plannedPosChange.playerId)) \(plannedPosChange.fromPosition.abbreviation) ’ \(plannedPosChange.toPosition.abbreviation)"
            )
            
            // Mark as executed
            if let posChangeIndex = game.plannedPositionChanges.firstIndex(where: { $0.id == plannedPosChange.id }) {
                game.plannedPositionChanges[posChangeIndex].isExecuted = true
                game.plannedPositionChanges[posChangeIndex].actualMinute = currentMinute
            }
            
            // Update game state manager
            gameStateManager.activeGameState?.lineupPositions = lineupPositions
            
            // Update game and team
            selectedGame = game
            if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
                team.games[gameIndex] = game
            }
            
            teamManager.updateTeam(team, activeGameId: game.id)
            
            print("POSITION CHANGE: \(getPlayerName(plannedPosChange.playerId)) \(plannedPosChange.fromPosition.abbreviation)  \(plannedPosChange.toPosition.abbreviation) at \(currentMinute)'")
        }
    }
    
    private func executeLineupPhaseChange(_ phase: LineupPhase) {
        guard var game = selectedGame else { return }
        
        print("Executing full lineup phase: \(phase.name)")
        
        let currentMinute = gameStateManager.calculatedMinute
        for (oldPos, newPos) in zip(gameStateManager.activeGameState?.lineupPositions ?? [], phase.lineup) {
            if oldPos.playerId != newPos.playerId {
                if let oldPlayerId = oldPos.playerId {
                    trackPlayerExit(playerId: oldPlayerId, minute: currentMinute)
                }
                if let newPlayerId = newPos.playerId {
                    trackPlayerEntry(playerId: newPlayerId, minute: currentMinute)
                }
            }
        }
        
        lineupPositions = phase.lineup
        print("Updated entire lineup for phase: \(phase.name)")
        
        gameStateManager.addAuditEntry(
            eventType: .substitution,
            gameTime: gameStateManager.auditLogTime,
            details: "AUTO: \(phase.name) - Full rotation executed (Planned)"
        )
        
        if let phaseIndex = game.lineupPhases.firstIndex(where: { $0.id == phase.id }) {
            game.lineupPhases[phaseIndex].isExecuted = true
        }
        
        gameStateManager.activeGameState?.lineupPositions = lineupPositions
        
        selectedGame = game
        if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[gameIndex] = game
        }
        
        // FIXED: Use active game context for lineup phase changes
        teamManager.updateTeam(team, activeGameId: game.id)
        
        print("Full rotation complete!")
    }

    // FIXED: Improved time tracking with better validation
    private func trackPlayingTime(playerOut: UUID, playerIn: UUID, minute: Int) {
        print("Tracking substitution time - Out: \(getPlayerName(playerOut)), In: \(getPlayerName(playerIn)), Minute: \(minute)")
        trackPlayerExit(playerId: playerOut, minute: minute)
        trackPlayerEntry(playerId: playerIn, minute: minute)
    }

    // FIXED: Better player exit tracking with validation
    private func trackPlayerExit(playerId: UUID, minute: Int) {
        guard var game = selectedGame else { return }
        
        if let statsIndex = game.playerStats.firstIndex(where: { $0.playerId == playerId }) {
            // Find the most recent open time entry
            if let lastEntryIndex = game.playerStats[statsIndex].timeEntries.lastIndex(where: { $0.exitedAt == nil }) {
                let entryStartTime = game.playerStats[statsIndex].timeEntries[lastEntryIndex].enteredAt
                
                // Validate the exit time makes sense
                if minute >= entryStartTime {
                    game.playerStats[statsIndex].timeEntries[lastEntryIndex].exitedAt = minute
                    print("Player \(getPlayerName(playerId)) exited at minute \(minute)")
                } else {
                    print("Invalid exit time for player \(getPlayerName(playerId)): \(minute) < \(entryStartTime)")
                }
            }
        }
        
        selectedGame = game
        if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[gameIndex] = game
        }
    }

    // FIXED: Better player entry tracking with validation
    private func trackPlayerEntry(playerId: UUID, minute: Int) {
        guard var game = selectedGame else { return }
        
        // Find or create player stats
        if let statsIndex = game.playerStats.firstIndex(where: { $0.playerId == playerId }) {
            // Add new time entry
            game.playerStats[statsIndex].timeEntries.append(TimeEntry(enteredAt: minute, exitedAt: nil))
            print("Player \(getPlayerName(playerId)) entered at minute \(minute)")
        } else {
            // Create new player stats with initial entry
            var newStats = PlayerGameStats(playerId: playerId)
            newStats.timeEntries.append(TimeEntry(enteredAt: minute, exitedAt: nil))
            game.playerStats.append(newStats)
            print("Created new stats for player \(getPlayerName(playerId)) entering at minute \(minute)")
        }
        
        selectedGame = game
        if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[gameIndex] = game
        }
    }

    private func getPlayerName(_ playerId: UUID) -> String {
        return team.players.first(where: { $0.id == playerId })?.name ?? "Unknown Player"
    }
}
// MARK: - Active Game Banner
struct ActiveGameBanner: View {
    let activeGame: ActiveGameState
    let onViewGame: () -> Void
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .scaleEffect(1.5)
                            .opacity(0.5)
                            .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true), value: UUID())
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACTIVE GAME")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("vs \(activeGame.opponent)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            Button(action: onViewGame) {
                Text("View Game")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct SubstitutionPlannerView: View {
    let team: Team
    @Binding var game: Game  // Changed back to @Binding
    let lineupPositions: [LineupPosition]
    let onPlanningDataChanged: () -> Void
    // Remove: let onSave: (Game) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var useAutoSubstitutions = false
    @EnvironmentObject var teamManager: TeamManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Text("Substitution Planning")
                        .font(.title2)
                        .bold()
                    
                    Text("Plan your substitutions before the game starts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Auto-substitution toggle
                HStack {
                    Toggle("Enable Auto-Substitutions", isOn: $useAutoSubstitutions)
                        .onChange(of: useAutoSubstitutions) { value in
                            game.useAutoSubstitutions = value
                            // SAVE TO FIREBASE IMMEDIATELY
                            saveGamePlanningData()
                        }
                }
                .padding(.horizontal)
                
                if useAutoSubstitutions {
                    // Individual substitution planner
                    IndividualSubstitutionPlanner(
                        team: team,
                        game: $game,
                        lineupPositions: lineupPositions,
                        onPlanningDataChanged: {
                            // SAVE TO FIREBASE WHENEVER PLANNING DATA CHANGES
                            saveGamePlanningData()
                        }
                    )
                }
                
                Spacer()
                
                if !useAutoSubstitutions {
                    Text("Enable auto-substitutions to start planning your game substitutions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle("Plan Substitutions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGamePlanningData()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            useAutoSubstitutions = game.useAutoSubstitutions
        }
    }
    
    private func saveGamePlanningData() {
        // Just trigger the callback to mark changes as unsaved
        onPlanningDataChanged()
    }

    init(team: Team, game: Binding<Game>, lineupPositions: [LineupPosition], onPlanningDataChanged: @escaping () -> Void) {
        self.team = team
        self._game = game
        self.lineupPositions = lineupPositions
        self.onPlanningDataChanged = onPlanningDataChanged
    }
}

struct PositionChangeView: View {
    let team: Team
    @Binding var game: Game
    let lineupPositions: [LineupPosition]
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPlayer: Player?
    @State private var selectedMinute: Int = 15
    @State private var fromPosition: Position?
    @State private var toPosition: Position?
    
    var playersOnFieldAtSelectedTime: [Player] {
        calculatePlayersOnField(atMinute: selectedMinute)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("When") {
                    Stepper("Minute: \(selectedMinute)", value: $selectedMinute, in: 0...90)
                }
                
                Section("Player") {
                    Picker("Player to Move", selection: $selectedPlayer) {
                        Text("Select Player").tag(nil as Player?)
                        ForEach(playersOnFieldAtSelectedTime) { player in
                            Text("\(player.name) (#\(player.jerseyNumber))").tag(player as Player?)
                        }
                    }
                    .onChange(of: selectedPlayer) { player in
                        if let player = player {
                            fromPosition = getCurrentPosition(for: player, atMinute: selectedMinute)
                        }
                    }
                }
                
                if let fromPos = fromPosition {
                    Section("Position Change") {
                        HStack {
                            Text("From:")
                            Spacer()
                            Text(fromPos.rawValue)
                                .foregroundColor(.red)
                        }
                        
                        Picker("To Position", selection: $toPosition) {
                            Text("Select Position").tag(nil as Position?)
                            ForEach(Position.allCases.filter { $0 != fromPos }, id: \.self) { position in
                                Text(position.rawValue).tag(position as Position?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Position Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addPositionChange()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(selectedPlayer == nil || toPosition == nil)
                }
            }
        }
    }
    
    private func addPositionChange() {
        guard let player = selectedPlayer,
              let fromPos = fromPosition,
              let toPos = toPosition else { return }
        
        let positionChange = PlannedPositionChange(
            playerId: player.id,
            fromPosition: fromPos,
            toPosition: toPos,
            plannedMinute: selectedMinute
        )
        
        game.plannedPositionChanges.append(positionChange)
    }
    
    private func calculatePlayersOnField(atMinute minute: Int) -> [Player] {
        var currentFieldPlayers = Set<UUID>()
        for position in lineupPositions {
            if let playerId = position.playerId {
                currentFieldPlayers.insert(playerId)
            }
        }
        
        let relevantSubs = game.plannedSubstitutions
            .filter { $0.plannedMinute <= minute }
            .sorted { $0.plannedMinute < $1.plannedMinute }
        
        for sub in relevantSubs {
            currentFieldPlayers.remove(sub.playerOut)
            currentFieldPlayers.insert(sub.playerIn)
        }
        
        return currentFieldPlayers.compactMap { playerId in
            team.players.first { $0.id == playerId }
        }.sorted { $0.name < $1.name }
    }
    
    private func getCurrentPosition(for player: Player, atMinute minute: Int) -> Position? {
        // Use the same updated logic as above
        let relevantSubs = game.plannedSubstitutions
            .filter { $0.plannedMinute <= minute }
            .sorted { $0.plannedMinute < $1.plannedMinute }
        
        let relevantPositionChanges = game.plannedPositionChanges
            .filter { $0.plannedMinute < minute && $0.playerId == player.id }
            .sorted { $0.plannedMinute < $1.plannedMinute }
        
        var isOnField = false
        var currentPosition: Position? = nil
        
        if let startingPosition = lineupPositions.first(where: { $0.playerId == player.id }) {
            isOnField = true
            currentPosition = startingPosition.position
        }
        
        // Create chronological timeline
        var allEvents: [(minute: Int, type: String, data: Any)] = []
        
        for sub in relevantSubs {
            if sub.playerOut == player.id {
                allEvents.append((minute: sub.plannedMinute, type: "subOut", data: sub))
            } else if sub.playerIn == player.id {
                allEvents.append((minute: sub.plannedMinute, type: "subIn", data: sub))
            }
        }
        
        for posChange in relevantPositionChanges {
            allEvents.append((minute: posChange.plannedMinute, type: "positionChange", data: posChange))
        }
        
        allEvents.sort { $0.minute < $1.minute }
        
        for event in allEvents {
            switch event.type {
            case "subOut":
                if let sub = event.data as? PlannedSubstitution, sub.playerOut == player.id {
                    isOnField = false
                    currentPosition = nil
                }
            case "subIn":
                if let sub = event.data as? PlannedSubstitution, sub.playerIn == player.id {
                    isOnField = true
                    currentPosition = sub.targetPosition
                }
            case "positionChange":
                if let posChange = event.data as? PlannedPositionChange, isOnField {
                    currentPosition = posChange.toPosition
                }
            default:
                break
            }
        }
        
        return isOnField ? currentPosition : nil
    }
    
    private func calculatePlayersOnBench(atMinute minute: Int) -> [Player] {
        let playersOnField = Set(calculatePlayersOnField(atMinute: minute).map { $0.id })
        
        return team.players.filter { player in
            !playersOnField.contains(player.id)
        }.sorted { $0.name < $1.name }
    }
}

struct PositionSwapView: View {
    let team: Team
    @Binding var game: Game
    let lineupPositions: [LineupPosition]
    let onPositionChangeAdded: () -> Void
    let initialMinute: Int  // NEW
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedMinute: Int
    @State private var playerA: Player?
    @State private var playerB: Player?
    @State private var playerAPosition: Position?
    @State private var playerBPosition: Position?
    @State private var swapsAdded: Int = 0
    
    // NEW: Custom init to set initial minute
    init(team: Team, game: Binding<Game>, lineupPositions: [LineupPosition], onPositionChangeAdded: @escaping () -> Void, initialMinute: Int = 0) {
        self.team = team
        self._game = game
        self.lineupPositions = lineupPositions
        self.onPositionChangeAdded = onPositionChangeAdded
        self.initialMinute = initialMinute
        self._selectedMinute = State(initialValue: initialMinute)
    }
    
    var playersOnFieldAtSelectedTime: [Player] {
        calculatePlayersOnField(atMinute: selectedMinute)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("When") {
                    Stepper("Minute: \(selectedMinute)", value: $selectedMinute, in: 0...90)
                }
                
                if swapsAdded > 0 {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(swapsAdded) swap\(swapsAdded == 1 ? "" : "s") added — select another pair or tap Done")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Select Players to Swap") {
                    Picker("First Player", selection: $playerA) {
                        Text("Select Player").tag(nil as Player?)
                        ForEach(playersOnFieldAtSelectedTime) { player in
                            let position = getCurrentPosition(for: player, atMinute: selectedMinute)
                            Text("\(player.name) (#\(player.jerseyNumber)) - \(position?.abbreviation ?? "?")")
                                .tag(player as Player?)
                        }
                    }
                    .onChange(of: playerA) { player in
                        if let player = player {
                            playerAPosition = getCurrentPosition(for: player, atMinute: selectedMinute)
                        }
                        // Reset second player if same as first
                        if playerA?.id == playerB?.id {
                            playerB = nil
                            playerBPosition = nil
                        }
                    }
                    
                    Picker("Second Player", selection: $playerB) {
                        Text("Select Player").tag(nil as Player?)
                        ForEach(playersOnFieldAtSelectedTime.filter { $0.id != playerA?.id }) { player in
                            let position = getCurrentPosition(for: player, atMinute: selectedMinute)
                            Text("\(player.name) (#\(player.jerseyNumber)) - \(position?.abbreviation ?? "?")")
                                .tag(player as Player?)
                        }
                    }
                    .onChange(of: playerB) { player in
                        if let player = player {
                            playerBPosition = getCurrentPosition(for: player, atMinute: selectedMinute)
                        }
                    }
                }
                
                if let playerA = playerA, let playerB = playerB,
                   let posA = playerAPosition, let posB = playerBPosition {
                    Section("Swap Preview") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(playerA.name)
                                    .font(.subheadline)
                                    .bold()
                                Text(posA.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.left.arrow.right")
                                .foregroundColor(.purple)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text(playerB.name)
                                    .font(.subheadline)
                                    .bold()
                                Text(posB.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Text("After swap:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("\(playerA.name) \(posB.abbreviation)")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Spacer()
                            
                            Text("\(playerB.name) \(posA.abbreviation)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Swap Positions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        if swapsAdded > 0 {
                            onPositionChangeAdded()
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Swap") {
                        createPositionSwap()
                        swapsAdded += 1
                        playerA = nil
                        playerB = nil
                        playerAPosition = nil
                        playerBPosition = nil
                    }
                    .disabled(playerA == nil || playerB == nil)
                }
            }
        }
    }

    private func createPositionSwap() {
        guard let playerA = playerA, let playerB = playerB,
              let posA = playerAPosition, let posB = playerBPosition else { return }
        
        // Create two position changes that happen simultaneously
        let swapA = PlannedPositionChange(
            playerId: playerA.id,
            fromPosition: posA,
            toPosition: posB,
            plannedMinute: selectedMinute
        )
        
        let swapB = PlannedPositionChange(
            playerId: playerB.id,
            fromPosition: posB,
            toPosition: posA,
            plannedMinute: selectedMinute
        )
        
        game.plannedPositionChanges.append(swapA)
        game.plannedPositionChanges.append(swapB)
    }
    
    private func calculatePlayersOnField(atMinute minute: Int) -> [Player] {
        var currentFieldPlayers = Set<UUID>()
        for position in lineupPositions {
            if let playerId = position.playerId {
                currentFieldPlayers.insert(playerId)
            }
        }
        
        let relevantSubs = game.plannedSubstitutions
            .filter { $0.plannedMinute <= minute }
            .sorted { $0.plannedMinute < $1.plannedMinute }
        
        for sub in relevantSubs {
            currentFieldPlayers.remove(sub.playerOut)
            currentFieldPlayers.insert(sub.playerIn)
        }
        
        return currentFieldPlayers.compactMap { playerId in
            team.players.first { $0.id == playerId }
        }.sorted { $0.name < $1.name }
    }
    
    private func getCurrentPosition(for player: Player, atMinute minute: Int) -> Position? {
        // Using <= for position changes so that chained swaps at the same minute
        // correctly reflect the result of previously-added swaps in the same session.
        let relevantSubs = game.plannedSubstitutions
            .filter { $0.plannedMinute <= minute }
            .sorted { $0.plannedMinute < $1.plannedMinute }

        let relevantPositionChanges = game.plannedPositionChanges
            .filter { $0.plannedMinute <= minute && $0.playerId == player.id }
            .sorted { $0.plannedMinute < $1.plannedMinute }

        // Track player's status through all events chronologically
        var isOnField = false
        var currentPosition: Position? = nil

        // First check if player is in starting lineup
        if let startingPosition = lineupPositions.first(where: { $0.playerId == player.id }) {
            isOnField = true
            currentPosition = startingPosition.position
        }

        // Create a combined timeline of all events
        var allEvents: [(minute: Int, type: String, data: Any)] = []

        // Add substitutions to timeline
        for sub in relevantSubs {
            if sub.playerOut == player.id {
                allEvents.append((minute: sub.plannedMinute, type: "subOut", data: sub))
            } else if sub.playerIn == player.id {
                allEvents.append((minute: sub.plannedMinute, type: "subIn", data: sub))
            }
        }

        // Add position changes to timeline
        for posChange in relevantPositionChanges {
            allEvents.append((minute: posChange.plannedMinute, type: "positionChange", data: posChange))
        }

        // Sort all events chronologically
        allEvents.sort { $0.minute < $1.minute }

        // Apply events in chronological order
        for event in allEvents {
            switch event.type {
            case "subOut":
                if let sub = event.data as? PlannedSubstitution, sub.playerOut == player.id {
                    isOnField = false
                    currentPosition = nil
                }
            case "subIn":
                if let sub = event.data as? PlannedSubstitution, sub.playerIn == player.id {
                    isOnField = true
                    currentPosition = sub.targetPosition
                }
            case "positionChange":
                if let posChange = event.data as? PlannedPositionChange, isOnField {
                    currentPosition = posChange.toPosition
                }
            default:
                break
            }
        }

        return isOnField ? currentPosition : nil
    }
}
struct IndividualSubstitutionPlanner: View {
    let team: Team
    @Binding var game: Game
    let lineupPositions: [LineupPosition]
    let onPlanningDataChanged: () -> Void
    
    @State private var showingAddSubstitution = false
    @State private var showingMultiSubstitution = false
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showingPositionChange = false
    
    private var groupedSubstitutions: [(groupIndex: Int, groupName: String, substitutions: [PlannedSubstitution])] {
        // Group by stored subGroupIndex, not by time proximity
        var groups: [Int: [PlannedSubstitution]] = [:]
        
        for sub in game.plannedSubstitutions {
            let groupIndex = sub.subGroupIndex ?? 1
            groups[groupIndex, default: []].append(sub)
        }
        
        // Sort each group's subs by planned minute, then return sorted groups
        return groups.keys.sorted().compactMap { groupIndex in
            guard var subs = groups[groupIndex], !subs.isEmpty else { return nil }
            subs.sort { $0.plannedMinute < $1.plannedMinute }
            return (groupIndex: groupIndex, groupName: "Sub \(groupIndex)", substitutions: subs)
        }
    }
    
    private var nextSubstitutionMinute: Int {
        if game.plannedSubstitutions.isEmpty {
            return 0
        }
        // Return the last substitution's minute
        return game.plannedSubstitutions.map { $0.plannedMinute }.max() ?? 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with share button
            HStack {
                Text("Substitution Plan")
                    .font(.headline)
                
                Spacer()
                
                if !game.plannedSubstitutions.isEmpty {
                    Button(action: shareSubstitutionPlan) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Plan")
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            
            // Current planned substitutions with playing time
            ScrollView {
                VStack(spacing: 12) {
                    if game.plannedSubstitutions.isEmpty && game.plannedPositionChanges.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.left.arrow.right.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No planned substitutions")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Add substitutions to plan when players should be swapped during the game")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        // Clear all button
                        HStack {
                            Spacer()
                            Button("Clear All") {
                                clearAllSubstitutions()
                            }
                            .foregroundColor(.red)
                            .font(.subheadline)
                        }
                        .padding(.horizontal)
                        
                        // Playing time summary
                        PlayingTimeSummary(
                            team: team,
                            game: game,
                            lineupPositions: lineupPositions
                        )
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Grouped substitutions display
                        ForEach(groupedSubstitutions, id: \.groupIndex) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                // Group header
                                HStack {
                                    Text(group.groupName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                    
                                    Text("(\(group.substitutions.count) subs)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if let firstSub = group.substitutions.first {
                                        Text("~\(firstSub.plannedMinute)'")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                                
                                // Substitutions in this group
                                ForEach(group.substitutions.sorted(by: { $0.plannedMinute < $1.plannedMinute })) { sub in
                                    CompactPlannedSubstitutionRow(
                                        plannedSub: sub,
                                        team: team,
                                        onDelete: { deleteSubstitution(sub) }
                                    )
                                }
                                
                                // Position changes in similar time range
                                ForEach(game.plannedPositionChanges.filter { posChange in
                                    group.substitutions.contains { abs($0.plannedMinute - posChange.plannedMinute) <= 5 }
                                }.sorted { $0.plannedMinute < $1.plannedMinute }) { posChange in
                                    CompactPositionChangeRow(
                                        positionChange: posChange,
                                        team: team,
                                        onDelete: { deletePositionChange(posChange) }
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6).opacity(0.3))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Coaching Notes section - added at bottom
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coaching Notes")
                            .font(.headline)
                        
                        TextEditor(text: Binding(
                            get: { game.substitutionNotes ?? "" },
                            set: {
                                game.substitutionNotes = $0.isEmpty ? nil : $0
                                onPlanningDataChanged()  // ADDED: Mark as changed so it saves
                            }
                        ))
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        
                        Text("Add tactical instructions, reminders, or context for your substitution plan")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal)
            }
            
            // Action buttons - put all in same HStack
            HStack(spacing: 12) {
                Button(action: { showingAddSubstitution = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "person.fill")
                        Text("Single Sub")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                
                Button(action: { showingMultiSubstitution = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                        Text("Multi Sub")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(10)
                }
                
                Button(action: { showingPositionChange = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                        Text("Swap Positions")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingAddSubstitution) {
            AddSubstitutionView(
                team: team,
                game: $game,
                lineupPositions: lineupPositions,
                onSubstitutionAdded: {
                    onPlanningDataChanged()
                },
                initialMinute: nextSubstitutionMinute
            )
        }
        .sheet(isPresented: $showingMultiSubstitution) {
            MultiSubstitutionView(
                team: team,
                game: $game,
                lineupPositions: lineupPositions,
                onSubstitutionsAdded: {
                    onPlanningDataChanged()
                },
                initialMinute: nextSubstitutionMinute
            )
        }
        .sheet(isPresented: $showingPositionChange) {
            PositionSwapView(
                team: team,
                game: $game,
                lineupPositions: lineupPositions,
                onPositionChangeAdded: {
                    onPlanningDataChanged()
                },
                initialMinute: nextSubstitutionMinute
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
    }
    
    private func deleteSubstitution(_ substitution: PlannedSubstitution) {
        game.plannedSubstitutions.removeAll { $0.id == substitution.id }
        onPlanningDataChanged()  // NOTIFY OF CHANGES
    }
    
    private func deletePositionChange(_ positionChange: PlannedPositionChange) {
        game.plannedPositionChanges.removeAll { $0.id == positionChange.id }
        onPlanningDataChanged()  // NOTIFY OF CHANGES
    }
    
    private func clearAllSubstitutions() {
        game.plannedSubstitutions.removeAll()
        game.plannedPositionChanges.removeAll()
        onPlanningDataChanged()
    }
    
    private func shareSubstitutionPlan() {
        let substitutionPlanView = SubstitutionPlanShareView(
            game: game,
            team: team,
            lineupPositions: lineupPositions,
            groupedSubstitutions: groupedSubstitutions
        )
        
        let hostingController = UIHostingController(rootView: substitutionPlanView)
        hostingController.view.backgroundColor = .white
        
        // Wider format for two columns
        let printWidth: CGFloat = 650
        let maxHeight: CGFloat = 1200
        
        hostingController.view.frame = CGRect(origin: .zero, size: CGSize(width: printWidth, height: maxHeight))
        
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: printWidth, height: maxHeight)))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        window.rootViewController?.view.addSubview(hostingController.view)
        
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        let contentSize = hostingController.view.systemLayoutSizeFitting(
            CGSize(width: printWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        let finalHeight = min(max(contentSize.height + 40, 300), maxHeight)
        let finalSize = CGSize(width: printWidth, height: finalHeight)
        
        hostingController.view.frame = CGRect(origin: .zero, size: finalSize)
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIGraphicsBeginImageContextWithOptions(finalSize, true, 2.0)
            defer { UIGraphicsEndImageContext() }
            
            guard let context = UIGraphicsGetCurrentContext() else { return }
            
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: finalSize))
            
            hostingController.view.layer.render(in: context)
            
            if let image = UIGraphicsGetImageFromCurrentImageContext() {
                self.shareImage = image
                self.showingShareSheet = true
            }
            
            hostingController.view.removeFromSuperview()
            window.isHidden = true
        }
    }
}
struct CompactPositionChangeRow: View {
    let positionChange: PlannedPositionChange
    let team: Team
    let onDelete: () -> Void
    
    var player: Player? {
        team.players.first { $0.id == positionChange.playerId }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Time
            Text("\(positionChange.plannedMinute)'")
                .font(.subheadline)
                .bold()
                .foregroundColor(.purple)
                .frame(width: 30)
            
            // Player and position change
            HStack(spacing: 6) {
                if let player = player {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("\(player.jerseyNumber)")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.purple)
                        )
                    
                    Text(player.name.components(separatedBy: " ").first ?? "")
                        .font(.caption)
                        .bold()
                }
                
                // Position change indicator
                Text(positionChange.fromPosition.abbreviation)
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                
                Image(systemName: "arrow.triangle.swap")
                    .foregroundColor(.purple)
                    .font(.caption)
                
                Text(positionChange.toPosition.abbreviation)
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(8)
    }
}

struct PlayingTimeSummary: View {
    let team: Team
    let game: Game
    let lineupPositions: [LineupPosition]
    
    var playingTimeData: [(Player, Int)] {
        calculateProjectedPlayingTime()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projected Playing Time")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(playingTimeData, id: \.0.id) { player, minutes in
                    HStack {
                        Circle()
                            .fill(getPlayingTimeColor(minutes: minutes))
                            .frame(width: 8, height: 8)
                        
                        Text(player.name.components(separatedBy: " ").first ?? "")
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("\(minutes)m")
                            .font(.caption)
                            .bold()
                            .foregroundColor(getPlayingTimeColor(minutes: minutes))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
            }
        }
    }
    
    // FIXED: Better calculation that caps at total game time
    private func calculateProjectedPlayingTime() -> [(Player, Int)] {
        let totalGameTime = team.defaultHalfLength * 2
        var playingTime: [UUID: Int] = [:]
        
        // Initialize with starting lineup getting full game time
        for position in lineupPositions {
            if let playerId = position.playerId {
                playingTime[playerId] = totalGameTime
            }
        }
        
        // Apply planned substitutions in chronological order
        let sortedSubs = game.plannedSubstitutions.sorted { $0.plannedMinute < $1.plannedMinute }
        
        for sub in sortedSubs {
            let remainingTime = max(0, totalGameTime - sub.plannedMinute)
            
            // Player going out loses remaining time
            if let currentTime = playingTime[sub.playerOut] {
                playingTime[sub.playerOut] = max(0, currentTime - remainingTime)
            }
            
            // Player coming in gains remaining time
            playingTime[sub.playerIn] = (playingTime[sub.playerIn] ?? 0) + remainingTime
        }
        
        // Cap all playing times at total game time
        for playerId in playingTime.keys {
            playingTime[playerId] = min(playingTime[playerId] ?? 0, totalGameTime)
        }
        
        return team.players.compactMap { player in
            if let minutes = playingTime[player.id], minutes > 0 {
                return (player, minutes)
            }
            return nil
        }.sorted { $0.1 > $1.1 }
    }
    
    private func getPlayingTimeColor(minutes: Int) -> Color {
        let totalGameTime = team.defaultHalfLength * 2
        let percentage = Double(minutes) / Double(totalGameTime)
        
        switch percentage {
        case 0.5...: return .green
        case 0.25..<0.5: return .orange
        case 0.01..<0.25: return .red
        default: return .gray
        }
    }
}
// MARK: - Compact Planned Substitution Row (NEW - smaller design)
struct CompactPlannedSubstitutionRow: View {
    let plannedSub: PlannedSubstitution
    let team: Team
    let onDelete: () -> Void
    
    var playerOut: Player? {
        team.players.first { $0.id == plannedSub.playerOut }
    }
    
    var playerIn: Player? {
        team.players.first { $0.id == plannedSub.playerIn }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Time - smaller
            Text("\(plannedSub.plannedMinute)'")
                .font(.subheadline)
                .bold()
                .foregroundColor(.blue)
                .frame(width: 30)
            
            // Players with position info - more compact
            HStack(spacing: 6) {
                if let playerOut = playerOut {
                    CompactPlayerChip(player: playerOut, color: .red, label: "OUT")
                }
                
                // Position indicator
                Text(plannedSub.targetPosition.abbreviation)
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.blue)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                if let playerIn = playerIn {
                    CompactPlayerChip(player: playerIn, color: .green, label: "IN")
                }
            }
            
            Spacer()
            
            // Reason and delete - smaller
            VStack(alignment: .trailing, spacing: 2) {
                Text(plannedSub.reason.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Compact Player Chip (NEW - smaller version)
struct CompactPlayerChip: View {
    let player: Player
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(
                    Text("\(player.jerseyNumber)")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 1) {
                Text(player.name.components(separatedBy: " ").first ?? "")
                    .font(.caption)
                    .bold()
                Text(label)
                    .font(.caption2)
                    .foregroundColor(color)
                    .bold()
            }
        }
    }
}

struct ShareableSubstitutionRow: View {
    let substitution: PlannedSubstitution
    let team: Team
    
    var playerOut: Player? {
        team.players.first { $0.id == substitution.playerOut }
    }
    
    var playerIn: Player? {
        team.players.first { $0.id == substitution.playerIn }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Time
            Text("\(substitution.plannedMinute)'")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .frame(width: 40, alignment: .leading)
            
            // OUT Player
            if let playerOut = playerOut {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("\(playerOut.jerseyNumber)")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.white)
                        )
                    Text(playerOut.name.components(separatedBy: " ").first ?? "")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            }
            
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.blue)
            
            // IN Player
            if let playerIn = playerIn {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("\(playerIn.jerseyNumber)")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.white)
                        )
                    Text(playerIn.name.components(separatedBy: " ").first ?? "")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            Text(substitution.reason.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct MultiSubstitutionView: View {
    let team: Team
    @Binding var game: Game
    let lineupPositions: [LineupPosition]
    let onSubstitutionsAdded: () -> Void
    let initialMinute: Int  // NEW
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedMinute: Int
    @State private var selectedReason: SubstitutionReason = .tactical
    @State private var playersOut: [Player] = []
    @State private var playersIn: [Player] = []
    
    // NEW: Custom init to set initial minute
    init(team: Team, game: Binding<Game>, lineupPositions: [LineupPosition], onSubstitutionsAdded: @escaping () -> Void, initialMinute: Int = 0) {
        self.team = team
        self._game = game
        self.lineupPositions = lineupPositions
        self.onSubstitutionsAdded = onSubstitutionsAdded
        self.initialMinute = initialMinute
        self._selectedMinute = State(initialValue: initialMinute)
    }
    
    var playersOnFieldAtSelectedTime: [Player] {
        calculatePlayersOnField(atMinute: selectedMinute)
    }
    
    var playersOnBenchAtSelectedTime: [Player] {
        calculatePlayersOnBench(atMinute: selectedMinute)
    }
    
    private var subGroupIndex: Int {
        // Simply get the next available group index
        let existingGroupIndices = game.plannedSubstitutions.compactMap { $0.subGroupIndex }
        if existingGroupIndices.isEmpty {
            return 1
        }
        return (existingGroupIndices.max() ?? 0) + 1
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Time selection - compact
                VStack(alignment: .leading, spacing: 8) {
                    Text("When")
                        .font(.headline)
                    
                    HStack {
                        Text("Minute:")
                        Stepper("\(selectedMinute)", value: $selectedMinute, in: 1...90)
                            .onChange(of: selectedMinute) { _ in
                                // Reset selections when time changes
                                playersOut = []
                                playersIn = []
                            }
                    }
                    
                    HStack {
                        Text("Sub Group:")
                        Spacer()
                        Text("Sub \(subGroupIndex)")
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal)
                
                // Multi-select interface - much more compact
                HStack(spacing: 8) {
                    // Players coming off
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coming Off (\(playersOut.count))")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.red)
                        
                        // Compact grid instead of ScrollView
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 4) {
                            ForEach(playersOnFieldAtSelectedTime) { player in
                                CompactMultiSelectPlayerCard(
                                    player: player,
                                    isSelected: playersOut.contains(player),
                                    color: .red,
                                    index: playersOut.firstIndex(of: player),
                                    currentPosition: getCurrentPosition(for: player, atMinute: selectedMinute)
                                ) {
                                    togglePlayerOut(player)
                                }
                            }
                        }
                    }
                    
                    // Pairing indicator - smaller
                    VStack {
                        Image(systemName: "arrow.right")
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        Text("1:1")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .frame(width: 30)
                    
                    // Players coming on
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coming On (\(playersIn.count))")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.green)
                        
                        // Compact grid instead of ScrollView
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 4) {
                            ForEach(playersOnBenchAtSelectedTime) { player in
                                CompactMultiSelectPlayerCard(
                                    player: player,
                                    isSelected: playersIn.contains(player),
                                    color: .green,
                                    index: playersIn.firstIndex(of: player),
                                    currentPosition: nil // Bench players don't have current position
                                ) {
                                    togglePlayerIn(player)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Pairing preview - more compact
                if !playersOut.isEmpty || !playersIn.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Substitution Pairs")
                            .font(.subheadline)
                            .bold()
                        
                        ForEach(0..<max(playersOut.count, playersIn.count), id: \.self) { index in
                            HStack(spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                
                                if index < playersOut.count {
                                    Text("#\(playersOut[index].jerseyNumber) \(playersOut[index].name.components(separatedBy: " ").first ?? "")")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                } else {
                                    Text("(No player selected)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                
                                if index < playersIn.count {
                                    Text("#\(playersIn[index].jerseyNumber) \(playersIn[index].name.components(separatedBy: " ").first ?? "")")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("(No player selected)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Multi Substitution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add All") {
                        addMultipleSubstitutions()
                        onSubstitutionsAdded()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(playersOut.isEmpty || playersIn.isEmpty || playersOut.count != playersIn.count)
                }
            }
        }
    }
    
    private func togglePlayerOut(_ player: Player) {
        if let index = playersOut.firstIndex(of: player) {
            playersOut.remove(at: index)
        } else {
            playersOut.append(player)
        }
    }
    
    private func togglePlayerIn(_ player: Player) {
        if let index = playersIn.firstIndex(of: player) {
            playersIn.remove(at: index)
        } else {
            playersIn.append(player)
        }
    }
    
    private func addMultipleSubstitutions() {
        let maxCount = min(playersOut.count, playersIn.count)
        let groupIndex = subGroupIndex
        
        for i in 0..<maxCount {
            // Find the position for the player being substituted out
            guard let targetPosition = getCurrentPosition(for: playersOut[i], atMinute: selectedMinute) else {
                print("Could not determine position for \(playersOut[i].name)")
                continue
            }
            
            var plannedSub = PlannedSubstitution(
                playerOut: playersOut[i].id,
                playerIn: playersIn[i].id,
                plannedMinute: selectedMinute,
                reason: selectedReason,
                targetPosition: targetPosition  // CAPTURE THE POSITION
            )
            
            plannedSub.subGroupIndex = groupIndex
            game.plannedSubstitutions.append(plannedSub)
        }
    }
    
    private func getCurrentPosition(for player: Player, atMinute minute: Int) -> Position? {
        // Get all events before this minute, sorted chronologically
        let relevantSubs = game.plannedSubstitutions
            .filter { $0.plannedMinute <= minute }
            .sorted { $0.plannedMinute < $1.plannedMinute }
        
        let relevantPositionChanges = game.plannedPositionChanges
            .filter { $0.plannedMinute < minute && $0.playerId == player.id }
            .sorted { $0.plannedMinute < $1.plannedMinute }
        
        // Track player's status through all events chronologically
        var isOnField = false
        var currentPosition: Position? = nil
        
        // First check if player is in starting lineup
        if let startingPosition = lineupPositions.first(where: { $0.playerId == player.id }) {
            isOnField = true
            currentPosition = startingPosition.position
        }
        
        // Create a combined timeline of all events
        var allEvents: [(minute: Int, type: String, data: Any)] = []
        
        // Add substitutions to timeline
        for sub in relevantSubs {
            if sub.playerOut == player.id {
                allEvents.append((minute: sub.plannedMinute, type: "subOut", data: sub))
            } else if sub.playerIn == player.id {
                allEvents.append((minute: sub.plannedMinute, type: "subIn", data: sub))
            }
        }
        
        // Add position changes to timeline
        for posChange in relevantPositionChanges {
            allEvents.append((minute: posChange.plannedMinute, type: "positionChange", data: posChange))
        }
        
        // Sort all events chronologically
        allEvents.sort { $0.minute < $1.minute }
        
        // Apply events in chronological order
        for event in allEvents {
            switch event.type {
            case "subOut":
                if let sub = event.data as? PlannedSubstitution, sub.playerOut == player.id {
                    isOnField = false
                    currentPosition = nil
                }
            case "subIn":
                if let sub = event.data as? PlannedSubstitution, sub.playerIn == player.id {
                    isOnField = true
                    currentPosition = sub.targetPosition
                }
            case "positionChange":
                if let posChange = event.data as? PlannedPositionChange, isOnField {
                    currentPosition = posChange.toPosition
                }
            default:
                break
            }
        }
        
        return isOnField ? currentPosition : nil
    }
    
    // Same helper functions as before
    private func calculatePlayersOnField(atMinute minute: Int) -> [Player] {
        var currentFieldPlayers = Set<UUID>()
        for position in lineupPositions {
            if let playerId = position.playerId {
                currentFieldPlayers.insert(playerId)
            }
        }
        
        let relevantSubs = game.plannedSubstitutions
            .filter { $0.plannedMinute <= minute }
            .sorted { $0.plannedMinute < $1.plannedMinute }
        
        for sub in relevantSubs {
            currentFieldPlayers.remove(sub.playerOut)
            currentFieldPlayers.insert(sub.playerIn)
        }
        
        return currentFieldPlayers.compactMap { playerId in
            team.players.first { $0.id == playerId }
        }.sorted { $0.name < $1.name }
    }
    
    private func calculatePlayersOnBench(atMinute minute: Int) -> [Player] {
        let playersOnField = Set(calculatePlayersOnField(atMinute: minute).map { $0.id })
        
        return team.players.filter { player in
            !playersOnField.contains(player.id)
        }.sorted { $0.name < $1.name }
    }
}

// MARK: - Compact Multi Select Player Card (NEW)
struct CompactMultiSelectPlayerCard: View {
    let player: Player
    let isSelected: Bool
    let color: Color
    let index: Int?
    let currentPosition: Position?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Selection indicator with number - smaller
                ZStack {
                    Circle()
                        .fill(isSelected ? color : Color.gray.opacity(0.3))
                        .frame(width: 18, height: 18)
                    
                    if let index = index {
                        Text("\(index + 1)")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.white)
                    } else if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }
                
                // Player info - compact
                HStack(spacing: 4) {
                    Text("#\(player.jerseyNumber)")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.secondary)
                        .frame(width: 25, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(player.name.components(separatedBy: " ").first ?? "")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.primary)
                        
                        if let position = currentPosition {
                            Text(position.abbreviation)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("BENCH")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Full Rotation Planner
struct FullRotationPlanner: View {
    let team: Team
    @Binding var game: Game
    let lineupPositions: [LineupPosition]
    
    var body: some View {
        VStack(spacing: 16) {
            if game.lineupPhases.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No rotation phases planned")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Perfect for youth soccer - plan complete lineup changes at specific times")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            
            Spacer()
            
            Text("Full rotation planning coming soon!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

// MARK: - Planned Substitution Row
struct PlannedSubstitutionRow: View {
    let plannedSub: PlannedSubstitution
    let team: Team
    let onDelete: () -> Void
    
    var playerOut: Player? {
        team.players.first { $0.id == plannedSub.playerOut }
    }
    
    var playerIn: Player? {
        team.players.first { $0.id == plannedSub.playerIn }
    }
    
    var body: some View {
        HStack {
            // Time
            Text("\(plannedSub.plannedMinute)'")
                .font(.headline)
                .bold()
                .foregroundColor(.blue)
                .frame(width: 40)
            
            // Players
            HStack(spacing: 8) {
                if let playerOut = playerOut {
                    PlayerSubChip(player: playerOut, color: .red, label: "OUT")
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                if let playerIn = playerIn {
                    PlayerSubChip(player: playerIn, color: .green, label: "IN")
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(plannedSub.reason.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Player Sub Chip
struct PlayerSubChip: View {
    let player: Player
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("\(player.jerseyNumber)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                    )
                
                Text(player.name.components(separatedBy: " ").first ?? "")
                    .font(.subheadline)
                    .bold()
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(color)
                .bold()
        }
    }
}

struct AddSubstitutionView: View {
    let team: Team
    @Binding var game: Game
    let lineupPositions: [LineupPosition]
    let onSubstitutionAdded: () -> Void
    let initialMinute: Int  // NEW
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPlayerOut: Player?
    @State private var selectedPlayerIn: Player?
    @State private var selectedMinute: Int
    @State private var selectedReason: SubstitutionReason = .tactical
    
    // NEW: Custom init to set initial minute
    init(team: Team, game: Binding<Game>, lineupPositions: [LineupPosition], onSubstitutionAdded: @escaping () -> Void, initialMinute: Int = 0) {
        self.team = team
        self._game = game
        self.lineupPositions = lineupPositions
        self.onSubstitutionAdded = onSubstitutionAdded
        self.initialMinute = initialMinute
        self._selectedMinute = State(initialValue: initialMinute)
    }
    
    // MARK: - Smart Player Lists Based on Time
    var playersOnFieldAtSelectedTime: [Player] {
        calculatePlayersOnField(atMinute: selectedMinute)
    }
    
    var playersOnBenchAtSelectedTime: [Player] {
        calculatePlayersOnBench(atMinute: selectedMinute)
    }
    
    private var subGroupIndex: Int {
        // Simply get the next available group index
        let existingGroupIndices = game.plannedSubstitutions.compactMap { $0.subGroupIndex }
        if existingGroupIndices.isEmpty {
            return 1
        }
        return (existingGroupIndices.max() ?? 0) + 1
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("When") {
                    Stepper("Minute: \(selectedMinute)", value: $selectedMinute, in: 0...90)
                        .onChange(of: selectedMinute) { _ in
                            // Reset selections when time changes
                            selectedPlayerOut = nil
                            selectedPlayerIn = nil
                        }
                    
                    HStack {
                        Text("Sub Group:")
                        Spacer()
                        Text("Sub \(subGroupIndex)")
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
                
                Section("Substitution") {
                    Picker("Player Coming Off", selection: $selectedPlayerOut) {
                        Text("Select Player").tag(nil as Player?)
                        ForEach(playersOnFieldAtSelectedTime) { player in
                            Text("\(player.name) (#\(player.jerseyNumber))").tag(player as Player?)
                        }
                    }
                    
                    Picker("Player Coming On", selection: $selectedPlayerIn) {
                        Text("Select Player").tag(nil as Player?)
                        ForEach(playersOnBenchAtSelectedTime) { player in
                            Text("\(player.name) (#\(player.jerseyNumber))").tag(player as Player?)
                        }
                    }
                    
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(SubstitutionReason.allCases, id: \.self) { reason in
                            Text(reason.rawValue).tag(reason)
                        }
                    }
                }
                
                if selectedMinute > 1 {
                    Section("Field Status at \(selectedMinute) Minutes") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("On Field (\(playersOnFieldAtSelectedTime.count))")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            ForEach(playersOnFieldAtSelectedTime.prefix(5)) { player in
                                Text("\(player.name) (#\(player.jerseyNumber))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if playersOnFieldAtSelectedTime.count > 5 {
                                Text("... and \(playersOnFieldAtSelectedTime.count - 5) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            Text("On Bench (\(playersOnBenchAtSelectedTime.count))")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            ForEach(playersOnBenchAtSelectedTime.prefix(5)) { player in
                                Text("\(player.name) (#\(player.jerseyNumber))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if playersOnBenchAtSelectedTime.count > 5 {
                                Text("... and \(playersOnBenchAtSelectedTime.count - 5) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Substitution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addSubstitution()
                        onSubstitutionAdded()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(selectedPlayerOut == nil || selectedPlayerIn == nil)
                }
            }
        }
    }
    
    // MARK: - Smart Logic Functions
    private func calculatePlayersOnField(atMinute minute: Int) -> [Player] {
        // Start with initial lineup
        var currentFieldPlayers = Set<UUID>()
        for position in lineupPositions {
            if let playerId = position.playerId {
                currentFieldPlayers.insert(playerId)
            }
        }
        
        // Apply all substitutions that happen before the selected minute
        let relevantSubs = game.plannedSubstitutions
            .filter { $0.plannedMinute <= minute }
            .sorted { $0.plannedMinute < $1.plannedMinute }
        
        for sub in relevantSubs {
            // Remove player going out
            currentFieldPlayers.remove(sub.playerOut)
            // Add player coming in
            currentFieldPlayers.insert(sub.playerIn)
        }
        
        // Convert UUIDs back to Player objects
        return currentFieldPlayers.compactMap { playerId in
            team.players.first { $0.id == playerId }
        }.sorted { $0.name < $1.name }
    }
    
    private func calculatePlayersOnBench(atMinute minute: Int) -> [Player] {
        let playersOnField = Set(calculatePlayersOnField(atMinute: minute).map { $0.id })
        
        return team.players.filter { player in
            !playersOnField.contains(player.id)
        }.sorted { $0.name < $1.name }
    }
    
    private func addSubstitution() {
        guard let playerOut = selectedPlayerOut,
              let playerIn = selectedPlayerIn else { return }
        
        // Find the position that playerOut currently occupies
        guard let currentPosition = getCurrentPosition(for: playerOut, atMinute: selectedMinute) else {
            print("Could not determine position for player being substituted out")
            return
        }
        
        var plannedSub = PlannedSubstitution(
            playerOut: playerOut.id,
            playerIn: playerIn.id,
            plannedMinute: selectedMinute,
            reason: selectedReason,
            targetPosition: currentPosition  // CAPTURE THE POSITION
        )
        
        plannedSub.subGroupIndex = subGroupIndex
        game.plannedSubstitutions.append(plannedSub)
    }
    
    private func getCurrentPosition(for player: Player, atMinute minute: Int) -> Position? {
        // Get all events before this minute, sorted chronologically
        let relevantSubs = game.plannedSubstitutions
            .filter { $0.plannedMinute <= minute }
            .sorted { $0.plannedMinute < $1.plannedMinute }
        
        let relevantPositionChanges = game.plannedPositionChanges
            .filter { $0.plannedMinute < minute && $0.playerId == player.id }
            .sorted { $0.plannedMinute < $1.plannedMinute }
        
        // Track player's status through all events chronologically
        var isOnField = false
        var currentPosition: Position? = nil
        
        // First check if player is in starting lineup
        if let startingPosition = lineupPositions.first(where: { $0.playerId == player.id }) {
            isOnField = true
            currentPosition = startingPosition.position
        }
        
        // Create a combined timeline of all events
        var allEvents: [(minute: Int, type: String, data: Any)] = []
        
        // Add substitutions to timeline
        for sub in relevantSubs {
            if sub.playerOut == player.id {
                allEvents.append((minute: sub.plannedMinute, type: "subOut", data: sub))
            } else if sub.playerIn == player.id {
                allEvents.append((minute: sub.plannedMinute, type: "subIn", data: sub))
            }
        }
        
        // Add position changes to timeline
        for posChange in relevantPositionChanges {
            allEvents.append((minute: posChange.plannedMinute, type: "positionChange", data: posChange))
        }
        
        // Sort all events chronologically
        allEvents.sort { $0.minute < $1.minute }
        
        // Apply events in chronological order
        for event in allEvents {
            switch event.type {
            case "subOut":
                if let sub = event.data as? PlannedSubstitution, sub.playerOut == player.id {
                    isOnField = false
                    currentPosition = nil
                }
            case "subIn":
                if let sub = event.data as? PlannedSubstitution, sub.playerIn == player.id {
                    isOnField = true
                    currentPosition = sub.targetPosition
                }
            case "positionChange":
                if let posChange = event.data as? PlannedPositionChange, isOnField {
                    currentPosition = posChange.toPosition
                }
            default:
                break
            }
        }
        
        return isOnField ? currentPosition : nil
    }
}
// MARK: - Print-Optimized SubstitutionPlanShareView (Two-Column Layout)
struct SubstitutionPlanShareView: View {
    let game: Game
    let team: Team
    let lineupPositions: [LineupPosition]
    let groupedSubstitutions: [(groupIndex: Int, groupName: String, substitutions: [PlannedSubstitution])]
    
    private var halfLength: Int {
        team.defaultHalfLength
    }
    
    // Split groups into first half and second half
    private var firstHalfGroups: [(groupIndex: Int, groupName: String, substitutions: [PlannedSubstitution])] {
        groupedSubstitutions.compactMap { group in
            let firstHalfSubs = group.substitutions.filter { $0.plannedMinute < halfLength }
            if firstHalfSubs.isEmpty { return nil }
            return (groupIndex: group.groupIndex, groupName: group.groupName, substitutions: firstHalfSubs)
        }
    }
    
    private var secondHalfGroups: [(groupIndex: Int, groupName: String, substitutions: [PlannedSubstitution])] {
        groupedSubstitutions.compactMap { group in
            let secondHalfSubs = group.substitutions.filter { $0.plannedMinute >= halfLength }
            if secondHalfSubs.isEmpty { return nil }
            return (groupIndex: group.groupIndex, groupName: group.groupName, substitutions: secondHalfSubs)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 6) {
                Text("SUBSTITUTION PLAN")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    Text(team.name)
                        .fontWeight(.semibold)
                    Text("vs")
                        .foregroundColor(.secondary)
                    Text(game.opponent)
                        .fontWeight(.semibold)
                }
                .font(.headline)
                
                Text(game.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)
            
            // Two-column layout
            HStack(alignment: .top, spacing: 24) {
                // First Half
                VStack(alignment: .leading, spacing: 0) {
                    // Column header
                    Text("FIRST HALF (0-\(halfLength)')")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.15))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Starters section
                        startersSection
                        
                        // Substitution Groups
                        if firstHalfGroups.isEmpty {
                            Text("No subs planned")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        } else {
                            ForEach(firstHalfGroups, id: \.groupIndex) { group in
                                substitutionGroupView(group: group)
                            }
                        }
                    }
                    .padding(12)
                    
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                
                // Second Half
                VStack(alignment: .leading, spacing: 0) {
                    // Column header
                    Text("SECOND HALF (\(halfLength)'+)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.15))
                    
                    // Groups
                    if secondHalfGroups.isEmpty {
                        Text("No subs planned")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(secondHalfGroups, id: \.groupIndex) { group in
                                substitutionGroupView(group: group)
                            }
                        }
                        .padding(12)
                    }
                    
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }

            // Position Changes (if any) - compact
            if !game.plannedPositionChanges.isEmpty {
                positionChangesSection
            }

            // Footer
            HStack {
                Text("Generated by Coach Caddie")
                Spacer()
                Text(Date().formatted(.dateTime.month().day().hour().minute()))
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color.white)
    }
    
    // MARK: - Starters Section
    private var startersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Starters")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .cornerRadius(4)
            
            // Show starting players with positions
            ForEach(sortedStarters, id: \.player.id) { starter in
                HStack(spacing: 4) {
                    Text("#\(starter.player.jerseyNumber)")
                        .fontWeight(.bold)
                    Text(starter.player.name.components(separatedBy: " ").first ?? "")
                    Text("(\(starter.position.abbreviation))")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                .padding(.leading, 8)
            }
        }
    }

    // Helper to get sorted starters
    private var sortedStarters: [(player: Player, position: Position)] {
        var result: [(player: Player, position: Position)] = []
        
        for lineupPosition in lineupPositions {
            guard let playerId = lineupPosition.playerId,
                  let player = team.players.first(where: { $0.id == playerId }) else {
                continue
            }
            result.append((player: player, position: lineupPosition.position))
        }
        
        return result.sorted(by: { positionSortOrder($0.position) < positionSortOrder($1.position) })
    }

    // Helper to define position sort order (GK first, then DEF, MID, FWD)
    private func positionSortOrder(_ position: Position) -> Int {
        let abbr = position.abbreviation.uppercased()
        if abbr.contains("GK") { return 0 }
        if abbr.contains("DEF") || abbr.contains("CB") || abbr.contains("LB") || abbr.contains("RB") { return 1 }
        if abbr.contains("MID") || abbr.contains("CM") || abbr.contains("LM") || abbr.contains("RM") || abbr.contains("DM") || abbr.contains("AM") { return 2 }
        if abbr.contains("FWD") || abbr.contains("ST") || abbr.contains("LW") || abbr.contains("RW") || abbr.contains("CF") { return 3 }
        return 4
    }
    
    // MARK: - Substitution Group View
    private func substitutionGroupView(group: (groupIndex: Int, groupName: String, substitutions: [PlannedSubstitution])) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Group header with minute
            let firstMinute = group.substitutions.map { $0.plannedMinute }.min() ?? 0
            HStack {
                Text(group.groupName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("(\(firstMinute)')")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(4)
            
            // Substitutions in this group
            ForEach(group.substitutions) { sub in
                substitutionRow(sub: sub)
            }
        }
    }
    
    // MARK: - Single Substitution Row
    private func substitutionRow(sub: PlannedSubstitution) -> some View {
        HStack(spacing: 4) {
            // Player In (coming on)
            if let playerIn = team.players.first(where: { $0.id == sub.playerIn }) {
                Text("#\(playerIn.jerseyNumber)")
                    .fontWeight(.bold)
                Text(playerIn.name.components(separatedBy: " ").first ?? "")
            }
            
            Text("→")
                .foregroundColor(.blue)
            
            // Player Out (going off)
            if let playerOut = team.players.first(where: { $0.id == sub.playerOut }) {
                Text("#\(playerOut.jerseyNumber)")
                    .fontWeight(.bold)
                Text(playerOut.name.components(separatedBy: " ").first ?? "")
            }
            
            Text("(\(sub.targetPosition.abbreviation))")
                .foregroundColor(.secondary)
        }
        .font(.subheadline)
        .padding(.leading, 8)
    }
    
    // MARK: - Position Changes Section (compact)
    private var positionChangesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("POSITION CHANGES")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(4)
            
            // Compact horizontal list
            let changes = game.plannedPositionChanges.sorted { $0.plannedMinute < $1.plannedMinute }
            
            SubstitutionFlowLayout(spacing: 8) {
                ForEach(changes) { change in
                    if let player = team.players.first(where: { $0.id == change.playerId }) {
                        Text("\(change.plannedMinute)': #\(player.jerseyNumber) \(player.name.components(separatedBy: " ").first ?? "") \(change.fromPosition.abbreviation)→\(change.toPosition.abbreviation)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Simple Flow Layout for Position Changes
struct SubstitutionFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Simple Timeline Event structure
struct TimelineEvent {
    let minute: Int
    var substitutions: [PlannedSubstitution]
    var positionChanges: [PlannedPositionChange]
}

// MARK: - Simple Substitution Row (for share sheet)
struct SimpleSubstitutionRow: View {
    let substitution: PlannedSubstitution
    let team: Team
    
    var playerOut: Player? {
        team.players.first { $0.id == substitution.playerOut }
    }
    
    var playerIn: Player? {
        team.players.first { $0.id == substitution.playerIn }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text("SUB:")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            if let playerOut = playerOut {
                Text("#\(playerOut.jerseyNumber) \(playerOut.name.components(separatedBy: " ").first ?? "")")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundColor(.blue)
            
            if let playerIn = playerIn {
                Text("#\(playerIn.jerseyNumber) \(playerIn.name.components(separatedBy: " ").first ?? "")")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Text("(\(substitution.targetPosition.abbreviation))")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(substitution.reason.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(4)
    }
}

// MARK: - Simple Position Change Row (for share sheet)
struct SimplePositionChangeRow: View {
    let positionChange: PlannedPositionChange
    let team: Team
    
    var player: Player? {
        team.players.first { $0.id == positionChange.playerId }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text("POS:")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            if let player = player {
                Text("#\(player.jerseyNumber) \(player.name.components(separatedBy: " ").first ?? "")")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            
            Text(positionChange.fromPosition.abbreviation)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.red.opacity(0.1))
                .cornerRadius(3)
            
            Image(systemName: "arrow.triangle.swap")
                .font(.caption2)
                .foregroundColor(.purple)
            
            Text(positionChange.toPosition.abbreviation)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.green.opacity(0.1))
                .cornerRadius(3)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(4)
    }
}

// MARK: - Modern Formation Button
struct ModernFormationButton: View {
    let formation: Formation
    let isSelected: Bool
    let playerCount: Int
    let totalPositions: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(formation.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text("\(playerCount)/\(totalPositions)")
                        .font(.caption)
                }
                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Modern Game Selector Button
struct ModernGameSelectorButton: View {
    let selectedGame: Game?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 16))
                
                if let game = selectedGame {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("vs \(game.opponent)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(game.date, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Select Game")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(selectedGame != nil ? .primary : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

// MARK: - Modern Game Selector View (UPDATED)
struct ModernGameSelectorView: View {
    let teamId: UUID
    @Binding var selectedGame: Game?
    @Binding var showingCreateGame: Bool
    @EnvironmentObject var teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    
    // CRITICAL: Get team directly from teamManager to ensure fresh data
    private var team: Team {
        teamManager.teams.first(where: { $0.id == teamId }) ?? Team(name: "Unknown", format: .elevenVEleven)
    }
    
    // Get current date at start of day for comparison
    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    // Upcoming Games: Today or later AND unscored
    var upcomingGames: [Game] {
        team.games.filter { game in
            let gameStart = Calendar.current.startOfDay(for: game.date)
            return gameStart >= todayStart && game.result == nil
        }.sorted { $0.date < $1.date }
    }
    
    // Completed Games: Any game with a score OR dated before today
    var completedGames: [Game] {
        team.games.filter { game in
            let gameStart = Calendar.current.startOfDay(for: game.date)
            return game.result != nil || gameStart < todayStart
        }.sorted { $0.date > $1.date } // Most recent first
    }
    
    var body: some View {
        NavigationView {
            List {
                // Upcoming Games Section
                if !upcomingGames.isEmpty {
                    Section("Upcoming Games") {
                        ForEach(upcomingGames) { game in
                            UpcomingGameRowView(game: game) {
                                selectedGame = game
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }
                
                // Completed Games Section
                if !completedGames.isEmpty {
                    Section("Completed Games") {
                        ForEach(completedGames) { game in
                            CompletedGameRowView(game: game) {
                                selectedGame = game
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }
                
                // Create New Game Section
                Section {
                    Button(action: {
                        showingCreateGame = true
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Label("Schedule New Game", systemImage: "plus.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Select Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Upcoming Game Row View (NEW)
struct UpcomingGameRowView: View {
    let game: Game
    let action: () -> Void
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(game.date)
    }
    
    private var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(game.date)
    }
    
    private var relativeDateText: String {
        if isToday {
            return "Today"
        } else if isTomorrow {
            return "Tomorrow"
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: game.date, relativeTo: Date())
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("vs \(game.opponent)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        // Relative date (Today, Tomorrow, etc.)
                        Text(relativeDateText)
                            .font(.subheadline)
                            .foregroundColor(isToday ? .orange : .blue)
                            .fontWeight(isToday ? .semibold : .medium)
                        
                        // Time
                        Text(game.date.formatted(.dateTime.hour().minute()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Location indicator
                    HStack(spacing: 4) {
                        Image(systemName: game.isHome ? "house.fill" : "airplane")
                            .font(.caption)
                            .foregroundColor(game.isHome ? .green : .orange)
                        
                        Text(game.isHome ? "Home" : "Away")
                            .font(.caption)
                            .foregroundColor(game.isHome ? .green : .orange)
                            .fontWeight(.medium)
                        
                        if let location = game.location {
                            Text(" - \(location)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Status indicator
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("Scheduled")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    
                    // Full date for reference
                    Text(game.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Completed Game Row View (NEW)
struct CompletedGameRowView: View {
    let game: Game
    let action: () -> Void
    
    private var gameResult: (text: String, color: Color) {
        guard let result = game.result else {
            // Game is in the past but no score recorded
            return ("Not Played", .gray)
        }
        
        if result.goalsFor > result.goalsAgainst {
            return ("Won \(result.goalsFor)-\(result.goalsAgainst)", .green)
        } else if result.goalsFor < result.goalsAgainst {
            return ("Lost \(result.goalsFor)-\(result.goalsAgainst)", .red)
        } else {
            return ("Draw \(result.goalsFor)-\(result.goalsAgainst)", .orange)
        }
    }
    
    private var timeSinceGame: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: game.date, relativeTo: Date())
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("vs \(game.opponent)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        // Time since game
                        Text(timeSinceGame)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Date
                        Text(game.date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Location indicator
                    HStack(spacing: 4) {
                        Image(systemName: game.isHome ? "house.fill" : "airplane")
                            .font(.caption)
                            .foregroundColor(game.isHome ? .green : .orange)
                        
                        Text(game.isHome ? "Home" : "Away")
                            .font(.caption)
                            .foregroundColor(game.isHome ? .green : .orange)
                            .fontWeight(.medium)
                        
                        if let location = game.location {
                            Text(" - \(location)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Result
                    if let result = game.result {
                        HStack(spacing: 8) {
                            Text("\(result.goalsFor)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(gameResult.color)
                            
                            Text("-")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            Text("\(result.goalsAgainst)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(gameResult.color)
                        }
                        
                        Text(gameResult.text.components(separatedBy: " ").first ?? "")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(gameResult.color)
                    } else {
                        // Past game with no score
                        VStack(alignment: .trailing) {
                            Text("No Score")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("Recorded")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Game Row View
struct GameRowView: View {
    let game: Game
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("vs \(game.opponent)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(game.date.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(game.isHome ? "Home" : "Away")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(game.isHome ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                if let result = game.result {
                    VStack(alignment: .trailing) {
                        Text("\(result.goalsFor) - \(result.goalsAgainst)")
                            .font(.title2)
                            .bold()
                        Text(result.goalsFor > result.goalsAgainst ? "Win" : result.goalsFor < result.goalsAgainst ? "Loss" : "Draw")
                            .font(.caption)
                            .foregroundColor(result.goalsFor > result.goalsAgainst ? .green : result.goalsFor < result.goalsAgainst ? .red : .orange)
                    }
                } else {
                    Text("Scheduled")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Lineup Instructions View
struct LineupInstructionsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to Build Your Lineup")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        InstructionStep(
                            number: 1,
                            title: "Select Formation",
                            description: "Choose your team's formation from the available options. Each formation shows how many players are currently assigned."
                        )
                        
                        InstructionStep(
                            number: 2,
                            title: "Assign Players",
                            description: "Tap a player from the available list, then tap a position on the field to assign them. Or tap an assigned position to remove a player."
                        )
                        
                        InstructionStep(
                            number: 3,
                            title: "Select Game",
                            description: "Choose a scheduled game to save your lineup for that specific match."
                        )
                        
                        InstructionStep(
                            number: 4,
                            title: "Start Game Mode",
                            description: "Once you have a game selected and lineup ready, start game mode to track live events, substitutions, and statistics."
                        )
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TipView(text: "Lineups are automatically saved for each team")
                            TipView(text: "Players are color-coded by their preferred position")
                            TipView(text: "Use the clear button to quickly remove all players")
                            TipView(text: "Game mode allows real-time event tracking")
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Lineup Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .bold()
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TipView: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Edit Timer View
struct EditTimerView: View {
    let currentMinute: Int
    let currentSecond: Int
    let onSave: (Int, Int) -> Void
    
    @State private var minute: Int
    @State private var second: Int
    @Environment(\.presentationMode) var presentationMode
    
    init(currentMinute: Int, currentSecond: Int, onSave: @escaping (Int, Int) -> Void) {
        self.currentMinute = currentMinute
        self.currentSecond = currentSecond
        self.onSave = onSave
        self._minute = State(initialValue: currentMinute)
        self._second = State(initialValue: currentSecond)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Edit Game Timer")
                    .font(.title2)
                    .bold()
                
                VStack(spacing: 20) {
                    HStack {
                        VStack {
                            Text("Minutes")
                                .font(.headline)
                            Picker("Minutes", selection: $minute) {
                                ForEach(0...120, id: \.self) { min in
                                    Text("\(min)").tag(min)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 100)
                        }
                        
                        Text(":")
                            .font(.title)
                            .bold()
                        
                        VStack {
                            Text("Seconds")
                                .font(.headline)
                            Picker("Seconds", selection: $second) {
                                ForEach(0...59, id: \.self) { sec in
                                    Text(String(format: "%02d", sec)).tag(sec)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 100)
                        }
                    }
                }
                
                Text("Current: \(String(format: "%d:%02d", currentMinute, currentSecond))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(minute, second)
                    }
                }
            }
        }
    }
}
// MARK: - Modern Lineup Builder (FIXED GeometryReader height)
struct ModernLineupBuilder: View {
    @Binding var team: Team
    let selectedFormation: Formation
    @Binding var lineupPositions: [LineupPosition]
    @Binding var selectedPlayer: Player?
    @Binding var selectedPositionIndex: Int?
    let availableHeight: CGFloat
    let hideAvailablePlayersHeader: Bool
    @EnvironmentObject var teamManager: TeamManager

    /// Players eligible for the lineup: those in the active season's roster.
    /// Falls back to the full squad if no season is selected or the season has no roster entries.
    private var activeSeasonPlayers: [Player] {
        guard let activeSeasonId = team.activeSeasonId,
              let activeSeason = team.seasons.first(where: { $0.id == activeSeasonId }),
              !activeSeason.activePlayerIds.isEmpty else {
            return team.players
        }
        let activeIds = Set(activeSeason.activePlayerIds)
        return team.players.filter { activeIds.contains($0.id) }
    }

    var unassignedPlayers: [Player] {
        let unsorted = activeSeasonPlayers.filter { player in
            !lineupPositions.contains { $0.playerId == player.id }
        }
        
        // Apply sorting based on app settings
        switch teamManager.appSettings.defaultSortOrder {
        case .byName:
            return unsorted.sorted { $0.name < $1.name }
        case .byNumber:
            return unsorted.sorted { $0.jerseyNumber < $1.jerseyNumber }
        case .byPosition:
            return unsorted.sorted {
                if $0.preferredPosition != $1.preferredPosition {
                    return $0.preferredPosition < $1.preferredPosition
                } else {
                    return $0.name < $1.name
                }
            }
        }
    }
    
    var assignedPlayers: [(Int, LineupPosition, Player)] {
        lineupPositions.enumerated().compactMap { index, position in
            if let playerId = position.playerId,
               let player = team.players.first(where: { $0.id == playerId }) {
                return (index, position, player)
            }
            return nil
        }
    }
    
    // UPDATED: Dynamic field sizing based on formation complexity
    private var idealFieldHeight: CGFloat {
        let baseHeight: CGFloat = 280
        let playerCount = selectedFormation.positions.count
        let densityMultiplier = playerCount >= 11 ? 1.2 : playerCount >= 9 ? 1.1 : 1.0
        return baseHeight * densityMultiplier
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Soccer Field - UPDATED with responsive sizing
            GeometryReader { geometry in
                let fieldSize = CGSize(
                    width: min(geometry.size.width * 0.95, 400), // Cap max width, more margin
                    height: idealFieldHeight
                )
                
                VStack {
                    ModernSoccerFieldView(
                        formation: selectedFormation,
                        lineupPositions: lineupPositions,
                        selectedPlayer: selectedPlayer,
                        selectedPositionIndex: selectedPositionIndex,
                        hoveredPositionIndex: nil,
                        team: team,
                        onPositionTapped: { index in
                            handlePositionTap(at: index)
                        }
                    )
                    .frame(width: fieldSize.width, height: fieldSize.height)
                    .padding(.horizontal, 10) // More padding
                    
                    Spacer()
                }
            }
            .frame(height: idealFieldHeight + 40) // UPDATED: Dynamic height with buffer
            
            // Player Lists
            ScrollView {
                VStack(spacing: 20) {
                    // Available Players
                    if !unassignedPlayers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            if !hideAvailablePlayersHeader {
                                HStack {
                                    Text("Available Players")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(unassignedPlayers.count)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(unassignedPlayers) { player in
                                        ModernPlayerCard(
                                            player: player,
                                            isSelected: selectedPlayer?.id == player.id,
                                            team: team,
                                            onTap: {
                                                handlePlayerSelection(player)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Assigned Players
                    if !assignedPlayers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("On Field")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(assignedPlayers.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(assignedPlayers, id: \.0) { index, position, player in
                                    ModernAssignedPlayerRow(
                                        player: player,
                                        position: position.position,
                                        onRemove: {
                                            removePlayerFromPosition(at: index)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Color.clear.frame(height: 100)
                }
            }
        }
    }
    
    private func handlePlayerSelection(_ player: Player) {
        if selectedPlayer?.id == player.id {
            selectedPlayer = nil
        } else {
            selectedPlayer = player
            selectedPositionIndex = nil
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handlePositionTap(at index: Int) {
        if let player = selectedPlayer {
            assignPlayerToPosition(player, at: index)
        } else if lineupPositions[index].playerId != nil {
            removePlayerFromPosition(at: index)
        } else {
            selectedPositionIndex = index
        }
    }
    
    private func assignPlayerToPosition(_ player: Player, at index: Int) {
        for i in 0..<lineupPositions.count {
            if lineupPositions[i].playerId == player.id {
                lineupPositions[i].playerId = nil
            }
        }
        
        lineupPositions[index].playerId = player.id
        
        selectedPlayer = nil
        selectedPositionIndex = nil
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func removePlayerFromPosition(at index: Int) {
        lineupPositions[index].playerId = nil
        selectedPositionIndex = nil
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}
// MARK: - Modern Player Card
struct ModernPlayerCard: View {
    let player: Player
    let isSelected: Bool
    let team: Team
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(team.primaryColor)
                        .frame(width: 42, height: 42)
                    
                    Text(String(player.jerseyNumber))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 2) {
                    Text(player.name.components(separatedBy: " ").first ?? "")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(player.positions.joined(separator: "/"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 80)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? team.primaryColor.opacity(0.15) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? team.primaryColor : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Modern Assigned Player Row
struct ModernAssignedPlayerRow: View {
    let player: Player
    let position: Position
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(position.color)
                    .frame(width: 40, height: 40)
                
                Text(String(player.jerseyNumber))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(position.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Modern Soccer Field View
struct ModernSoccerFieldView: View {
    let formation: Formation
    let lineupPositions: [LineupPosition]
    let selectedPlayer: Player?
    let selectedPositionIndex: Int?
    let hoveredPositionIndex: Int?
    let team: Team
    let onPositionTapped: (Int) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ModernSoccerFieldBackground()
                
                ForEach(Array(lineupPositions.enumerated()), id: \.offset) { index, position in
                    let defaultPos = formation.fieldPositions(for: geometry.size)[index]
                    
                    ModernPositionMarker(
                        position: position,
                        isSelected: selectedPositionIndex == index,
                        isHovered: hoveredPositionIndex == index,
                        hasSelectedPlayer: selectedPlayer != nil,
                        team: team,
                        isInCrowdedLine: isInCrowdedLine(positionIndex: index)
                    )
                    .position(defaultPos)
                    .onTapGesture {
                        onPositionTapped(index)
                    }
                }
            }
        }
    }
    
    private func isInCrowdedLine(positionIndex: Int, threshold: Int = 4) -> Bool {
        let fieldPositions = formation.fieldPositions(for: CGSize(width: 300, height: 400))
        let currentY = fieldPositions[positionIndex].y
        
        let sameLinePositions = lineupPositions.enumerated().filter { index, _ in
            let posY = fieldPositions[index].y
            return abs(posY - currentY) <= 20
        }
        
        return sameLinePositions.count >= threshold
    }
}

// MARK: - Modern Soccer Field Background
struct ModernSoccerFieldBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 0.15, green: 0.55, blue: 0.15), location: 0),
                                .init(color: Color(red: 0.18, green: 0.60, blue: 0.18), location: 0.5),
                                .init(color: Color(red: 0.15, green: 0.55, blue: 0.15), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                    )
                
                ModernFieldLines()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white, lineWidth: 3)
            )
        }
    }
}

// MARK: - Modern Field Lines
struct ModernFieldLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        
        path.addEllipse(in: CGRect(
            x: rect.midX - 50,
            y: rect.midY - 50,
            width: 100,
            height: 100
        ))
        
        let penaltyWidth: CGFloat = 70
        let penaltyHeight: CGFloat = 140
        path.addRoundedRect(
            in: CGRect(
                x: 0,
                y: rect.midY - penaltyHeight/2,
                width: penaltyWidth,
                height: penaltyHeight
            ),
            cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: 5, topTrailing: 5)
        )
        
        path.addRoundedRect(
            in: CGRect(
                x: rect.maxX - penaltyWidth,
                y: rect.midY - penaltyHeight/2,
                width: penaltyWidth,
                height: penaltyHeight
            ),
            cornerRadii: RectangleCornerRadii(topLeading: 5, bottomLeading: 5, bottomTrailing: 0, topTrailing: 0)
        )
        
        let goalWidth: CGFloat = 25
        let goalHeight: CGFloat = 70
        
        path.addRoundedRect(
            in: CGRect(
                x: 0,
                y: rect.midY - goalHeight/2,
                width: goalWidth,
                height: goalHeight
            ),
            cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: 3, topTrailing: 3)
        )
        
        path.addRoundedRect(
            in: CGRect(
                x: rect.maxX - goalWidth,
                y: rect.midY - goalHeight/2,
                width: goalWidth,
                height: goalHeight
            ),
            cornerRadii: RectangleCornerRadii(topLeading: 3, bottomLeading: 3, bottomTrailing: 0, topTrailing: 0)
        )
        
        return path
    }
}

// MARK: - Modern Position Marker
struct ModernPositionMarker: View {
    let position: LineupPosition
    let isSelected: Bool
    let isHovered: Bool
    let hasSelectedPlayer: Bool
    let team: Team
    let isInCrowdedLine: Bool
    
    private var player: Player? {
        guard let playerId = position.playerId else { return nil }
        return team.players.first { $0.id == playerId }
    }
    
    // UPDATED: Adaptive chip sizing based on screen size and density
    private var adaptiveChipSize: CGFloat {
        let baseSize: CGFloat = 40
        let screenWidth = UIScreen.main.bounds.width
        let screenFactor = min(screenWidth / 375, 1.15) // Scale for larger screens
        return baseSize * screenFactor
    }
    
    // UPDATED: Smart name display logic
    private var shouldShowPlayerName: Bool {
        // Always show names unless in very crowded formations
        let veryDenseFormations: [String] = ["5-4-1", "5-3-2", "3-5-2"]
        let formationString = position.position.rawValue
        return !veryDenseFormations.contains(formationString) || !isInCrowdedLine
    }
    
    var body: some View {
        ZStack {
            if isSelected || (hasSelectedPlayer && position.playerId == nil) {
                Circle()
                    .stroke(isSelected ? Color.yellow : Color.green, lineWidth: 3)
                    .frame(width: adaptiveChipSize + 12, height: adaptiveChipSize + 12)
                    .animation(.easeInOut(duration: 0.3), value: isSelected)
            }
            
            if let player = player {
                VStack(spacing: 2) {
                    ZStack {
                        Circle()
                            .fill(position.position.color)
                            .frame(width: adaptiveChipSize, height: adaptiveChipSize)
                        
                        VStack(spacing: 1) {
                            Text(String(player.jerseyNumber))
                                .font(.system(size: adaptiveChipSize * 0.33, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(position.position.abbreviation)
                                .font(.system(size: adaptiveChipSize * 0.16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    // UPDATED: Smart name positioning and display
                    if shouldShowPlayerName {
                        if isInCrowdedLine {
                            ZStack {
                                HStack {
                                    Text(player.name.components(separatedBy: " ").first ?? "")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(4)
                                        .offset(x: -35)
                                    
                                    Spacer()
                                }
                                .frame(width: 80)
                            }
                        } else {
                            Text(player.name.components(separatedBy: " ").first ?? "")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                        }
                    }
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: adaptiveChipSize, height: adaptiveChipSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        )
                    
                    Text(position.position.abbreviation)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
    }
}

struct ModernGameModeView: View {
    @Binding var team: Team
    @Binding var game: Game
    @Binding var lineupPositions: [LineupPosition]
    let selectedFormation: Formation
    @Binding var showingEditTimer: Bool
    @Binding var editedMinute: Int
    @Binding var editedSecond: Int
    let timerTick: Bool
    let onExitGameMode: () -> Void
    let onClearGameData: () -> Void
    let onEndGame: () -> Void
    
    @EnvironmentObject var gameStateManager: GameStateManager
    @EnvironmentObject var teamManager: TeamManager
    @State private var selectedPlayer: Player?
    @State private var selectedEventType: EventType = .goal
    @State private var showingAuditLog = false
    @State private var showingEndGameConfirmation = false
    @State private var showingClearGameConfirmation = false
    @State private var userRole: AccessLevel?
    @State private var canEditGame = false
    @State private var isSwapMode = false
    @State private var swapSourcePlayer: Player? = nil
    
    // UPDATED: Check if user has game editing permissions
    private var isReadOnlyUser: Bool {
        return userRole == .viewer || userRole == .parent
    }

    /// Players eligible for the bench: those in the active season's roster.
    /// Falls back to the full squad if no season is selected or the season has no roster entries.
    private var activeSeasonPlayers: [Player] {
        guard let activeSeasonId = team.activeSeasonId,
              let activeSeason = team.seasons.first(where: { $0.id == activeSeasonId }),
              !activeSeason.activePlayerIds.isEmpty else {
            return team.players
        }
        let activeIds = Set(activeSeason.activePlayerIds)
        return team.players.filter { activeIds.contains($0.id) }
    }
    
    var calculatedMinute: Int { gameStateManager.calculatedMinute }
    var calculatedSecond: Int { gameStateManager.calculatedSecond }
    
    var body: some View {
        VStack(spacing: 0) {
            // Game Header - UPDATED with reduced spacing
            ModernGameHeader(
                game: game,
                formattedTime: gameStateManager.formattedTime,
                isFirstHalf: gameStateManager.activeGameState?.isFirstHalf ?? true,
                isPaused: gameStateManager.activeGameState?.isPaused ?? false,
                timerTick: timerTick,
                onExit: onExitGameMode,
                onShowAuditLog: { showingAuditLog = true },
                onEditTimer: {
                    editedMinute = calculatedMinute
                    editedSecond = calculatedSecond
                    showingEditTimer = true
                },
                onClearGame: { showingClearGameConfirmation = true },
                isReadOnlyUser: isReadOnlyUser
            )
            
            // Timer Controls - UPDATED with reduced padding
            if !isReadOnlyUser {
                ModernTimerControls(
                    isPaused: gameStateManager.activeGameState?.isPaused ?? false,
                    isFirstHalf: gameStateManager.activeGameState?.isFirstHalf ?? true,
                    calculatedMinute: calculatedMinute,
                    halfLength: gameStateManager.activeGameState?.halfLength ?? 45,
                    onPause: pauseGame,
                    onResume: resumeGame,
                    onStartSecondHalf: startSecondHalf,
                    onEndGame: { showingEndGameConfirmation = true }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8) // REDUCED from default padding
            }
            
            // Event Recording Section - UPDATED with reduced spacing
            if !isReadOnlyUser {
                VStack(spacing: 8) { // REDUCED from 12
                    Text("Record Event")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Single row of 5 equally-sized buttons
                    HStack(spacing: 6) { // REDUCED from 8
                        ForEach([EventType.goal, EventType.assist, EventType.shot, EventType.save, EventType.goalAgainst], id: \.self) { eventType in
                            ModernEventTypeButton(
                                eventType: eventType,
                                isSelected: selectedEventType == eventType,
                                action: {
                                    selectedEventType = eventType
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8) // REDUCED from 12
            }
            
            // Action Bar - UPDATED with reduced padding
            if !isReadOnlyUser {
                ModernActionBar(
                    selectedPlayer: selectedPlayer,
                    selectedEventType: selectedEventType,
                    isSwapMode: isSwapMode,
                    swapSourcePlayer: swapSourcePlayer,
                    onRecord: recordEvent,
                    onCancel: { selectedPlayer = nil },
                    onSwapMode: enterSwapMode,
                    onCancelSwap: cancelSwapMode
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 6) // REDUCED from 8
            } else {
                // Show read-only message for viewers/parents
                HStack {
                    Image(systemName: userRole == .viewer ? "eye.fill" : "person.2.fill")
                        .foregroundColor(.secondary)
                    Text(userRole == .viewer ? "View Only Access" : "Parent View - Watch Only")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            
            // Field + Bench — shrinks into compact layout when Sub/Swap is active
            ScrollView {
                VStack(spacing: isSwapMode ? 8 : 12) {
                    ModernGameFieldView(
                        formation: selectedFormation,
                        lineupPositions: lineupPositions,
                        selectedPlayer: $selectedPlayer,
                        selectedEventType: selectedEventType,
                        team: team,
                        game: game,
                        isReadOnlyUser: isReadOnlyUser,
                        isSwapMode: isSwapMode,
                        swapSourcePlayerId: swapSourcePlayer?.id,
                        onSwapTap: handleSwapTap
                    )
                    .frame(height: isSwapMode ? 305 : 380)
                    .padding(.horizontal, 12)
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isSwapMode)

                    ModernBenchView(
                        benchPlayers: activeSeasonPlayers.filter { player in
                            !lineupPositions.contains { $0.playerId == player.id }
                        },
                        selectedPlayer: $selectedPlayer,
                        isReadOnlyUser: isReadOnlyUser,
                        isSwapMode: isSwapMode,
                        hasSwapSource: swapSourcePlayer != nil,
                        onSwapTap: handleSwapTap
                    )
                    .padding(.horizontal, 12)

                    Color.clear.frame(height: isSwapMode ? 8 : 30)
                }
            }
        }
        .onAppear {
            checkGamePermissions()
            syncGameStateOnAppear()
        }
        .sheet(isPresented: $showingAuditLog) {
            if let auditLog = gameStateManager.activeGameState?.auditLog {
                EnhancedGameAuditLogView(
                    auditLog: auditLog,
                    game: game,
                    team: team,
                    onAuditEntryEdit: { editedEntry in
                        if !isReadOnlyUser {
                            handleAuditEntryEdit(editedEntry)
                        }
                    },
                    onAuditEntryDelete: { entryId in
                        if !isReadOnlyUser {
                            handleAuditEntryDelete(entryId)
                        }
                    },
                    onAddNewEntry: { newEntry in
                        if !isReadOnlyUser {
                            handleAddNewAuditEntry(newEntry)
                        }
                    },
                    isReadOnlyUser: isReadOnlyUser
                )
            }
        }
        .sheet(isPresented: $showingEndGameConfirmation) {
            if !isReadOnlyUser {
                EnhancedEndGameView(
                    game: $game,
                    auditLog: gameStateManager.activeGameState?.auditLog ?? [],
                    team: team,
                    onConfirmEnd: onEndGame,
                    onAuditEntryEdit: { editedEntry in
                        handleAuditEntryEdit(editedEntry)
                    },
                    onAuditEntryDelete: { entryId in
                        handleAuditEntryDelete(entryId)
                    }
                )
            }
        }
        .alert("Clear All Game Data", isPresented: $showingClearGameConfirmation) {
            Button("Cancel", role: .cancel) { }
            if !isReadOnlyUser {
                Button("Clear All Data", role: .destructive) {
                    onClearGameData()
                }
            }
        } message: {
            Text("This will permanently clear all game data including lineup, events, stats, and scores. You'll return to lineup editing mode. This action cannot be undone.")
        }
    }
    
    // MARK: - Quick Swap Mode
    private func enterSwapMode() {
        isSwapMode = true
        swapSourcePlayer = nil
        selectedPlayer = nil
    }

    private func cancelSwapMode() {
        isSwapMode = false
        swapSourcePlayer = nil
    }

    private func handleSwapTap(_ tappedPlayer: Player) {
        guard isSwapMode else { return }

        if swapSourcePlayer == nil {
            // Only allow field players as the source
            let isOnField = lineupPositions.contains { $0.playerId == tappedPlayer.id }
            guard isOnField else { return }
            swapSourcePlayer = tappedPlayer
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else if swapSourcePlayer?.id == tappedPlayer.id {
            // Tapped the same player — deselect
            swapSourcePlayer = nil
        } else {
            let source = swapSourcePlayer!
            let isTargetOnField = lineupPositions.contains { $0.playerId == tappedPlayer.id }
            if isTargetOnField {
                executeQuickPositionSwap(player1: source, player2: tappedPlayer)
            } else {
                executeQuickSubstitution(playerOut: source, playerIn: tappedPlayer)
            }
            cancelSwapMode()
        }
    }

    private func executeQuickPositionSwap(player1: Player, player2: Player) {
        guard let idx1 = lineupPositions.firstIndex(where: { $0.playerId == player1.id }),
              let idx2 = lineupPositions.firstIndex(where: { $0.playerId == player2.id }) else { return }

        let pos1 = lineupPositions[idx1].position
        let pos2 = lineupPositions[idx2].position

        // Swap player IDs between their lineup slots (positions stay with slots)
        lineupPositions[idx1].playerId = player2.id
        lineupPositions[idx2].playerId = player1.id

        gameStateManager.addAuditEntry(
            eventType: .positionChange,
            gameTime: gameStateManager.auditLogTime,
            details: "SWAP: \(player1.name) (\(pos1.abbreviation)) ↔ \(player2.name) (\(pos2.abbreviation))"
        )

        gameStateManager.activeGameState?.lineupPositions = lineupPositions
        teamManager.updateTeam(team, activeGameId: game.id)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func executeQuickSubstitution(playerOut: Player, playerIn: Player) {
        guard let positionIndex = lineupPositions.firstIndex(where: { $0.playerId == playerOut.id }) else { return }

        lineupPositions[positionIndex].playerId = playerIn.id

        let substitution = Substitution(
            playerIn: playerIn.id,
            playerOut: playerOut.id,
            minute: gameStateManager.calculatedMinute,
            reason: .tactical
        )
        game.substitutions.append(substitution)

        gameStateManager.addAuditEntry(
            eventType: .substitution,
            gameTime: gameStateManager.auditLogTime,
            details: "\(playerOut.name) → \(playerIn.name) (Tactical)"
        )

        gameStateManager.activeGameState?.lineupPositions = lineupPositions
        teamManager.updateTeam(team, activeGameId: game.id)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Permission Check
    private func checkGamePermissions() {
        Task {
            userRole = await teamManager.getCurrentUserRole(for: team)
            canEditGame = userRole == .coach
        }
    }
    
    // NEW: Sync game state on appear to fix score display issue
    private func syncGameStateOnAppear() {
        // Restore game state from GameStateManager when view appears
        if let activeState = gameStateManager.activeGameState,
           activeState.gameId == game.id {
            
            // Restore the audit log
            game.auditLog = activeState.auditLog
            
            // Recalculate and restore the game result from audit log
            var goalsFor = 0
            var goalsAgainst = 0
            
            for entry in activeState.auditLog {
                switch entry.eventType {
                case .goal:
                    goalsFor += 1
                case .goalAgainst:
                    goalsAgainst += 1
                default:
                    break
                }
            }
            
            // Update the game result
            if goalsFor > 0 || goalsAgainst > 0 {
                game.result = GameResult(goalsFor: goalsFor, goalsAgainst: goalsAgainst)
            }
            
            print("🔄 Restored game state on appear - Score: \(goalsFor)-\(goalsAgainst)")
        }
    }
    
    // MARK: - Game Control Methods
    private func pauseGame() {
        gameStateManager.pauseGame()
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func resumeGame() {
        gameStateManager.resumeGame()
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func startSecondHalf() {
        gameStateManager.startHalfTime()
        
        for index in lineupPositions.indices {
            lineupPositions[index].fieldPosition.x = 1.0 - lineupPositions[index].fieldPosition.x
            lineupPositions[index].fieldPosition.y = 1.0 - lineupPositions[index].fieldPosition.y
        }
        
        game.auditLog = gameStateManager.activeGameState?.auditLog ?? []
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    private func recordEvent() {
        guard let player = selectedPlayer else { return }
        
        print("📝 RECORDING EVENT LOCALLY: \(player.name) - \(selectedEventType.rawValue)")
        
        // Create the game event
        let event = GameEvent(
            playerId: player.id,
            eventType: selectedEventType,
            minute: calculatedMinute
        )
        
        // Add event to game
        game.gameEvents.append(event)
        
        // Convert event type to audit event type
        let auditEventType: GameAuditEventType
        switch selectedEventType {
        case .goal:
            auditEventType = .goal
        case .assist:
            auditEventType = .assist
        case .goalAgainst:
            auditEventType = .goalAgainst
        case .yellowCard:
            auditEventType = .yellowCard
        case .redCard:
            auditEventType = .redCard
        case .save:
            auditEventType = .save
        case .shot:
            auditEventType = .shot
        case .shotOnTarget:
            auditEventType = .shotOnTarget
        case .freeKick:
            auditEventType = .freeKick
        case .cornerKick:
            auditEventType = .cornerKick
        case .penaltyKick:
            auditEventType = .penaltyKick
        }
        
        // Add to audit log via GameStateManager
        gameStateManager.addAuditEntry(
            eventType: auditEventType,
            gameTime: gameStateManager.auditLogTime,
            playerName: player.name,
            playerId: player.id,
            details: "\(player.name) - \(selectedEventType.rawValue)"
        )
        
        // Update game audit log from GameStateManager
        game.auditLog = gameStateManager.activeGameState?.auditLog ?? []
        
        // Update game result for goals
        if selectedEventType == .goal {
            if game.result == nil {
                game.result = GameResult(goalsFor: 0, goalsAgainst: 0)
            }
            game.result?.goalsFor += 1
        } else if selectedEventType == .goalAgainst {
            if game.result == nil {
                game.result = GameResult(goalsFor: 0, goalsAgainst: 0)
            }
            game.result?.goalsAgainst += 1
        }
        
        // CRITICAL: Update player stats immediately
        updatePlayerStats(for: player, event: selectedEventType)
        
        // Update game in team (LOCAL ONLY - no Firebase sync during live games)
        if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[gameIndex] = game
        }
        
        // Update TeamManager's teams array locally
        if let teamIndex = teamManager.teams.firstIndex(where: { $0.id == team.id }) {
            teamManager.teams[teamIndex] = team
        }
        
        // Save locally only (TeamManager will skip Firebase due to local-only mode)
        teamManager.updateTeam(team, activeGameId: game.id)
        
        // CRITICAL: Also persist the game state with updated result
        gameStateManager.persistActiveGameState()
        
        // Clear selection
        selectedPlayer = nil
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("✅ Event recorded locally - \(selectedEventType.rawValue) for \(player.name)")
    }
    
    private func updatePlayerStats(for player: Player, event: EventType) {
        print("📊 Updating stats for \(player.name): \(event.rawValue)")
        
        // Find or create player stats for this game
        if let statsIndex = game.playerStats.firstIndex(where: { $0.playerId == player.id }) {
            // Update existing stats
            switch event {
            case .goal:
                game.playerStats[statsIndex].goals += 1
            case .assist:
                game.playerStats[statsIndex].assists += 1
            case .save:
                game.playerStats[statsIndex].saves += 1
            case .goalAgainst:
                game.playerStats[statsIndex].goalsConceded += 1
            case .yellowCard:
                game.playerStats[statsIndex].yellowCards += 1
            case .redCard:
                game.playerStats[statsIndex].redCards += 1
            case .shot, .shotOnTarget:
                game.playerStats[statsIndex].shots += 1
            default:
                break
            }
            print("📊 Updated existing stats for \(player.name) - Goals: \(game.playerStats[statsIndex].goals)")
        } else {
            // Create new stats for this player
            var newStats = PlayerGameStats(playerId: player.id)
            switch event {
            case .goal:
                newStats.goals = 1
            case .assist:
                newStats.assists = 1
            case .save:
                newStats.saves = 1
            case .goalAgainst:
                newStats.goalsConceded = 1
            case .yellowCard:
                newStats.yellowCards = 1
            case .redCard:
                newStats.redCards = 1
            case .shot, .shotOnTarget:
                newStats.shots = 1
            default:
                break
            }
            game.playerStats.append(newStats)
            print("📊 Created new stats for \(player.name)")
        }
        
        // Also update season stats for the player
        if let playerIndex = team.players.firstIndex(where: { $0.id == player.id }) {
            switch event {
            case .goal:
                team.players[playerIndex].seasonStats.goals += 1
            case .assist:
                team.players[playerIndex].seasonStats.assists += 1
            case .save:
                team.players[playerIndex].seasonStats.saves += 1
            case .goalAgainst:
                team.players[playerIndex].seasonStats.goalsConceded += 1
            case .yellowCard:
                team.players[playerIndex].seasonStats.yellowCards += 1
            case .redCard:
                team.players[playerIndex].seasonStats.redCards += 1
            default:
                break
            }
        }
        
        print("✅ Updated stats for \(player.name): \(event.rawValue)")
    }
    
    // MARK: - Audit Log Management (unchanged)
    private func handleAuditEntryEdit(_ editedEntry: GameAuditEntry) {
        gameStateManager.editAuditEntry(
            entryId: editedEntry.id,
            newEventType: editedEntry.eventType,
            newGameTime: editedEntry.gameTime,
            newPlayerName: editedEntry.playerName,
            newPlayerId: editedEntry.playerId,
            newDetails: editedEntry.details
        )
        
        recalculateStatsFromAuditLog()
    }
    
    private func handleAuditEntryDelete(_ entryId: UUID) {
        gameStateManager.deleteAuditEntry(entryId: entryId)
        recalculateStatsFromAuditLog()
    }
    
    private func handleAddNewAuditEntry(_ newEntry: GameAuditEntry) {
        gameStateManager.addAuditEntry(
            eventType: newEntry.eventType,
            gameTime: newEntry.gameTime,
            playerName: newEntry.playerName,
            playerId: newEntry.playerId,
            details: newEntry.details
        )
        
        recalculateStatsFromAuditLog()
    }
    
    private func recalculateStatsFromAuditLog() {
        print("🔄 RECALCULATING STATS FROM AUDIT LOG")
        
        // Reset all player stats for this game
        for index in game.playerStats.indices {
            let savedMinutes = game.playerStats[index].minutesPlayed // Preserve minutes
            let savedTimeEntries = game.playerStats[index].timeEntries // Preserve time entries
            
            game.playerStats[index].goals = 0
            game.playerStats[index].assists = 0
            game.playerStats[index].saves = 0
            game.playerStats[index].goalsConceded = 0
            game.playerStats[index].yellowCards = 0
            game.playerStats[index].redCards = 0
            game.playerStats[index].shots = 0
            
            // Restore preserved data
            game.playerStats[index].minutesPlayed = savedMinutes
            game.playerStats[index].timeEntries = savedTimeEntries
            
            print("🔄 Reset stats for player \(game.playerStats[index].playerId)")
        }
        
        // Reset game result
        game.result = GameResult(goalsFor: 0, goalsAgainst: 0)
        
        // Recalculate from audit log
        if let auditLog = gameStateManager.activeGameState?.auditLog {
            print("🔄 Processing \(auditLog.count) audit log entries")
            for entry in auditLog {
                guard let playerId = entry.playerId else {
                    print("⚠️ Skipping entry with no playerId: \(entry.eventType.rawValue)")
                    continue
                }
                
                // Find or create player stats
                var playerStats: PlayerGameStats
                if let existingIndex = game.playerStats.firstIndex(where: { $0.playerId == playerId }) {
                    playerStats = game.playerStats[existingIndex]
                } else {
                    playerStats = PlayerGameStats(playerId: playerId)
                    game.playerStats.append(playerStats)
                    print("➕ Created new stats for player \(playerId)")
                }
                
                // Update stats based on event type
                switch entry.eventType {
                case .goal:
                    playerStats.goals += 1
                    game.result?.goalsFor += 1
                    print("⚽ Added goal for player")
                case .goalAgainst:
                    playerStats.goalsConceded += 1
                    game.result?.goalsAgainst += 1
                    print("🥅 Added goal against for player")
                case .assist:
                    playerStats.assists += 1
                    print("🎯 Added assist for player")
                case .save:
                    playerStats.saves += 1
                    print("🥊 Added save for player")
                case .yellowCard:
                    playerStats.yellowCards += 1
                    print("🟨 Added yellow card for player")
                case .redCard:
                    playerStats.redCards += 1
                    print("🟥 Added red card for player")
                case .shot:
                    playerStats.shots += 1
                    print("🎯 Added shot for player")
                default:
                    print("ℹ️ Processed non-stat event: \(entry.eventType.rawValue)")
                }
                
                // Update the stats in the array
                if let existingIndex = game.playerStats.firstIndex(where: { $0.playerId == playerId }) {
                    game.playerStats[existingIndex] = playerStats
                }
            }
            
            print("✅ Finished recalculating stats. Final score: \(game.result?.goalsFor ?? 0)-\(game.result?.goalsAgainst ?? 0)")
        }
        
        // Update local team state
        if let gameIndex = team.games.firstIndex(where: { $0.id == game.id }) {
            team.games[gameIndex] = game
        }
        
        if let teamIndex = teamManager.teams.firstIndex(where: { $0.id == team.id }) {
            teamManager.teams[teamIndex] = team
        }
        
        // Save the recalculated stats
        Task {
            await teamManager.updateTeamImmediatelyForActiveGame(team, activeGameId: game.id)
        }
    }
}
    // MARK: - Modern Game Header (UPDATED with Reduced Spacing)
    struct ModernGameHeader: View {
        let game: Game
        let formattedTime: String
        let isFirstHalf: Bool
        let isPaused: Bool
        let timerTick: Bool
        let onExit: () -> Void
        let onShowAuditLog: () -> Void
        let onEditTimer: () -> Void
        let onClearGame: () -> Void
        let isReadOnlyUser: Bool
        
        var body: some View {
            VStack(spacing: 8) { // REDUCED from 12
                HStack {
                    Button(action: onExit) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Exit")
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) { // REDUCED from 4
                        Text("vs \(game.opponent)")
                            .font(.headline)
                            .bold()
                        
                        HStack(spacing: 8) {
                            Text(game.isHome ? "HOME" : "AWAY")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(game.isHome ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .cornerRadius(4)
                            
                            if let result = game.result {
                                Text("\(result.goalsFor) - \(result.goalsAgainst)")
                                    .font(.headline)
                                    .bold()
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Menu button for coaches or audit log for read-only users
                    if !isReadOnlyUser {
                        Menu {
                            Button("View Audit Log", action: onShowAuditLog)
                            Button("Edit Timer", action: onEditTimer)
                            Button("Clear Game Data", action: onClearGame)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: onShowAuditLog) {
                            Image(systemName: "list.clipboard")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Timer Display - UPDATED with reduced spacing
                VStack(spacing: 2) { // REDUCED from 4
                    Text(formattedTime)
                        .font(.system(size: 32, weight: .bold, design: .monospaced)) // REDUCED from 36
                        .foregroundColor(isPaused ? .orange : .primary)
                    
                    Text(isFirstHalf ? "First Half" : "Second Half")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16) // REDUCED from 20
            .padding(.vertical, 12) // REDUCED from 16
            .background(Color(.systemBackground))
        }
    }
    
    // In the ModernTimerControls struct (around line 1850):
    struct ModernTimerControls: View {
        let isPaused: Bool
        let isFirstHalf: Bool
        let calculatedMinute: Int
        let halfLength: Int  // This already comes from the team's setting via the game state
        let onPause: () -> Void
        let onResume: () -> Void
        let onStartSecondHalf: () -> Void
        let onEndGame: () -> Void
        
        var body: some View {
            HStack(spacing: 16) {
                if isPaused {
                    Button(action: onResume) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Resume")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                } else {
                    Button(action: onPause) {
                        HStack {
                            Image(systemName: "pause.fill")
                            Text("Pause")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }
                }
                
                // CHANGED: This logic now uses the team's half length that was passed in
                if isFirstHalf && calculatedMinute >= halfLength {
                    Button(action: onStartSecondHalf) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("2nd Half")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                
                if !isFirstHalf {
                    Button(action: onEndGame) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("End Game")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    // MARK: - Modern Event Type Button (UPDATED for equal sizing)
    struct ModernEventTypeButton: View {
        let eventType: EventType
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 6) {
                    Image(systemName: eventType.systemImage)
                        .font(.title2)
                        .frame(height: 24) // Fixed height for icon
                    
                    Text(eventType.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(height: 30) // Fixed height for text
                }
                .foregroundColor(isSelected ? .white : eventType.color)
                .frame(maxWidth: .infinity) // Equal width distribution
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? eventType.color : eventType.color.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(eventType.color.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                )
            }
        }
    }
    
    // MARK: - Modern Action Bar
    struct ModernActionBar: View {
        let selectedPlayer: Player?
        let selectedEventType: EventType
        let isSwapMode: Bool
        let swapSourcePlayer: Player?
        let onRecord: () -> Void
        let onCancel: () -> Void
        let onSwapMode: () -> Void
        let onCancelSwap: () -> Void

        var body: some View {
            HStack {
                if isSwapMode {
                    // Swap mode — waiting for source or target
                    if let source = swapSourcePlayer {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text("\(source.jerseyNumber)")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.white)
                                )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(source.name.components(separatedBy: " ").first ?? source.name)
                                    .font(.subheadline)
                                    .bold()
                                Text("Field player = swap · Bench = sub")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                            Text("Tap a field player to swap")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button("Cancel", action: onCancelSwap)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                } else if let player = selectedPlayer {
                    HStack {
                        Circle()
                            .fill(selectedEventType.color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Text("\(player.jerseyNumber)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.name)
                                .font(.subheadline)
                                .bold()
                            Text(selectedEventType.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    Spacer()

                    Button("Record", action: onRecord)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)

                    Button("Cancel", action: onCancel)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                } else {
                    Text("Select a player to record an event")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: onSwapMode) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right")
                            Text("Sub / Swap")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Modern Game Field View (UPDATED with Position Swap Support)
    struct ModernGameFieldView: View {
        let formation: Formation
        let lineupPositions: [LineupPosition]
        @Binding var selectedPlayer: Player?
        let selectedEventType: EventType
        let team: Team
        let game: Game
        let isReadOnlyUser: Bool
        var isSwapMode: Bool = false
        var swapSourcePlayerId: UUID? = nil
        var onSwapTap: (Player) -> Void = { _ in }
        
        // NEW: Calculate actual field positions considering position swaps
        private func calculateActualFieldPositions(for geometry: CGSize) -> [CGPoint] {
            let basePositions = formation.fieldPositions(for: geometry)
            var actualPositions = basePositions
            
            // Track position swaps by finding players who have different positions than their original formation slot
            var positionMappings: [Int: Int] = [:]
            
            // Build a map of original position to current position
            for (index, lineupPos) in lineupPositions.enumerated() {
                // Find if this player was originally supposed to be in a different position
                let originalFormationPosition = formation.positions[index]
                let currentPosition = lineupPos.position
                
                if originalFormationPosition != currentPosition {
                    // This player has been moved - find where they should be now
                    if let targetIndex = formation.positions.firstIndex(of: currentPosition) {
                        positionMappings[index] = targetIndex
                    }
                }
            }
            
            // Apply the position mappings
            for (fromIndex, toIndex) in positionMappings {
                if fromIndex < actualPositions.count && toIndex < actualPositions.count {
                    actualPositions[fromIndex] = basePositions[toIndex]
                }
            }
            
            return actualPositions
        }
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    ModernSoccerFieldBackground()
                    
                    ForEach(Array(lineupPositions.enumerated()), id: \.offset) { index, position in
                        // Use calculated actual positions instead of default formation positions
                        let actualPositions = calculateActualFieldPositions(for: geometry.size)
                        let actualPos = actualPositions[index]
                        
                        if let playerId = position.playerId,
                           let player = team.players.first(where: { $0.id == playerId }) {
                            
                            GamePlayerMarker(
                                player: player,
                                position: position.position,
                                isSelected: selectedPlayer?.id == player.id && !isSwapMode,
                                eventColor: selectedEventType.color,
                                isReadOnlyUser: isReadOnlyUser,
                                isSwapSource: isSwapMode && swapSourcePlayerId == player.id,
                                isSwapTarget: isSwapMode && swapSourcePlayerId != nil && swapSourcePlayerId != player.id,
                                isCompact: isSwapMode
                            )
                            .position(actualPos)
                            .onTapGesture {
                                if !isReadOnlyUser {
                                    if isSwapMode {
                                        onSwapTap(player)
                                    } else {
                                        selectedPlayer = player
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    // MARK: - Game Player Marker
    struct GamePlayerMarker: View {
        let player: Player
        let position: Position
        let isSelected: Bool
        let eventColor: Color
        let isReadOnlyUser: Bool
        var isSwapSource: Bool = false
        var isSwapTarget: Bool = false
        var isCompact: Bool = false

        private var circleSize: CGFloat { isCompact ? 36 : 45 }
        private var ringSize: CGFloat { isCompact ? 48 : 60 }
        private var fontSize: CGFloat { isCompact ? 13 : 16 }

        var body: some View {
            ZStack {
                if isSwapSource {
                    Circle()
                        .stroke(Color.orange, lineWidth: 3)
                        .frame(width: ringSize, height: ringSize)
                } else if isSwapTarget {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: ringSize, height: ringSize)
                } else if isSelected && !isReadOnlyUser {
                    Circle()
                        .stroke(eventColor, lineWidth: 3)
                        .frame(width: ringSize, height: ringSize)
                        .animation(.easeInOut(duration: 0.3), value: isSelected)
                }

                VStack(spacing: 2) {
                    ZStack {
                        Circle()
                            .fill(isSwapSource ? Color.orange : position.color)
                            .frame(width: circleSize, height: circleSize)

                        Text(String(player.jerseyNumber))
                            .font(.system(size: fontSize, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text(player.name.components(separatedBy: " ").first ?? "")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, isCompact ? 4 : 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isCompact)
        }
    }
    // MARK: - Modern Bench View
    struct ModernBenchView: View {
        let benchPlayers: [Player]
        @Binding var selectedPlayer: Player?
        let isReadOnlyUser: Bool
        var isSwapMode: Bool = false
        var hasSwapSource: Bool = false
        var onSwapTap: (Player) -> Void = { _ in }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Bench")
                        .font(.headline)
                        .padding(.horizontal)

                    // Hint label when a source is selected and bench players are available
                    if isSwapMode && hasSwapSource && !benchPlayers.isEmpty {
                        Text("Tap to sub in")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(6)
                    }

                    Spacer()

                    Text("\(benchPlayers.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                if benchPlayers.isEmpty {
                    Text("All players are on the field")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(benchPlayers) { player in
                                BenchPlayerCard(
                                    player: player,
                                    isSelected: selectedPlayer?.id == player.id && !isSwapMode,
                                    isReadOnlyUser: isReadOnlyUser,
                                    isSwapTarget: isSwapMode && hasSwapSource,
                                    isCompact: isSwapMode
                                ) {
                                    if !isReadOnlyUser {
                                        if isSwapMode {
                                            onSwapTap(player)
                                        } else {
                                            selectedPlayer = player
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    // MARK: - Bench Player Card
    struct BenchPlayerCard: View {
        let player: Player
        let isSelected: Bool
        let isReadOnlyUser: Bool
        var isSwapTarget: Bool = false
        var isCompact: Bool = false
        let onTap: () -> Void

        private var circleSize: CGFloat { isCompact ? 34 : 42 }
        private var cardWidth: CGFloat { isCompact ? 62 : 80 }
        private var verticalPadding: CGFloat { isCompact ? 5 : 8 }

        var body: some View {
            Button(action: onTap) {
                VStack(spacing: isCompact ? 4 : 8) {
                    ZStack {
                        Circle()
                            .fill(isSwapTarget ? Color.green.opacity(0.25) : Color.gray.opacity(0.3))
                            .frame(width: circleSize, height: circleSize)

                        Text(String(player.jerseyNumber))
                            .font(isCompact ? .subheadline : .headline)
                            .fontWeight(.bold)
                            .foregroundColor(isSwapTarget ? .green : .gray)
                    }

                    VStack(spacing: 2) {
                        Text(player.name.components(separatedBy: " ").first ?? "")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        if !isCompact {
                            Text(player.positions.joined(separator: "/"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(width: cardWidth)
                .padding(.vertical, verticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isSwapTarget ? Color.green.opacity(0.12) :
                            (isSelected && !isReadOnlyUser ? Color.blue.opacity(0.15) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSwapTarget ? Color.green :
                                    (isSelected && !isReadOnlyUser ? Color.blue : Color.clear),
                                    lineWidth: 2
                                )
                        )
                )
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isCompact)
            }
            .disabled(isReadOnlyUser)
        }
    }
    
    
    // MARK: - Substitution View
    struct SubstitutionView: View {
        let team: Team
        @Binding var game: Game
        @Binding var lineupPositions: [LineupPosition]
        @EnvironmentObject var gameStateManager: GameStateManager
        @Environment(\.presentationMode) var presentationMode
        
        @State private var playerOut: Player?
        @State private var playerIn: Player?
        @State private var substitutionReason: SubstitutionReason = .tactical
        
        var playersOnField: [Player] {
            lineupPositions.compactMap { position in
                guard let playerId = position.playerId else { return nil }
                return team.players.first { $0.id == playerId }
            }
        }
        
        var playersOnBench: [Player] {
            team.players.filter { player in
                !lineupPositions.contains { $0.playerId == player.id }
            }
        }
        
        var body: some View {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Make Substitution")
                        .font(.title2)
                        .bold()
                    
                    VStack(spacing: 16) {
                        // Player Out
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Player Coming Off")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(playersOnField) { player in
                                        SubPlayerCard(
                                            player: player,
                                            isSelected: playerOut?.id == player.id,
                                            cardType: .out
                                        ) {
                                            playerOut = player
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Player In
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Player Coming On")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(playersOnBench) { player in
                                        SubPlayerCard(
                                            player: player,
                                            isSelected: playerIn?.id == player.id,
                                            cardType: .in
                                        ) {
                                            playerIn = player
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Reason
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reason")
                                .font(.headline)
                            
                            Picker("Reason", selection: $substitutionReason) {
                                ForEach(SubstitutionReason.allCases, id: \.self) { reason in
                                    Text(reason.rawValue).tag(reason)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    
                    Spacer()
                    
                    Button("Make Substitution") {
                        makeSubstitution()
                    }
                    .disabled(playerOut == nil || playerIn == nil)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(playerOut != nil && playerIn != nil ? Color.green : Color.gray)
                    .cornerRadius(12)
                }
                .padding()
                .navigationTitle("Substitution")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
        
        private func makeSubstitution() {
            guard let playerOut = playerOut, let playerIn = playerIn else { return }
            
            // Find position of player going out
            if let positionIndex = lineupPositions.firstIndex(where: { $0.playerId == playerOut.id }) {
                lineupPositions[positionIndex].playerId = playerIn.id
            }
            
            // Create substitution record
            let substitution = Substitution(
                playerIn: playerIn.id,
                playerOut: playerOut.id,
                minute: gameStateManager.calculatedMinute,
                reason: substitutionReason
            )
            
            game.substitutions.append(substitution)
            
            // Add to audit log
            gameStateManager.addAuditEntry(
                eventType: .substitution,
                gameTime: gameStateManager.auditLogTime,
                details: "\(playerOut.name) ” \(playerIn.name) (\(substitutionReason.rawValue))"
            )
            
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // MARK: - Sub Player Card
    struct SubPlayerCard: View {
        let player: Player
        let isSelected: Bool
        let cardType: CardType
        let onTap: () -> Void
        
        enum CardType {
            case `in`, out
        }
        
        var body: some View {
            Button(action: onTap) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(cardType == .out ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                            .frame(width: 50, height: 50)
                        
                        Text(String(player.jerseyNumber))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(cardType == .out ? .red : .green)
                    }
                    
                    VStack(spacing: 2) {
                        Text(player.name.components(separatedBy: " ").first ?? "")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text(player.positions.joined(separator: "/"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 80)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                        )
                )
            }
        }
    }
    
    // MARK: - Enhanced Game Audit Log View
    struct EnhancedGameAuditLogView: View {
        let auditLog: [GameAuditEntry]
        let game: Game
        let team: Team
        let onAuditEntryEdit: (GameAuditEntry) -> Void
        let onAuditEntryDelete: (UUID) -> Void
        let onAddNewEntry: (GameAuditEntry) -> Void
        let isReadOnlyUser: Bool  // ADDED
        
        @Environment(\.presentationMode) var presentationMode
        @State private var showingAddEntry = false
        @State private var editingEntry: GameAuditEntry?
        
        var body: some View {
            NavigationView {
                List {
                    if auditLog.isEmpty {
                        Text("No events recorded")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(auditLog.sorted { $0.realTime > $1.realTime }) { entry in
                            AuditEntryRow(
                                entry: entry,
                                onEdit: {
                                    if !isReadOnlyUser {  // ADDED: Only allow edits for coaches
                                        editingEntry = entry
                                    }
                                },
                                onDelete: {
                                    if !isReadOnlyUser {  // ADDED: Only allow deletes for coaches
                                        onAuditEntryDelete(entry.id)
                                    }
                                },
                                isReadOnlyUser: isReadOnlyUser  // ADDED
                            )
                        }
                    }
                }
                .navigationTitle("Game Events")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    // UPDATED: Only show Add Event for coaches
                    if !isReadOnlyUser {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add Event") {
                                showingAddEntry = true
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                if !isReadOnlyUser {  // ADDED: Only show for coaches
                    AddAuditEntryView(
                        team: team,
                        onAdd: onAddNewEntry
                    )
                }
            }
            .sheet(item: $editingEntry) { entry in
                if !isReadOnlyUser {  // ADDED: Only show for coaches
                    EditAuditEntryView(
                        entry: entry,
                        team: team,
                        onSave: onAuditEntryEdit
                    )
                }
            }
        }
    }
    
    // MARK: - Audit Entry Row
    struct AuditEntryRow: View {
        let entry: GameAuditEntry
        let onEdit: () -> Void
        let onDelete: () -> Void
        let isReadOnlyUser: Bool  // ADDED
        
        var body: some View {
            HStack {
                Image(systemName: entry.eventType.icon)
                    .foregroundColor(entry.eventType.color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.eventType.rawValue)
                        .font(.subheadline)
                        .bold()
                    
                    if let playerName = entry.playerName {
                        Text(playerName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(entry.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.gameTime)
                        .font(.caption)
                        .bold()
                    
                    Text(entry.realTime.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // UPDATED: Only show menu for coaches
                if !isReadOnlyUser {
                    Menu {
                        Button("Edit", action: onEdit)
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    // MARK: - Add Audit Entry View
    struct AddAuditEntryView: View {
        let team: Team
        let onAdd: (GameAuditEntry) -> Void
        
        @Environment(\.presentationMode) var presentationMode
        @State private var selectedEventType: GameAuditEventType = .goal
        @State private var gameTime = ""
        @State private var selectedPlayerId: UUID?
        @State private var details = ""
        
        var selectedPlayer: Player? {
            guard let playerId = selectedPlayerId else { return nil }
            return team.players.first { $0.id == playerId }
        }
        
        var body: some View {
            NavigationView {
                Form {
                    Section("Event Details") {
                        Picker("Event Type", selection: $selectedEventType) {
                            ForEach(GameAuditEventType.allCases, id: \.self) { eventType in
                                Text(eventType.rawValue).tag(eventType)
                            }
                        }
                        
                        TextField("Game Time (e.g., 45:30)", text: $gameTime)
                        
                        TextField("Details", text: $details)
                    }
                    
                    Section("Player (Optional)") {
                        Picker("Player", selection: $selectedPlayerId) {
                            Text("No Player").tag(UUID?.none)
                            ForEach(team.players) { player in
                                Text(player.name).tag(UUID?.some(player.id))
                            }
                        }
                    }
                }
                .navigationTitle("Add Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            let entry = GameAuditEntry(
                                eventType: selectedEventType,
                                gameTime: gameTime,
                                details: details,
                                playerName: selectedPlayer?.name,
                                playerId: selectedPlayer?.id
                            )
                            onAdd(entry)
                            presentationMode.wrappedValue.dismiss()
                        }
                        .disabled(gameTime.isEmpty || details.isEmpty)
                    }
                }
            }
        }
    }
    
    // MARK: - Edit Audit Entry View
    struct EditAuditEntryView: View {
        let entry: GameAuditEntry
        let team: Team
        let onSave: (GameAuditEntry) -> Void
        
        @Environment(\.presentationMode) var presentationMode
        @State private var selectedEventType: GameAuditEventType
        @State private var gameTime: String
        @State private var selectedPlayerId: UUID?
        @State private var details: String
        
        var selectedPlayer: Player? {
            guard let playerId = selectedPlayerId else { return nil }
            return team.players.first { $0.id == playerId }
        }
        
        init(entry: GameAuditEntry, team: Team, onSave: @escaping (GameAuditEntry) -> Void) {
            self.entry = entry
            self.team = team
            self.onSave = onSave
            
            self._selectedEventType = State(initialValue: entry.eventType)
            self._gameTime = State(initialValue: entry.gameTime)
            self._details = State(initialValue: entry.details)
            self._selectedPlayerId = State(initialValue: entry.playerId)
        }
        
        var body: some View {
            NavigationView {
                Form {
                    Section("Event Details") {
                        Picker("Event Type", selection: $selectedEventType) {
                            ForEach(GameAuditEventType.allCases, id: \.self) { eventType in
                                Text(eventType.rawValue).tag(eventType)
                            }
                        }
                        
                        TextField("Game Time", text: $gameTime)
                        
                        TextField("Details", text: $details)
                    }
                    
                    Section("Player") {
                        Picker("Player", selection: $selectedPlayerId) {
                            Text("No Player").tag(UUID?.none)
                            ForEach(team.players) { player in
                                Text(player.name).tag(UUID?.some(player.id))
                            }
                        }
                    }
                }
                .navigationTitle("Edit Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            var editedEntry = entry
                            editedEntry.eventType = selectedEventType
                            editedEntry.gameTime = gameTime
                            editedEntry.details = details
                            editedEntry.playerName = selectedPlayer?.name
                            editedEntry.playerId = selectedPlayer?.id
                            
                            onSave(editedEntry)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
    }
    
struct EnhancedEndGameView: View {
    @Binding var game: Game
    let auditLog: [GameAuditEntry]
    let team: Team
    let onConfirmEnd: () -> Void
    let onAuditEntryEdit: (GameAuditEntry) -> Void
    let onAuditEntryDelete: (UUID) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var goalsFor: Int
    @State private var goalsAgainst: Int
    @State private var editingEntry: GameAuditEntry?
    @State private var isSaving = false  // NEW: Track saving state
    
    init(game: Binding<Game>, auditLog: [GameAuditEntry], team: Team, onConfirmEnd: @escaping () -> Void, onAuditEntryEdit: @escaping (GameAuditEntry) -> Void, onAuditEntryDelete: @escaping (UUID) -> Void) {
        self._game = game
        self.auditLog = auditLog
        self.team = team
        self.onConfirmEnd = onConfirmEnd
        self.onAuditEntryEdit = onAuditEntryEdit
        self.onAuditEntryDelete = onAuditEntryDelete
        
        self._goalsFor = State(initialValue: game.wrappedValue.result?.goalsFor ?? 0)
        self._goalsAgainst = State(initialValue: game.wrappedValue.result?.goalsAgainst ?? 0)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    Text("End Game Confirmation")
                        .font(.title2)
                        .bold()
                    
                    // Final Score Section
                    VStack(spacing: 16) {
                        Text("Final Score")
                            .font(.headline)
                        
                        HStack(spacing: 40) {
                            VStack {
                                Text("Goals For")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Button("-") {
                                        if goalsFor > 0 { goalsFor -= 1 }
                                    }
                                    .disabled(goalsFor <= 0 || isSaving)  // Disable when saving
                                    
                                    Text("\(goalsFor)")
                                        .font(.title)
                                        .bold()
                                        .frame(minWidth: 40)
                                    
                                    Button("+") {
                                        goalsFor += 1
                                    }
                                    .disabled(isSaving)  // Disable when saving
                                }
                            }
                            
                            Text("vs")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            VStack {
                                Text("Goals Against")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Button("-") {
                                        if goalsAgainst > 0 { goalsAgainst -= 1 }
                                    }
                                    .disabled(goalsAgainst <= 0 || isSaving)  // Disable when saving
                                    
                                    Text("\(goalsAgainst)")
                                        .font(.title)
                                        .bold()
                                        .frame(minWidth: 40)
                                    
                                    Button("+") {
                                        goalsAgainst += 1
                                    }
                                    .disabled(isSaving)  // Disable when saving
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Game Events Review
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Game Events Review")
                            .font(.headline)
                        
                        if auditLog.isEmpty {
                            Text("No events recorded")
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(auditLog.sorted { $0.realTime < $1.realTime }) { entry in
                                        CompactAuditEntryRow(
                                            entry: entry,
                                            onEdit: { editingEntry = entry },
                                            onDelete: { onAuditEntryDelete(entry.id) }
                                        )
                                        .disabled(isSaving)  // Disable interaction when saving
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    // Confirm Button - UPDATED with loading state
                    Button(action: {
                        isSaving = true
                        game.result = GameResult(goalsFor: goalsFor, goalsAgainst: goalsAgainst)
                        onConfirmEnd()
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                                Text("Ending Game...")
                            } else {
                                Text("Confirm & End Game")
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSaving ? Color.gray : Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving)
                }
                .padding()
                .blur(radius: isSaving ? 2 : 0)  // Blur background when saving
                
                // NEW: Full-screen saving overlay
                if isSaving {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Saving Game Data...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Syncing to cloud...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                }
            }
            .navigationTitle("End Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if !isSaving {  // Only allow cancel if not saving
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .sheet(item: $editingEntry) { entry in
            if !isSaving {  // Only show edit sheet if not saving
                EditAuditEntryView(
                    entry: entry,
                    team: team,
                    onSave: onAuditEntryEdit
                )
            }
        }
    }
}
    
    // MARK: - Compact Audit Entry Row
    struct CompactAuditEntryRow: View {
        let entry: GameAuditEntry
        let onEdit: () -> Void
        let onDelete: () -> Void
        
        var body: some View {
            Button(action: onEdit) {
                HStack {
                    Image(systemName: entry.eventType.icon)
                        .foregroundColor(entry.eventType.color)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.eventType.rawValue)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.primary)
                        
                        if let playerName = entry.playerName {
                            Text(playerName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(entry.details)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(entry.gameTime)
                            .font(.caption)
                            .bold()
                            .foregroundColor(.primary)
                        
                        Text(entry.realTime.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Menu {
                        Button("Edit", action: onEdit)
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                    .onTapGesture {} // Prevent button action when tapping menu
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
    }

// MARK: - Complete Game Detail View (UPDATED with Binding)
struct GameDetailView: View {
    @Binding var game: Game
    let team: Team
    let onViewActiveGame: (() -> Void)?
    @State private var selectedTab = 0
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showingDeleteAlert = false
    @State private var showingOptionsMenu = false
    @State private var showingEditGame = false
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var gameStateManager: GameStateManager
    
    init(game: Binding<Game>, team: Team, onViewActiveGame: (() -> Void)? = nil) {
        self._game = game
        self.team = team
        self.onViewActiveGame = onViewActiveGame
    }
    
    var gameResult: String {
        if gameStateManager.activeGameState?.gameId == game.id {
            return "In Progress"
        }
        
        guard let result = game.result else { return "Not Played" }
        if result.goalsFor > result.goalsAgainst {
            return "Won \(result.goalsFor)-\(result.goalsAgainst)"
        } else if result.goalsFor < result.goalsAgainst {
            return "Lost \(result.goalsFor)-\(result.goalsAgainst)"
        } else {
            return "Draw \(result.goalsFor)-\(result.goalsAgainst)"
        }
    }
    
    var gameStatusColor: Color {
        if gameStateManager.activeGameState?.gameId == game.id {
            return .blue
        }
        
        guard let result = game.result else { return .gray }
        if result.goalsFor > result.goalsAgainst {
            return .green
        } else if result.goalsFor < result.goalsAgainst {
            return .red
        } else {
            return .orange
        }
    }
    
    var isActiveGame: Bool {
        return gameStateManager.activeGameState?.gameId == game.id
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Clean Header Section
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("vs \(game.opponent)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(game.date.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if let result = game.result {
                            HStack(spacing: 8) {
                                Text("\(result.goalsFor)")
                                    .font(.system(size: 32, weight: .bold, design: .default))
                                    .foregroundColor(gameStatusColor)
                                
                                Text("-")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                
                                Text("\(result.goalsAgainst)")
                                    .font(.system(size: 32, weight: .bold, design: .default))
                                    .foregroundColor(gameStatusColor)
                            }
                        } else {
                            Text("vs")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(gameResult)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(gameStatusColor)
                    }
                    
                    // Fixed Ellipsis Button
                    Button(action: {
                        showingOptionsMenu = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 24, weight: .medium, design: .default))
                            .foregroundColor(.blue)
                    }
                    .frame(width: 44, height: 44) // Fixed frame for proper hit target
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Game Info Row
                HStack(spacing: 12) {
                    Text(game.isHome ? "HOME" : "AWAY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(game.isHome ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(game.isHome ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        )
                    
                    if let location = game.location {
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(Color(.systemBackground))
            
            // Active Game Banner (if this game is active)
            if isActiveGame {
                ActiveGameBanner(
                    activeGame: gameStateManager.activeGameState!,
                    onViewGame: {
                        if let onViewActiveGame = onViewActiveGame {
                            onViewActiveGame()
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.top)
            }
            
            // Tab Selection
            Picker("View", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Lineup").tag(1)
                Text("Events").tag(2)
                Text("Stats").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // Tab Content
            TabView(selection: $selectedTab) {
                ShareableTabContent(tabType: .overview) {
                    GameOverviewTab(game: $game, team: team)
                }
                .tag(0)
                
                ShareableTabContent(tabType: .lineup) {
                    GameLineupTab(game: game, team: team)
                }
                .tag(1)
                
                ShareableTabContent(tabType: .events) {
                    GameEventsTab(game: game, team: team)
                }
                .tag(2)
                
                ShareableTabContent(tabType: .stats) {
                    GameStatsTab(game: game, team: team)
                }
                .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationBarHidden(true)
        .actionSheet(isPresented: $showingOptionsMenu) {
            ActionSheet(
                title: Text("Game Options"),
                buttons: [
                    .default(Text("Edit Game")) {
                        showingEditGame = true
                    },
                    .default(Text("Share Game Report")) {
                        shareCurrentTab()
                    },
                    .destructive(Text("Delete Game")) {
                        showingDeleteAlert = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
        .sheet(isPresented: $showingEditGame) {
            EditGameView(game: $game, team: .constant(team))
                .environmentObject(teamManager)
        }
        .alert("Delete Game", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteGame()
            }
        } message: {
            Text("Are you sure you want to permanently delete the game vs \(game.opponent)? This action cannot be undone.")
        }
    }
    
    private func deleteGame() {
        teamManager.removeGame(from: team, game: game)
        
        // Dismiss immediately since removeGame handles the deletion efficiently
        DispatchQueue.main.async {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func shareCurrentTab() {
        let tabName = ["Overview", "Lineup", "Events", "Stats"][selectedTab]
        
        let fullContentView = VStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("vs \(game.opponent)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(game.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(tabName)
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    if let result = game.result {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(result.goalsFor) - \(result.goalsAgainst)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(gameResult)
                                .font(.caption)
                                .foregroundColor(gameStatusColor)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            
            Group {
                switch selectedTab {
                case 0:
                    FullCaptureGameOverviewTab(game: game, team: team)
                case 1:
                    FullCaptureGameLineupTab(game: game, team: team)
                case 2:
                    FullCaptureGameEventsTab(game: game, team: team)
                case 3:
                    FullCaptureGameStatsTab(game: game, team: team)
                default:
                    FullCaptureGameOverviewTab(game: game, team: team)
                }
            }
        }
            .background(Color(.systemGroupedBackground))
        
        let hostingController = UIHostingController(rootView: fullContentView)
        hostingController.view.backgroundColor = UIColor.systemGroupedBackground
        
        let screenWidth = UIScreen.main.bounds.width
        let maxHeight: CGFloat = 10000
        
        let targetSize = CGSize(width: screenWidth, height: maxHeight)
        hostingController.view.frame = CGRect(origin: .zero, size: targetSize)
        
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        let fittingSize = hostingController.view.systemLayoutSizeFitting(
            CGSize(width: screenWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: UILayoutPriority.required,
            verticalFittingPriority: UILayoutPriority.fittingSizeLevel
        )
        
        let finalWidth: CGFloat
        if selectedTab == 3 {
            finalWidth = max(screenWidth, fittingSize.width + 40)
        } else {
            finalWidth = screenWidth
        }
        
        let finalSize = CGSize(width: finalWidth, height: max(fittingSize.height + 100, 400))
        
        hostingController.view.frame = CGRect(origin: .zero, size: finalSize)
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        let renderer = UIGraphicsImageRenderer(size: finalSize)
        let image = renderer.image { context in
            hostingController.view.drawHierarchy(in: CGRect(origin: .zero, size: finalSize), afterScreenUpdates: true)
        }
        
        shareImage = image
        showingShareSheet = true
    }
}
    

    // MARK: - Full Capture Tab Views (Non-scrollable versions)
    struct FullCaptureGameOverviewTab: View {
        let game: Game
        let team: Team
        
        var body: some View {
            VStack(spacing: 20) {
                // Game Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Game Summary")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        if let result = game.result {
                            HStack {
                                Text("Final Score")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(result.goalsFor) - \(result.goalsAgainst)")
                                    .font(.title2)
                                    .bold()
                            }
                        }
                        
                        HStack {
                            Text("Date")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(game.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Text("Time")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(game.date.formatted(.dateTime.hour().minute()))
                                .font(.subheadline)
                        }
                        
                        if let location = game.location {
                            HStack {
                                Text("Location")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(location)
                                    .font(.subheadline)
                            }
                        }
                        
                        if let formation = game.formation {
                            HStack {
                                Text("Formation")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formation.rawValue)
                                    .font(.subheadline)
                            }
                        }
                        
                        HStack {
                            Text("Status")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            
                            if let result = game.result {
                                let statusText = result.goalsFor > result.goalsAgainst ? "Win" :
                                result.goalsFor < result.goalsAgainst ? "Loss" : "Draw"
                                let statusColor: Color = result.goalsFor > result.goalsAgainst ? .green :
                                result.goalsFor < result.goalsAgainst ? .red : .orange
                                Text(statusText)
                                    .font(.subheadline)
                                    .foregroundColor(statusColor)
                            } else {
                                Text(game.isCompleted ? "Completed" : "Scheduled")
                                    .font(.subheadline)
                                    .foregroundColor(game.isCompleted ? .green : .blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                }
                
                // Quick Stats - now using seasonStats
                if team.players.contains(where: { $0.seasonStats.goals > 0 || $0.seasonStats.assists > 0 || $0.seasonStats.saves > 0 }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Player Stats Summary")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            StatRowView(icon: "soccerball", title: "Total Goals", value: "\(team.players.reduce(0) { $0 + $1.seasonStats.goals })")
                            Divider().padding(.horizontal)
                            
                            StatRowView(icon: "hands.and.sparkles.fill", title: "Total Assists", value: "\(team.players.reduce(0) { $0 + $1.seasonStats.assists })")
                            Divider().padding(.horizontal)
                            
                            StatRowView(icon: "hand.raised.fill", title: "Total Saves", value: "\(team.players.reduce(0) { $0 + $1.seasonStats.saves })")
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    }
                }
                
                // Notes
                if let notes = game.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text(notes)
                            .font(.subheadline)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

struct FullCaptureGameLineupTab: View {
    let game: Game
    let team: Team
    
    private var startingLineupPlayers: [(Player, Position)] {
        let lineup = game.startingLineup ?? game.actualStartingLineup
        guard let lineup = lineup else { return [] }
        
        return lineup.compactMap { position in
            guard let playerId = position.playerId,
                  let player = team.players.first(where: { $0.id == playerId }) else { return nil }
            return (player, position.position)
        }
    }
    
    private var displayLineup: [LineupPosition] {
        return game.startingLineup ?? game.actualStartingLineup ?? []
    }
    
    private func romanNumeral(for count: Int) -> String {
        switch count {
        case 7: return "VII"
        case 8: return "VIII"
        case 9: return "IX"
        case 10: return "X"
        case 11: return "XI"
        default: return "\(count)"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if let formation = game.formation, !displayLineup.isEmpty {
                // Formation Display
                VStack(alignment: .leading, spacing: 12) {
                    Text("Starting Lineup - \(formation.rawValue)")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Field View
                    GeometryReader { geometry in
                        ZStack {
                            ModernSoccerFieldBackground()
                            
                            ForEach(Array(displayLineup.enumerated()), id: \.offset) { index, position in
                                let defaultPos = formation.fieldPositions(for: geometry.size)[index]
                                
                                if let playerId = position.playerId,
                                   let player = team.players.first(where: { $0.id == playerId }) {
                                    
                                    GameDetailPlayerMarker(
                                        player: player,
                                        position: position.position
                                    )
                                    .position(defaultPos)
                                }
                            }
                        }
                    }
                    .frame(height: 300)
                    .padding(.horizontal)
                }
                
                // Starting XI List - FIXED: Added proper VStack wrapper and dynamic text
                VStack(alignment: .leading, spacing: 12) {
                    Text("Starting \(romanNumeral(for: startingLineupPlayers.count))")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        ForEach(startingLineupPlayers, id: \.0.id) { player, position in
                            HStack {
                                Circle()
                                    .fill(position.color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text("\(player.jerseyNumber)")
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .font(.subheadline)
                                        .bold()
                                    Text(position.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                }
            } else {
                Text("No lineup recorded for this game")
                    .foregroundColor(.secondary)
                    .padding()
            }

        }
        .padding(.vertical)
    }
}
    struct FullCaptureGameEventsTab: View {
        let game: Game
        let team: Team
        
        var body: some View {
            VStack(spacing: 16) {
                if let auditLog = game.auditLog, !auditLog.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Game Timeline")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // ALL events without ScrollView - this will show everything
                        VStack(spacing: 8) {
                            ForEach(auditLog.sorted { $0.realTime < $1.realTime }) { entry in
                                GameEventRow(entry: entry, team: team)
                            }
                        }
                        .padding(.horizontal)
                    }
                } else if !game.gameEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Game Events")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // ALL events without ScrollView
                        VStack(spacing: 8) {
                            ForEach(game.gameEvents.sorted { $0.minute < $1.minute }) { event in
                                if let player = team.players.first(where: { $0.id == event.playerId }) {
                                    SimpleGameEventRow(event: event, player: player)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("No events recorded for this game")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.vertical)
        }
    }
    
    struct FullCaptureGameStatsTab: View {
        let game: Game
        let team: Team
        
        var body: some View {
            VStack(spacing: 16) {
                if !game.playerStats.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Player Statistics")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // ALL player stats without horizontal ScrollView
                        VStack(spacing: 8) {
                            ForEach(game.playerStats.sorted { $0.goals > $1.goals }, id: \.playerId) { stats in
                                if let player = team.players.first(where: { $0.id == stats.playerId }) {
                                    FullCaptureGamePlayerStatsRow(player: player, stats: stats, game: game, team: team)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("No player statistics recorded for this game")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Full Capture Game Player Stats Row (UPDATED - Only shows Goals, Assists, Saves, Minutes with presumed calculation)
    struct FullCaptureGamePlayerStatsRow: View {
        let player: Player
        let stats: PlayerGameStats
        let game: Game
        let team: Team
        
        // Calculate presumed minutes for display using the game method
        private var presumedMinutes: Int {
            return game.calculatePresumedMinutesPlayed(for: player.id, with: team)
        }
        
        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    // Player Info
                    HStack(spacing: 8) {
                        Circle()
                            .fill(player.preferredPositionEnum.color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Text("\(player.jerseyNumber)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                            )
                        
                        Text(player.name)
                            .font(.subheadline)
                            .bold()
                    }
                    
                    Spacer()
                    
                    // Show presumed minutes instead of stored minutes
                    Text("\(presumedMinutes) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    GameStatItem(label: "Goals", value: stats.goals, color: .green)
                    GameStatItem(label: "Assists", value: stats.assists, color: .blue)
                    GameStatItem(label: "Saves", value: stats.saves, color: .purple)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
    // MARK: - Shareable Tab Content Wrapper
    struct ShareableTabContent<Content: View>: View {
        let tabType: TabType
        let content: Content
        
        enum TabType {
            case overview, lineup, events, stats
        }
        
        init(tabType: TabType, @ViewBuilder content: () -> Content) {
            self.tabType = tabType
            self.content = content()
        }
        
        var body: some View {
            content
        }
    }
    
    // MARK: - Game Overview Tab with Clear Score Editing
    struct GameOverviewTab: View {
        @Binding var game: Game
        let team: Team
        @State private var editingScore = false
        @State private var tempGoalsFor: String = ""
        @State private var tempGoalsAgainst: String = ""
        
        // FIXED: Calculate player stats from actual game events instead of cached seasonStats
        private func calculatePlayerStatsFromGame() -> (goals: Int, assists: Int, saves: Int) {
            var totalGoals = 0
            var totalAssists = 0
            var totalSaves = 0
            
            for event in game.gameEvents {
                switch event.eventType {
                case .goal:
                    totalGoals += 1
                case .assist:
                    totalAssists += 1
                case .save:
                    totalSaves += 1
                default:
                    break
                }
            }
            
            return (goals: totalGoals, assists: totalAssists, saves: totalSaves)
        }
        
        // FIXED: Check if any stats exist from game events instead of seasonStats
        private var hasAnyStats: Bool {
            let gameStats = calculatePlayerStatsFromGame()
            return gameStats.goals > 0 || gameStats.assists > 0 || gameStats.saves > 0
        }
        
        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    // Game Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Game Summary")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            if let result = game.result {
                                HStack {
                                    Text("Final Score")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    
                                    // Enhanced Editable Score with Clear Visual Cues
                                    Button(action: {
                                        tempGoalsFor = "\(result.goalsFor)"
                                        tempGoalsAgainst = "\(result.goalsAgainst)"
                                        editingScore = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Text("\(result.goalsFor) - \(result.goalsAgainst)")
                                                .font(.title2)
                                                .bold()
                                                .foregroundColor(.primary)
                                            
                                            Image(systemName: "pencil.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.title3)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal)
                                
                                if let result = game.result {
                                    HStack {
                                        Text("Result")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        let statusText = result.goalsFor > result.goalsAgainst ? "Win" :
                                        result.goalsFor < result.goalsAgainst ? "Loss" : "Draw"
                                        let statusColor: Color = result.goalsFor > result.goalsAgainst ? .green :
                                        result.goalsFor < result.goalsAgainst ? .red : .orange
                                        Text(statusText)
                                            .font(.subheadline)
                                            .foregroundColor(statusColor)
                                    }
                                    .padding(.horizontal)
                                }
                            } else {
                                HStack {
                                    Text("Status")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(game.isCompleted ? "Completed" : "Scheduled")
                                        .font(.subheadline)
                                        .foregroundColor(game.isCompleted ? .green : .blue)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Basic game info
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Opponent")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(game.opponent)
                                        .font(.subheadline)
                                        .bold()
                                }
                                
                                HStack {
                                    Text("Date")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(game.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                        .font(.subheadline)
                                }
                                
                                HStack {
                                    Text("Location")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(game.isHome ? "Home" : "Away")
                                        .font(.subheadline)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(game.isHome ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    
                    // FIXED: Player Stats Summary - now calculates from game events instead of cached seasonStats
                    if hasAnyStats {
                        let gameStats = calculatePlayerStatsFromGame()
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Player Stats Summary")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                StatRowView(icon: "soccerball", title: "Total Goals", value: "\(gameStats.goals)")
                                Divider().padding(.horizontal)
                                
                                StatRowView(icon: "hands.and.sparkles.fill", title: "Total Assists", value: "\(gameStats.assists)")
                                Divider().padding(.horizontal)
                                
                                StatRowView(icon: "hand.raised.fill", title: "Total Saves", value: "\(gameStats.saves)")
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(15)
                            .shadow(radius: 2)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Notes
                    if let notes = game.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Text(notes)
                                .font(.subheadline)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .alert("Edit Final Score", isPresented: $editingScore) {
                TextField("Goals For", text: $tempGoalsFor)
                    .keyboardType(.numberPad)
                TextField("Goals Against", text: $tempGoalsAgainst)
                    .keyboardType(.numberPad)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    updateScore()
                }
            } message: {
                Text("Enter the final score for this game")
            }
        }
        
        private func updateScore() {
            guard let goalsFor = Int(tempGoalsFor),
                  let goalsAgainst = Int(tempGoalsAgainst),
                  goalsFor >= 0,
                  goalsAgainst >= 0 else { return }
            
            if game.result == nil {
                game.result = GameResult(goalsFor: goalsFor, goalsAgainst: goalsAgainst)
            } else {
                game.result?.goalsFor = goalsFor
                game.result?.goalsAgainst = goalsAgainst
            }
        }
    }
    
    // MARK: - Complete Professional Game Quick Stat Card with Dark Colors and Icons
    struct GameQuickStatCard: View {
        let title: String
        let value: String
        let color: Color
        let icon: String?
        
        // Convenience initializer with icon
        init(title: String, value: String, color: Color, icon: String? = nil) {
            self.title = title
            self.value = value
            self.color = color
            self.icon = icon
        }
        
        private var cardBackgroundColor: Color {
            switch title.lowercased() {
            case "goals":
                return Color(red: 0.1, green: 0.4, blue: 0.2) // Darker forest green
            case "assists":
                return Color(red: 0.1, green: 0.25, blue: 0.55) // Darker navy blue
            case "shots":
                return Color(red: 0.55, green: 0.2, blue: 0.1) // Darker burnt orange
            case "cards":
                return Color(red: 0.65, green: 0.45, blue: 0.0) // Professional amber/gold
            case "subs", "substitutions":
                return Color(red: 0.15, green: 0.35, blue: 0.65) // Professional dark blue
            case "saves":
                return Color(red: 0.35, green: 0.15, blue: 0.55) // Darker purple
            default:
                return Color(red: 0.2, green: 0.2, blue: 0.2) // Darker gray
            }
        }
        
        private var cardIcon: String {
            if let icon = icon {
                return icon
            }
            
            // Auto-assign icons based on title
            switch title.lowercased() {
            case "goals":
                return "soccerball.circle.fill"
            case "assists":
                return "arrow.triangle.2.circlepath"
            case "shots":
                return "scope"
            case "cards":
                return "rectangle.fill"
            case "subs", "substitutions":
                return "arrow.left.arrow.right.circle.fill"
            case "saves":
                return "hand.raised.circle.fill"
            default:
                return "chart.bar.fill"
            }
        }
        
        var body: some View {
            VStack(spacing: 8) {
                // Icon
                Image(systemName: cardIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                // Value
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Title
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackgroundColor)
                    .shadow(color: cardBackgroundColor.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Game Lineup Tab
    struct GameLineupTab: View {
        let game: Game
        let team: Team
        
        private var startingLineupPlayers: [(Player, Position)] {
            // Use the true starting lineup, not the actual lineup which may have changed
            let lineup = game.startingLineup ?? game.actualStartingLineup
            guard let lineup = lineup else { return [] }
            
            return lineup.compactMap { position in
                guard let playerId = position.playerId,
                      let player = team.players.first(where: { $0.id == playerId }) else { return nil }
                return (player, position.position)
            }
        }
        
        private var displayLineup: [LineupPosition] {
            return game.startingLineup ?? game.actualStartingLineup ?? []
        }
        
        private func romanNumeral(for count: Int) -> String {
            switch count {
            case 7: return "VII"
            case 8: return "VIII"
            case 9: return "IX"
            case 10: return "X"
            case 11: return "XI"
            default: return "\(count)"
            }
        }
        
        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    if let formation = game.formation, !displayLineup.isEmpty {
                        // Formation Display
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Starting Lineup - \(formation.rawValue)")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Field View
                            GeometryReader { geometry in
                                ZStack {
                                    ModernSoccerFieldBackground()
                                    
                                    ForEach(Array(displayLineup.enumerated()), id: \.offset) { index, position in
                                        let defaultPos = formation.fieldPositions(for: geometry.size)[index]
                                        
                                        if let playerId = position.playerId,
                                           let player = team.players.first(where: { $0.id == playerId }) {
                                            
                                            GameDetailPlayerMarker(
                                                player: player,
                                                position: position.position
                                            )
                                            .position(defaultPos)
                                        }
                                    }
                                }
                            }
                            .frame(height: 300)
                            .padding(.horizontal)
                        }
                        
                        // Starting XI List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Starting \(romanNumeral(for: startingLineupPlayers.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(startingLineupPlayers, id: \.0.id) { player, position in
                                    HStack {
                                        Circle()
                                            .fill(position.color)
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Text("\(player.jerseyNumber)")
                                                    .font(.caption)
                                                    .bold()
                                                    .foregroundColor(.white)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(player.name)
                                                .font(.subheadline)
                                                .bold()
                                            Text(position.rawValue)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            .padding(.horizontal)
                        }
                    } else {
                        Text("No lineup recorded for this game")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(.vertical)
            }
        }
        
        
    }
    // MARK: - Game Detail Player Marker
    struct GameDetailPlayerMarker: View {
        let player: Player
        let position: Position
        
        var body: some View {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(position.color)
                        .frame(width: 40, height: 40)
                    
                    Text(String(player.jerseyNumber))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(player.name.components(separatedBy: " ").first ?? "")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
            }
        }
    }
    
    // MARK: - Substitution Row
    struct SubstitutionRow: View {
        let playerIn: Player
        let playerOut: Player
        let minute: Int
        let reason: SubstitutionReason
        
        var body: some View {
            HStack {
                Text("\(minute)'")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .leading)
                
                HStack(spacing: 8) {
                    // Player Out
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("\(playerOut.jerseyNumber)")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.red)
                            )
                        Text(playerOut.name.components(separatedBy: " ").first ?? "")
                            .font(.caption)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    // Player In
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("\(playerIn.jerseyNumber)")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.green)
                            )
                        Text(playerIn.name.components(separatedBy: " ").first ?? "")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                Text(reason.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Game Events Tab
    struct GameEventsTab: View {
        let game: Game
        let team: Team
        
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    if let auditLog = game.auditLog, !auditLog.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Game Timeline")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(auditLog.sorted { $0.realTime < $1.realTime }) { entry in
                                    GameEventRow(entry: entry, team: team)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else if !game.gameEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Game Events")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(game.gameEvents.sorted { $0.minute < $1.minute }) { event in
                                    if let player = team.players.first(where: { $0.id == event.playerId }) {
                                        SimpleGameEventRow(event: event, player: player)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        Text("No events recorded for this game")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(.vertical)
            }
        }
    }
    
    // MARK: - Game Event Row
    struct GameEventRow: View {
        let entry: GameAuditEntry
        let team: Team
        
        var body: some View {
            HStack {
                // Time
                Text(entry.gameTime)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
                
                // Event Icon
                Image(systemName: entry.eventType.icon)
                    .foregroundColor(entry.eventType.color)
                    .frame(width: 30)
                
                // Event Details
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.eventType.rawValue)
                        .font(.subheadline)
                        .bold()
                    
                    if let playerName = entry.playerName {
                        Text(playerName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !entry.details.isEmpty && entry.details != "\(entry.playerName ?? "") - \(entry.eventType.rawValue)" {
                        Text(entry.details)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Simple Game Event Row
    struct SimpleGameEventRow: View {
        let event: GameEvent
        let player: Player
        
        var body: some View {
            HStack {
                Text("\(event.minute)'")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
                
                Image(systemName: event.eventType.systemImage)
                    .foregroundColor(event.eventType.color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.eventType.rawValue)
                        .font(.subheadline)
                        .bold()
                    
                    Text(player.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let notes = event.notes {
                        Text(notes)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Game Stats Tab
    // MARK: - Game Stats Tab (FIXED - Calculates from game events instead of cached stats)
    struct GameStatsTab: View {
        let game: Game
        let team: Team
        
        // Calculate player stats from actual game events instead of cached playerStats
        func calculatePlayerStats(for playerId: UUID) -> PlayerGameStats {
            var stats = PlayerGameStats(playerId: playerId)
            
            // Count stats from actual game events
            for event in game.gameEvents where event.playerId == playerId {
                switch event.eventType {
                case .goal:
                    stats.goals += 1
                case .assist:
                    stats.assists += 1
                case .shot, .shotOnTarget:
                    stats.shots += 1
                case .save:
                    stats.saves += 1
                case .goalAgainst:
                    stats.goalsConceded += 1
                case .yellowCard:
                    stats.yellowCards += 1
                case .redCard:
                    stats.redCards += 1
                default:
                    break
                }
            }
            
            // Get minutes played from original playerStats if available
            if let originalStats = game.playerStats.first(where: { $0.playerId == playerId }) {
                stats.minutesPlayed = originalStats.minutesPlayed
            }
            
            return stats
        }
        
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    if !team.players.isEmpty {
                        LazyVStack(spacing: 12) {
                            ForEach(team.players.sorted { player1, player2 in
                                let stats1 = calculatePlayerStats(for: player1.id)
                                let stats2 = calculatePlayerStats(for: player2.id)
                                return stats1.goals > stats2.goals
                            }, id: \.id) { player in
                                let stats = calculatePlayerStats(for: player.id)
                                FullCaptureGamePlayerStatsRow(player: player, stats: stats, game: game, team: team)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        Text("No player statistics recorded for this game")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(.vertical)
            }
        }
    }
    
    // MARK: - Game Player Stats Row
    
    struct GamePlayerStatsRow: View {
        let player: Player
        let stats: PlayerGameStats
        
        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    // Player Info
                    HStack(spacing: 8) {
                        Circle()
                            .fill(player.preferredPositionEnum.color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Text("\(player.jerseyNumber)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                            )
                        
                        Text(player.name)
                            .font(.subheadline)
                            .bold()
                    }
                    
                    Spacer()
                    
                    // Minutes Played
                    Text("\(stats.minutesPlayed) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Stats Grid - ONLY showing Goals, Assists, Shots, Saves
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        GameStatItem(label: "Goals", value: stats.goals, color: .green)
                        GameStatItem(label: "Assists", value: stats.assists, color: .blue)
                        GameStatItem(label: "Shots", value: stats.shots, color: .orange)
                        GameStatItem(label: "Saves", value: stats.saves, color: .purple)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Game Stat Item
    struct GameStatItem: View {
        let label: String
        let value: Int
        let color: Color
        
        var body: some View {
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(value > 0 ? color : .secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 50)
        }
    }
