import SwiftUI

struct EnhancedQuickStatsView: View {
    @EnvironmentObject var teamManager: TeamManager
    @State private var selectedStatType = "Overview"
    @State private var selectedTeamId: UUID?
    @State private var selectedTimeRange: TimeRange = .allTime
    @State private var showingDetailedStats = false
    @State private var isLoading = false
    @State private var isEditMode = false  // NEW: Edit mode toggle
    
    enum TimeRange: String, CaseIterable {
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case lastSeason = "Last Season"
        case allTime = "All Time"
        
        var dateRange: DateInterval? {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .lastWeek:
                let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
                return DateInterval(start: weekAgo, end: now)
            case .lastMonth:
                let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
                return DateInterval(start: monthAgo, end: now)
            case .lastSeason:
                let seasonAgo = calendar.date(byAdding: .year, value: -1, to: now)!
                return DateInterval(start: seasonAgo, end: now)
            case .allTime:
                return nil
            }
        }
    }
    
    private var filteredTeams: [Team] {
        if let selectedId = selectedTeamId,
           let selected = teamManager.teams.first(where: { $0.id == selectedId }) {
            return [selected]
        }
        return teamManager.teams
    }
    
    private var allPlayers: [Player] {
        filteredTeams.flatMap { $0.players }
    }
    
    private var filteredGames: [Game] {
        let allGames = filteredTeams.flatMap { $0.games }
        
        guard let dateRange = selectedTimeRange.dateRange else {
            return allGames
        }
        
        return allGames.filter { dateRange.contains($0.date) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header controls
                    headerControls
                    
                    if isLoading {
                        ProgressView("Loading stats...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if teamManager.teams.isEmpty {
                        EmptyStatsStateView(
                            icon: "chart.bar.xaxis",
                            title: "No Teams Yet",
                            description: "Create a team to start tracking statistics and performance."
                        )
                    } else {
                        // Stats content
                        statsContent
                    }
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isEditMode.toggle()
                    }) {
                        if isEditMode {
                            Label("Done", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Edit Stats", systemImage: "pencil.circle")
                        }
                    }
                }
            }
        }
        .onChange(of: teamManager.teams) { _ in
            if let selectedId = selectedTeamId {
                // Check if the selected team still exists
                if !teamManager.teams.contains(where: { $0.id == selectedId }) {
                    selectedTeamId = nil
                }
            }
        }
        .onAppear {
            recalculateAllStats()
        }
    }
    
    private var headerControls: some View {
        VStack(spacing: 16) {
            // Team selector
            if teamManager.teams.count > 1 {
                HStack {
                    Text("Team:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Team", selection: $selectedTeamId) {
                        Text("All Teams").tag(nil as UUID?)
                        ForEach(teamManager.teams, id: \.id) { team in
                            Text(team.name).tag(team.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Spacer()
                }
            }
            // Stat type selector
            Picker("Stat Type", selection: $selectedStatType) {
                Text("Overview").tag("Overview")
                Text("Players").tag("Players")
                Text("Teams").tag("Teams")
            }
            .pickerStyle(.segmented)
        }
    }
    
    @ViewBuilder
    private var statsContent: some View {
        switch selectedStatType {
        case "Overview":
            overviewSection
        case "Players":
            playersSection
        case "Teams":
            teamsSection
        default:
            overviewSection
        }
    }
    
    private var overviewSection: some View {
        let visibilitySettings = getVisibilitySettings()
        
        return VStack(spacing: 16) {
            let overallStats = calculateOverallStats()
            
            // Only show overview stats if permitted
            if visibilitySettings.showOverallStats {
                // Overview cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    MetricCard(
                        title: "Total Teams",
                        value: "\(filteredTeams.count)",
                        icon: "shield.fill",
                        color: Color(red: 0.05, green: 0.15, blue: 0.35),
                        trend: nil
                    )
                    
                    MetricCard(
                        title: "Total Players",
                        value: "\(overallStats.totalPlayers)",
                        icon: "person.fill",
                        color: Color(red: 0.13, green: 0.47, blue: 0.25),
                        trend: nil
                    )
                    
                    MetricCard(
                        title: "Games Played",
                        value: "\(overallStats.totalGames)",
                        icon: "sportscourt.fill",
                        color: .orange,
                        trend: nil
                    )
                    
                    // FIXED: Win Rate display with "No Games Played" handling
                    MetricCard(
                        title: "Win Rate",
                        value: overallStats.winPercentage < 0 ? "No Games Played" : String(format: "%.1f%%", overallStats.winPercentage),
                        icon: "trophy.fill",
                        color: .yellow,
                        trend: overallStats.winPercentage < 0 ? nil : overallStats.winTrend
                    )
                }
            }
            
            // Only show goals chart if permitted
            if visibilitySettings.showGoalsChart && !overallStats.recentGames.isEmpty {
                TotalGoalsChartView(teams: filteredTeams)
            }
            
            // Only show top performers if permitted
            if visibilitySettings.showTopPerformers && !overallStats.topPerformers.isEmpty {
                TopPerformersView(players: overallStats.topPerformers)
            }
            
            // Only show team comparison if permitted
            if visibilitySettings.showTeamComparison && filteredTeams.count > 1 {
                TeamsComparisonView(teams: filteredTeams)
            }
        }
    }
    
    // MARK: - Players Section
    private var playersSection: some View {
        return VStack(spacing: 16) {
            ForEach(filteredTeams, id: \.id) { team in
                PlayerStatsTeamSection(team: team, timeRange: selectedTimeRange, isEditMode: isEditMode)
            }
        }
    }
    
    // MARK: - Teams Section
    private var teamsSection: some View {
        let visibilitySettings = getVisibilitySettings()
        
        return VStack(spacing: 16) {
            ForEach(filteredTeams, id: \.id) { team in
                let analytics = calculateTeamAnalytics(for: team)
                FilteredTeamPerformanceCard(team: team, analytics: analytics, visibilitySettings: visibilitySettings)
            }
            
            // Only show monthly trends if permitted and single team
            if visibilitySettings.showMonthlyTrends && filteredTeams.count == 1 {
                let monthlyStats = calculateMonthlyStats(from: filteredGames)
                if !monthlyStats.isEmpty {
                    MonthlyTrendsChart(monthlyStats: monthlyStats)
                }
            }
        }
    }
    
    // NEW: Get visibility settings based on user role
    private func getVisibilitySettings() -> StatsVisibilitySettings {
        guard let firstTeam = filteredTeams.first else { return .coachDefault }
        
        let userRole = getCurrentUserRole()
        
        switch userRole {
        case .coach:
            return .coachDefault
        case .parent:
            return firstTeam.statsVisibilityForParents
        case .viewer:
            return firstTeam.statsVisibilityForViewers
        }
    }
    
    // Helper method to get current user role
    private func getCurrentUserRole() -> AccessLevel {
        // For single team view
        if let team = filteredTeams.first {
            return teamManager.getCurrentUserRole(for: team)
        }
        // For multi-team view, return most restrictive role
        let roles = filteredTeams.map { teamManager.getCurrentUserRole(for: $0) }
        if roles.contains(.viewer) { return .viewer }
        if roles.contains(.parent) { return .parent }
        return .coach
    }
    
    // MARK: - Fixed Helper Methods in StatsView
    private func calculateOverallStats() -> OverallStats {
        // FIXED: Only count games with results as completed games
        let completedGames = filteredGames.filter { $0.result != nil }
        let allPlayers = self.allPlayers
        
        let wins = completedGames.compactMap { $0.result }.filter { $0.goalsFor > $0.goalsAgainst }.count
        // FIXED: Calculate win percentage based on completed games only, with proper "No Games" handling
        let winPercentage = completedGames.isEmpty ? -1 : Double(wins) / Double(completedGames.count) * 100
        
        // UPDATED: Calculate top performers from actual game data instead of just season stats
        let topPerformers = calculateTopPerformersFromGames(players: allPlayers, games: completedGames)
        
        // Calculate monthly stats for trends
        let monthlyStats = calculateMonthlyStats(from: completedGames)
        
        return OverallStats(
            totalPlayers: allPlayers.count,
            totalGames: completedGames.count, // FIXED: Only count completed games
            winPercentage: winPercentage,
            winTrend: calculateWinTrend(from: completedGames),
            recentGames: Array(completedGames.suffix(10)),
            topPerformers: topPerformers,
            monthlyStats: monthlyStats
        )
    }
    
    // NEW: Calculate top performers based on actual game events instead of season stats
    private func calculateTopPerformersFromGames(players: [Player], games: [Game]) -> [Player] {
        var playerPoints: [UUID: Int] = [:]
        
        // Initialize all players with 0 points
        for player in players {
            playerPoints[player.id] = 0
        }
        
        // Count points from actual game events
        for game in games {
            for event in game.gameEvents {
                let currentPoints = playerPoints[event.playerId] ?? 0
                switch event.eventType {
                case .goal:
                    playerPoints[event.playerId] = currentPoints + 3 // Goals worth 3 points
                case .assist:
                    playerPoints[event.playerId] = currentPoints + 2 // Assists worth 2 points
                case .save:
                    playerPoints[event.playerId] = currentPoints + 1 // Saves worth 1 point
                default:
                    break
                }
            }
        }
        
        // Sort players by points and return top 5
        return players
            .sorted { (playerPoints[$0.id] ?? 0) > (playerPoints[$1.id] ?? 0) }
            .prefix(5)
            .map { $0 }
    }
    
    private func calculateTeamAnalytics(for team: Team) -> TeamAnalytics {
        let games = team.games.compactMap { $0.result }
        let wins = games.filter { $0.goalsFor > $0.goalsAgainst }.count
        let losses = games.filter { $0.goalsFor < $0.goalsAgainst }.count
        let draws = games.filter { $0.goalsFor == $0.goalsAgainst }.count
        let goalsFor = games.reduce(0) { $0 + $1.goalsFor }
        let goalsAgainst = games.reduce(0) { $0 + $1.goalsAgainst }
        
        // UPDATED: Calculate top scorer from actual game events, not season stats
        let topScorer = calculateTopScorerFromGames(team: team)
        let mostAssists = calculateTopAssisterFromGames(team: team)
        
        let cleanSheets = games.filter { $0.goalsAgainst == 0 }.count
        
        return TeamAnalytics(
            totalGames: games.count,
            wins: wins,
            losses: losses,
            draws: draws,
            goalsFor: goalsFor,
            goalsAgainst: goalsAgainst,
            topScorer: topScorer,
            mostAssists: mostAssists,
            cleanSheets: cleanSheets
        )
    }
    
    // NEW: Calculate top scorer from actual game events
    private func calculateTopScorerFromGames(team: Team) -> Player? {
        var goalCounts: [UUID: Int] = [:]
        
        for game in team.games {
            for event in game.gameEvents where event.eventType == .goal {
                goalCounts[event.playerId, default: 0] += 1
            }
        }
        
        guard let topScorerId = goalCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }
        
        return team.players.first { $0.id == topScorerId }
    }
    
    // NEW: Calculate top assister from actual game events
    private func calculateTopAssisterFromGames(team: Team) -> Player? {
        var assistCounts: [UUID: Int] = [:]
        
        for game in team.games {
            for event in game.gameEvents where event.eventType == .assist {
                assistCounts[event.playerId, default: 0] += 1
            }
        }
        
        guard let topAssisterId = assistCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }
        
        return team.players.first { $0.id == topAssisterId }
    }
    
    private func calculateWinTrend(from games: [Game]) -> Double? {
        let gamesWithResults = games.compactMap { $0.result }
        guard gamesWithResults.count >= 4 else { return nil }
        
        let recentGames = Array(gamesWithResults.suffix(4))
        let olderGames = Array(gamesWithResults.dropLast(4).suffix(4))
        
        guard !olderGames.isEmpty else { return nil }
        
        let recentWins = recentGames.filter { $0.goalsFor > $0.goalsAgainst }.count
        let olderWins = olderGames.filter { $0.goalsFor > $0.goalsAgainst }.count
        
        let recentWinRate = Double(recentWins) / Double(recentGames.count)
        let olderWinRate = Double(olderWins) / Double(olderGames.count)
        
        return (recentWinRate - olderWinRate) * 100
    }
    
    private func calculateMonthlyStats(from games: [Game]) -> [MonthlyStats] {
        let calendar = Calendar.current
        
        let groupedGames = Dictionary(grouping: games) { game in
            calendar.dateComponents([.year, .month], from: game.date)
        }
        
        return groupedGames.compactMap { components, games in
            guard let year = components.year, let month = components.month else { return nil }
            
            let wins = games.compactMap { $0.result }.filter { $0.goalsFor > $0.goalsAgainst }.count
            let totalGoals = games.compactMap { $0.result }.reduce(0) { $0 + $1.goalsFor }
            
            return MonthlyStats(
                month: calendar.date(from: components) ?? Date(),
                wins: wins,
                totalGames: games.count,
                totalGoals: totalGoals
            )
        }.sorted { $0.month < $1.month }
    }

    private func recalculateAllStats() {
        isLoading = true
        
        // FIXED: Capture teams array on main actor first
        let teamsToProcess = teamManager.teams
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Create array to hold updated teams
            var updatedTeams: [Team] = []
            
            // Recalculate stats for all teams using the captured array
            for team in teamsToProcess {
                var updatedTeam = team
                
                // Recalculate each player's season stats from game events
                for playerIndex in updatedTeam.players.indices {
                    let playerId = updatedTeam.players[playerIndex].id
                    
                    // Store the manual adjustments (preserve them)
                    let manualAdjustments = updatedTeam.players[playerIndex].seasonStats.manualAdjustments
                    
                    var calculatedStats = PlayerSeasonStats() // Start fresh
                    
                    // Count stats from all games (ALWAYS count, no locks)
                    for game in team.games {
                        // Count from game events
                        for event in game.gameEvents where event.playerId == playerId {
                            switch event.eventType {
                            case .goal:
                                calculatedStats.goals += 1
                            case .assist:
                                calculatedStats.assists += 1
                            case .shot, .shotOnTarget:
                                calculatedStats.shots += 1
                            case .save:
                                calculatedStats.saves += 1
                            case .goalAgainst:
                                calculatedStats.goalsConceded += 1
                            case .yellowCard:
                                calculatedStats.yellowCards += 1
                            case .redCard:
                                calculatedStats.redCards += 1
                            default:
                                break
                            }
                        }

                        var updatedGame = game
                        updatedGame.updateAllPresumedMinutes(with: updatedTeam)

                        if let playerGameStats = updatedGame.playerStats.first(where: { $0.playerId == playerId }) {
                            if updatedGame.isCompleted {
                                calculatedStats.gamesPlayed += 1
                            }
                            calculatedStats.minutesPlayed += playerGameStats.minutesPlayed
                        }
                    }

                    // Apply manual adjustments to calculated values
                    calculatedStats.goals += manualAdjustments["goals"] ?? 0
                    calculatedStats.assists += manualAdjustments["assists"] ?? 0
                    calculatedStats.shots += manualAdjustments["shots"] ?? 0
                    calculatedStats.saves += manualAdjustments["saves"] ?? 0
                    calculatedStats.goalsConceded += manualAdjustments["goalsConceded"] ?? 0
                    calculatedStats.yellowCards += manualAdjustments["yellowCards"] ?? 0
                    calculatedStats.redCards += manualAdjustments["redCards"] ?? 0
                    calculatedStats.gamesPlayed += manualAdjustments["gamesPlayed"] ?? 0
                    calculatedStats.minutesPlayed += manualAdjustments["minutesPlayed"] ?? 0
                    calculatedStats.shotOnTarget += manualAdjustments["shotOnTarget"] ?? 0
                    
                    // Restore the manual adjustments dictionary
                    calculatedStats.manualAdjustments = manualAdjustments

                    // Update the player's stats
                    updatedTeam.players[playerIndex].seasonStats = calculatedStats
                }

                updatedTeams.append(updatedTeam)
            }

            // Update on main thread
            DispatchQueue.main.async {
                for updatedTeam in updatedTeams {
                    if let index = self.teamManager.teams.firstIndex(where: { $0.id == updatedTeam.id }) {
                        self.teamManager.teams[index] = updatedTeam
                    }
                }

                self.teamManager.saveLocalData()
                self.isLoading = false

                print("✅ Recalculated stats for \(updatedTeams.count) teams with manual adjustments")
            }
        }
    }
}

