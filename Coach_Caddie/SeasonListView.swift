import SwiftUI

// MARK: - Season List View
struct SeasonListView: View {
    @Binding var team: Team
    @EnvironmentObject var teamManager: TeamManager
    @State private var showingNewSeason = false
    @State private var selectedSeasonForEdit: Season?
    @State private var showingDeleteAlert = false
    @State private var seasonToDelete: Season?
    @State private var showingMigrationAlert = false
    @State private var isMigrating = false
    @State private var migrationError: String?
    @State private var showingMigrationError = false
    @State private var showingMigrationSuccess = false
    @State private var migratedSeasonName: String = ""
    @State private var refreshID = UUID()
    @State private var showArchived: Bool = false
    
    // CRITICAL: Get team directly from teamManager to ensure fresh data
    private var currentTeam: Team {
        teamManager.teams.first(where: { $0.id == team.id }) ?? team
    }
    
    // Check migration locally - only check games, not practices
    private var needsMigration: Bool {
        guard !isMigrating else { return false }
        
        let validSeasonIds = Set(currentTeam.seasons.map { $0.id })
        
        let unassignedGames = currentTeam.games.filter { game in
            game.seasonId == nil || (game.seasonId != nil && !validSeasonIds.contains(game.seasonId!))
        }.count
        
        return unassignedGames > 0
    }

    private var unassignedGamesCount: Int {
        let validSeasonIds = Set(currentTeam.seasons.map { $0.id })
        return currentTeam.games.filter { game in
            game.seasonId == nil || (game.seasonId != nil && !validSeasonIds.contains(game.seasonId!))
        }.count
    }
    
    private var unassignedPracticesCount: Int {
        let validSeasonIds = Set(currentTeam.seasons.map { $0.id })
        return currentTeam.practices.filter { practice in
            practice.seasonId == nil || (practice.seasonId != nil && !validSeasonIds.contains(practice.seasonId!))
        }.count
    }
    
