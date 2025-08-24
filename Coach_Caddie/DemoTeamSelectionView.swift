import SwiftUI

struct DemoTeamSelectionView: View {
    @ObservedObject var teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedFormat: GameFormat = .sevenVSeven
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "soccerball")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Create Demo Team")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Choose your team format to see Coach Caddie in action with realistic players and stats")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // Format Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Team Format")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(GameFormat.allCases, id: \.self) { format in
                            FormatSelectionCard(
                                format: format,
                                isSelected: selectedFormat == format,
                                onTap: {
                                    selectedFormat = format
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Selected Format Details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Demo Team Details")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        DemoDetailRow(title: "Format", value: selectedFormat.rawValue)
                        DemoDetailRow(title: "Players", value: "\(playerCount(for: selectedFormat)) players")
                        DemoDetailRow(title: "Formation", value: selectedFormat.availableFormations.first?.rawValue ?? "")
                        DemoDetailRow(title: "Includes", value: "Realistic stats, game history, player data")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Create Button
                Button(action: {
                    createDemoTeam()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Create Demo Team")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func playerCount(for format: GameFormat) -> Int {
        switch format {
        case .fiveVFive: return 8      // 8 players
        case .sevenVSeven: return 10   // 10 players
        case .nineVNine: return 12     // 12 players
        case .elevenVEleven: return 15 // 15 players
        }
    }
    
    // MARK: - Enhanced Demo Team Creation
    private func createDemoTeam() {
        // Step 1: Generate games first to establish total team goals
        let (pastGames, futureGames, totalGoalsFor) = generateDemoGamesWithTotals(for: selectedFormat)
        
        // Step 2: Generate players with stats that match the team totals
        let demoPlayers = generateDemoPlayers(for: selectedFormat, totalTeamGoals: totalGoalsFor)
        
        // Step 3: Generate practices (past and future)
        let (pastPractices, futurePractices) = generateDemoPractices(players: demoPlayers)
        
        // Step 4: Create team with reconciled demo data - UPDATED DEFAULT FORMATION
        let demoTeam = Team(
            name: "Demo \(selectedFormat.rawValue) Team",
            format: selectedFormat,
            defaultFormation: selectedFormat.defaultFormation, // Use the format's default formation
            players: demoPlayers,
            games: pastGames + futureGames,
            practices: pastPractices + futurePractices,
            dateCreated: Date()
        )
        
        // Use addTeam with isDemo flag set to true
        teamManager.addTeam(demoTeam, isDemo: true)
        teamManager.selectedTeam = demoTeam
        presentationMode.wrappedValue.dismiss()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Demo Data Generation
    private func generateDemoGamesWithTotals(for format: GameFormat) -> (pastGames: [Game], futureGames: [Game], totalGoalsFor: Int) {
        let opponents = [
            "Lions FC", "Eagles United", "Sharks SC", "Tigers Academy",
            "Wolves FC", "Panthers SC", "Hawks United", "Bears FC"
        ]
        
        var pastGames: [Game] = []
        var futureGames: [Game] = []
        var totalGoalsFor = 0
        
        // Generate 4-6 past games
        let pastGameCount = Int.random(in: 4...6)
        for i in 0..<pastGameCount {
            let daysAgo = Double((i + 1) * 10 + Int.random(in: 1...7))
            let gameDate = Calendar.current.date(byAdding: .day, value: -Int(daysAgo), to: Date()) ?? Date()
            
            let opponent = opponents[i % opponents.count]
            let isHome = Bool.random()
            
            var game = Game(
                date: gameDate,
                opponent: opponent,
                isHome: isHome,
                location: isHome ? "Home Field" : "\(opponent) Stadium",
                formation: selectedFormat.defaultFormation
            )
            
            // Generate realistic game result
            let ourGoals = Int.random(in: 0...5)
            let theirGoals = Int.random(in: 0...4)
            
            game.result = GameResult(goalsFor: ourGoals, goalsAgainst: theirGoals)
            totalGoalsFor += ourGoals
            
            pastGames.append(game)
        }
        
        // Generate 3-4 future games
        let futureGameCount = Int.random(in: 3...4)
        for i in 0..<futureGameCount {
            let daysFromNow = Double((i + 1) * 12 + Int.random(in: 1...5))
            let gameDate = Calendar.current.date(byAdding: .day, value: Int(daysFromNow), to: Date()) ?? Date()
            
            let opponent = opponents[(pastGameCount + i) % opponents.count]
            let isHome = Bool.random()
            
            let game = Game(
                date: gameDate,
                opponent: opponent,
                isHome: isHome,
                location: isHome ? "Home Field" : "\(opponent) Stadium",
                formation: selectedFormat.defaultFormation
            )
            
            futureGames.append(game)
        }
        
        return (pastGames.sorted { $0.date < $1.date },
                futureGames.sorted { $0.date < $1.date },
                totalGoalsFor)
    }
    
    private func generateDemoPlayers(for format: GameFormat, totalTeamGoals: Int) -> [Player] {
        let playerNames = getDemoPlayerNames(for: format)
        let positions = getPositionsForFormat(format)
        var players: [Player] = []
        
        // Distribute team goals among players realistically
        var remainingGoals = totalTeamGoals
        var playerGoals: [Int] = []
        
        // Assign goals based on position
        for (index, position) in positions.enumerated() {
            let maxGoalsForPosition: Int
            switch position {
            case "GK": maxGoalsForPosition = 0
            case "DEF": maxGoalsForPosition = min(2, remainingGoals)
            case "MID": maxGoalsForPosition = min(4, remainingGoals)
            case "FWD": maxGoalsForPosition = min(8, remainingGoals)
            default: maxGoalsForPosition = min(3, remainingGoals)
            }
            
            let goalsForPlayer: Int
            if index == positions.count - 1 {
                // Last player gets remaining goals
                goalsForPlayer = remainingGoals
            } else {
                goalsForPlayer = Int.random(in: 0...maxGoalsForPosition)
            }
            
            playerGoals.append(goalsForPlayer)
            remainingGoals -= goalsForPlayer
            
            if remainingGoals <= 0 {
                // Fill remaining players with 0 goals
                while playerGoals.count < positions.count {
                    playerGoals.append(0)
                }
                break
            }
        }
        
        // Create players with reconciled stats
        for (index, name) in playerNames.enumerated() {
            let jerseyNumber = index + 1
            let position = positions[index]
            let goals = playerGoals[index]
            
            // Generate other stats based on goals and position
            let stats = generateRealisticStats(for: position, goals: goals)
            
            let player = Player(
                name: name,
                jerseyNumber: jerseyNumber,
                positions: [position],
                preferredPosition: position,
                seasonStats: stats,
                parentInfo: generateDemoParentInfo(for: name)
            )
            
            players.append(player)
        }
        
        return players
    }
    
    private func generateDemoPractices(players: [Player]) -> (pastPractices: [Practice], futurePractices: [Practice]) {
        var pastPractices: [Practice] = []
        var futurePractices: [Practice] = []
        
        // Generate past practices
        let pastPracticeCount = Int.random(in: 3...5)
        for i in 0..<pastPracticeCount {
            let daysAgo = Double((i + 1) * 7 + Int.random(in: 1...3))
            let practiceDate = Calendar.current.date(byAdding: .day, value: -Int(daysAgo), to: Date()) ?? Date()
            
            let attendance = generatePracticeAttendance(players: players)
            let drills = generateDemoDrills()
            
            let practice = Practice(
                date: practiceDate,
                duration: Int.random(in: 60...90),
                location: "Training Ground",
                notes: ["Good intensity", "Focused on passing", "Great effort", "Need to work on defense"].randomElement(),
                drills: drills,
                attendance: attendance,
                weather: ["Sunny", "Cloudy", "Cool", "Overcast"].randomElement()
            )
            
            pastPractices.append(practice)
        }
        
        // Generate future practices
        let futurePracticeCount = Int.random(in: 2...4)
        for i in 0..<futurePracticeCount {
            let daysFromNow = Double((i + 1) * 7 + Int.random(in: 1...3))
            let practiceDate = Calendar.current.date(byAdding: .day, value: Int(daysFromNow), to: Date()) ?? Date()
            
            let drills = generateDemoDrills()
            
            let practice = Practice(
                date: practiceDate,
                duration: Int.random(in: 60...90),
                location: "Training Ground",
                drills: drills
            )
            
            futurePractices.append(practice)
        }
        
        return (pastPractices.sorted { $0.date < $1.date },
                futurePractices.sorted { $0.date < $1.date })
    }
    
    // MARK: - Helper Functions
    private func getDemoPlayerNames(for format: GameFormat) -> [String] {
        let baseNames = [
            "Alex Rodriguez", "Jordan Smith", "Taylor Johnson", "Morgan Davis",
            "Casey Wilson", "Riley Brown", "Avery Garcia", "Quinn Martinez",
            "Sage Thompson", "Blake Anderson", "Cameron Lee", "Drew Miller",
            "Emery Walker", "Finley Moore", "Hunter Clark", "Justice Lewis",
            "Skyler White", "River Jones"
        ]
        
        let count = playerCount(for: format)
        return Array(baseNames.prefix(count))
    }
    
    private func getPositionsForFormat(_ format: GameFormat) -> [String] {
        switch format {
        case .fiveVFive:
            // 8 players, NO goalkeepers
            return ["FWD", "FWD", "MID", "MID", "DEF", "DEF", "FWD", "MID"]
        case .sevenVSeven:
            // 10 players with 1 goalkeeper
            return ["GK", "DEF", "DEF", "MID", "MID", "MID", "FWD", "FWD", "DEF", "MID"]
        case .nineVNine:
            // 12 players with 1 goalkeeper
            return ["GK", "DEF", "DEF", "DEF", "MID", "MID", "MID", "MID", "FWD", "FWD", "DEF", "MID"]
        case .elevenVEleven:
            // 15 players with 1 goalkeeper
            return ["GK", "DEF", "DEF", "DEF", "DEF", "MID", "MID", "MID", "MID", "MID", "FWD", "FWD", "FWD", "DEF", "MID"]
        }
    }
    
    private func generateRealisticStats(for position: String, goals: Int) -> PlayerStats {
        var stats = PlayerStats()
        let gamesPlayed = Int.random(in: 6...10)
        
        stats.gamesPlayed = gamesPlayed
        stats.goals = goals
        stats.minutesPlayed = gamesPlayed * Int.random(in: 45...90)
        
        // Generate assists based on position and goals
        switch position {
        case "GK":
            stats.assists = 0
            stats.saves = Int.random(in: 20...50)
            stats.shots = 0
            stats.shotOnTarget = 0
        case "DEF":
            stats.assists = Int.random(in: 0...2)
            stats.shots = Int.random(in: 0...5)
            stats.shotOnTarget = Int.random(in: 0...2)
            stats.saves = 0
        case "MID":
            stats.assists = Int.random(in: 2...6)
            stats.shots = goals + Int.random(in: 3...10)
            stats.shotOnTarget = goals + Int.random(in: 1...5)
            stats.saves = 0
        case "FWD":
            stats.assists = Int.random(in: 1...4)
            stats.shots = goals + Int.random(in: 5...15)
            stats.shotOnTarget = goals + Int.random(in: 2...8)
            stats.saves = 0
        default:
            stats.assists = Int.random(in: 0...3)
            stats.shots = Int.random(in: 0...5)
            stats.shotOnTarget = Int.random(in: 0...2)
            stats.saves = 0
        }
        
        // Add some yellow cards randomly
        if Bool.random() {
            stats.yellowCards = Int.random(in: 1...2)
        }
        
        return stats
    }
    
    private func generateDemoParentInfo(for playerName: String) -> ParentInfo {
        let parentFirstNames = ["John", "Jane", "Michael", "Sarah", "David", "Emily", "Robert", "Lisa"]
        let lastName = String(playerName.split(separator: " ").last ?? "")
        let parentFirstName = parentFirstNames.randomElement()!
        
        var parentInfo = ParentInfo()
        parentInfo.parentName = "\(parentFirstName) \(lastName)"
        parentInfo.parentPhone = "(555) \(String(format: "%03d", Int.random(in: 100...999)))-\(String(format: "%04d", Int.random(in: 1000...9999)))"
        parentInfo.parentEmail = "\(lastName.lowercased())family@email.com"
        parentInfo.allowPhotoSharing = true
        parentInfo.allowPublicSharing = true
        
        return parentInfo
    }
    
    private func generatePracticeAttendance(players: [Player]) -> [UUID: Bool] {
        var attendance: [UUID: Bool] = [:]
        
        for player in players {
            // 80-95% attendance rate
            attendance[player.id] = Int.random(in: 1...100) <= 85
        }
        
        return attendance
    }
    
    private func generateDemoDrills() -> [Drill] {
        let allDrills = [
            Drill(
                name: "Warm-up Jog",
                description: "Light jogging around the field",
                duration: 10,
                category: "Warm-Up",
                difficulty: "Easy",
                equipment: []
            ),
            Drill(
                name: "Passing Triangle",
                description: "Three players passing in a triangle formation",
                duration: 15,
                category: "Technical",
                difficulty: "Medium",
                equipment: ["Cones", "Balls"]
            ),
            Drill(
                name: "Shooting Practice",
                description: "Players take turns shooting on goal",
                duration: 20,
                category: "Technical",
                difficulty: "Medium",
                equipment: ["Goals", "Balls", "Cones"]
            ),
            Drill(
                name: "Small-Sided Game",
                description: "5v5 scrimmage on half field",
                duration: 25,
                category: "Tactical",
                difficulty: "Hard",
                equipment: ["Bibs", "Balls", "Goals"]
            )
        ]
        
        // Return 2-3 random drills
        return Array(allDrills.shuffled().prefix(Int.random(in: 2...3)))
    }
}

// MARK: - Supporting Views
struct FormatSelectionCard: View {
    let format: GameFormat
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: iconForFormat(format))
                    .font(.system(size: 30))
                    .foregroundColor(isSelected ? .white : .green)
                
                Text(format.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("\(playerCountForFormat(format)) players")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.green : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func iconForFormat(_ format: GameFormat) -> String {
        switch format {
        case .fiveVFive: return "5.square.fill"
        case .sevenVSeven: return "7.square.fill"
        case .nineVNine: return "9.square.fill"
        case .elevenVEleven: return "11.square.fill"
        }
    }
    
    private func playerCountForFormat(_ format: GameFormat) -> Int {
        switch format {
        case .fiveVFive: return 8
        case .sevenVSeven: return 10
        case .nineVNine: return 12
        case .elevenVEleven: return 15
        }
    }
}

struct DemoDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
