import SwiftUI

// MARK: - Team Event Model (UPDATED with RSVP for specific players)
struct TeamEvent: Identifiable, Codable {
    let id: String
    let type: TeamEventType
    let title: String
    let location: String
    let date: Date
    let duration: Int // in minutes
    let gameId: UUID?
    let practiceId: UUID?
    let teamId: UUID
    let teamName: String
    
    // Helper computed property for getting details
    func getGame(from team: Team) -> Game? {
        guard let gameId = gameId else { return nil }
        return team.games.first { $0.id == gameId }
    }
    
    func getPractice(from team: Team) -> Practice? {
        guard let practiceId = practiceId else { return nil }
        return team.practices.first { $0.id == practiceId }
    }
    
    // Get RSVP status for a specific player
    func getRSVPStatus(for playerId: UUID, from team: Team) -> RSVPStatus {
        if let game = getGame(from: team) {
            return game.playerRSVPs[playerId] ?? .unknown
        } else if let practice = getPractice(from: team) {
            return practice.playerRSVPs[playerId] ?? .unknown
        }
        return .unknown
    }
    
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        let startTime = formatter.string(from: date)
        let endDate = date.addingTimeInterval(TimeInterval(duration * 60))
        let endTime = formatter.string(from: endDate)
        return "\(startTime) - \(endTime)"
    }
    
    // UPDATED: Convenience initializers
    init(from game: Game, team: Team) {
        self.id = game.id.uuidString
        self.type = .game
        self.title = "vs \(game.opponent)"
        self.location = game.location ?? "TBD"
        self.date = game.date
        self.duration = 90 // Default game duration
        self.gameId = game.id
        self.practiceId = nil
        self.teamId = team.id
        self.teamName = team.name
    }
    
    init(from practice: Practice, team: Team) {
        self.id = practice.id.uuidString
        self.type = .practice
        self.title = "Practice Session"
        self.location = practice.location ?? "TBD"
        self.date = practice.date
        self.duration = practice.duration
        self.gameId = nil
        self.practiceId = practice.id
        self.teamId = team.id
        self.teamName = team.name
    }
}

enum TeamEventType: String, Codable {
    case game = "game"
    case practice = "practice"
    
    var color: Color {
        switch self {
        case .game: return .green
        case .practice: return .blue
        }
    }
}

enum RSVPStatus: String, Codable {
    case confirmed = "confirmed"
    case declined = "declined"
    case unknown = "unknown"
    