    var body: some View {
        List {
            allTimeStatsSection
            seasonStatusSection
            migrationSection
            currentSeasonsSection
            upcomingSeasonsSection
            pastSeasonsSection
            archiveToggleSection
            emptyStateSection
        }
        .id(refreshID)
        .navigationTitle("Seasons")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewSeason = true }) {
                    Image(systemName: "plus")
                }
                .disabled(isMigrating)
            }
        }
        .sheet(isPresented: $showingNewSeason, onDismiss: {
            // Sync binding from manager and refresh
            if let index = teamManager.teams.firstIndex(where: { $0.id == team.id }) {
                team = teamManager.teams[index]
            }
            refreshID = UUID()
        }) {
            NewSeasonView(team: $team)
                .environmentObject(teamManager)
        }
        .sheet(item: $selectedSeasonForEdit, onDismiss: {
            // Sync binding from manager and refresh
            if let index = teamManager.teams.firstIndex(where: { $0.id == team.id }) {
                team = teamManager.teams[index]
            }
            refreshID = UUID()
        }) { season in
            EditSeasonView(team: $team, season: season)
                .environmentObject(teamManager)
        }
        .alert("Delete Season", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let season = seasonToDelete {
                    deleteSeason(season)
                }
            }
        } message: {
            if let season = seasonToDelete {
                let gameCount = currentTeam.games(for: season.id).count
                let practiceCount = currentTeam.practices(for: season.id).count
                Text("Are you sure you want to delete '\(season.displayName)'? This will also remove the season assignment from \(gameCount) game(s) and \(practiceCount) practice(s).")
            }
        }
        .alert("Migrate Existing Data", isPresented: $showingMigrationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Migrate") {
                migrateExistingData()
            }
        } message: {
            Text("You have \(unassignedGamesCount) game(s) without a season. Would you like to create a season and assign them to it?")
        }
        .alert("Migration Complete", isPresented: $showingMigrationSuccess) {
            Button("OK") { }
        } message: {
            Text("Successfully created '\(migratedSeasonName)' and assigned \(currentTeam.games.count) game(s) and \(currentTeam.practices.count) practice(s) to it.")
        }
        .alert("Migration Failed", isPresented: $showingMigrationError) {
            Button("OK") { }
        } message: {
            Text(migrationError ?? "An unknown error occurred during migration.")
        }
        .overlay {
            if isMigrating {
                migrationOverlay
            }
        }
        .allowsHitTesting(!isMigrating)
        .onAppear {
            showArchived = currentTeam.showArchivedSeasons
        }
        // CRITICAL: Watch for changes in teamManager and refresh
        .onReceive(teamManager.objectWillChange) { _ in
            refreshID = UUID()
        }
    }

    // MARK: - Body Subsections

    @ViewBuilder
    private var allTimeStatsSection: some View {
        if !team.games.isEmpty {
            AllTimeStatsSection(team: team)
        }
    }

    @ViewBuilder
    private var seasonStatusSection: some View {
        if !currentTeam.seasons.isEmpty {
            Section {
                HStack {
                    Image(systemName: currentTeam.seasonStatus.icon)
                        .foregroundColor(.accentColor)
                    Text(currentTeam.seasonStatus.displayText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var migrationSection: some View {
        if needsMigration {
            migrationBanner
        }
    }

    @ViewBuilder
    private var currentSeasonsSection: some View {
        if !currentSeasons.isEmpty {
            Section {
                ForEach(currentSeasons) { season in
                    SeasonRowView(season: season, team: currentTeam, isEffectiveActive: currentTeam.effectiveActiveSeason?.id == season.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSeasonForEdit = season
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                seasonToDelete = season
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                toggleArchive(season)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                }
            } header: {
                Text("Current Seasons")
            }
        }
    }

    @ViewBuilder
    private var upcomingSeasonsSection: some View {
        if !upcomingSeasons.isEmpty {
            Section {
                ForEach(upcomingSeasons) { season in
                    SeasonRowView(season: season, team: currentTeam, isEffectiveActive: currentTeam.effectiveActiveSeason?.id == season.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSeasonForEdit = season
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                seasonToDelete = season
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text("Upcoming")
            }
        }
    }

    @ViewBuilder
    private var pastSeasonsSection: some View {
        if !pastSeasons.isEmpty {
            Section {
                ForEach(pastSeasons) { season in
                    SeasonRowView(season: season, team: currentTeam, isEffectiveActive: false)
                        .opacity(season.isArchived ? 0.6 : 1.0)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSeasonForEdit = season
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                seasonToDelete = season
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            if season.isArchived {
                                Button {
                                    toggleArchive(season)
                                } label: {
                                    Label("Unarchive", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            } else {
                                Button {
                                    toggleArchive(season)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                }
            } header: {
                Text("Past Seasons")
            }
        }
    }

    @ViewBuilder
    private var archiveToggleSection: some View {
        if team.seasons.contains(where: { $0.isArchived }) {
            Section {
                Toggle("Show Archived Seasons", isOn: $showArchived)
                    .onChange(of: showArchived) { newValue in
                        if let index = teamManager.teams.firstIndex(where: { $0.id == team.id }) {
                            teamManager.teams[index].showArchivedSeasons = newValue
                            team.showArchivedSeasons = newValue
                            teamManager.saveLocalData()
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var emptyStateSection: some View {
        if team.seasons.isEmpty && !needsMigration {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Seasons Yet")
                        .font(.headline)
                    
                    Text("Create a season to start organizing your games and practices.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: { showingNewSeason = true }) {
                        Label("Create First Season", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
    }

    private var migrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Migrating Data...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Please wait while your games and practices are being organized.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
        }
    }
    
    private var currentSeasons: [Season] {
        let today = Calendar.current.startOfDay(for: Date())
        return currentTeam.seasons.filter { season in
            let start = Calendar.current.startOfDay(for: season.startDate)
            let end = Calendar.current.startOfDay(for: season.endDate)
            let isCurrent = today >= start && today <= end
            let shouldShow = showArchived || !season.isArchived
            return isCurrent && shouldShow
        }.sorted { $0.startDate > $1.startDate }
    }

    private var upcomingSeasons: [Season] {
        let today = Calendar.current.startOfDay(for: Date())
        return currentTeam.seasons.filter { season in
            let isUpcoming = Calendar.current.startOfDay(for: season.startDate) > today
            let shouldShow = showArchived || !season.isArchived
            return isUpcoming && shouldShow
        }.sorted { $0.startDate < $1.startDate }
    }

    private var pastSeasons: [Season] {
        let today = Calendar.current.startOfDay(for: Date())
        return currentTeam.seasons.filter { season in
            let isPast = Calendar.current.startOfDay(for: season.endDate) < today
            let shouldShow = showArchived || !season.isArchived
            return isPast && shouldShow
        }.sorted { $0.endDate > $1.endDate }
    }
    
    // MARK: - Migration Banner
    private var migrationBanner: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Migration Needed")
                        .font(.headline)
                }
                
                Text("You have \(unassignedGamesCount) game(s) without a season.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: { showingMigrationAlert = true }) {
                    Text("Migrate to Season")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isMigrating)
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Helper to update team in manager
    
    private func updateTeamInManager() {
        if let index = teamManager.teams.firstIndex(where: { $0.id == team.id }) {
            teamManager.teams[index] = team
        }
        teamManager.updateTeamLocalOnly(team)
    }
    
    // MARK: - Actions
    
    private func toggleArchive(_ season: Season) {
        guard let index = team.seasons.firstIndex(where: { $0.id == season.id }) else { return }
        team.seasons[index].isArchived.toggle()
        
        Task {
            do {
                try await teamManager.firebaseManager.updateSeason(team.seasons[index], in: team)
                await MainActor.run {
                    updateTeamInManager()
                    refreshID = UUID()
                }
            } catch {
                print("Failed to update season: \(error)")
            }
        }
    }
    
    private func deleteSeason(_ season: Season) {
        Task {
            do {
                try await teamManager.firebaseManager.deleteSeason(season, from: team)
                
                await MainActor.run {
                    // Update the manager's team first
                    if let teamIndex = teamManager.teams.firstIndex(where: { $0.id == team.id }) {
                        teamManager.teams[teamIndex].seasons.removeAll { $0.id == season.id }
                        
                        // Clear seasonId from associated games and practices
                        for index in teamManager.teams[teamIndex].games.indices {
                            if teamManager.teams[teamIndex].games[index].seasonId == season.id {
                                teamManager.teams[teamIndex].games[index].seasonId = nil
                            }
                        }
                        for index in teamManager.teams[teamIndex].practices.indices {
                            if teamManager.teams[teamIndex].practices[index].seasonId == season.id {
                                teamManager.teams[teamIndex].practices[index].seasonId = nil
                            }
                        }
                        
                        // Clear active season if this was it
                        if teamManager.teams[teamIndex].activeSeasonId == season.id {
                            teamManager.teams[teamIndex].activeSeasonId = nil
                        }
                        
                        // Update the binding FROM the manager
                        team = teamManager.teams[teamIndex]
                        
                        // Save locally
                        teamManager.saveLocalData()
                        
                        // CRITICAL: Force TeamManager to notify observers
                        teamManager.objectWillChange.send()
                        
                        // Force UI refresh
                        refreshID = UUID()
                    }
                }
            } catch {
                print("Failed to delete season: \(error)")
            }
        }
    }
    
    private func migrateExistingData() {
        guard !isMigrating else {
            print("⚠️ Migration already in progress, ignoring duplicate call")
            return
        }
        
        isMigrating = true
        migrationError = nil
        
        Task {
            do {
                print("🚀 Starting migration...")
                
                let newSeason = try await teamManager.firebaseManager.migrateExistingDataToSeason(
                    for: team
                )
                
                await MainActor.run {
                    print("✅ Migration successful, updating local data...")
                    
                    guard let teamIndex = teamManager.teams.firstIndex(where: { $0.id == team.id }) else {
                        print("❌ Could not find team in manager")
                        isMigrating = false
                        return
                    }
                    
                    // Add the new season to the manager's team
                    teamManager.teams[teamIndex].seasons.append(newSeason)
                    teamManager.teams[teamIndex].activeSeasonId = newSeason.id
                    
                    // Update seasonId on games only (not practices)
                    for gameIndex in teamManager.teams[teamIndex].games.indices {
                        if teamManager.teams[teamIndex].games[gameIndex].seasonId == nil {
                            teamManager.teams[teamIndex].games[gameIndex].seasonId = newSeason.id
                        }
                    }
                    
                    // Update the binding
                    team = teamManager.teams[teamIndex]
                    
                    // Save locally
                    teamManager.saveLocalData()
                    
                    // Set success state
                    migratedSeasonName = newSeason.displayName
                    isMigrating = false
                    
                    // Force UI refresh
                    refreshID = UUID()
                    
                    // Show success
                    showingMigrationSuccess = true
                    
                    print("🎉 Local data updated successfully")
                    print("📊 Games with seasonId: \(team.games.filter { $0.seasonId != nil }.count)/\(team.games.count)")
                    print("📅 Seasons count: \(team.seasons.count)")
                }
            } catch {
                await MainActor.run {
                    print("❌ Migration failed: \(error)")
                    migrationError = error.localizedDescription
                    isMigrating = false
                    showingMigrationError = true
                }
            }
        }
    }
}

// MARK: - All Time Stats Section
struct AllTimeStatsSection: View {
    let team: Team
    
    private var allTimeRecord: (wins: Int, losses: Int, draws: Int) {
        team.record
    }
    
    private var totalGoalsFor: Int {
        team.games.compactMap { $0.result }.reduce(0) { $0 + $1.goalsFor }
    }
    
    private var totalGoalsAgainst: Int {
        team.games.compactMap { $0.result }.reduce(0) { $0 + $1.goalsAgainst }
    }
    
    private var completedGamesCount: Int {
        team.games.filter { $0.result != nil }.count
    }
    
    private var winPercentage: Double {
        guard completedGamesCount > 0 else { return 0 }
        return Double(allTimeRecord.wins) / Double(completedGamesCount) * 100
    }
    
    var body: some View {
        Section {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                        .font(.title2)
                    
                    Text("All-Time Statistics")
                        .font(.headline)
                    
                    Spacer()
                }
                
                // Stats Grid
                HStack(spacing: 0) {
                    // Total Players
                    StatBox(
                        value: "\(team.players.count)",
                        label: "Players",
                        icon: "person.fill",
                        color: .blue
                    )
                    
                    Divider()
                        .frame(height: 50)
                    
                    // Total Games
                    StatBox(
                        value: "\(team.games.count)",
                        label: "Games",
                        icon: "sportscourt",
                        color: .orange
                    )
                    
                    Divider()
                        .frame(height: 50)
                    
                    // Win %
                    StatBox(
                        value: completedGamesCount > 0 ? String(format: "%.0f%%", winPercentage) : "-",
                        label: "Win %",
                        icon: "percent",
                        color: Color(red: 0.13, green: 0.47, blue: 0.25)
                    )
                }
                
                // Record and Goals Row
                if completedGamesCount > 0 {
                    HStack(spacing: 20) {
                        // Record
                        VStack(spacing: 4) {
                            Text("\(allTimeRecord.wins)W - \(allTimeRecord.losses)L - \(allTimeRecord.draws)D")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Record")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        // Goals
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Text("\(totalGoalsFor)")
                                    .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                                Text("-")
                                Text("\(totalGoalsAgainst)")
                                    .foregroundColor(.red)
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            
                            Text("GF - GA")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Stat Box (for All Time Stats)
struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Season Row View
struct SeasonRowView: View {
    let season: Season
    let team: Team
    var isEffectiveActive: Bool = false
    
    // Determine if this season is truly current (we're within its date range)
    private var isTrulyCurrent: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.startOfDay(for: season.startDate)
        let end = Calendar.current.startOfDay(for: season.endDate)
        return today >= start && today <= end
    }
    
    // Determine if this is an upcoming season
    private var isUpcoming: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.startOfDay(for: season.startDate)
        return start > today
    }
    
    // Determine if this is a past season
    private var isPast: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: season.endDate)
        return end < today
    }
    
    // Season stats computed properties
    private var seasonGames: [Game] {
        team.games(for: season.id)
    }
    
    private var seasonRecord: (wins: Int, losses: Int, draws: Int) {
        team.record(for: season.id)
    }
    
    private var goalsFor: Int {
        seasonGames.compactMap { $0.result }.reduce(0) { $0 + $1.goalsFor }
    }
    
    private var goalsAgainst: Int {
        seasonGames.compactMap { $0.result }.reduce(0) { $0 + $1.goalsAgainst }
    }
    
    private var hasCompletedGames: Bool {
        seasonGames.contains { $0.result != nil }
    }
    
    var body: some View {
        HStack {
            // Season type icon
            Image(systemName: season.type.icon)
                .foregroundColor(season.type.color)
                .font(.title2)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(season.displayName)
                        .font(.headline)
                    
                    // Show appropriate badge based on actual status
                    if isTrulyCurrent {
                        Text("CURRENT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    } else if isUpcoming && isEffectiveActive {
                        Text("NEXT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    } else if isPast && isEffectiveActive && !season.isArchived {
                        Text("MOST RECENT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                    
                    if season.isArchived {
                        Text("ARCHIVED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray)
                            .cornerRadius(4)
                    }
                }
                
                Text(dateRangeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Stats row: Active Players, Games, Record
                HStack(spacing: 12) {
                    // Active players for this season
                    Label("\(season.activePlayerIds.count)", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Game count
                    let gameCount = seasonGames.count
                    Label("\(gameCount)", systemImage: "sportscourt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Record (if has completed games)
                    if hasCompletedGames {
                        Text("\(seasonRecord.wins)W-\(seasonRecord.losses)L-\(seasonRecord.draws)D")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(recordColor)
                        
                        // Goals For/Against
                        Text("\(goalsFor)-\(goalsAgainst)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: season.startDate)) - \(formatter.string(from: season.endDate))"
    }
    
    private var recordColor: Color {
        if seasonRecord.wins > seasonRecord.losses {
            return Color(red: 0.13, green: 0.47, blue: 0.25) // Green for winning record
        } else if seasonRecord.losses > seasonRecord.wins {
            return .red
        } else {
            return .orange
        }
    }
}

// MARK: - New Season View
struct NewSeasonView: View {
    @Binding var team: Team
    @EnvironmentObject var teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var seasonType: SeasonType = .fall
    @State private var year = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60 * 60 * 24 * 90) // 90 days
    @State private var selectedPlayerIds: Set<UUID> = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                // Season Type
                Section {
                    Picker("Season Type", selection: $seasonType) {
                        ForEach(SeasonType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .onChange(of: seasonType) { newType in
                        updateNameSuggestion()
                    }
                    
                    TextField("Year (e.g., 2024)", text: $year)
                        .keyboardType(.numberPad)
                        .onChange(of: year) { _ in
                            updateNameSuggestion()
                        }
                    
                    if seasonType == .tournament {
                        TextField("Tournament Name", text: $name)
                    } else {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(suggestedName)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Season Info")
                } footer: {
                    if seasonType == .tournament {
                        Text("Enter a custom name for your tournament.")
                    }
                }
                
                // Dates
                Section {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                } header: {
                    Text("Dates")
                } footer: {
                    Text("Games can only be added to seasons where the end date hasn't passed.")
                }
                
                // Active Roster
                Section {
                    if team.players.isEmpty {
                        Text("No players on team roster yet")
                            .foregroundColor(.secondary)
                    } else {
                        Button(action: selectAllPlayers) {
                            HStack {
                                Text(selectedPlayerIds.count == team.players.count ? "Deselect All" : "Select All")
                                Spacer()
                                Text("\(selectedPlayerIds.count)/\(team.players.count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        ForEach(team.players.sorted { $0.jerseyNumber < $1.jerseyNumber }) { player in
                            PlayerSelectionRow(
                                player: player,
                                isSelected: selectedPlayerIds.contains(player.id),
                                onToggle: { togglePlayer(player.id) }
                            )
                        }
                    }
                } header: {
                    Text("Active Roster")
                } footer: {
                    Text("Select which players are active for this season. You can change this later.")
                }
                
                // Error Message
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Season")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createSeason()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                // Set default year
                year = String(Calendar.current.component(.year, from: Date()))
                // Select all players by default
                selectedPlayerIds = Set(team.players.map { $0.id })
            }
            .overlay {
                if isSaving {
                    ProgressView("Creating season...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var suggestedName: String {
        if seasonType == .tournament {
            return name.isEmpty ? "Tournament" : name
        }
        return "\(seasonType.rawValue) \(year)"
    }
    
    private var isValid: Bool {
        if year.isEmpty { return false }
        if seasonType == .tournament && name.isEmpty { return false }
        if endDate <= startDate { return false }
        return true
    }
    
    // MARK: - Actions
    
    private func updateNameSuggestion() {
        if seasonType != .tournament {
            name = ""
        }
    }
    
    private func selectAllPlayers() {
        if selectedPlayerIds.count == team.players.count {
            selectedPlayerIds.removeAll()
        } else {
            selectedPlayerIds = Set(team.players.map { $0.id })
        }
    }
    
    private func togglePlayer(_ playerId: UUID) {
        if selectedPlayerIds.contains(playerId) {
            selectedPlayerIds.remove(playerId)
        } else {
            selectedPlayerIds.insert(playerId)
        }
    }
    
    private func createSeason() {
        isSaving = true
        errorMessage = nil
        
        let finalName = seasonType == .tournament ? name : "\(seasonType.rawValue) \(year)"
        
        let newSeason = Season(
            name: finalName,
            type: seasonType,
            year: year,
            startDate: startDate,
            endDate: endDate,
            activePlayerIds: Array(selectedPlayerIds),
            guestPlayers: [],
            isArchived: false
        )
        
        Task {
            do {
                // Save only the season to Firebase
                try await teamManager.firebaseManager.saveSeason(newSeason, in: team)
                
                // Update activeSeasonId in Firebase if needed
                let shouldSetActive = team.activeSeasonId == nil || newSeason.isActive
                if shouldSetActive {
                    try? await teamManager.firebaseManager.updateTeamField(
                        teamId: team.id,
                        field: "activeSeasonId",
                        value: newSeason.id.uuidString  // Fixed: was season.id, should be newSeason.id
                    )
                }
                
                await MainActor.run {
                    // Find the team in teamManager to preserve games
                    guard let teamIndex = teamManager.teams.firstIndex(where: { $0.id == team.id }) else {
                        isSaving = false
                        presentationMode.wrappedValue.dismiss()
                        return
                    }
                    
                    // Add the new season
                    teamManager.teams[teamIndex].seasons.append(newSeason)
                    
                    // Set as active if first or current
                    if shouldSetActive {
                        teamManager.teams[teamIndex].activeSeasonId = newSeason.id
                    }
                    
                    // Update binding from manager (preserves games)
                    team = teamManager.teams[teamIndex]
                    
                    // Save locally only
                    teamManager.saveLocalData()
                    
                    isSaving = false
                    presentationMode.wrappedValue.dismiss()
                    
                    print("✅ Season created without touching games")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create season: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Player Selection Row
struct PlayerSelectionRow: View {
    let player: Player
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                    
                    Text("\(player.jerseyNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .foregroundColor(.primary)
                    
                    Text(player.preferredPosition)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .secondary)
                    .font(.title3)
            }
        }
    }
}

struct EditSeasonView: View {
    @Binding var team: Team
    let season: Season
    @EnvironmentObject var teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name: String
    @State private var seasonType: SeasonType
    @State private var year: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isArchived: Bool
    @State private var isSaving = false
    @State private var showingRosterView = false
    @State private var showingGuestPlayers = false
    
    // CRITICAL: Get team directly from teamManager to ensure fresh data
    private var currentTeam: Team {
        teamManager.teams.first(where: { $0.id == team.id }) ?? team
    }
    
    init(team: Binding<Team>, season: Season) {
        self._team = team
        self.season = season
        self._name = State(initialValue: season.name)
        self._seasonType = State(initialValue: season.type)
        self._year = State(initialValue: season.year)
        self._startDate = State(initialValue: season.startDate)
        self._endDate = State(initialValue: season.endDate)
        self._isArchived = State(initialValue: season.isArchived)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Season Info
                Section {
                    Picker("Season Type", selection: $seasonType) {
                        ForEach(SeasonType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    
                    TextField("Year", text: $year)
                        .keyboardType(.numberPad)
                    
                    if seasonType == .tournament {
                        TextField("Tournament Name", text: $name)
                    }
                } header: {
                    Text("Season Info")
                }
                
                // Dates
                Section {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                } header: {
                    Text("Dates")
                }
                
                // Stats Summary
                Section {
                    let games = currentTeam.games(for: season.id)
                    let practices = currentTeam.practices(for: season.id)
                    let record = currentTeam.record(for: season.id)
                    
                    HStack {
                        Text("Games")
                        Spacer()
                        Text("\(games.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Practices")
                        Spacer()
                        Text("\(practices.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if !games.isEmpty {
                        HStack {
                            Text("Record")
                            Spacer()
                            Text("\(record.wins)W - \(record.losses)L - \(record.draws)D")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Statistics")
                }
                
                // Roster Management
                Section {
                    NavigationLink {
                        SeasonRosterView(team: $team, season: season)
                            .environmentObject(teamManager)
                    } label: {
                        HStack {
                            Text("Active Roster")
                            Spacer()
                            Text("\(season.activePlayerIds.count) players")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if seasonType == .tournament {
                        NavigationLink {
                            GuestPlayersView(team: $team, season: season)
                                .environmentObject(teamManager)
                        } label: {
                            HStack {
                                Text("Guest Players")
                                Spacer()
                                Text("\(season.guestPlayers.count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Roster")
                }
                
                // Set as Active
                Section {
                    Toggle("Archived", isOn: $isArchived)
                    
                    if currentTeam.activeSeasonId != season.id {
                        Button("Set as Active Season") {
                            setAsActive()
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("This is the active season")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Status")
                }
            }
            .navigationTitle("Edit Season")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSeason()
                    }
                    .disabled(isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Saving...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
            }
        }
    }
    
    private func setAsActive() {
        // Find the team in teamManager to preserve all data (including games)
        guard let teamIndex = teamManager.teams.firstIndex(where: { $0.id == team.id }) else { return }
        
        // Update only activeSeasonId
        teamManager.teams[teamIndex].activeSeasonId = season.id
        
        // Update the binding from the manager
        team = teamManager.teams[teamIndex]
        
        // Save only the activeSeasonId field to Firebase, NOT the whole team
        Task {
            do {
                try await teamManager.firebaseManager.updateTeamField(
                    teamId: team.id,
                    field: "activeSeasonId",
                    value: season.id.uuidString
                )
                print("✅ Updated activeSeasonId in Firebase")
            } catch {
                print("❌ Failed to update activeSeasonId: \(error)")
            }
        }
        
        // Save locally only
        teamManager.saveLocalData()
        
        // CRITICAL: Notify observers to refresh UI
        teamManager.objectWillChange.send()
    }
    
    private func saveSeason() {
        isSaving = true
        
        // Find the team in teamManager to preserve all data (including games)
        guard let teamIndex = teamManager.teams.firstIndex(where: { $0.id == team.id }),
              let seasonIndex = teamManager.teams[teamIndex].seasons.firstIndex(where: { $0.id == season.id }) else {
            isSaving = false
            return
        }
        
        // Build updated season
        var updatedSeason = teamManager.teams[teamIndex].seasons[seasonIndex]
        updatedSeason.name = seasonType == .tournament ? name : "\(seasonType.rawValue) \(year)"
        updatedSeason.type = seasonType
        updatedSeason.year = year
        updatedSeason.startDate = startDate
        updatedSeason.endDate = endDate
        updatedSeason.isArchived = isArchived
        
        Task {
            do {
                // Save only the season to Firebase (not the whole team)
                try await teamManager.firebaseManager.updateSeason(updatedSeason, in: team)
                
                await MainActor.run {
                    // Update the season in teamManager
                    teamManager.teams[teamIndex].seasons[seasonIndex] = updatedSeason
                    
                    // Update the binding from teamManager (preserves games)
                    team = teamManager.teams[teamIndex]
                    
                    // Save locally only - do NOT call updateTeam which triggers Firebase save
                    teamManager.saveLocalData()
                    
                    isSaving = false
                    presentationMode.wrappedValue.dismiss()
                    
                    print("✅ Season saved without touching games")
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("❌ Failed to save season: \(error)")
                }
            }
        }
    }
}

// MARK: - Season Roster View
struct SeasonRosterView: View {
    @Binding var team: Team
    let season: Season
    @EnvironmentObject var teamManager: TeamManager
    @State private var selectedPlayerIds: Set<UUID>
    @State private var isSaving = false
    
    init(team: Binding<Team>, season: Season) {
        self._team = team
        self.season = season
        self._selectedPlayerIds = State(initialValue: Set(season.activePlayerIds))
    }
    
    var body: some View {
        List {
            Section {
                Button(action: selectAllPlayers) {
                    HStack {
                        Text(selectedPlayerIds.count == team.players.count ? "Deselect All" : "Select All")
                        Spacer()
                        Text("\(selectedPlayerIds.count)/\(team.players.count) active")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                ForEach(team.players.sorted { $0.jerseyNumber < $1.jerseyNumber }) { player in
                    PlayerSelectionRow(
                        player: player,
                        isSelected: selectedPlayerIds.contains(player.id),
                        onToggle: { togglePlayer(player.id) }
                    )
                }
            } header: {
                Text("Team Roster")
            } footer: {
                Text("Players not selected will not appear in lineups for this season's games.")
            }
        }
        .navigationTitle("Season Roster")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveRoster()
                }
                .disabled(isSaving)
            }
        }
        .overlay {
            if isSaving {
                ProgressView("Saving...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
            }
        }
    }
    
    private func selectAllPlayers() {
        if selectedPlayerIds.count == team.players.count {
            selectedPlayerIds.removeAll()
        } else {
            selectedPlayerIds = Set(team.players.map { $0.id })
        }
    }
    
    private func togglePlayer(_ playerId: UUID) {
        if selectedPlayerIds.contains(playerId) {
            selectedPlayerIds.remove(playerId)
        } else {
            selectedPlayerIds.insert(playerId)
        }
    }
    
    private func saveRoster() {
        isSaving = true
        
        guard let index = team.seasons.firstIndex(where: { $0.id == season.id }) else {
            isSaving = false
            return
        }
        
        Task {
            do {
                try await teamManager.firebaseManager.updateSeasonRoster(
                    seasonId: season.id,
                    activePlayerIds: Array(selectedPlayerIds),
                    in: team
                )
                
                await MainActor.run {
                    team.seasons[index].activePlayerIds = Array(selectedPlayerIds)
                    teamManager.updateTeam(team)
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("Failed to save roster: \(error)")
                }
            }
        }
    }
}

// MARK: - Guest Players View
struct GuestPlayersView: View {
    @Binding var team: Team
    let season: Season
    @EnvironmentObject var teamManager: TeamManager
    @State private var showingAddGuest = false
    @State private var guestToPromote: GuestPlayer?
    @State private var showingPromoteAlert = false
    
    private var currentSeason: Season? {
        team.seasons.first(where: { $0.id == season.id })
    }
    
    var body: some View {
        List {
            if let currentSeason = currentSeason {
                if currentSeason.guestPlayers.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No Guest Players")
                                .font(.headline)
                            
                            Text("Add temporary players for this tournament.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                } else {
                    Section {
                        ForEach(currentSeason.guestPlayers) { guest in
                            GuestPlayerRow(guest: guest)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        removeGuest(guest)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        guestToPromote = guest
                                        showingPromoteAlert = true
                                    } label: {
                                        Label("Promote", systemImage: "arrow.up.circle")
                                    }
                                    .tint(.green)
                                }
                        }
                    } header: {
                        Text("Guest Players (\(currentSeason.guestPlayers.count))")
                    }
                }
            }
        }
        .navigationTitle("Guest Players")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddGuest = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddGuest) {
            AddGuestPlayerView(team: $team, season: season)
                .environmentObject(teamManager)
        }
        .alert("Promote to Roster", isPresented: $showingPromoteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Promote") {
                if let guest = guestToPromote {
                    promoteGuest(guest)
                }
            }
        } message: {
            if let guest = guestToPromote {
                Text("Promote '\(guest.name)' to the permanent team roster? Their stats will be transferred.")
            }
        }
    }
    
    private func removeGuest(_ guest: GuestPlayer) {
        guard var currentSeason = currentSeason else { return }
        
        Task {
            do {
                try await teamManager.firebaseManager.removeGuestPlayer(guest, from: currentSeason, in: team)
                
                await MainActor.run {
                    if let seasonIndex = team.seasons.firstIndex(where: { $0.id == season.id }) {
                        team.seasons[seasonIndex].guestPlayers.removeAll { $0.id == guest.id }
                        teamManager.updateTeam(team)
                    }
                }
            } catch {
                print("Failed to remove guest: \(error)")
            }
        }
    }
    
    private func promoteGuest(_ guest: GuestPlayer) {
        guard let currentSeason = currentSeason else { return }
        
        Task {
            do {
                let newPlayer = try await teamManager.firebaseManager.promoteGuestToRoster(
                    guest,
                    in: currentSeason,
                    team: team
                )
                
                await MainActor.run {
                    // Add player to team
                    team.players.append(newPlayer)
                    
                    // Remove from guests
                    if let seasonIndex = team.seasons.firstIndex(where: { $0.id == season.id }) {
                        team.seasons[seasonIndex].guestPlayers.removeAll { $0.id == guest.id }
                        team.seasons[seasonIndex].activePlayerIds.append(newPlayer.id)
                    }
                    
                    teamManager.updateTeam(team)
                }
            } catch {
                print("Failed to promote guest: \(error)")
            }
        }
    }
}

// MARK: - Guest Player Row
struct GuestPlayerRow: View {
    let guest: GuestPlayer
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Text("\(guest.jerseyNumber)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(guest.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("GUEST")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(3)
                }
                
                Text(guest.preferredPosition)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Stats summary
            if guest.seasonStats.goals > 0 || guest.seasonStats.assists > 0 {
                HStack(spacing: 8) {
                    if guest.seasonStats.goals > 0 {
                        Label("\(guest.seasonStats.goals)", systemImage: "soccerball")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if guest.seasonStats.assists > 0 {
                        Label("\(guest.seasonStats.assists)", systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Guest Player View
struct AddGuestPlayerView: View {
    @Binding var team: Team
    let season: Season
    @EnvironmentObject var teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var jerseyNumber = ""
    @State private var preferredPosition = "Midfielder"
    @State private var notes = ""
    @State private var isSaving = false
    
    let positions = ["Goalkeeper", "Defender", "Midfielder", "Forward"]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                    
                    TextField("Jersey Number", text: $jerseyNumber)
                        .keyboardType(.numberPad)
                    
                    Picker("Position", selection: $preferredPosition) {
                        ForEach(positions, id: \.self) { position in
                            Text(position).tag(position)
                        }
                    }
                } header: {
                    Text("Player Info")
                }
                
                Section {
                    TextField("Notes (optional)", text: $notes)
                } header: {
                    Text("Additional")
                }
            }
            .navigationTitle("Add Guest Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addGuest()
                    }
                    .disabled(name.isEmpty || jerseyNumber.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func addGuest() {
        guard let number = Int(jerseyNumber) else { return }
        
        isSaving = true
        
        let guest = GuestPlayer(
            name: name,
            jerseyNumber: number,
            preferredPosition: preferredPosition,
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            do {
                guard var currentSeason = team.seasons.first(where: { $0.id == season.id }) else {
                    isSaving = false
                    return
                }
                
                try await teamManager.firebaseManager.addGuestPlayer(guest, to: currentSeason, in: team)
                
                await MainActor.run {
                    if let seasonIndex = team.seasons.firstIndex(where: { $0.id == season.id }) {
                        team.seasons[seasonIndex].guestPlayers.append(guest)
                        teamManager.updateTeam(team)
                    }
                    
                    isSaving = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("Failed to add guest: \(error)")
                }
            }
        }
    }
}

// MARK: - Season Picker View (for use in NewGameView, etc.)
struct SeasonPickerView: View {
    @Binding var selectedSeasonId: UUID?
    let team: Team
    
    private var availableSeasons: [Season] {
        team.availableSeasonsForGames
    }
    
    var body: some View {
        if availableSeasons.isEmpty {
            VStack(spacing: 8) {
                Text("No Active Seasons")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Please create a season first")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        } else {
            Picker("Season", selection: $selectedSeasonId) {
                ForEach(availableSeasons) { season in
                    Label(season.displayName, systemImage: season.type.icon)
                        .tag(season.id as UUID?)
                }
            }
        }
    }
}

// MARK: - Season Filter Picker (for Stats views)
struct SeasonFilterPicker: View {
    @Binding var selectedSeasonId: UUID?
    let team: Team
    let includeAllTime: Bool
    
    init(selectedSeasonId: Binding<UUID?>, team: Team, includeAllTime: Bool = true) {
        self._selectedSeasonId = selectedSeasonId
        self.team = team
        self.includeAllTime = includeAllTime
    }
    
    var body: some View {
        Picker("Season", selection: $selectedSeasonId) {
            if includeAllTime {
                Text("All-Time")
                    .tag(nil as UUID?)
            }
            
            ForEach(team.visibleSeasons) { season in
                Label(season.displayName, systemImage: season.type.icon)
                    .tag(season.id as UUID?)
            }
        }
        .pickerStyle(.menu)
    }
}
