import SwiftUI
import FirebaseAuth

struct TeamDetailView: View {
    @Binding var team: Team
    @ObservedObject var teamManager: TeamManager
    @State private var selectedTab = 0
    @State private var showingAddPlayer = false
    @State private var showingNewGame = false
    @State private var showingNewPractice = false
    @State private var showingTeamSettings = false
    @State private var showingDeleteAlert = false
    @State private var isInGameMode = false
    @State private var showingStatsVisibility = false
    @State private var userRole: AccessLevel?
    @State private var showingCOPPASettings = false
    @State private var isTeamOwner = false
    @State private var showingSeasonList = false      // NEW
    @State private var showingNewSeason = false
    @Environment(\.presentationMode) var presentationMode
    
    private var shouldHideTabBar: Bool {
        return isInGameMode || selectedTab == 4 || selectedTab == 5 // Hide for game mode, lineup tab, or tactics tab
    }
    
    private var isCurrentUserTeamOwner: Bool {
        guard let currentUser = Auth.auth().currentUser else { return false }
        return team.coachUID == currentUser.uid
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content based on selected tab
            Group {
                switch selectedTab {
                case 0:
                    NavigationView {
                        TeamOverviewTab(
                            team: $team,
                            showingAddPlayer: $showingAddPlayer,
                            showingNewGame: $showingNewGame,
                            showingNewPractice: $showingNewPractice,
                            selectedTab: $selectedTab
                        )
                        .navigationTitle(team.name)
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarItems(
                            leading: Button("Teams") {
                                presentationMode.wrappedValue.dismiss()
                            },
                            trailing: Menu {
                                // Only show settings to team owners (paying coaches)
                                if userRole == .coach && isTeamOwner {
                                    Button(action: { showingCOPPASettings = true }) {
                                        Label("COPPA & Privacy Settings", systemImage: "shield.checkered")
                                    }
                                    
                                    Button(action: { showingTeamSettings = true }) {
                                        Label("Team Settings", systemImage: "gear")
                                    }
                                    
                                    Button(action: { showingStatsVisibility = true }) {
                                        Label("Stats Visibility", systemImage: "eye.circle")
                                    }
                                }
                                
                                // No menu items for non-paying users (invited coaches, parents, viewers)
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                            }
                        )
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                case 1:
                    NavigationView {
                        TeamPlayersTab(team: $team, showingAddPlayer: $showingAddPlayer)
                            .navigationTitle("Players")
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationBarItems(
                                leading: Button("Overview") {
                                    selectedTab = 0
                                },
                                trailing: userRole == .coach ? AnyView(
                                    Button(action: { showingAddPlayer = true }) {
                                        Image(systemName: "plus")
                                    }
                                ) : AnyView(EmptyView())
                            )
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                case 2:
                    NavigationView {
                        TeamGamesTab(
                            team: $team,
                            showingNewGame: $showingNewGame,
                            onSwitchToLineup: {
                                selectedTab = 4
                                // Give the lineup view time to appear, then trigger game mode
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    NotificationCenter.default.post(name: NSNotification.Name("EnterActiveGameMode"), object: nil)
                                }
                            }
                        )
                            .navigationTitle("Games")
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationBarItems(
                                leading: Button("Overview") {
                                    selectedTab = 0
                                },
                                trailing: userRole == .coach ? AnyView(
                                    Button(action: { showingNewGame = true }) {
                                        Image(systemName: "plus")
                                    }
                                ) : AnyView(EmptyView())
                            )
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                case 3:
                    NavigationView {
                        TeamPracticesTab(team: $team, showingNewPractice: $showingNewPractice)
                            .navigationTitle("Practices")
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationBarItems(
                                leading: Button("Overview") {
                                    selectedTab = 0
                                },
                                trailing: userRole == .coach ? AnyView(
                                    Button(action: { showingNewPractice = true }) {
                                        Image(systemName: "plus")
                                    }
                                ) : AnyView(EmptyView())
                            )
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                case 4:
                    NavigationView {
                        LineupView(team: $team, isInGameMode: $isInGameMode, teamManager: teamManager)
                            .navigationTitle("Lineup")
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationBarItems(
                                leading: Button("Overview") {
                                    selectedTab = 0
                                }
                            )
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                case 5:
                    NavigationView {
                        TacticsWhiteboardView(team: $team, onDismiss: {
                            selectedTab = 0
                        })
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                default:
                    NavigationView {
                        TeamOverviewTab(
                            team: $team,
                            showingAddPlayer: $showingAddPlayer,
                            showingNewGame: $showingNewGame,
                            showingNewPractice: $showingNewPractice,
                            selectedTab: $selectedTab
                        )
                        .navigationTitle(team.name)
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemGroupedBackground), Color(.systemBackground)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Custom Tab Bar - Hide when in game mode or lineup tab
            if !shouldHideTabBar {
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 34)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView(team: $team)
                .environmentObject(teamManager)
        }
        .sheet(isPresented: $showingCOPPASettings) {
            PrivacyDisclosureText.COPPATeamSettingsView(team: $team)
                .environmentObject(teamManager)
        }
        .sheet(isPresented: $showingNewGame) {
            SuperEnhancedNewGameView(team: $team)
                .environmentObject(teamManager)
        }
        .sheet(isPresented: $showingNewPractice) {
            ImprovedNewPracticeView(team: $team)
                .environmentObject(teamManager)
        }
        .sheet(isPresented: $showingTeamSettings) {
            TeamSettingsView(
                team: $team,
                teamManager: teamManager,
                showingDeleteAlert: $showingDeleteAlert
            )
        }
        .sheet(isPresented: $showingStatsVisibility) {
            StatsVisibilityConfigView(team: team)
                .environmentObject(teamManager)
        }
        .sheet(isPresented: $showingSeasonList) {
            NavigationView {
                SeasonListView(team: $team)
                    .environmentObject(teamManager)
            }
        }
        .sheet(isPresented: $showingNewSeason) {
            NewSeasonView(team: $team)
                .environmentObject(teamManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSeasonCreation"))) { notification in
            // Handle request to open season creation from game/practice views
            if let teamId = notification.object as? UUID, teamId == team.id {
                showingNewSeason = true
            }
        }
        .alert("Delete Team", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                teamManager.deleteTeam(team)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("This action cannot be undone. All team data will be permanently deleted.")
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    // Check user permissions
    private func checkPermissions() {
        Task {
            userRole = await teamManager.getCurrentUserRole(for: team)
            
            await MainActor.run {
                isTeamOwner = isCurrentUserTeamOwner
            }
        }
    }
}
// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    let tabs = [
        (icon: "house.fill", title: "Overview"),
        (icon: "person.3.fill", title: "Players"),
        (icon: "sportscourt.fill", title: "Games"),
        (icon: "figure.run", title: "Practice"),
        (icon: "rectangle.3.group.fill", title: "Lineup"),
        (icon: "pencil.and.outline", title: "Tactics")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 3) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(tabs[index].title)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(selectedTab == index ? Color(red: 0.05, green: 0.15, blue: 0.35) : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedTab == index ? Color(red: 0.05, green: 0.15, blue: 0.35).opacity(0.1) : Color.clear)
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 16)
    }
}

struct TeamOverviewTab: View {
    @Binding var team: Team
    @Binding var showingAddPlayer: Bool
    @Binding var showingNewGame: Bool
    @Binding var showingNewPractice: Bool
    @Binding var selectedTab: Int
    @EnvironmentObject var teamManager: TeamManager
    
    @State private var userRole: AccessLevel?
    @State private var isLoadingPermissions = true
    @State private var showingSeasonList = false      // NEW
    @State private var showingNewSeason = false
    
    // CRITICAL FIX: Get fresh team data from TeamManager
    private var currentTeam: Team {
        teamManager.teams.first(where: { $0.id == team.id }) ?? team
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Team Info Card (using old UI style)
                teamInfoCard
                
                // Quick Actions - Now permission-based (using old UI style)
                if !isLoadingPermissions {
                    quickActionsSection
                }
                
                // Team Stats Summary (using fresh data - ONLY CHANGE)
                TeamStatsSummary(team: currentTeam)
                
                // Add bottom padding to prevent tab bar overlap
                Color.clear
                    .frame(height: 120)
            }
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    private var teamInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text(currentTeam.name)
                        .font(.largeTitle)
                        .bold()
                    Text("\(currentTeam.format.rawValue) • \(currentTeam.defaultFormation.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "shield.fill")
                    .font(.system(size: 50))
                    .foregroundColor(currentTeam.primaryColor)
            }
            
            // Season Banner - Uses smart status logic
            seasonBannerView
            
            HStack(spacing: 30) {
                VStack {
                    Text("\(activePlayerCount)")
                        .font(.title2)
                        .bold()
                    Text(activePlayerLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack {
                    Text("\(upcomingGamesCount)")
                        .font(.title2)
                        .bold()
                    Text("Upcoming Games")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(upcomingPracticesCount)")
                        .font(.title2)
                        .bold()
                    Text("Upcoming Practices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
        .padding(.horizontal)
        .sheet(isPresented: $showingSeasonList) {
            NavigationView {
                SeasonListView(team: $team)
                    .environmentObject(teamManager)
            }
        }
        .sheet(isPresented: $showingNewSeason) {
            NewSeasonView(team: $team)
                .environmentObject(teamManager)
        }
    }

    // Active player count for current/active season
    private var activePlayerCount: Int {
        if let activeSeason = currentTeam.effectiveActiveSeason {
            return activeSeason.activePlayerIds.count
        }
        // Fallback to total players if no active season
        return currentTeam.players.count
    }

    // Label changes based on whether we have an active season
    private var activePlayerLabel: String {
        if currentTeam.effectiveActiveSeason != nil {
            return "Active Players"
        }
        return "Players"
    }

    // NEW: Smart Season Banner View
    @ViewBuilder
    private var seasonBannerView: some View {
        switch currentTeam.seasonStatus {
        case .inSeason(let season):
            // Currently in a season
            Button(action: { showingSeasonList = true }) {
                HStack {
                    Image(systemName: season.type.icon)
                        .foregroundColor(season.type.color)
                    
                    Text(season.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("Current Season")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
        case .betweenSeasons(let nextSeason):
            // Between seasons, show next upcoming
            Button(action: { showingSeasonList = true }) {
                HStack {
                    Image(systemName: nextSeason.type.icon)
                        .foregroundColor(nextSeason.type.color)
                    
                    Text(nextSeason.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("Next Season")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
        case .noUpcomingSeasons(let lastSeason):
            // No upcoming seasons
            if let last = lastSeason {
                Button(action: { showingSeasonList = true }) {
                    HStack {
                        Image(systemName: last.type.icon)
                            .foregroundColor(last.type.color)
                        
                        Text(last.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("Past Season")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Has seasons but none upcoming and none past (shouldn't happen, but handle it)
                Button(action: { showingNewSeason = true }) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.orange)
                        
                        Text("Create a new season")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
        case .noSeasons:
            // No seasons at all - prompt to create
            Button(action: { showingNewSeason = true }) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.orange)
                    
                    Text("Create your first season")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // Helper computed properties for upcoming events
    private var upcomingGamesCount: Int {
        let now = Date()
        return currentTeam.games.filter { $0.date > now }.count
    }
    
    private var upcomingPracticesCount: Int {
        let now = Date()
        return currentTeam.practices.filter { $0.date > now }.count
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                
                Spacer()
                
                // Show user role indicator
                if let role = userRole {
                    Text(role.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(role == .coach ? Color.green.opacity(0.2) :
                                   role == .parent ? Color.blue.opacity(0.2) :
                                   Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            // Show different actions based on role
            switch userRole {
            case .coach:
                coachQuickActions
            case .parent:
                parentQuickActions
            case .viewer:
                viewerQuickActions
            case .none:
                Text("Loading permissions...")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }
    
    private var coachQuickActions: some View {
        HStack(spacing: 8) {
            QuickActionButton(
                icon: "person.badge.plus",
                title: "Add Player",
                color: Color(red: 0.8, green: 0.2, blue: 0.2),
                textColor: .white,
                backgroundColor: Color(red: 0.8, green: 0.2, blue: 0.2)
            ) {
                showingAddPlayer = true
            }
            
            QuickActionButton(
                icon: "sportscourt",
                title: "New Game",
                color: .white,
                textColor: .white,
                backgroundColor: Color(red: 0.1, green: 0.4, blue: 0.8)
            ) {
                showingNewGame = true
            }
            
            QuickActionButton(
                icon: "figure.run",
                title: "New Practice",
                color: Color(red: 1.0, green: 0.6, blue: 0.1),
                textColor: .white,
                backgroundColor: Color(red: 1.0, green: 0.6, blue: 0.1)
            ) {
                showingNewPractice = true
            }
            
            QuickActionButton(
                icon: "rectangle.3.group",
                title: "Manage Lineup",
                color: .white,
                textColor: .white,
                backgroundColor: Color(red: 0.15, green: 0.6, blue: 0.15)
            ) {
                selectedTab = 4
            }
            
            QuickActionButton(
                icon: "calendar",
                title: "Seasons",
                color: .purple,
                textColor: .white,
                backgroundColor: .purple
            ) {
                showingSeasonList = true
            }
        }
        .padding(.horizontal)
    }
    
    private var parentQuickActions: some View {
        HStack(spacing: 8) {
            QuickActionButton(
                icon: "person.circle",
                title: "View Players",
                color: .white,
                textColor: .white,
                backgroundColor: Color(red: 0.1, green: 0.4, blue: 0.8)
            ) {
                selectedTab = 1
            }
            
            QuickActionButton(
                icon: "calendar",
                title: "View Schedule",
                color: .white,
                textColor: .white,
                backgroundColor: Color(red: 0.15, green: 0.6, blue: 0.15)
            ) {
                selectedTab = 2
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var viewerQuickActions: some View {
        VStack(spacing: 12) {
            Text("👁️ View Only Access")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("You can view team information but cannot make changes.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 8) {
                QuickActionButton(
                    icon: "person.3",
                    title: "View Players",
                    color: .white,
                    textColor: .white,
                    backgroundColor: Color.gray
                ) {
                    selectedTab = 1
                }
                
                QuickActionButton(
                    icon: "calendar",
                    title: "View Schedule",
                    color: .white,
                    textColor: .white,
                    backgroundColor: Color.gray
                ) {
                    selectedTab = 2
                }
                
                Spacer()
                Spacer()
            }
        }
        .padding(.horizontal)
    }
    
    private func checkPermissions() {
        Task {
            userRole = await teamManager.getCurrentUserRole(for: team)
            await MainActor.run {
                isLoadingPermissions = false
            }
        }
    }
}

struct TeamPlayersTab: View {
    @Binding var team: Team
    @Binding var showingAddPlayer: Bool
    @EnvironmentObject var teamManager: TeamManager
    
    @State private var userRole: AccessLevel?
    @State private var editablePlayerIds: [UUID] = []
    @State private var isLoadingPermissions = true
    @State private var selectedPlayerId: UUID?
    @State private var showingPlayerDetail = false
    
    // CRITICAL: Get fresh team data from TeamManager
    private var currentTeam: Team? {
        teamManager.teams.first(where: { $0.id == team.id })
    }
    
    var body: some View {
        VStack {
            if let freshTeam = currentTeam {
                if freshTeam.players.isEmpty {
                    EmptyPlayersView(showingAddPlayer: $showingAddPlayer)
                } else {
                    Group {
                        if isLoadingPermissions {
                            ProgressView("Loading permissions...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            playersList(team: freshTeam)
                        }
                    }
                }
            } else {
                Text("Team not found")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingPlayerDetail) {
            if let playerId = selectedPlayerId {
                PlayerDetailView(playerId: playerId, teamId: team.id)
                    .environmentObject(teamManager)
            }
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    @ViewBuilder
    private func playersList(team: Team) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(team.players.sorted { $0.jerseyNumber < $1.jerseyNumber }, id: \.id) { player in
                    // Simple player row showing name, position, and goals
                    HStack(spacing: 12) {
                        // Jersey number circle
                        Circle()
                            .fill(player.preferredPositionEnum.color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("\(player.jerseyNumber)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(player.name)
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Text(player.positions.joined(separator: " / "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(player.seasonStats.goals)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Goals")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .onTapGesture {
                        if editablePlayerIds.contains(player.id) {
                            selectedPlayerId = player.id
                            showingPlayerDetail = true
                        }
                    }
                    .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 1)
                    .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
            }
            .padding(.vertical)
        }
    }
    
    private func checkPermissions() {
        Task {
            userRole = await teamManager.getCurrentUserRole(for: team)
            editablePlayerIds = teamManager.getEditablePlayerIds(for: team)
            await MainActor.run {
                isLoadingPermissions = false
            }
        }
    }
}
// MARK: - Simple Player Row View (to replace missing PlayerRowView)
struct SimplePlayerRowView: View {
    let player: Player
    let canEdit: Bool
    let userRole: AccessLevel?
    
    var body: some View {
        HStack(spacing: 12) {
            // Jersey number circle
            Circle()
                .fill(player.preferredPositionEnum.color)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(player.jerseyNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(player.positions.joined(separator: " / "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(player.seasonStats.goals)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Goals")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TeamGamesTab: View {
    @Binding var team: Team
    @Binding var showingNewGame: Bool
    let onSwitchToLineup: () -> Void
    @EnvironmentObject var teamManager: TeamManager
    
    @State private var userRole: AccessLevel?
    @State private var selectedGame: Game?
    @State private var showingGameDetail = false
    @StateObject private var gameStateManager = GameStateManager.shared
    
    // CRITICAL FIX: Get fresh team data from TeamManager
    private var currentTeam: Team {
        teamManager.teams.first(where: { $0.id == team.id }) ?? team
    }
    
    var body: some View {
        VStack {
            if currentTeam.games.isEmpty {
                TeamEmptyGamesView(showingNewGame: $showingNewGame)
            } else {
                List {
                    ForEach(currentTeam.games.sorted(by: { $0.date < $1.date })) { game in
                        Button(action: {
                            selectedGame = game
                            showingGameDetail = true
                        }) {
                            TeamGameRowView(game: game)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                    
                    // Add bottom padding to prevent tab bar overlap
                    if !currentTeam.games.isEmpty {
                        Color.clear
                            .frame(height: 120)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color(.systemGroupedBackground))
            }
        }
        .sheet(isPresented: $showingGameDetail) {
            if let selectedGame = selectedGame {
                let gameBinding = Binding<Game>(
                    get: { currentTeam.games.first(where: { $0.id == selectedGame.id }) ?? selectedGame },
                    set: { newGame in
                        if let index = team.games.firstIndex(where: { $0.id == selectedGame.id }) {
                            team.games[index] = newGame
                        }
                    }
                )
                GameDetailView(
                    game: gameBinding,
                    team: currentTeam,
                    onViewActiveGame: {
                        showingGameDetail = false
                        onSwitchToLineup()
                    }
                )
                .environmentObject(gameStateManager)
                .environmentObject(teamManager)
            }
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        Task {
            userRole = await teamManager.getCurrentUserRole(for: team)
        }
    }
}

struct TeamPracticesTab: View {
    @Binding var team: Team
    @Binding var showingNewPractice: Bool
    @EnvironmentObject var teamManager: TeamManager
    
    @State private var userRole: AccessLevel?
    @State private var selectedPractice: Practice?
    @State private var showingPracticeDetail = false
    
    var body: some View {
        VStack {
            if team.practices.isEmpty {
                EmptyPracticesView(showingNewPractice: $showingNewPractice)
            } else {
                List {
                    ForEach(team.practices.sorted(by: { $0.date > $1.date })) { practice in
                        Button(action: {
                            selectedPractice = practice
                            showingPracticeDetail = true
                        }) {
                            PracticeRowView(practice: practice)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                    
                    // Add bottom padding to prevent tab bar overlap
                    if !team.practices.isEmpty {
                        Color.clear
                            .frame(height: 120)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationBarBackButtonHidden(false)
        .sheet(isPresented: $showingPracticeDetail) {
            if let selectedPractice = selectedPractice {
                let practiceBinding = Binding<Practice>(
                    get: { team.practices.first(where: { $0.id == selectedPractice.id }) ?? selectedPractice },
                    set: { newPractice in
                        if let index = team.practices.firstIndex(where: { $0.id == selectedPractice.id }) {
                            team.practices[index] = newPractice
                        }
                    }
                )
                PracticeDetailView(practice: practiceBinding, team: $team)
            }
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    private func bindingForPractice(_ practice: Practice) -> Binding<Practice> {
        return Binding<Practice>(
            get: {
                team.practices.first(where: { $0.id == practice.id }) ?? practice
            },
            set: { newPractice in
                if let index = team.practices.firstIndex(where: { $0.id == practice.id }) {
                    team.practices[index] = newPractice
                }
            }
        )
    }
    
    private func checkPermissions() {
        Task {
            userRole = await teamManager.getCurrentUserRole(for: team)
        }
    }
}
// MARK: - Supporting Views
struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let textColor: Color
    let backgroundColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
}

// MARK: - Team Stats Summary (UPDATED TO COMBINE GAME DATA + MANUAL EDITS)
struct TeamStatsSummary: View {
    let team: Team
    
    // Calculate total goals: sum of all player seasonStats (which includes manual edits)
    var totalGoals: Int {
        return team.players.reduce(0) { $0 + $1.seasonStats.goals }
    }
    
    // Calculate total assists: sum of all player seasonStats (which includes manual edits)
    var totalAssists: Int {
        return team.players.reduce(0) { $0 + $1.seasonStats.assists }
    }
    
    var gamesWon: Int {
        team.games.filter { game in
            guard let result = game.result else { return false }
            return result.goalsFor > result.goalsAgainst
        }.count
    }
    
    var gamesLost: Int {
        team.games.filter { game in
            guard let result = game.result else { return false }
            return result.goalsFor < result.goalsAgainst
        }.count
    }
    
    var gamesDrawn: Int {
        team.games.filter { game in
            guard let result = game.result else { return false }
            return result.goalsFor == result.goalsAgainst
        }.count
    }
    
    // Calculate top scorer from player seasonStats (which includes manual edits)
    var topScorer: Player? {
        return team.players.max(by: { $0.seasonStats.goals < $1.seasonStats.goals })
    }
    
    // Get the actual goal count for the top scorer from their seasonStats
    var topScorerGoals: Int {
        return topScorer?.seasonStats.goals ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Team Statistics")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                StatRowView(icon: "soccerball", title: "Goals", value: "\(totalGoals)")
                Divider().padding(.horizontal)
                
                StatRowView(icon: "hands.and.sparkles.fill", title: "Assists", value: "\(totalAssists)")
                Divider().padding(.horizontal)
                
                StatRowView(icon: "trophy.fill", title: "Wins", value: "\(gamesWon)")
                Divider().padding(.horizontal)
                
                StatRowView(icon: "equal.circle.fill", title: "Draws", value: "\(gamesDrawn)")
                Divider().padding(.horizontal)
                
                StatRowView(icon: "xmark.circle.fill", title: "Losses", value: "\(gamesLost)")
                
                if let topScorer = topScorer, topScorerGoals > 0 {
                    Divider().padding(.horizontal)
                    StatRowView(icon: "crown.fill", title: "Top Scorer", value: "\(topScorer.name) (\(topScorerGoals))")
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 2)
            .padding(.horizontal)
        }
    }
}

struct StatRowView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(red: 0.1, green: 0.4, blue: 0.8))
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}


struct TeamGameRowView: View {
    let game: Game
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("vs \(game.opponent)")
                    .font(.headline)
                Text(game.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(game.isHome ? "Home" : "Away")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(game.isHome ? Color(red: 0.13, green: 0.47, blue: 0.25).opacity(0.2) : Color.orange.opacity(0.2))
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
                        .foregroundColor(result.goalsFor > result.goalsAgainst ? Color(red: 0.13, green: 0.47, blue: 0.25) : result.goalsFor < result.goalsAgainst ? .red : .orange)
                }
            } else {
                Text("Scheduled")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

struct PracticeRowView: View {
    let practice: Practice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Practice Session")
                    .font(.headline)
                Spacer()
                Text(practice.date.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(practice.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(practice.drills.count) drills")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

// MARK: - Empty State Views
struct EmptyPlayersView: View {
    @Binding var showingAddPlayer: Bool
    @EnvironmentObject var teamManager: TeamManager
    
    @State private var userRole: AccessLevel?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Players Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add your first player to get started with team management.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if userRole == .coach {
                Button(action: { showingAddPlayer = true }) {
                    Text("Add Player")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color(red: 0.05, green: 0.15, blue: 0.35))
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        // This would need access to the team to check permissions
        // For now, assume coach role for empty state
        userRole = .coach
    }
}

struct TeamEmptyGamesView: View {
    @Binding var showingNewGame: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sportscourt.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Games Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Schedule your first game to track team performance.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { showingNewGame = true }) {
                Text("Schedule Game")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color(red: 0.05, green: 0.15, blue: 0.35))
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyPracticesView: View {
    @Binding var showingNewPractice: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Practices Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Schedule your first practice session.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { showingNewPractice = true }) {
                Text("Schedule Practice")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Team Settings View (FIXED - Half Length Picker Issue)
struct TeamSettingsView: View {
    @Binding var team: Team
    @ObservedObject var teamManager: TeamManager
    @Binding var showingDeleteAlert: Bool
    @Environment(\.presentationMode) var presentationMode
    
    // Add local state to track changes
    @State private var localTeamName: String = ""
    @State private var localFormat: GameFormat = .elevenVEleven
    @State private var localDefaultFormation: Formation = .formation442
    @State private var localDefaultHalfLength: Int = 45
    @State private var hasUnsavedChanges = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Team Information") {
                    TextField("Team Name", text: $localTeamName)
                        .onChange(of: localTeamName) { _ in hasUnsavedChanges = true }
                    
                    Picker("Team Format", selection: $localFormat) {
                        ForEach(GameFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .onChange(of: localFormat) { newFormat in
                        hasUnsavedChanges = true
                        // Update formation if the current one isn't available for the new format
                        if !newFormat.availableFormations.contains(localDefaultFormation) {
                            localDefaultFormation = newFormat.defaultFormation
                        }
                    }
                    
                    Picker("Default Formation", selection: $localDefaultFormation) {
                        ForEach(localFormat.availableFormations, id: \.self) { formation in
                            Text(formation.rawValue).tag(formation)
                        }
                    }
                    .onChange(of: localDefaultFormation) { _ in hasUnsavedChanges = true }
                    
                    // FIXED: Half Length Picker with explicit onChange
                    Picker("Default Half Length", selection: $localDefaultHalfLength) {
                        ForEach([15, 20, 25, 30, 35, 40, 45], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .onChange(of: localDefaultHalfLength) { newValue in
                        print("Half length changed to: \(newValue)")
                        hasUnsavedChanges = true
                    }
                }
                
                Section("Team Statistics") {
                    HStack {
                        Text("Total Players")
                        Spacer()
                        Text("\(team.players.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Games")
                        Spacer()
                        Text("\(team.games.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Practices")
                        Spacer()
                        Text("\(team.practices.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Save Changes") {
                        saveChanges()
                    }
                    .foregroundColor(hasUnsavedChanges ? .blue : .gray)
                    .disabled(!hasUnsavedChanges)
                }
                
                Section {
                    Button("Delete Team") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Team Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                // Optional: Add a Save button in the toolbar too
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasUnsavedChanges)
                }
            }
        }
        .onAppear {
            // Initialize local state with current team values
            localTeamName = team.name
            localFormat = team.format
            localDefaultFormation = team.defaultFormation
            localDefaultHalfLength = team.defaultHalfLength
            hasUnsavedChanges = false
            print("TeamSettingsView appeared - Half length initialized to: \(localDefaultHalfLength)")
        }
        .onDisappear {
            // Warn about unsaved changes if needed
            if hasUnsavedChanges {
                print("Warning: TeamSettingsView dismissed with unsaved changes")
            }
        }
    }
    
    private func saveChanges() {
        print("Saving team changes - Half length: \(localDefaultHalfLength)")
        
        // Create updated team with local changes
        var updatedTeam = team
        updatedTeam.name = localTeamName
        updatedTeam.format = localFormat
        updatedTeam.defaultFormation = localDefaultFormation
        updatedTeam.defaultHalfLength = localDefaultHalfLength
        
        // Update through team manager
        teamManager.updateTeam(updatedTeam)
        
        // Update the binding to reflect changes
        team = updatedTeam
        
        hasUnsavedChanges = false
        presentationMode.wrappedValue.dismiss()
        
        print("Team settings saved successfully - Half length: \(updatedTeam.defaultHalfLength)")
    }
}

// MARK: - Stats Visibility Configuration View
struct StatsVisibilityConfigView: View {
    let team: Team
    @State private var parentSettings: StatsVisibilitySettings
    @State private var viewerSettings: StatsVisibilitySettings
    @State private var selectedAccessLevel: AccessLevel = .parent
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var teamManager: TeamManager
    
    init(team: Team) {
        self.team = team
        self._parentSettings = State(initialValue: team.statsVisibilityForParents)
        self._viewerSettings = State(initialValue: team.statsVisibilityForViewers)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Access Level Picker
                Picker("Access Level", selection: $selectedAccessLevel) {
                    Text("Parents").tag(AccessLevel.parent)
                    Text("Viewers").tag(AccessLevel.viewer)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Settings Form
                Form {
                    playerStatsSection
                    teamStatsSection
                    overviewStatsSection
                    presetsSection
                }
            }
            .navigationTitle("Stats Visibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var currentSettings: Binding<StatsVisibilitySettings> {
        selectedAccessLevel == .parent ? $parentSettings : $viewerSettings
    }
    
    private var playerStatsSection: some View {
        Section {
            VisibilityToggleRow(
                title: "Goals",
                description: "Player goals scored",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showGoals },
                    set: { currentSettings.wrappedValue.showGoals = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Assists",
                description: "Player assists made",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showAssists },
                    set: { currentSettings.wrappedValue.showAssists = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Shots",
                description: "Total shots taken",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showShots },
                    set: { currentSettings.wrappedValue.showShots = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Saves",
                description: "Goalkeeper saves",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showSaves },
                    set: { currentSettings.wrappedValue.showSaves = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Goals Conceded",
                description: "Goals allowed (goalkeepers)",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showGoalsConceded },
                    set: { currentSettings.wrappedValue.showGoalsConceded = $0 }
                ),
                isRecommended: false
            )
            
            VisibilityToggleRow(
                title: "Yellow Cards",
                description: "Disciplinary cards received",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showYellowCards },
                    set: { currentSettings.wrappedValue.showYellowCards = $0 }
                ),
                isRecommended: false
            )
            
            VisibilityToggleRow(
                title: "Red Cards",
                description: "Ejections from games",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showRedCards },
                    set: { currentSettings.wrappedValue.showRedCards = $0 }
                ),
                isRecommended: false
            )
            
            VisibilityToggleRow(
                title: "Games Played",
                description: "Total games participated in",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showGamesPlayed },
                    set: { currentSettings.wrappedValue.showGamesPlayed = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Total Playing Time",
                description: "Minutes played across all games",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showTotalPlayingTime },
                    set: { currentSettings.wrappedValue.showTotalPlayingTime = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Relative Playing Time",
                description: "Percentage of total possible playing time",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showRelativePlayingTime },
                    set: { currentSettings.wrappedValue.showRelativePlayingTime = $0 }
                )
            )
        } header: {
            Text("Player Statistics")
        } footer: {
            Text("Choose which individual player stats to show to \(selectedAccessLevel.teamDisplayName.lowercased()).")
        }
    }
    
    private var teamStatsSection: some View {
        Section {
            VisibilityToggleRow(
                title: "Team Record",
                description: "Wins, losses, and draws",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showTeamRecord },
                    set: { currentSettings.wrappedValue.showTeamRecord = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Goal Difference",
                description: "Goals for minus goals against",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showGoalDifference },
                    set: { currentSettings.wrappedValue.showGoalDifference = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Win Percentage",
                description: "Percentage of games won",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showWinPercentage },
                    set: { currentSettings.wrappedValue.showWinPercentage = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Top Performers",
                description: "Ranking of best players",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showTopPerformers },
                    set: { currentSettings.wrappedValue.showTopPerformers = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Team Comparisons",
                description: "Side-by-side team analysis",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showTeamComparison },
                    set: { currentSettings.wrappedValue.showTeamComparison = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Monthly Trends",
                description: "Performance trends over time",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showMonthlyTrends },
                    set: { currentSettings.wrappedValue.showMonthlyTrends = $0 }
                ),
                isRecommended: false
            )
        } header: {
            Text("Team Statistics")
        }
    }
    
    private var overviewStatsSection: some View {
        Section {
            VisibilityToggleRow(
                title: "Overall Statistics",
                description: "Summary cards and metrics",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showOverallStats },
                    set: { currentSettings.wrappedValue.showOverallStats = $0 }
                )
            )
            
            VisibilityToggleRow(
                title: "Goals Chart",
                description: "Visual chart of team goals",
                isVisible: Binding(
                    get: { currentSettings.wrappedValue.showGoalsChart },
                    set: { currentSettings.wrappedValue.showGoalsChart = $0 }
                )
            )
        } header: {
            Text("Overview")
        }
    }
    
    private var presetsSection: some View {
        Section {
            Button("Parent-Friendly Preset") {
                if selectedAccessLevel == .parent {
                    parentSettings = StatsVisibilitySettings.parentFriendly
                } else {
                    viewerSettings = StatsVisibilitySettings.parentFriendly
                }
            }
            
            Button("Basic Preset") {
                if selectedAccessLevel == .parent {
                    parentSettings = StatsVisibilitySettings.basic
                } else {
                    viewerSettings = StatsVisibilitySettings.basic
                }
            }
            
            Button("Show All Stats") {
                if selectedAccessLevel == .parent {
                    parentSettings = StatsVisibilitySettings.coachDefault
                } else {
                    viewerSettings = StatsVisibilitySettings.coachDefault
                }
            }
        } header: {
            Text("Quick Presets")
        } footer: {
            Text("Apply common configurations quickly. You can still customize individual settings after applying a preset.")
        }
    }
    
    private func saveSettings() {
        // Save to team (which will persist to UserDefaults/Firebase)
        var updatedTeam = team
        updatedTeam.statsVisibilityForParents = parentSettings
        updatedTeam.statsVisibilityForViewers = viewerSettings
        
        // Update through TeamManager
        teamManager.updateTeam(updatedTeam)
        
        presentationMode.wrappedValue.dismiss()
    }
}

struct VisibilityToggleRow: View {
    let title: String
    let description: String
    @Binding var isVisible: Bool
    let isRecommended: Bool
    
    init(title: String, description: String, isVisible: Binding<Bool>, isRecommended: Bool = true) {
        self.title = title
        self.description = description
        self._isVisible = isVisible
        self.isRecommended = isRecommended
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.body)
                    
                    if !isRecommended {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isVisible)
        }
        .padding(.vertical, 2)
    }
}

// Add this extension to AccessLevel for display
extension AccessLevel {
    var teamDisplayName: String {
        switch self {
        case .coach: return "Coaches"
        case .parent: return "Parents"
        case .viewer: return "Viewers"
        }
    }
}
