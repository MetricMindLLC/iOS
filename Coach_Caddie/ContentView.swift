import SwiftUI
import Firebase
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var teamManager: TeamManager
    @State private var showingNewTeam = false
    @State private var showingDemoTeamSelection = false
    @State private var showingQuickActions = false
    @State private var showingStats = false
    @State private var isDataFullyLoaded = false
    @State private var hasStartedLoading = false  // NEW: Track if load has started
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        // Overview Statistics Section
                        if !teamManager.teams.isEmpty && isDataFullyLoaded {
                            overviewSection
                        }
                        
                        if teamManager.teams.isEmpty && isDataFullyLoaded {
                            emptyStateSection
                        } else if !teamManager.teams.isEmpty && isDataFullyLoaded {
                            teamsListSection
                        }
                    }
                    .padding(.top)
                }
                .navigationBarHidden(true)
                .opacity(isDataFullyLoaded ? 1 : 0.3)
                .disabled(!isDataFullyLoaded)
                .refreshable {
                    await loadDataAndWait(isRefresh: true)
                }
                
                // Loading Overlay
                if !isDataFullyLoaded {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.13, green: 0.47, blue: 0.25)))
                            
                            VStack(spacing: 8) {
                                Text("Loading team data...")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(loadingStatusText)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                        )
                    }
                    .transition(.opacity)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())  // NEW: Prevents double-mounting
        .onAppear {
            // Only load data on the first appearance
            if !hasStartedLoading {
                hasStartedLoading = true  // Set immediately to prevent duplicates
                Task {
                    await loadDataAndWait(isRefresh: false)
                }
            }
        }
        .sheet(isPresented: $showingNewTeam) {
            NewTeamView(teamManager: teamManager)
        }
        .sheet(isPresented: $showingDemoTeamSelection) {
            DemoTeamSelectionView(teamManager: teamManager)
        }
        .sheet(isPresented: $showingStats) {
            NavigationView {
                EnhancedQuickStatsView()
                    .environmentObject(teamManager)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingStats = false
                            }
                        }
                    }
            }
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
    }
    
    @State private var loadingStatusText = "Please wait..."
    
    private func loadDataAndWait(isRefresh: Bool = false) async {
        // Skip if already loading (unless it's a manual refresh)
        if !isRefresh && isDataFullyLoaded {
            return
        }
        
        await MainActor.run {
            isDataFullyLoaded = false
            loadingStatusText = "Loading teams..."
        }
        
        print("🔄 ContentView: Starting data load at \(Date())")
        
        // Trigger the load
        await MainActor.run {
            teamManager.loadData()
        }
        
        // Wait for initial team load
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Wait for isLoading to become false
        var iterations = 0
        while await MainActor.run(body: { teamManager.isLoading }) && iterations < 100 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            iterations += 1
        }
        
        let teamCount = await MainActor.run { teamManager.teams.count }
        print("🔄 ContentView: Initial load complete at \(Date()), teams: \(teamCount)")
        
        // Now monitor for subcollection loading
        if teamCount > 0 {
            await MainActor.run {
                loadingStatusText = "Loading games and players..."
            }
            
            // Monitor game/player counts with a longer, more patient approach
            var previousSnapshot: [UUID: (games: Int, players: Int)] = [:]
            var consecutiveStableChecks = 0
            let requiredStableChecks = 8 // Need 8 checks at 0.5s = 4 seconds of stability
            let checkInterval: UInt64 = 500_000_000 // 0.5 seconds
            let maxWaitTime: TimeInterval = 15.0 // Wait up to 15 seconds
            let startTime = Date()
            
            while Date().timeIntervalSince(startTime) < maxWaitTime {
                try? await Task.sleep(nanoseconds: checkInterval)
                
                // Get current snapshot
                let currentSnapshot = await MainActor.run {
                    var snapshot: [UUID: (games: Int, players: Int)] = [:]
                    for team in teamManager.teams {
                        snapshot[team.id] = (games: team.games.count, players: team.players.count)
                    }
                    return snapshot
                }
                
                // Log current state
                let totalGames = currentSnapshot.values.reduce(0) { $0 + $1.games }
                let totalPlayers = currentSnapshot.values.reduce(0) { $0 + $1.players }
                print("📊 Check at \(Date()): Games=\(totalGames), Players=\(totalPlayers), Stable=\(consecutiveStableChecks)/\(requiredStableChecks)")
                
                // Compare with previous
                if currentSnapshot == previousSnapshot {
                    consecutiveStableChecks += 1
                    
                    if consecutiveStableChecks >= requiredStableChecks {
                        print("✅ ContentView: Data stabilized after \(consecutiveStableChecks) checks")
                        print("✅ Final: Games=\(totalGames), Players=\(totalPlayers)")
                        break
                    }
                } else {
                    // Data changed
                    if !previousSnapshot.isEmpty {
                        print("🔄 Data changed, resetting stability counter")
                        for (teamId, current) in currentSnapshot {
                            if let previous = previousSnapshot[teamId] {
                                if current.games != previous.games || current.players != previous.players {
                                    print("   Team \(teamId): Games \(previous.games)->\(current.games), Players \(previous.players)->\(current.players)")
                                }
                            }
                        }
                    }
                    consecutiveStableChecks = 0
                    previousSnapshot = currentSnapshot
                }
            }
            
            // Log final state
            let finalSnapshot = await MainActor.run {
                var snapshot: [UUID: (games: Int, players: Int)] = [:]
                for team in teamManager.teams {
                    snapshot[team.id] = (games: team.games.count, players: team.players.count)
                }
                return snapshot
            }
            let finalGames = finalSnapshot.values.reduce(0) { $0 + $1.games }
            let finalPlayers = finalSnapshot.values.reduce(0) { $0 + $1.players }
            print("✅ ContentView: Loading complete at \(Date())")
            print("✅ Final state: \(teamCount) teams, \(finalGames) games, \(finalPlayers) players")
        }
        
        // One more small delay before showing UI
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            withAnimation {
                isDataFullyLoaded = true
            }
        }
        
        print("✅ ContentView: UI ready at \(Date())")
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            HStack {
                // Updated to match OnboardingView logo
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 2) {
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        
                        VStack(spacing: 0) {
                            Text("COACH")
                                .font(.system(size: 6, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("CADDIE")
                                .font(.system(size: 6, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coach Caddie")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if isDataFullyLoaded {
                        Text("Managing \(teamManager.teams.count) team\(teamManager.teams.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Quick Actions Button
                if !teamManager.teams.isEmpty && isDataFullyLoaded {
                    Button(action: {
                        showingQuickActions = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                    }
                    .confirmationDialog("Quick Actions", isPresented: $showingQuickActions, titleVisibility: .visible) {
                        quickActionButtons()
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Overview Section
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                QuickStatCard(
                    value: "\(teamManager.teams.count)",
                    label: "Teams",
                    icon: "person.3.fill",
                    color: .blue
                )
                
                QuickStatCard(
                    value: "\(totalPlayers)",
                    label: "Players",
                    icon: "person.fill",
                    color: .green
                )
                
                QuickStatCard(
                    value: "\(totalGames)",
                    label: "Games",
                    icon: "soccerball",
                    color: .orange
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Teams List Section
    private var teamsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Teams")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    showingNewTeam = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                }
            }
            .padding(.horizontal)
            
            LazyVStack(spacing: 16) {
                ForEach(teamManager.teams, id: \.id) { team in
                    NavigationLink(destination: TeamDetailView(team: .constant(team), teamManager: teamManager)) {
                        EnhancedTeamCard(team: team)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Updated Empty State Section with Limit Check
    private var emptyStateSection: some View {
        VStack(spacing: 32) {
            VStack(spacing: 20) {
                Image(systemName: "soccerball")
                    .font(.system(size: 80))
                    .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25).opacity(0.6))
                    .shadow(color: Color(red: 0.13, green: 0.47, blue: 0.25).opacity(0.2), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 12) {
                    Text("Ready to start coaching?")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Create your first team to begin managing lineups, tracking stats, and planning practices.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            // Create Team Button - Enhanced with subscription awareness
            createTeamButton
        }
        .padding(.horizontal)
    }
    
    // MARK: - Create Team Button with Subscription Check
    private var createTeamButton: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingNewTeam = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Your First Team")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 0.13, green: 0.47, blue: 0.25))
                .cornerRadius(12)
            }
            
            Button(action: {
                showingDemoTeamSelection = true
            }) {
                HStack {
                    Image(systemName: "eye.fill")
                    Text("View Demo Team")
                        .fontWeight(.medium)
                }
                .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 0.13, green: 0.47, blue: 0.25).opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Quick Action Buttons
    @ViewBuilder
    private func quickActionButtons() -> some View {
        Button("New Team") {
            showingNewTeam = true
        }
        
        Button("View All Stats") {
            showingStats = true
        }
        
        if !teamManager.teams.isEmpty {
            Button("Export All Data") {
                // Export functionality here
            }
        }
    }
}

// MARK: - Extensions
extension ContentView {
    // MARK: - Computed Properties
    private var totalPlayers: Int {
        teamManager.teams.reduce(0) { $0 + $1.players.count }
    }
    
    private var totalGames: Int {
        teamManager.teams.reduce(0) { $0 + $1.games.count }
    }
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Enhanced Team Card
struct EnhancedTeamCard: View {
    let team: Team
    
    private var winPercentage: Double {
        let gamesWithResults = team.games.compactMap { $0.result }
        guard !gamesWithResults.isEmpty else { return 0 }
        
        let wins = gamesWithResults.filter { $0.goalsFor > $0.goalsAgainst }.count
        return Double(wins) / Double(gamesWithResults.count) * 100
    }
    
    private var nextGame: Game? {
        team.games.filter { $0.date > Date() }.sorted { $0.date < $1.date }.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                // Team logo or icon
                ZStack {
                    if let logoData = team.logoData,
                       let uiImage = UIImage(data: logoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(team.primaryColor)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "soccerball")
                                    .font(.title3)
                                    .foregroundColor(.white)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(team.format.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Stats
            HStack(spacing: 12) {
                StatBubble(value: "\(team.players.count)", label: "Players", color: Color(red: 0.05, green: 0.15, blue: 0.35))
                StatBubble(value: "\(team.games.count)", label: "Games", color: Color(red: 0.13, green: 0.47, blue: 0.25))
                if team.games.count > 0 {
                    StatBubble(value: String(format: "%.0f%%", winPercentage), label: "Win", color: .orange)
                }
            }
            
            // Next Event
            if let next = nextGame {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Game")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("vs \(next.opponent)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(next.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            } else if let lastGame = team.games.sorted(by: { $0.date > $1.date }).first {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Game")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("vs \(lastGame.opponent)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        if let result = lastGame.result {
                            Text("\(result.goalsFor)-\(result.goalsAgainst)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(result.goalsFor > result.goalsAgainst ? Color(red: 0.13, green: 0.47, blue: 0.25) : result.goalsFor < result.goalsAgainst ? .red : .orange)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Stat Bubble
struct StatBubble: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// Helper extension for dictionary comparison
extension Dictionary where Key == UUID, Value == (games: Int, players: Int) {
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (key, value) in lhs {
            guard let rhsValue = rhs[key],
                  value.games == rhsValue.games,
                  value.players == rhsValue.players else {
                return false
            }
        }
        return true
    }
}