    var color: Color {
        switch self {
        case .confirmed: return .green
        case .declined: return .red
        case .unknown: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .confirmed: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var displayText: String {
        switch self {
        case .confirmed: return "Going"
        case .declined: return "Not Going"
        case .unknown: return "No Response"
        }
    }
}

// MARK: - Optimized Events View with Caching
struct UpcomingEventsListView: View {
    @EnvironmentObject var teamManager: TeamManager
    @State private var selectedDate = Date()
    @State private var selectedTeamId: UUID? = nil
    @State private var selectedEvent: TeamEvent?
    @State private var showingEventDetail = false
    @State private var showingCalendar = true
    @State private var isLoadingTeamData = false
    @State private var hasInitiallyLoaded = false
    
    // ADDED: Caching for expensive calculations
    @State private var cachedEvents: [TeamEvent] = []
    @State private var lastTeamsHash: Int = 0
    @State private var lastCacheUpdate: Date = Date.distantPast
    @State private var cacheDebounceTask: Task<Void, Never>? = nil
    
    // Cache expiration time (30 seconds)
    private let cacheExpirationInterval: TimeInterval = 30
    
    // Use teamManager.teams directly instead of passing teams as parameter
    var teams: [Team] {
        return teamManager.teams
    }
    
    var allEvents: [TeamEvent] {
        // Don't modify state in computed property - just return cached events
        return cachedEvents
    }
    
    var filteredEvents: [TeamEvent] {
        selectedTeamId == nil ? allEvents : allEvents.filter { $0.teamId == selectedTeamId }
    }
    
    var availableTeams: [Team] {
        teams.filter { team in
            allEvents.contains { $0.teamId == team.id }
        }
    }
    
    var upcomingEvents: [TeamEvent] {
        let now = Date()
        return filteredEvents.filter { $0.date >= now }.sorted { $0.date < $1.date }
    }
    
    var nextFiveEvents: [TeamEvent] {
        Array(upcomingEvents.prefix(5))
    }
    
    var todayEvents: [TeamEvent] {
        upcomingEvents.filter { Calendar.current.isDateInToday($0.date) }
    }
    
    var selectedDateEvents: [TeamEvent] {
        filteredEvents.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }
    
    // Check if selected date is different from today
    var isSelectedDateNotToday: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }
    
    // Check if we're ready to show content
    var isReadyToShowContent: Bool {
        !isLoadingTeamData && hasInitiallyLoaded
    }
    
    var body: some View {
        NavigationView {
            Group {
                if !hasInitiallyLoaded {
                    // Loading state
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading your events...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Main content
                    mainContent
                }
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                selectedDate = Date()
                // Load data with proper initialization check
                if !hasInitiallyLoaded {
                    performInitialLoad()
                } else {
                    // Just update cache if we've already loaded
                    updateCacheIfNeeded()
                }
            }
            .onChange(of: teamManager.teams) { _ in
                // Debounce cache updates so rapid bursts (e.g. subcollection loading) only trigger once
                cacheDebounceTask?.cancel()
                cacheDebounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    guard !Task.isCancelled else { return }
                    updateCacheIfNeeded()
                    if !teamManager.teams.isEmpty && !hasInitiallyLoaded {
                        hasInitiallyLoaded = true
                    }
                }
            }
            .refreshable {
                invalidateCache()
                await loadAllTeamDataFromFirebase()
            }
        }
        .sheet(isPresented: $showingEventDetail) {
            if let event = selectedEvent {
                // First try to find the team in teamManager
                if let team = teamManager.teams.first(where: { $0.id == event.teamId }) {
                    EventDetailView(event: event, team: team)
                        .environmentObject(teamManager)
                        .onAppear {
                            print("📋 Sheet: Presenting event \(event.title) for team \(event.teamName)")
                            print("📋 Sheet: Found team \(team.name) with \(team.players.count) players")
                        }
                } else {
                    // Show loading state if team not found yet
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Loading event details...")
                            .font(.headline)
                        
                        Text("Please wait a moment while we load the team data.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Cancel") {
                            showingEventDetail = false
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    .onAppear {
                        // Try to load the specific team
                        Task {
                            await loadSpecificTeam(teamId: event.teamId)
                        }
                    }
                }
            }
        }
    }
    
    // Split main content into a separate computed property to avoid complexity
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Loading indicator for refresh
            if isLoadingTeamData {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Updating events...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Team Filter (if multiple teams)
            if teams.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        TeamFilterButton(
                            title: "All Teams",
                            isSelected: selectedTeamId == nil,
                            action: { selectedTeamId = nil }
                        )
                        
                        ForEach(availableTeams) { team in
                            TeamFilterButton(
                                title: team.name,
                                isSelected: selectedTeamId == team.id,
                                action: { selectedTeamId = team.id }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            
            // Calendar Toggle
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingCalendar.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showingCalendar ? "calendar.badge.minus" : "calendar.badge.plus")
                        Text(showingCalendar ? "Hide Calendar" : "Show Calendar")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical, 8)
            
            // Mini Calendar
            if showingCalendar {
                EventsCalendarView(
                    selectedDate: $selectedDate,
                    events: filteredEvents
                )
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            
            // Events List
            eventsListContent
        }
    }
    
    @ViewBuilder
    private var eventsListContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Today's Events (if any and calendar is showing)
                if showingCalendar && !todayEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                        
                        ForEach(todayEvents) { event in
                            EventCard(event: event, teams: teams) {
                                selectedEvent = event
                                showingEventDetail = true
                            }
                        }
                    }
                }
                
                // Selected Date Events (only if different from today and calendar is showing)
                if showingCalendar && isSelectedDateNotToday && !selectedDateEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Selected Date - \(DateFormatter.selectedDate.string(from: selectedDate))")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .padding(.horizontal)
                        
                        ForEach(selectedDateEvents) { event in
                            EventCard(event: event, teams: teams) {
                                selectedEvent = event
                                showingEventDetail = true
                            }
                        }
                    }
                }
                
                // Next 5 Events Section (always visible)
                if !nextFiveEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next 5 Events")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ForEach(nextFiveEvents) { event in
                            EventCard(event: event, teams: teams) {
                                selectedEvent = event
                                showingEventDetail = true
                            }
                        }
                    }
                } else {
                    // Empty state
                    EmptyEventsView(isUpcoming: true)
                        .padding(.top, 20)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100) // Account for tab bar
        }
    }
    
    // MARK: - Initial Load
    private func performInitialLoad() {
        guard !hasInitiallyLoaded else { return }
        
        isLoadingTeamData = true
        
        Task {
            // Give the teamManager a moment to load if it hasn't already
            if teamManager.teams.isEmpty {
                await MainActor.run {
                    teamManager.loadData()
                }
                
                // Wait for initial load
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
            
            // Load subcollections if needed
            for team in teamManager.teams {
                if team.useSubcollections && (team.players.isEmpty || team.games.isEmpty || team.practices.isEmpty) {
                    await teamManager.loadTeamDataWithSubcollections(team)
                }
            }
            
            await MainActor.run {
                isLoadingTeamData = false
                hasInitiallyLoaded = true
                updateCacheIfNeeded()
                print("📋 Initial load complete with \(teamManager.teams.count) teams")
            }
        }
    }
    
    // MARK: - Load specific team
    private func loadSpecificTeam(teamId: UUID) async {
        // Check if team exists but needs subcollection data
        if let team = teamManager.teams.first(where: { $0.id == teamId }) {
            if team.useSubcollections && (team.players.isEmpty || team.games.isEmpty || team.practices.isEmpty) {
                await teamManager.loadTeamDataWithSubcollections(team)
                
                await MainActor.run {
                    updateCacheIfNeeded()
                    // Retry showing the event detail
                    showingEventDetail = true
                }
            }
        } else {
            // Team not in manager, try to reload all teams
            await loadAllTeamDataFromFirebase()
        }
    }
    
    // New async function for refreshable
    private func loadAllTeamDataFromFirebase() async {
        isLoadingTeamData = true
        
        // Force reload using the public forceLoadTeamsFromFirebase method
        await teamManager.forceLoadTeamsFromFirebase()
        
        // Load subcollections for teams that need it
        for team in teamManager.teams {
            if team.useSubcollections {
                await teamManager.loadTeamDataWithSubcollections(team)
            }
        }
        
        await MainActor.run {
            isLoadingTeamData = false
            hasInitiallyLoaded = true
            updateCacheIfNeeded()
        }
    }
    
    // MARK: - Cache Management
    private func updateCacheIfNeeded() {
        let currentHash = calculateTeamsHash()
        let now = Date()
        
        // Check if cache needs updating
        let shouldUpdate = (currentHash != lastTeamsHash) ||
                          (now.timeIntervalSince(lastCacheUpdate) >= cacheExpirationInterval) ||
                          cachedEvents.isEmpty
        
        if shouldUpdate {
            print("🔄 Updating cache - hash changed: \(currentHash != lastTeamsHash), expired: \(now.timeIntervalSince(lastCacheUpdate) >= cacheExpirationInterval), empty: \(cachedEvents.isEmpty)")
            
            let newEvents = calculateAllEvents()
            cachedEvents = newEvents
            lastTeamsHash = currentHash
            lastCacheUpdate = now
        } else {
            print("💾 Cache is valid, using \(cachedEvents.count) cached events")
        }
    }
    
    private func calculateTeamsHash() -> Int {
        var hasher = Hasher()
        
        for team in teams {
            hasher.combine(team.id)
            hasher.combine(team.games.count)
            hasher.combine(team.practices.count)
            hasher.combine(team.players.count) // Include players count
            
            // Hash game and practice dates for more sensitive change detection
            for game in team.games {
                hasher.combine(game.id)
                hasher.combine(game.date.timeIntervalSince1970)
            }
            
            for practice in team.practices {
                hasher.combine(practice.id)
                hasher.combine(practice.date.timeIntervalSince1970)
            }
        }
        
        return hasher.finalize()
    }
    
    private func calculateAllEvents() -> [TeamEvent] {
        let startTime = CFAbsoluteTimeGetCurrent()
        var events: [TeamEvent] = []
        
        print("📋 calculateAllEvents: Processing \(teams.count) teams")
        
        for team in teams {
            print("📋 calculateAllEvents: Team \(team.name) has \(team.players.count) players, \(team.games.count) games, \(team.practices.count) practices")
            
            // Add games
            for game in team.games {
                events.append(TeamEvent(from: game, team: team))
            }
            
            // Add practices
            for practice in team.practices {
                events.append(TeamEvent(from: practice, team: team))
            }
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("📋 calculateAllEvents: Created \(events.count) total events in \(String(format: "%.3f", timeElapsed))s")
        return events
    }
    
    private func invalidateCache() {
        lastTeamsHash = 0
        lastCacheUpdate = Date.distantPast
        cachedEvents = []
        print("🗑️ Event cache invalidated")
    }
}

// MARK: - Team Filter Button
struct TeamFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Mini Calendar View
struct EventsCalendarView: View {
    @Binding var selectedDate: Date
    let events: [TeamEvent]
    @State private var currentMonth = Date()
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    private var monthYearString: String {
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: currentMonth)
    }
    
    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end - 1) else {
            return []
        }
        
        var days: [Date] = []
        var date = monthFirstWeek.start
        
        while date < monthLastWeek.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        return days
    }
    
    private func eventsForDate(_ date: Date) -> [TeamEvent] {
        events.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    private func isInCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Month Navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(monthYearString)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Day headers
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                // Calendar days
                ForEach(daysInMonth, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        events: eventsForDate(date),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isInCurrentMonth: isInCurrentMonth(date),
                        isToday: calendar.isDateInToday(date)
                    ) {
                        selectedDate = date
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

// MARK: - Calendar Day View
struct CalendarDayView: View {
    let date: Date
    let events: [TeamEvent]
    let isSelected: Bool
    let isInCurrentMonth: Bool
    let isToday: Bool
    let onTap: () -> Void
    
    private var dayNumber: String {
        DateFormatter.dayNumber.string(from: date)
    }
    
    private var hasGames: Bool {
        events.contains { $0.type == .game }
    }
    
    private var hasPractices: Bool {
        events.contains { $0.type == .practice }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(
                        isSelected ? .white :
                        isToday ? .blue :
                        isInCurrentMonth ? .primary : .secondary
                    )
                
                // Event indicators
                HStack(spacing: 2) {
                    if hasGames {
                        Circle()
                            .fill(TeamEventType.game.color)
                            .frame(width: 4, height: 4)
                    }
                    if hasPractices {
                        Circle()
                            .fill(TeamEventType.practice.color)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(width: 35, height: 35)
            .background(
                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
            )
            .overlay(
                Circle()
                    .stroke(isToday && !isSelected ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Event Card
struct EventCard: View {
    let event: TeamEvent
    let teams: [Team]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .center, spacing: 4) {
                    Text(DateFormatter.dayOfWeek.string(from: event.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(DateFormatter.dayNumber.string(from: event.date))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(event.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Show team name if multiple teams
                        if teams.count > 1 {
                            Text(event.teamName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                        
                        Image(systemName: event.type == .game ? "soccerball" : "figure.run")
                            .foregroundColor(event.type.color)
                    }
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text(event.timeRange)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                        Text(event.location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty Events View
struct EmptyEventsView: View {
    let isUpcoming: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isUpcoming ? "calendar.badge.plus" : "calendar.badge.checkmark")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(isUpcoming ? "No upcoming events" : "No past events")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(isUpcoming ? "Schedule your first game or practice to get started" : "Events will appear here after they happen")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Event Detail View
struct EventDetailView: View {
    let event: TeamEvent
    let team: Team
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var teamManager: TeamManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Event Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(event.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: "person.3")
                            Text(event.teamName)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        
                        HStack {
                            Image(systemName: "calendar")
                            Text(DateFormatter.fullDateTime.string(from: event.date))
                        }
                        .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "location")
                            Text(event.location)
                        }
                        .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "clock")
                            Text("\(event.duration) minutes")
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Event-specific details
                    if event.type == .game, let game = event.getGame(from: team) {
                        GameDetailsSection(game: game, team: team)
                    } else if event.type == .practice, let practice = event.getPractice(from: team) {
                        PracticeDetailsSection(practice: practice, team: team)
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
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

// MARK: - Game Details Section (Enhanced)
struct GameDetailsSection: View {
    let game: Game
    let team: Team
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Game Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Game Details")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    DetailRow(icon: "person.2", title: "Opponent", value: game.opponent)
                    DetailRow(icon: "house", title: "Home/Away", value: game.isHome ? "Home" : "Away")
                    
                    if let result = game.result {
                        DetailRow(icon: "soccerball", title: "Score", value: "\(result.goalsFor) - \(result.goalsAgainst)")
                        DetailRow(icon: "trophy", title: "Result", value: result.goalsFor > result.goalsAgainst ? "Win" : result.goalsFor < result.goalsAgainst ? "Loss" : "Draw")
                    } else {
                        DetailRow(icon: "calendar.badge.clock", title: "Status", value: "Upcoming")
                    }
                    
                    if let location = game.location {
                        DetailRow(icon: "map", title: "Venue", value: location)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Formation for this game
            if let formation = game.formation {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Formation")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "rectangle.3.group")
                            .foregroundColor(.blue)
                        Text(formation.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            
            // Game Events Summary (if game has been played)
            if let result = game.result, !game.gameEvents.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Game Summary")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        // Goals scored
                        let goals = game.gameEvents.filter { $0.eventType == .goal }
                        if !goals.isEmpty {
                            HStack {
                                Image(systemName: "soccerball")
                                    .foregroundColor(.green)
                                Text("Goals")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(goals.count)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        // Yellow cards
                        let yellowCards = game.gameEvents.filter { $0.eventType == .yellowCard }
                        if !yellowCards.isEmpty {
                            HStack {
                                Image(systemName: "rectangle.fill")
                                    .foregroundColor(.yellow)
                                Text("Yellow Cards")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(yellowCards.count)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        // Red cards
                        let redCards = game.gameEvents.filter { $0.eventType == .redCard }
                        if !redCards.isEmpty {
                            HStack {
                                Image(systemName: "rectangle.fill")
                                    .foregroundColor(.red)
                                Text("Red Cards")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(redCards.count)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            
            // Key Players to Watch (for upcoming games)
            if game.result == nil {
                let topPlayers = getTopPlayers(from: team)
                if !topPlayers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key Players")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(topPlayers.prefix(3), id: \.id) { player in
                                HStack {
                                    Circle()
                                        .fill(player.preferredPositionEnum.color)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Text("\(player.jerseyNumber)")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        )
                                    
                                    VStack(alignment: .leading) {
                                        Text(player.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("\(player.seasonStats.goals) goals, \(player.seasonStats.assists) assists")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private func getTopPlayers(from team: Team) -> [Player] {
        team.players.sorted { player1, player2 in
            let score1 = player1.seasonStats.goals * 2 + player1.seasonStats.assists
            let score2 = player2.seasonStats.goals * 2 + player2.seasonStats.assists
            return score1 > score2
        }
    }
}

// MARK: - Practice Details Section (Updated to match Game UI)
struct PracticeDetailsSection: View {
    let practice: Practice
    let team: Team
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Practice Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Practice Details")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    DetailRow(icon: "clock", title: "Duration", value: "\(practice.duration) minutes")
                    
                    if let location = practice.location {
                        DetailRow(icon: "map", title: "Venue", value: location)
                    }
                    
                    if let weather = practice.weather {
                        DetailRow(icon: weatherIcon(for: weather), title: "Weather", value: weather)
                    }
                    
                    DetailRow(icon: "figure.run.circle", title: "Status", value: practice.date > Date() ? "Upcoming" : "Completed")
                    
                    DetailRow(icon: "list.bullet", title: "Total Drills", value: "\(practice.drills.count)")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Practice Plan
            if !practice.drills.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Practice Plan")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(Array(practice.drills.enumerated()), id: \.element.id) { index, drill in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.blue))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(drill.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack {
                                        Text("\(drill.duration) min")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        Text(drill.category)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            
            // Practice Focus Areas (similar to Key Players for games)
            VStack(alignment: .leading, spacing: 12) {
                Text("Focus Areas")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 8) {
                    if let topCategories = getTopDrillCategories(from: practice.drills) {
                        ForEach(topCategories, id: \.self) { category in
                            HStack {
                                Image(systemName: categoryIcon(for: category))
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading) {
                                    Text(category)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(drillsInCategory(category, drills: practice.drills)) drills")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Notes Section
            if let notes = practice.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Coach Notes")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text(notes)
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    private func weatherIcon(for weather: String) -> String {
        switch weather.lowercased() {
        case "clear", "sunny": return "sun.max.fill"
        case "cloudy", "overcast": return "cloud.fill"
        case "rainy", "rain": return "cloud.rain.fill"
        case "windy": return "wind"
        case "hot": return "thermometer.sun.fill"
        case "cold": return "thermometer.snowflake"
        case "indoor": return "house.fill"
        default: return "cloud.sun.fill"
        }
    }
    
    private func getTopDrillCategories(from drills: [Drill]) -> [String]? {
        guard !drills.isEmpty else { return nil }
        
        var categoryCount: [String: Int] = [:]
        for drill in drills {
            categoryCount[drill.category, default: 0] += 1
        }
        
        return Array(categoryCount.keys.sorted {
            categoryCount[$0]! > categoryCount[$1]!
        }.prefix(3))
    }
    
    private func drillsInCategory(_ category: String, drills: [Drill]) -> Int {
        drills.filter { $0.category == category }.count
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "warm-up": return "figure.walk"
        case "technical", "dribbling": return "sportscourt"
        case "passing": return "arrow.left.and.right"
        case "shooting": return "target"
        case "defending": return "shield"
        case "fitness": return "figure.run"
        case "tactical": return "brain"
        case "informational": return "info.circle"
        case "game": return "gamecontroller"
        case "relay": return "arrow.triangle.2.circlepath"
        default: return "star"
        }
    }
}

// MARK: - Event Drill Row (Simplified drill display for events)
struct EventDrillRow: View {
    let drill: Drill
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.blue))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(drill.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(drill.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label("\(drill.duration) min", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(drill.category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        
                        Text(drill.difficulty)
                            .font(.caption)
                            .foregroundColor(difficultyColor(for: drill.difficulty))
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
    
    private func difficultyColor(for difficulty: String) -> Color {
        switch difficulty {
        case "Easy": return .green
        case "Medium": return .orange
        case "Hard": return .red
        default: return .gray
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.blue)
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Date Formatters
extension DateFormatter {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    static let dayOfWeek: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
    
    static let dayNumber: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter
    }()
    
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        return formatter
    }()
    
    static let selectedDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
}