struct PlayerStatsCard: View {
    let player: Player
    let isEditMode: Bool
    let onStatChange: ((String, Int) -> Void)?
    @EnvironmentObject var teamManager: TeamManager
    let team: Team?
    
    // CRITICAL FIX: Get fresh player data from TeamManager
    private var currentPlayer: Player {
        guard let team = team,
              let teamIndex = teamManager.teams.firstIndex(where: { $0.id == team.id }),
              let playerIndex = teamManager.teams[teamIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return player // Fallback to original player if not found
        }
        return teamManager.teams[teamIndex].players[playerIndex]
    }
    
    // Get visibility settings based on user role
    private var visibilitySettings: StatsVisibilitySettings {
        guard let team = team else { return .coachDefault }
        
        let userRole = teamManager.getCurrentUserRole(for: team)
        
        switch userRole {
        case .coach:
            return .coachDefault
        case .parent:
            return team.statsVisibilityForParents
        case .viewer:
            return team.statsVisibilityForViewers
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Player info - using currentPlayer for fresh data
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(currentPlayer.preferredPositionEnum.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text("\(currentPlayer.jerseyNumber)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    Text(currentPlayer.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text(currentPlayer.positions.joined(separator: "/"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            
            // Stats with visibility controls - using currentPlayer for fresh data
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Show stats based on visibility settings
                    Group {
                        if visibilitySettings.showGoals {
                            EditableStatsStatItem(
                                value: currentPlayer.seasonStats.goals,
                                label: "Goals",
                                isEditMode: isEditMode,
                                onValueChange: { onStatChange?("goals", $0) }
                            )
                        }
                        
                        if visibilitySettings.showAssists {
                            EditableStatsStatItem(
                                value: currentPlayer.seasonStats.assists,
                                label: "Assists",
                                isEditMode: isEditMode,
                                onValueChange: { onStatChange?("assists", $0) }
                            )
                        }
                        
                        if visibilitySettings.showShots {
                            EditableStatsStatItem(
                                value: currentPlayer.seasonStats.shots,
                                label: "Shots",
                                isEditMode: isEditMode,
                                onValueChange: { onStatChange?("shots", $0) }
                            )
                        }
                        
                        if visibilitySettings.showSaves {
                            EditableStatsStatItem(
                                value: currentPlayer.seasonStats.saves,
                                label: "Saves",
                                isEditMode: isEditMode,
                                onValueChange: { onStatChange?("saves", $0) }
                            )
                        }
                        
                        if visibilitySettings.showGoalsConceded {
                            EditableStatsStatItem(
                                value: currentPlayer.seasonStats.goalsConceded,
                                label: "Goals Conceded",
                                isEditMode: isEditMode,
                                onValueChange: { onStatChange?("goalsConceded", $0) }
                            )
                        }
                    }
                    
                    Group {
                        if visibilitySettings.showYellowCards {
                            EditableStatsStatItem(
                                value: currentPlayer.seasonStats.yellowCards,
                                label: "Yellow",
                                isEditMode: isEditMode,
                                onValueChange: { onStatChange?("yellowCards", $0) }
                            )
                        }
                        
                        if visibilitySettings.showRedCards {
                            EditableStatsStatItem(
                                value: currentPlayer.seasonStats.redCards,
                                label: "Red",
                                isEditMode: isEditMode,
                                onValueChange: { onStatChange?("redCards", $0) }
                            )
                        }
                        
                        if visibilitySettings.showGamesPlayed {
                            EditableStatsStatItem(
                                value: currentPlayer.seasonStats.gamesPlayed,
                                label: "Games",
                                isEditMode: isEditMode,
                                onValueChange: { onStatChange?("gamesPlayed", $0) }
                            )
                        }
                        
                        if visibilitySettings.showTotalPlayingTime, let team = team {
                            PlayingTimeStatItem(
                                player: currentPlayer,
                                team: team,
                                isEditMode: isEditMode,
                                onValueChange: { onStatChange?("minutesPlayed", $0) }
                            )
                        }
                        
                        if visibilitySettings.showRelativePlayingTime, let team = team {
                            RelativePlayingTimeStatItem(
                                player: currentPlayer,
                                team: team
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 200)
        }
        .padding(.vertical, 8)
    }
}
// MARK: - Stat Edit Sheet
struct StatEditSheet: View {
    let currentValue: Int
    let statLabel: String
    let onSave: (Int) -> Void
    
    @State private var newValue: String
    @Environment(\.presentationMode) var presentationMode
    
    init(currentValue: Int, statLabel: String, onSave: @escaping (Int) -> Void) {
        self.currentValue = currentValue
        self.statLabel = statLabel
        self.onSave = onSave
        self._newValue = State(initialValue: String(currentValue))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit \(statLabel)")) {
                    TextField("Value", text: $newValue)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit \(statLabel)")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    if let intValue = Int(newValue) {
                        onSave(intValue)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
// MARK: - Corrected PlayingTimeStatItem (REPLACE THE EXISTING ONE)
struct PlayingTimeStatItem: View {
    let player: Player
    let team: Team
    let isEditMode: Bool
    let onValueChange: ((Int) -> Void)?
    
    private var totalMinutes: Int {
        // Calculate total minutes from all games using presumed calculation
        var total = 0
        for game in team.games {
            total += game.calculatePresumedMinutesPlayed(for: player.id, with: team)
        }
        return total
    }
    
    private var displayText: String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        VStack(spacing: 1) {
            if isEditMode {
                HStack(spacing: 4) {
                    Button(action: {
                        onValueChange?(max(0, totalMinutes - 15))
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(totalMinutes <= 0 ? .gray : .red)
                            .font(.caption)
                    }
                    .disabled(totalMinutes <= 0)
                    
                    Text(displayText)
                        .font(.caption)
                        .bold()
                        .frame(minWidth: 35)
                    
                    Button(action: {
                        onValueChange?(totalMinutes + 15)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                            .font(.caption)
                    }
                }
            } else {
                Text(displayText)
                    .font(.subheadline)
                    .bold()
            }
            
            Text("Total Time")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 50)
    }
}

struct RelativePlayingTimeStatItem: View {
    let player: Player
    let team: Team
    
    private var relativePlayingTimePercentage: Int {
        var totalMinutesPlayed = 0
        var totalPossibleMinutes = 0
        let teamGameLength = team.defaultHalfLength * 2
        
        // Go through each game and sum up minutes only for games where player actually played
        for game in team.games {
            let playerMinutes = game.calculatePresumedMinutesPlayed(for: player.id, with: team)
            
            // Only include games where the player actually played (> 0 minutes)
            if playerMinutes > 0 {
                totalMinutesPlayed += playerMinutes
                totalPossibleMinutes += teamGameLength
            }
        }
        
        // Calculate percentage: SUM(Total Time) / SUM(Total Game Mins)
        guard totalPossibleMinutes > 0 else { return 0 }
        let percentage = Double(totalMinutesPlayed) / Double(totalPossibleMinutes) * 100
        return Int(percentage.rounded())
    }
    
    var body: some View {
        VStack(spacing: 1) {
            Text("\(relativePlayingTimePercentage)%")
                .font(.subheadline)
                .bold()
                .foregroundColor(colorForPercentage(relativePlayingTimePercentage))
            
            Text("Relative Time")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 50)
    }
    
    private func colorForPercentage(_ percentage: Int) -> Color {
        switch percentage {
        case 75...: return .green
        case 50..<75: return .orange
        case 25..<50: return .red
        default: return .gray
        }
    }
}

struct EditableStatsStatItem: View {
    let value: Int
    let label: String
    let isEditMode: Bool
    let onValueChange: ((Int) -> Void)?
    
    @State private var showingEditSheet = false
    
    var body: some View {
        VStack(spacing: 1) {
            if isEditMode {
                HStack(spacing: 4) {
                    Button(action: {
                        onValueChange?(max(0, value - 1))
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(value <= 0 ? .gray : .red)
                            .font(.caption)
                    }
                    .disabled(value <= 0)
                    
                    Text("\(value)")
                        .font(.caption)
                        .bold()
                        .frame(minWidth: 20)
                    
                    Button(action: {
                        onValueChange?(value + 1)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                            .font(.caption)
                    }
                }
            } else {
                Text("\(value)")
                    .font(.subheadline)
                    .bold()
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 35)
    }
}

struct PlayerStatsTeamSection: View {
    let team: Team
    let timeRange: EnhancedQuickStatsView.TimeRange
    let isEditMode: Bool
    @EnvironmentObject var teamManager: TeamManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(team.name)
                .font(.headline)
                .padding(.horizontal)
            
            if team.players.isEmpty {
                Text("No players in this team")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(team.players.sorted { $0.jerseyNumber < $1.jerseyNumber }, id: \.id) { player in
                        PlayerStatsCard(
                            player: player,
                            isEditMode: isEditMode,
                            onStatChange: { statType, newValue in
                                updatePlayerStat(player: player, statType: statType, newValue: newValue, team: team)
                            },
                            team: team
                        )
                        .padding(.horizontal)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private func updatePlayerStat(player: Player, statType: String, newValue: Int, team: Team) {
        // Find the team and player indices
        guard let teamIndex = teamManager.teams.firstIndex(where: { $0.id == team.id }),
              let playerIndex = teamManager.teams[teamIndex].players.firstIndex(where: { $0.id == player.id }) else {
            print("⚠️ Could not find team or player indices")
            return
        }
        
        // Create a mutable copy of the player
        var updatedPlayer = teamManager.teams[teamIndex].players[playerIndex]
        
        // Calculate current value from game events
        let gameEventValue = calculateGameEventValue(for: player, statType: statType, team: team)
        
        // Calculate the adjustment needed
        let adjustment = newValue - gameEventValue
        
        // Store the adjustment
        updatedPlayer.seasonStats.setManualAdjustment(statType, adjustment: adjustment)
        
        // CRITICAL FIX: Immediately update the actual stat value to reflect the new total
        switch statType {
        case "goals":
            updatedPlayer.seasonStats.goals = newValue
        case "assists":
            updatedPlayer.seasonStats.assists = newValue
        case "shots":
            updatedPlayer.seasonStats.shots = newValue
        case "saves":
            updatedPlayer.seasonStats.saves = newValue
        case "goalsConceded":
            updatedPlayer.seasonStats.goalsConceded = newValue
        case "yellowCards":
            updatedPlayer.seasonStats.yellowCards = newValue
        case "redCards":
            updatedPlayer.seasonStats.redCards = newValue
        case "gamesPlayed":
            updatedPlayer.seasonStats.gamesPlayed = newValue
        case "minutesPlayed":
            updatedPlayer.seasonStats.minutesPlayed = newValue
        case "shotOnTarget":
            updatedPlayer.seasonStats.shotOnTarget = newValue
        default:
            break
        }
        
        print("✅ Set adjustment for \(statType) for \(player.name): gameEvents=\(gameEventValue) + adjustment=\(adjustment) = \(newValue)")
        
        // Use the TeamManager's updatePlayer method which handles saves efficiently
        teamManager.updatePlayer(in: team, player: updatedPlayer)
        
        // Force UI refresh
        DispatchQueue.main.async {
            self.teamManager.objectWillChange.send()
        }
    }
    
    // Helper to calculate stat value from game events only
    private func calculateGameEventValue(for player: Player, statType: String, team: Team) -> Int {
        var count = 0
        
        for game in team.games {
            for event in game.gameEvents where event.playerId == player.id {
                switch (statType, event.eventType) {
                case ("goals", .goal):
                    count += 1
                case ("assists", .assist):
                    count += 1
                case ("shots", .shot), ("shots", .shotOnTarget):
                    count += 1
                case ("saves", .save):
                    count += 1
                case ("goalsConceded", .goalAgainst):
                    count += 1
                case ("yellowCards", .yellowCard):
                    count += 1
                case ("redCards", .redCard):
                    count += 1
                default:
                    break
                }
            }
            
            // Handle gamesPlayed and minutesPlayed
            if statType == "gamesPlayed" {
                if game.isCompleted && game.playerStats.contains(where: { $0.playerId == player.id }) {
                    count += 1
                }
            } else if statType == "minutesPlayed" {
                if let playerGameStats = game.playerStats.first(where: { $0.playerId == player.id }) {
                    count += playerGameStats.minutesPlayed
                }
            }
        }
        
        return count
    }
    
    private func recalculateStatsForTeam() {
        Task {
            guard let teamIndex = teamManager.teams.firstIndex(where: { $0.id == team.id }) else { return }
            
            var updatedTeam = teamManager.teams[teamIndex]
            
            for playerIndex in updatedTeam.players.indices {
                let playerId = updatedTeam.players[playerIndex].id
                
                // Store the manual adjustments (preserve them)
                let manualAdjustments = updatedTeam.players[playerIndex].seasonStats.manualAdjustments
                
                var calculatedStats = PlayerSeasonStats() // Start fresh
                
                // Count stats from all games (ALWAYS count)
                for game in updatedTeam.games {
                    // Count from game events
                    for event in game.gameEvents where event.playerId == playerId {
                        switch event.eventType {
                        case .goal:
                            calculatedStats.goals += 1
                        case .assist:
                            calculatedStats.assists += 1
                        case .shot, .shotOnTarget:
                            calculatedStats.shots += 1
                        case .save:
                            calculatedStats.saves += 1
                        case .goalAgainst:
                            calculatedStats.goalsConceded += 1
                        case .yellowCard:
                            calculatedStats.yellowCards += 1
                        case .redCard:
                            calculatedStats.redCards += 1
                        default:
                            break
                        }
                    }

                    var updatedGame = game
                    updatedGame.updateAllPresumedMinutes(with: updatedTeam)

                    if let playerGameStats = updatedGame.playerStats.first(where: { $0.playerId == playerId }) {
                        if updatedGame.isCompleted {
                            calculatedStats.gamesPlayed += 1
                        }
                        calculatedStats.minutesPlayed += playerGameStats.minutesPlayed
                    }
                }

                // Apply manual adjustments to calculated values
                calculatedStats.goals += manualAdjustments["goals"] ?? 0
                calculatedStats.assists += manualAdjustments["assists"] ?? 0
                calculatedStats.shots += manualAdjustments["shots"] ?? 0
                calculatedStats.saves += manualAdjustments["saves"] ?? 0
                calculatedStats.goalsConceded += manualAdjustments["goalsConceded"] ?? 0
                calculatedStats.yellowCards += manualAdjustments["yellowCards"] ?? 0
                calculatedStats.redCards += manualAdjustments["redCards"] ?? 0
                calculatedStats.gamesPlayed += manualAdjustments["gamesPlayed"] ?? 0
                calculatedStats.minutesPlayed += manualAdjustments["minutesPlayed"] ?? 0
                calculatedStats.shotOnTarget += manualAdjustments["shotOnTarget"] ?? 0
                
                // Restore the manual adjustments dictionary
                calculatedStats.manualAdjustments = manualAdjustments

                updatedTeam.players[playerIndex].seasonStats = calculatedStats
            }

            await MainActor.run {
                teamManager.teams[teamIndex] = updatedTeam
                teamManager.saveLocalData()
            }
        }
    }
}

struct StatsStatItem: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.subheadline)
                .bold()
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 35)
    }
}

// MARK: - Rest of Supporting Views (unchanged)
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Double?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
                if let trend = trend {
                    HStack(spacing: 4) {
                        Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                            .foregroundColor(trend >= 0 ? Color(red: 0.13, green: 0.47, blue: 0.25) : .red)
                            .font(.caption)
                        Text(String(format: "%.1f%%", abs(trend)))
                            .font(.caption)
                            .foregroundColor(trend >= 0 ? Color(red: 0.13, green: 0.47, blue: 0.25) : .red)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct TopPerformersView: View {
    let players: [Player]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Performers")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(rankColor(for: index))
                                    .frame(width: 50, height: 50)
                                
                                Text("\(index + 1)")
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
                            
                            VStack(spacing: 1) {
                                Text("\(player.seasonStats.goals + player.seasonStats.assists)")
                                    .font(.headline)
                                    .bold()
                                Text("points")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 80)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 1)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .orange
        default: return Color(red: 0.05, green: 0.15, blue: 0.35)
        }
    }
}

struct TeamPerformanceCard: View {
    let team: Team
    let analytics: TeamAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(team.name)
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Record")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analytics.wins)-\(analytics.losses)-\(analytics.draws)")
                        .font(.title3)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Win Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", analytics.winPercentage))
                        .font(.title3)
                        .bold()
                        .foregroundColor(analytics.winPercentage >= 50 ? Color(red: 0.13, green: 0.47, blue: 0.25) : .red)
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Goals For")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analytics.goalsFor)")
                        .font(.subheadline)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("Goal Diff")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analytics.goalDifference > 0 ? "+" : "")\(analytics.goalDifference)")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(analytics.goalDifference > 0 ? Color(red: 0.13, green: 0.47, blue: 0.25) : analytics.goalDifference < 0 ? .red : .gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Goals Against")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analytics.goalsAgainst)")
                        .font(.subheadline)
                        .bold()
                }
            }
            
            if let topScorer = analytics.topScorer {
                Divider()
                HStack {
                    Text("Top Scorer:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(topScorer.name)
                        .font(.caption)
                        .bold()
                    Text("(\(topScorer.seasonStats.goals) goals)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct TeamsComparisonView: View {
    let teams: [Team]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Teams Comparison")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(teams, id: \.id) { team in
                        TeamComparisonCard(team: team)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct TeamComparisonCard: View {
    let team: Team
    
    private var winPercentage: Double {
        // FIXED: Only count games with results
        let gamesWithResults = team.games.compactMap { $0.result }
        guard !gamesWithResults.isEmpty else { return -1 } // Use -1 to indicate no games
        let wins = gamesWithResults.filter { $0.goalsFor > $0.goalsAgainst }.count
        return Double(wins) / Double(gamesWithResults.count) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(team.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Win Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    // FIXED: Show "No Games" instead of 0%
                    if winPercentage < 0 {
                        Text("No Games")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.gray)
                    } else {
                        Text(String(format: "%.1f%%", winPercentage))
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(winPercentage >= 50 ? Color(red: 0.13, green: 0.47, blue: 0.25) : .red)
                    }
                }
                
                HStack {
                    Text("Games")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    // FIXED: Only count games with results
                    Text("\(team.games.compactMap { $0.result }.count)")
                        .font(.subheadline)
                        .bold()
                }
            }
        }
        .padding()
        .frame(width: 140)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct TotalGoalsChartView: View {
    let teams: [Team]
    
    private var teamGoalData: [(String, Int)] {
        teams.map { team in
            // FIXED: Calculate total goals from player seasonStats (includes manual adjustments)
            let totalGoals = team.players.reduce(0) { $0 + $1.seasonStats.goals }
            return (team.name, totalGoals)
        }.sorted { $0.1 > $1.1 } // Sort by goals descending
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total Goals by Team")
                .font(.headline)
                .padding(.horizontal)
            
            if teamGoalData.isEmpty || teamGoalData.allSatisfy({ $0.1 == 0 }) {
                Text("No goals scored yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // Horizontal bar chart
                VStack(spacing: 8) {
                    ForEach(Array(teamGoalData.enumerated()), id: \.offset) { index, data in
                        let (teamName, goals) = data
                        let maxGoals = teamGoalData.first?.1 ?? 1
                        let barWidth = goals > 0 ? CGFloat(goals) / CGFloat(maxGoals) * 200 : 0
                        
                        HStack {
                            Text(teamName)
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)
                            
                            HStack {
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: barWidth, height: 20)
                                    .cornerRadius(10)
                                
                                Spacer()
                            }
                            .frame(width: 200, alignment: .leading)
                            
                            Text("\(goals)")
                                .font(.caption)
                                .bold()
                                .frame(width: 30, alignment: .trailing)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct MonthlyTrendsChart: View {
    let monthlyStats: [MonthlyStats]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Performance")
                .font(.headline)
            
            if monthlyStats.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // Simplified chart
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(monthlyStats.indices, id: \.self) { index in
                            MonthlyStatBar(stat: monthlyStats[index])
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 120)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct MonthlyStatBar: View {
    let stat: MonthlyStats
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }
    
    private var safePercentage: Double {
        stat.winPercentage.isFinite ? min(stat.winPercentage, 100) : 0
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(Color.green)
                .frame(width: 30, height: max(4, safePercentage))
                .cornerRadius(2)
            
            Text(dateFormatter.string(from: stat.month))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct GameResultBadge: View {
    let result: GameResult?
    
    private var resultInfo: (text: String, color: Color) {
        guard let result = result else {
            return ("—", .gray)
        }
        
        if result.goalsFor > result.goalsAgainst {
            return ("W", Color(red: 0.13, green: 0.47, blue: 0.25))
        } else if result.goalsFor < result.goalsAgainst {
            return ("L", .red)
        } else {
            return ("D", .orange)
        }
    }
    
    var body: some View {
        Text(resultInfo.text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 25, height: 25)
            .background(Circle().fill(resultInfo.color))
    }
}

struct EmptyStatsStateView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - NEW: Filtered Team Performance Card with Visibility Controls
struct FilteredTeamPerformanceCard: View {
    let team: Team
    let analytics: TeamAnalytics
    let visibilitySettings: StatsVisibilitySettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(team.name)
                .font(.headline)
            
            if visibilitySettings.showTeamRecord {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Record")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(analytics.wins)-\(analytics.losses)-\(analytics.draws)")
                            .font(.title3)
                            .bold()
                    }
                    
                    Spacer()
                    
                    if visibilitySettings.showWinPercentage {
                        VStack(alignment: .trailing) {
                            Text("Win Rate")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", analytics.winPercentage))
                                .font(.title3)
                                .bold()
                                .foregroundColor(analytics.winPercentage >= 50 ? Color(red: 0.13, green: 0.47, blue: 0.25) : .red)
                        }
                    }
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Goals For")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analytics.goalsFor)")
                        .font(.subheadline)
                        .bold()
                }
                
                Spacer()
                
                if visibilitySettings.showGoalDifference {
                    VStack(alignment: .center) {
                        Text("Goal Diff")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(analytics.goalDifference > 0 ? "+" : "")\(analytics.goalDifference)")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(analytics.goalDifference > 0 ? Color(red: 0.13, green: 0.47, blue: 0.25) : analytics.goalDifference < 0 ? .red : .gray)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .trailing) {
                    Text("Goals Against")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analytics.goalsAgainst)")
                        .font(.subheadline)
                        .bold()
                }
            }
            
            if let topScorer = analytics.topScorer {
                Divider()
                HStack {
                    Text("Top Scorer:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(topScorer.name)
                        .font(.caption)
                        .bold()
                    Text("(\(topScorer.seasonStats.goals) goals)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Data Models
struct OverallStats {
    let totalPlayers: Int
    let totalGames: Int
    let winPercentage: Double
    let winTrend: Double?
    let recentGames: [Game]
    let topPerformers: [Player]
    let monthlyStats: [MonthlyStats]
}

struct MonthlyStats {
    let month: Date
    let wins: Int
    let totalGames: Int
    let totalGoals: Int
    
    var winPercentage: Double {
        totalGames > 0 ? Double(wins) / Double(totalGames) * 100 : 0
    }
}

// MARK: - Stats Visibility Settings (ADD THIS TO Models.swift)
struct StatsVisibilitySettings: Codable, Equatable {
    var showGoals: Bool = true
    var showAssists: Bool = true
    var showShots: Bool = true
    var showSaves: Bool = true
    var showGoalsConceded: Bool = false
    var showYellowCards: Bool = false
    var showRedCards: Bool = false
    var showGamesPlayed: Bool = true
    var showTotalPlayingTime: Bool = true
    var showRelativePlayingTime: Bool = false
    var showTeamRecord: Bool = true
    var showGoalDifference: Bool = true
    var showWinPercentage: Bool = true
    var showTopPerformers: Bool = true
    var showTeamComparison: Bool = false
    var showMonthlyTrends: Bool = false
    var showOverallStats: Bool = true
    var showGoalsChart: Bool = true
    
    // Preset configurations
    static let coachDefault = StatsVisibilitySettings(
        showGoals: true,
        showAssists: true,
        showShots: true,
        showSaves: true,
        showGoalsConceded: true,
        showYellowCards: true,
        showRedCards: true,
        showGamesPlayed: true,
        showTotalPlayingTime: true,
        showRelativePlayingTime: true,
        showTeamRecord: true,
        showGoalDifference: true,
        showWinPercentage: true,
        showTopPerformers: true,
        showTeamComparison: true,
        showMonthlyTrends: true,
        showOverallStats: true,
        showGoalsChart: true
    )
    
    static let parentFriendly = StatsVisibilitySettings(
        showGoals: true,
        showAssists: true,
        showShots: false,
        showSaves: true,
        showGoalsConceded: false,
        showYellowCards: false,
        showRedCards: false,
        showGamesPlayed: true,
        showTotalPlayingTime: true,
        showRelativePlayingTime: false,
        showTeamRecord: true,
        showGoalDifference: false,
        showWinPercentage: false,
        showTopPerformers: false,
        showTeamComparison: false,
        showMonthlyTrends: false,
        showOverallStats: true,
        showGoalsChart: true
    )
    
    static let basic = StatsVisibilitySettings(
        showGoals: true,
        showAssists: true,
        showShots: false,
        showSaves: false,
        showGoalsConceded: false,
        showYellowCards: false,
        showRedCards: false,
        showGamesPlayed: true,
        showTotalPlayingTime: false,
        showRelativePlayingTime: false,
        showTeamRecord: true,
        showGoalDifference: false,
        showWinPercentage: false,
        showTopPerformers: false,
        showTeamComparison: false,
        showMonthlyTrends: false,
        showOverallStats: true,
        showGoalsChart: false
    )
}

// MARK: - Team Extensions for Stats Visibility (ADD THIS TO Models.swift)
extension Team {
    // Stats visibility settings for different access levels
    var statsVisibilityForParents: StatsVisibilitySettings {
        get {
            // Try to decode from UserDefaults or Firebase
            if let data = UserDefaults.standard.data(forKey: "statsVisibility_parents_\(id.uuidString)"),
               let settings = try? JSONDecoder().decode(StatsVisibilitySettings.self, from: data) {
                return settings
            }
            return StatsVisibilitySettings.parentFriendly
        }
        set {
            // Save to UserDefaults (in production, save to Firebase)
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "statsVisibility_parents_\(id.uuidString)")
            }
        }
    }
    
    var statsVisibilityForViewers: StatsVisibilitySettings {
        get {
            if let data = UserDefaults.standard.data(forKey: "statsVisibility_viewers_\(id.uuidString)"),
               let settings = try? JSONDecoder().decode(StatsVisibilitySettings.self, from: data) {
                return settings
            }
            return StatsVisibilitySettings.basic
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "statsVisibility_viewers_\(id.uuidString)")
            }
        }
    }
}

// Type alias for compatibility
typealias StatsView = EnhancedQuickStatsView
