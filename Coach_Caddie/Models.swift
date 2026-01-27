import SwiftUI
import Foundation

// MARK: - Membership Type (NEW)
enum MembershipType: String, Codable, CaseIterable {
    case coach = "coach"
    case parent = "parent"
    case viewer = "viewer"
    case teamInvite = "team_invite"
    
    var displayName: String {
        switch self {
        case .coach: return "Coach"
        case .parent: return "Parent"
        case .viewer: return "Viewer"
        case .teamInvite: return "Team Member"
        }
    }
    
    var description: String {
        switch self {
        case .coach: return "Create and manage teams, add players, full access"
        case .parent: return "View team info, edit your child's details only"
        case .viewer: return "View-only access to team information"
        case .teamInvite: return "Invited team member with assigned access level"
        }
    }
    
    // ADD THIS COMPUTED PROPERTY:
    var defaultAccessLevel: AccessLevel {
        switch self {
        case .coach: return .coach
        case .parent: return .parent
        case .viewer: return .viewer
        case .teamInvite: return .viewer  // Default to viewer, but will be overridden by team role
        }
    }
    
    var canCreateTeams: Bool {
        switch self {
        case .coach: return true
        case .parent, .viewer: return false
        case .teamInvite: return false
        }
    }
}

// MARK: - Subscription Level
enum SubscriptionLevel: String, Codable, Equatable {
    case free = "free"               // Legacy unlimited accounts
    case trial = "trial"             // 7-day free trial
    case coach = "coach"             // $4.99/month - renamed from pro
    case proCoach = "proCoach"       // $9.99/month - renamed from premium
    case sharedAccess = "sharedAccess"  // FREE: Access to shared teams only
    case cancelled = "cancelled"     // Cancelled but data retained
    case expired = "expired"         // Hard deleted after 180 days
    
    var displayName: String {
        switch self {
        case .free: return "Legacy (Unlimited)"
        case .trial: return "Free Trial"
        case .coach: return "Coach"
        case .proCoach: return "Pro Coach"
        case .sharedAccess: return "Shared Team Access"
        case .cancelled: return "Cancelled"
        case .expired: return "Expired"
        }
    }
    
    var monthlyPrice: String {
        switch self {
        case .free: return "Free Forever"
        case .trial: return "Free for 7 days"
        case .coach: return "$4.99/month"
        case .proCoach: return "$9.99/month"
        case .sharedAccess: return "Free (Shared Access)"
        case .cancelled, .expired: return "Inactive"
        }
    }

    var yearlyPrice: String {
        switch self {
        case .free: return "Free Forever"
        case .trial: return "Free for 7 days"
        case .coach: return "$39.99/year (save 33%)"
        case .proCoach: return "$79.99/year (save 33%)"
        case .sharedAccess: return "Free (Shared Access)"
        case .cancelled, .expired: return "Inactive"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .free, .trial, .coach, .proCoach, .sharedAccess: return true
        case .cancelled, .expired: return false
        }
    }
    
    var canCreateTeams: Bool {
        switch self {
        case .sharedAccess: return false  // Cannot create own teams
        case .free, .trial, .coach, .proCoach: return true
        case .cancelled, .expired: return false
        }
    }
    
    var canGenerateInvites: Bool {
        switch self {
        case .free, .trial, .coach, .proCoach, .sharedAccess: return true
        case .cancelled, .expired: return false
        }
    }
    
    var maxTeams: Int {
        switch self {
        case .free: return 999        // UNLIMITED for legacy accounts
        case .trial: return 1
        case .coach: return 2         // 2 teams for Coach tier
        case .proCoach: return 999    // Unlimited for Pro Coach
        case .sharedAccess: return 0  // Cannot create own teams
        case .cancelled, .expired: return 0
        }
    }
    
    var maxCoachInvitesPerTeam: Int {
        switch self {
        case .free: return 999        // UNLIMITED for legacy accounts
        case .trial: return 1
        case .coach: return 2
        case .proCoach: return 3
        case .sharedAccess: return 3
        case .cancelled, .expired: return 0
        }
    }
    
    var maxParentInvitesPerTeam: Int {
        switch self {
        case .free: return 999        // UNLIMITED for legacy accounts
        case .trial: return 15
        case .coach: return 25
        case .proCoach: return 25
        case .sharedAccess: return 25
        case .cancelled, .expired: return 0
        }
    }
    
    var maxViewerInvitesPerTeam: Int {
        switch self {
        case .free: return 999        // UNLIMITED for legacy accounts
        case .trial: return 15
        case .coach: return 25
        case .proCoach: return 25
        case .sharedAccess: return 25
        case .cancelled, .expired: return 0
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "🎉 Legacy Account - Free Forever!",
                "Unlimited teams",
                "Unlimited invites",
                "All features included"
            ]
        case .trial:
            return [
                "7-day free trial",
                "1 team",
                "Full team management",
                "Formation planning",
                "Game & practice tracking"
            ]
        case .coach:
            return [
                "Up to 2 teams",
                "2 coach invites per team",
                "25 parent/viewer invites",
                "Advanced statistics",
                "Season management",
                "Export data"
            ]
        case .proCoach:
            return [
                "Unlimited teams",
                "3 coach invites per team",
                "25 parent/viewer invites",
                "Advanced statistics",
                "Season management",
                "Export data",
                "Priority support"
            ]
        case .sharedAccess:
            return [
                "🎯 Shared Team Access",
                "Full access to invited teams",
                "All coaching features",
                "Free forever"
            ]
        case .cancelled:
            return [
                "Access suspended",
                "Data retained for 180 days",
                "Reactivate anytime"
            ]
        case .expired:
            return [
                "Account expired",
                "Data permanently deleted"
            ]
        }
    }
}
// MARK: - Season Type
enum SeasonType: String, Codable, CaseIterable {
    case fall = "Fall"
    case winter = "Winter"
    case spring = "Spring"
    case summer = "Summer"
    case tournament = "Tournament"
    
    var icon: String {
        switch self {
        case .fall: return "leaf.fill"
        case .winter: return "snowflake"
        case .spring: return "leaf.arrow.circlepath" 
        case .summer: return "sun.max.fill"
        case .tournament: return "trophy.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .fall: return .orange
        case .winter: return .blue
        case .spring: return .green
        case .summer: return .yellow
        case .tournament: return .purple
        }
    }
}

// MARK: - Season
struct Season: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String                        // e.g., "Fall 2024", "Memorial Day Cup"
    var type: SeasonType
    var year: String                        // e.g., "2024", "2024-2025"
    var startDate: Date
    var endDate: Date
    var activePlayerIds: [UUID] = []        // Team players active this season
    var guestPlayers: [GuestPlayer] = []    // Tournament guests
    var isArchived: Bool = false
    var dateCreated: Date = Date()
    
    // Computed property for display name
    var displayName: String {
        if type == .tournament {
            return name
        }
        return "\(type.rawValue) \(year)"
    }
    
    // Check if season is current (can add games to it)
    var isCurrentOrFuture: Bool {
        return endDate >= Calendar.current.startOfDay(for: Date())
    }
    
    // Check if season is active (within date range)
    var isActive: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return today >= start && today <= end
    }
}

// MARK: - Season Status
enum SeasonStatus {
    case inSeason(Season)
    case betweenSeasons(nextSeason: Season)
    case noUpcomingSeasons(lastSeason: Season?)
    case noSeasons
    
    var displayText: String {
        switch self {
        case .inSeason(let season):
            return "Current: \(season.displayName)"
        case .betweenSeasons(let nextSeason):
            return "Next: \(nextSeason.displayName)"
        case .noUpcomingSeasons(let lastSeason):
            if let last = lastSeason {
                return "Last: \(last.displayName)"
            }
            return "No Upcoming Seasons"
        case .noSeasons:
            return "No Seasons"
        }
    }
    
    var icon: String {
        switch self {
        case .inSeason:
            return "calendar.badge.clock"
        case .betweenSeasons:
            return "calendar.badge.plus"
        case .noUpcomingSeasons:
            return "calendar.badge.minus"
        case .noSeasons:
            return "calendar.badge.exclamationmark"
        }
    }
}
// MARK: - Guest Player (Lightweight for tournaments)
struct GuestPlayer: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var jerseyNumber: Int
    var preferredPosition: String = "Midfielder"
    var notes: String?
    var dateAdded: Date = Date()
    
    // Stats for this season only (stored directly since guest is season-specific)
    var seasonStats: PlayerStats = PlayerStats()
}

struct User: Identifiable, Codable, Equatable {
    var id: UUID
    var firebaseUID: String
    var email: String?
    var membershipType: MembershipType?
    var dateJoined: Date = Date()
    var subscriptionLevel: SubscriptionLevel = .trial
    var trialStartDate: Date = Date()
    var subscriptionEndDate: Date?
    var cancellationDate: Date?
    var dataRetentionEndDate: Date?
    var hasUsedTrial: Bool = false  // NEW: Track if user has ever used trial
    
    // Add computed property to check trial eligibility
    var isTrialEligible: Bool {
        return !hasUsedTrial
    }
    
    // EXISTING: Computed property for backward compatibility
    var effectiveMembershipType: MembershipType {
        return membershipType ?? .coach
    }
    
    // EXISTING: Check if trial has expired
    var isTrialExpired: Bool {
        guard subscriptionLevel == .trial else { return false }
        let trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: trialStartDate) ?? trialStartDate
        return Date() > trialEndDate
    }
    
    // EXISTING: Check if subscription is active
    var hasActiveSubscription: Bool {
        return subscriptionLevel.isActive && !isTrialExpired
    }
    
    // EXISTING: Check if data should be deleted
    var shouldDeleteData: Bool {
        guard let retentionEndDate = dataRetentionEndDate else { return false }
        return Date() > retentionEndDate
    }
    
    // EXISTING: Get days remaining in trial
    var trialDaysRemaining: Int {
        guard subscriptionLevel == .trial else { return 0 }
        let trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: trialStartDate) ?? trialStartDate
        let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: trialEndDate).day ?? 0
        return max(0, daysLeft)
    }
    
    // ADD THESE NEW COMPUTED PROPERTIES HERE:
    var effectiveMaxTeams: Int {
        // Only coaches can create teams regardless of subscription level
        guard effectiveMembershipType.canCreateTeams else { return 0 }
        // Shared access users cannot create teams even if they're coaches
        guard subscriptionLevel != .sharedAccess else { return 0 }
        return subscriptionLevel.maxTeams
    }

    var effectiveMaxCoachInvites: Int {
        // Only coaches can generate coach invites
        guard effectiveMembershipType == .coach else { return 0 }
        return subscriptionLevel.maxCoachInvitesPerTeam
    }

    var effectiveMaxParentInvites: Int {
        // Only coaches can generate parent invites
        guard effectiveMembershipType == .coach else { return 0 }
        return subscriptionLevel.maxParentInvitesPerTeam
    }

    var effectiveMaxViewerInvites: Int {
        // Only coaches can generate viewer invites
        guard effectiveMembershipType == .coach else { return 0 }
        return subscriptionLevel.maxViewerInvitesPerTeam
    }
    
    enum CodingKeys: String, CodingKey {
        case id, firebaseUID, email, membershipType, dateJoined, subscriptionLevel
        case trialStartDate, subscriptionEndDate, cancellationDate, dataRetentionEndDate
        case hasUsedTrial  // NEW
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        firebaseUID = try container.decode(String.self, forKey: .firebaseUID)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        membershipType = try container.decodeIfPresent(MembershipType.self, forKey: .membershipType)
        dateJoined = try container.decodeIfPresent(Date.self, forKey: .dateJoined) ?? Date()
        subscriptionLevel = try container.decodeIfPresent(SubscriptionLevel.self, forKey: .subscriptionLevel) ?? .trial
        
        // NEW FIELDS: Use defaults if not present for backward compatibility
        trialStartDate = try container.decodeIfPresent(Date.self, forKey: .trialStartDate) ?? Date()
        subscriptionEndDate = try container.decodeIfPresent(Date.self, forKey: .subscriptionEndDate)
        cancellationDate = try container.decodeIfPresent(Date.self, forKey: .cancellationDate)
        dataRetentionEndDate = try container.decodeIfPresent(Date.self, forKey: .dataRetentionEndDate)
        hasUsedTrial = try container.decodeIfPresent(Bool.self, forKey: .hasUsedTrial) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(firebaseUID, forKey: .firebaseUID)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(membershipType, forKey: .membershipType)
        try container.encode(dateJoined, forKey: .dateJoined)
        try container.encode(subscriptionLevel, forKey: .subscriptionLevel)
        try container.encode(trialStartDate, forKey: .trialStartDate)
        try container.encodeIfPresent(subscriptionEndDate, forKey: .subscriptionEndDate)
        try container.encodeIfPresent(cancellationDate, forKey: .cancellationDate)
        try container.encodeIfPresent(dataRetentionEndDate, forKey: .dataRetentionEndDate)
        try container.encode(hasUsedTrial, forKey: .hasUsedTrial)  // ADD THIS LINE
    }
    
    // MARK: - Standard initializer
    init(id: UUID = UUID(),
         firebaseUID: String,
         email: String? = nil,
         membershipType: MembershipType? = nil,
         dateJoined: Date = Date(),
         subscriptionLevel: SubscriptionLevel = .trial,
         trialStartDate: Date = Date(),
         subscriptionEndDate: Date? = nil,
         cancellationDate: Date? = nil,
         dataRetentionEndDate: Date? = nil,
         hasUsedTrial: Bool = false) {  // ADD THIS PARAMETER
        self.id = id
        self.firebaseUID = firebaseUID
        self.email = email
        self.membershipType = membershipType
        self.dateJoined = dateJoined
        self.subscriptionLevel = subscriptionLevel
        self.trialStartDate = trialStartDate
        self.subscriptionEndDate = subscriptionEndDate
        self.cancellationDate = cancellationDate
        self.dataRetentionEndDate = dataRetentionEndDate
        self.hasUsedTrial = hasUsedTrial  // ADD THIS LINE
    }
}

struct PlannedSubstitution: Identifiable, Codable, Equatable {
    var id: UUID = UUID() // CHANGED: from 'let' to 'var'
    var playerOut: UUID
    var playerIn: UUID
    var plannedMinute: Int
    var reason: SubstitutionReason
    var targetPosition: Position  // ADD THIS LINE
    var isExecuted: Bool = false
    var actualMinute: Int?
    var subGroupIndex: Int? = nil
    var groupDisplayName: String {
        guard let groupIndex = subGroupIndex else { return "Individual" }
        return "Sub \(groupIndex)"
    }
    
    // ADD CUSTOM DECODER FOR BACKWARD COMPATIBILITY
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        playerOut = try container.decode(UUID.self, forKey: .playerOut)
        playerIn = try container.decode(UUID.self, forKey: .playerIn)
        plannedMinute = try container.decode(Int.self, forKey: .plannedMinute)
        reason = try container.decode(SubstitutionReason.self, forKey: .reason)
        targetPosition = try container.decodeIfPresent(Position.self, forKey: .targetPosition) ?? .midfielder // Fallback
        isExecuted = try container.decodeIfPresent(Bool.self, forKey: .isExecuted) ?? false
        actualMinute = try container.decodeIfPresent(Int.self, forKey: .actualMinute)
        subGroupIndex = try container.decodeIfPresent(Int.self, forKey: .subGroupIndex)
    }
    
    // STANDARD INITIALIZER
    init(playerOut: UUID,
         playerIn: UUID,
         plannedMinute: Int,
         reason: SubstitutionReason,
         targetPosition: Position) {
        self.id = UUID()
        self.playerOut = playerOut
        self.playerIn = playerIn
        self.plannedMinute = plannedMinute
        self.reason = reason
        self.targetPosition = targetPosition
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, playerOut, playerIn, plannedMinute, reason, targetPosition
        case isExecuted, actualMinute, subGroupIndex
    }
}

// MARK: - Lineup Phase
struct LineupPhase: Identifiable, Codable, Equatable {
    let id = UUID()
    var name: String
    var startMinute: Int
    var endMinute: Int?
    var lineup: [LineupPosition]
    var isExecuted: Bool = false
}

// MARK: - Team Format (Use GameFormat from Formation.swift instead)
typealias TeamFormat = GameFormat

// MARK: - Team
struct Team: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var format: TeamFormat
    var defaultFormation: Formation
    var defaultHalfLength: Int = 45
    var players: [Player]                   // Full historical roster
    var games: [Game]                       // KEEP for backward compatibility
    var practices: [Practice]               // KEEP for backward compatibility
    var seasons: [Season] = []              // NEW: All seasons for this team
    var activeSeasonId: UUID?               // NEW: Currently selected season
    var showArchivedSeasons: Bool = false   // NEW: Toggle to show/hide archived
    var primaryColor: Color
    var logoData: Data?
    var ageGroup: String?
    var season: String?                     // KEEP for backward compatibility (legacy)
    var dateCreated: Date
    var coachUID: String?
    var expirationDate: Date?
    var lastActivityTimestamp: Date = Date()
    var useSubcollections: Bool = false
    var lastSyncDate: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id, name, format, defaultFormation, defaultHalfLength, players, games, practices
        case seasons, activeSeasonId, showArchivedSeasons
        case primaryColorHex, logoData, ageGroup, season, dateCreated, coachUID
        case expirationDate, lastActivityTimestamp
        case useSubcollections, lastSyncDate
    }

    init(id: UUID = UUID(),
         name: String,
         format: TeamFormat,
         defaultFormation: Formation = .formation442,
         defaultHalfLength: Int = 45,
         players: [Player] = [],
         games: [Game] = [],
         practices: [Practice] = [],
         seasons: [Season] = [],
         activeSeasonId: UUID? = nil,
         showArchivedSeasons: Bool = false,
         primaryColor: Color = .green,
         logoData: Data? = nil,
         ageGroup: String? = nil,
         season: String? = nil,
         dateCreated: Date = Date(),
         coachUID: String? = nil) {
        self.id = id
        self.name = name
        self.format = format
        self.defaultFormation = defaultFormation
        self.defaultHalfLength = defaultHalfLength
        self.players = players
        self.games = games
        self.practices = practices
        self.seasons = seasons
        self.activeSeasonId = activeSeasonId
        self.showArchivedSeasons = showArchivedSeasons
        self.primaryColor = primaryColor
        self.logoData = logoData
        self.ageGroup = ageGroup
        self.season = season
        self.dateCreated = dateCreated
        self.coachUID = coachUID
        self.lastActivityTimestamp = Date()
        self.expirationDate = Calendar.current.date(byAdding: .day, value: 180, to: Date())
    }

    // Decode Color from hex
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        format = try container.decode(TeamFormat.self, forKey: .format)
        defaultFormation = try container.decodeIfPresent(Formation.self, forKey: .defaultFormation) ?? .formation442
        defaultHalfLength = try container.decodeIfPresent(Int.self, forKey: .defaultHalfLength) ?? 45
        players = try container.decode([Player].self, forKey: .players)
        games = try container.decode([Game].self, forKey: .games)
        practices = try container.decodeIfPresent([Practice].self, forKey: .practices) ?? []
        
        // NEW: Decode season fields with backward compatibility
        seasons = try container.decodeIfPresent([Season].self, forKey: .seasons) ?? []
        activeSeasonId = try container.decodeIfPresent(UUID.self, forKey: .activeSeasonId)
        showArchivedSeasons = try container.decodeIfPresent(Bool.self, forKey: .showArchivedSeasons) ?? false
        
        useSubcollections = try container.decodeIfPresent(Bool.self, forKey: .useSubcollections) ?? false
        lastSyncDate = try container.decodeIfPresent(Date.self, forKey: .lastSyncDate) ?? Date()
        
        // Handle TTL fields with backward compatibility
        lastActivityTimestamp = try container.decodeIfPresent(Date.self, forKey: .lastActivityTimestamp) ?? Date()
        expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
        
        // If no expiration date exists, set it to 180 days from last activity
        if expirationDate == nil {
            expirationDate = Calendar.current.date(byAdding: .day, value: 180, to: lastActivityTimestamp)
        }

        if let colorHex = try container.decodeIfPresent(String.self, forKey: .primaryColorHex) {
            primaryColor = Color(hex: colorHex)
        } else {
            primaryColor = .green
        }

        logoData = try container.decodeIfPresent(Data.self, forKey: .logoData)
        ageGroup = try container.decodeIfPresent(String.self, forKey: .ageGroup)
        season = try container.decodeIfPresent(String.self, forKey: .season)
        dateCreated = try container.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        coachUID = try container.decodeIfPresent(String.self, forKey: .coachUID)
    }

    // Encode Color to hex
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(format, forKey: .format)
        try container.encode(defaultFormation, forKey: .defaultFormation)
        try container.encode(defaultHalfLength, forKey: .defaultHalfLength)
        try container.encode(players, forKey: .players)
        try container.encode(games, forKey: .games)
        try container.encode(practices, forKey: .practices)
        
        // NEW: Encode season fields
        try container.encode(seasons, forKey: .seasons)
        try container.encodeIfPresent(activeSeasonId, forKey: .activeSeasonId)
        try container.encode(showArchivedSeasons, forKey: .showArchivedSeasons)
        
        try container.encode(useSubcollections, forKey: .useSubcollections)
        try container.encode(lastSyncDate, forKey: .lastSyncDate)
        try container.encode(primaryColor.toHex(), forKey: .primaryColorHex)
        try container.encodeIfPresent(logoData, forKey: .logoData)
        try container.encodeIfPresent(ageGroup, forKey: .ageGroup)
        try container.encodeIfPresent(season, forKey: .season)
        try container.encode(dateCreated, forKey: .dateCreated)
        try container.encodeIfPresent(coachUID, forKey: .coachUID)
        try container.encode(lastActivityTimestamp, forKey: .lastActivityTimestamp)
        try container.encodeIfPresent(expirationDate, forKey: .expirationDate)
    }

    // MARK: - Existing Computed Properties (KEEP ALL)
    
    var activePlayerCount: Int {
        players.filter { !($0.isInjured ?? false) }.count
    }

    var injuredPlayerCount: Int {
        players.filter { $0.isInjured ?? false }.count
    }

    var upcomingGames: [Game] {
        games.filter { $0.date > Date() }.sorted { $0.date < $1.date }
    }

    var pastGames: [Game] {
        games.filter { $0.date <= Date() }.sorted { $0.date > $1.date }
    }

    var nextGame: Game? {
        upcomingGames.first
    }

    var winPercentage: Double {
        let gamesWithResults = games.compactMap { $0.result }
        guard !gamesWithResults.isEmpty else { return 0 }

        let wins = gamesWithResults.filter { $0.goalsFor > $0.goalsAgainst }.count
        return Double(wins) / Double(gamesWithResults.count) * 100
    }

    var record: (wins: Int, losses: Int, draws: Int) {
        let gamesWithResults = games.compactMap { $0.result }
        let wins = gamesWithResults.filter { $0.goalsFor > $0.goalsAgainst }.count
        let losses = gamesWithResults.filter { $0.goalsFor < $0.goalsAgainst }.count
        let draws = gamesWithResults.filter { $0.goalsFor == $0.goalsAgainst }.count
        return (wins, losses, draws)
    }
    
    var activePlayers: [Player] {
        players.filter { !($0.isInjured ?? false) }
    }
    
    mutating func updateActivityForTTL() {
        lastActivityTimestamp = Date()
        expirationDate = Calendar.current.date(byAdding: .day, value: 180, to: Date())
    }
    
    // MARK: - NEW: Season Helper Properties & Methods
    
    /// Get the currently active season
    var activeSeason: Season? {
        guard let activeId = activeSeasonId else { return nil }
        return seasons.first(where: { $0.id == activeId })
    }
    
    /// Get seasons that can have games added (end date is today or future, not archived)
    var availableSeasonsForGames: [Season] {
        seasons.filter { $0.isCurrentOrFuture && !$0.isArchived }
    }
    
    /// Get visible seasons (respects archive toggle)
    var visibleSeasons: [Season] {
        if showArchivedSeasons {
            return seasons.sorted { $0.startDate > $1.startDate }
        }
        return seasons.filter { !$0.isArchived }.sorted { $0.startDate > $1.startDate }
    }
    
    /// Get games for a specific season
    func games(for seasonId: UUID) -> [Game] {
        games.filter { $0.seasonId == seasonId }
    }
    
    /// Get practices for a specific season
    func practices(for seasonId: UUID) -> [Practice] {
        practices.filter { $0.seasonId == seasonId }
    }
    
    /// Get active roster for a specific season (team players only, not guests)
    func activeRoster(for seasonId: UUID) -> [Player] {
        guard let season = seasons.first(where: { $0.id == seasonId }) else { return [] }
        return players.filter { season.activePlayerIds.contains($0.id) }
    }
    
    /// Get guest players for a specific season
    func guestPlayers(for seasonId: UUID) -> [GuestPlayer] {
        guard let season = seasons.first(where: { $0.id == seasonId }) else { return [] }
        return season.guestPlayers
    }
    
    /// Check if team has any seasons
    var hasSeasons: Bool {
        !seasons.isEmpty
    }
    
    var effectiveActiveSeason: Season? {
        let today = Calendar.current.startOfDay(for: Date())
        
        // First, check for a season we're currently in
        let currentSeason = seasons.first { season in
            let start = Calendar.current.startOfDay(for: season.startDate)
            let end = Calendar.current.startOfDay(for: season.endDate)
            return today >= start && today <= end && !season.isArchived
        }
        
        if let current = currentSeason {
            return current
        }
        
        // Next, find the next upcoming season
        let upcomingSeason = seasons
            .filter { Calendar.current.startOfDay(for: $0.startDate) > today && !$0.isArchived }
            .sorted { $0.startDate < $1.startDate }
            .first
        
        if let upcoming = upcomingSeason {
            return upcoming
        }
        
        // Finally, fall back to most recent past season that's not archived
        let pastSeason = seasons
            .filter { Calendar.current.startOfDay(for: $0.endDate) < today && !$0.isArchived }
            .sorted { $0.endDate > $1.endDate }
            .first
        
        return pastSeason
    }

    /// Season status for display purposes
    var seasonStatus: SeasonStatus {
        let today = Calendar.current.startOfDay(for: Date())
        
        // FIRST: Check if user has manually set an active season
        if let activeId = activeSeasonId,
           let activeSeason = seasons.first(where: { $0.id == activeId }),
           !activeSeason.isArchived {
            return .inSeason(activeSeason)
        }
        
        // Check if we're currently in a season (by dates)
        let currentSeason = seasons.first { season in
            let start = Calendar.current.startOfDay(for: season.startDate)
            let end = Calendar.current.startOfDay(for: season.endDate)
            return today >= start && today <= end && !season.isArchived
        }
        
        if let current = currentSeason {
            return .inSeason(current)
        }
        
        // Check for upcoming seasons
        let upcomingSeason = seasons
            .filter { Calendar.current.startOfDay(for: $0.startDate) > today && !$0.isArchived }
            .sorted { $0.startDate < $1.startDate }
            .first
        
        if let upcoming = upcomingSeason {
            return .betweenSeasons(nextSeason: upcoming)
        }
        
        // No current or upcoming - find most recent past season
        let pastSeason = seasons
            .filter { Calendar.current.startOfDay(for: $0.endDate) < today && !$0.isArchived }
            .sorted { $0.endDate > $1.endDate }
            .first
        
        if seasons.isEmpty {
            return .noSeasons
        }
        
        return .noUpcomingSeasons(lastSeason: pastSeason)
    }

    /// Get the season ID to use for new games/practices
    var seasonIdForNewEvents: UUID? {
        // First check if there's a manually set active season
        if let activeId = activeSeasonId,
           let activeSeason = seasons.first(where: { $0.id == activeId }),
           !activeSeason.isArchived {
            return activeId
        }
        
        // Otherwise use the effective active season
        return effectiveActiveSeason?.id
    }
    
    /// Get record for a specific season
    func record(for seasonId: UUID) -> (wins: Int, losses: Int, draws: Int) {
        let seasonGames = games(for: seasonId)
        let gamesWithResults = seasonGames.compactMap { $0.result }
        let wins = gamesWithResults.filter { $0.goalsFor > $0.goalsAgainst }.count
        let losses = gamesWithResults.filter { $0.goalsFor < $0.goalsAgainst }.count
        let draws = gamesWithResults.filter { $0.goalsFor == $0.goalsAgainst }.count
        return (wins, losses, draws)
    }
    
    static func == (lhs: Team, rhs: Team) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Player Privacy Settings (UPDATED for COPPA with Fallback)
struct PlayerPrivacySettings: Codable, Equatable {
    var allowNameDisplay: Bool = true
    var allowPhotoSharing: Bool = false // Default to false for COPPA compliance
    var allowStatsSharing: Bool = true
    var allowContactDisplay: Bool = false // Default to false for COPPA compliance
    var parentConsentReceived: Bool = false
    var consentDate: Date?
    var consentMethod: String? // "verbal", "written", "digital"
    
    // MARK: - Custom Decoding for Backward Compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // All fields are optional with fallback to defaults
        allowNameDisplay = try container.decodeIfPresent(Bool.self, forKey: .allowNameDisplay) ?? true
        allowPhotoSharing = try container.decodeIfPresent(Bool.self, forKey: .allowPhotoSharing) ?? false
        allowStatsSharing = try container.decodeIfPresent(Bool.self, forKey: .allowStatsSharing) ?? true
        allowContactDisplay = try container.decodeIfPresent(Bool.self, forKey: .allowContactDisplay) ?? false
        parentConsentReceived = try container.decodeIfPresent(Bool.self, forKey: .parentConsentReceived) ?? false
        consentDate = try container.decodeIfPresent(Date.self, forKey: .consentDate)
        consentMethod = try container.decodeIfPresent(String.self, forKey: .consentMethod)
    }
    
    // MARK: - Parameterized Initializer (for compatibility)
    init(allowNameDisplay: Bool = true,
         allowPhotoSharing: Bool = false,
         allowStatsSharing: Bool = true,
         allowContactDisplay: Bool = false,
         parentConsentReceived: Bool = false,
         consentDate: Date? = nil,
         consentMethod: String? = nil) {
        self.allowNameDisplay = allowNameDisplay
        self.allowPhotoSharing = allowPhotoSharing
        self.allowStatsSharing = allowStatsSharing
        self.allowContactDisplay = allowContactDisplay
        self.parentConsentReceived = parentConsentReceived
        self.consentDate = consentDate
        self.consentMethod = consentMethod
    }
    
    // MARK: - Default Initializer
    init() {
        // All properties use their default values from declarations above
    }
    
    // MARK: - CodingKeys
    private enum CodingKeys: String, CodingKey {
        case allowNameDisplay
        case allowPhotoSharing
        case allowStatsSharing
        case allowContactDisplay
        case parentConsentReceived
        case consentDate
        case consentMethod
    }
}
// MARK: - Updated TeamPrivacySettings with Parent Notification Tracking
struct TeamPrivacySettings: Codable, Equatable {
    var allowPublicRoster: Bool = false
    var allowPublicStats: Bool = false
    var allowPublicPhotos: Bool = false
    var coachDataResponsibility: Bool = false
    var dataRetentionPeriod: Int = 180 // days
    var lastActivityDate: Date = Date()
    
    // COPPA compliance acknowledgment
    var coppaComplianceAcknowledged: Bool = false
    var coppaAcknowledgmentDate: Date?
    
    // NEW: Parent notification tracking (NO email automation - just tracking)
    var parentNotificationSent: Bool = false
    var parentNotificationDate: Date?
    var parentNotificationMethod: String = "" // "email", "text", "meeting", etc.
    
    // MARK: - Custom Decoding for Backward Compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // All fields are optional with fallback to defaults
        allowPublicRoster = try container.decodeIfPresent(Bool.self, forKey: .allowPublicRoster) ?? false
        allowPublicStats = try container.decodeIfPresent(Bool.self, forKey: .allowPublicStats) ?? false
        allowPublicPhotos = try container.decodeIfPresent(Bool.self, forKey: .allowPublicPhotos) ?? false
        coachDataResponsibility = try container.decodeIfPresent(Bool.self, forKey: .coachDataResponsibility) ?? false
        dataRetentionPeriod = try container.decodeIfPresent(Int.self, forKey: .dataRetentionPeriod) ?? 180
        lastActivityDate = try container.decodeIfPresent(Date.self, forKey: .lastActivityDate) ?? Date()
        
        // COPPA compliance fields
        coppaComplianceAcknowledged = try container.decodeIfPresent(Bool.self, forKey: .coppaComplianceAcknowledged) ?? false
        coppaAcknowledgmentDate = try container.decodeIfPresent(Date.self, forKey: .coppaAcknowledgmentDate)
        
        // NEW: Parent notification fields (with fallback for existing teams)
        parentNotificationSent = try container.decodeIfPresent(Bool.self, forKey: .parentNotificationSent) ?? false
        parentNotificationDate = try container.decodeIfPresent(Date.self, forKey: .parentNotificationDate)
        parentNotificationMethod = try container.decodeIfPresent(String.self, forKey: .parentNotificationMethod) ?? ""
    }
    
    // MARK: - Parameterized Initializer (for compatibility)
    init(allowPublicRoster: Bool = false,
         allowPublicStats: Bool = false,
         allowPublicPhotos: Bool = false,
         coachDataResponsibility: Bool = false,
         dataRetentionPeriod: Int = 180,
         lastActivityDate: Date = Date(),
         coppaComplianceAcknowledged: Bool = false,
         coppaAcknowledgmentDate: Date? = nil,
         parentNotificationSent: Bool = false,
         parentNotificationDate: Date? = nil,
         parentNotificationMethod: String = "") {
        self.allowPublicRoster = allowPublicRoster
        self.allowPublicStats = allowPublicStats
        self.allowPublicPhotos = allowPublicPhotos
        self.coachDataResponsibility = coachDataResponsibility
        self.dataRetentionPeriod = dataRetentionPeriod
        self.lastActivityDate = lastActivityDate
        self.coppaComplianceAcknowledged = coppaComplianceAcknowledged
        self.coppaAcknowledgmentDate = coppaAcknowledgmentDate
        self.parentNotificationSent = parentNotificationSent
        self.parentNotificationDate = parentNotificationDate
        self.parentNotificationMethod = parentNotificationMethod
    }
    
    // MARK: - Default Initializer
    init() {
        // All properties use their default values from declarations above
    }
    
    // MARK: - CodingKeys
    private enum CodingKeys: String, CodingKey {
        case allowPublicRoster
        case allowPublicStats
        case allowPublicPhotos
        case coachDataResponsibility
        case dataRetentionPeriod
        case lastActivityDate
        case coppaComplianceAcknowledged
        case coppaAcknowledgmentDate
        // NEW: Parent notification keys
        case parentNotificationSent
        case parentNotificationDate
        case parentNotificationMethod
    }
}

// MARK: - Helper methods for parent notification tracking
extension TeamPrivacySettings {
    mutating func markParentNotificationSent(method: String) {
        parentNotificationSent = true
        parentNotificationDate = Date()
        parentNotificationMethod = method
    }
    
    mutating func clearParentNotification() {
        parentNotificationSent = false
        parentNotificationDate = nil
        parentNotificationMethod = ""
    }
    
    var parentNotificationStatus: String {
        if parentNotificationSent {
            let dateString = parentNotificationDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown"
            let methodString = parentNotificationMethod.isEmpty ? "Unknown method" : parentNotificationMethod
            return "Sent \(dateString) via \(methodString)"
        } else {
            return "Not sent"
        }
    }
}
// MARK: - Parent Info (UPDATED for COPPA Compliance with Fallback Decoding)
struct ParentInfo: Codable, Equatable {
    var parentName: String = ""
    var parentEmail: String = ""
    var parentPhone: String = ""
    var secondParentName: String = ""
    var secondParentEmail: String = ""
    var secondParentPhone: String = ""
    
    // COPPA compliance fields with fallback handling
    var dataCollectionConsent: Bool = false
    var consentDate: Date?
    var coachResponsibilityAcknowledged: Bool = false
    
    // Keep these for backward compatibility
    var allowPhotoSharing: Bool = true
    var allowPublicSharing: Bool = true
    
    // MARK: - Custom Decoding for Backward Compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Existing fields (required)
        parentName = try container.decodeIfPresent(String.self, forKey: .parentName) ?? ""
        parentEmail = try container.decodeIfPresent(String.self, forKey: .parentEmail) ?? ""
        parentPhone = try container.decodeIfPresent(String.self, forKey: .parentPhone) ?? ""
        secondParentName = try container.decodeIfPresent(String.self, forKey: .secondParentName) ?? ""
        secondParentEmail = try container.decodeIfPresent(String.self, forKey: .secondParentEmail) ?? ""
        secondParentPhone = try container.decodeIfPresent(String.self, forKey: .secondParentPhone) ?? ""
        
        // COPPA compliance fields (new - fallback to defaults if missing)
        dataCollectionConsent = try container.decodeIfPresent(Bool.self, forKey: .dataCollectionConsent) ?? false
        consentDate = try container.decodeIfPresent(Date.self, forKey: .consentDate)
        coachResponsibilityAcknowledged = try container.decodeIfPresent(Bool.self, forKey: .coachResponsibilityAcknowledged) ?? false
        
        // Existing fields with fallback
        allowPhotoSharing = try container.decodeIfPresent(Bool.self, forKey: .allowPhotoSharing) ?? true
        allowPublicSharing = try container.decodeIfPresent(Bool.self, forKey: .allowPublicSharing) ?? true
    }
    
    // MARK: - Parameterized Initializer (for ProfileSettingsView compatibility)
    init(parentName: String = "",
         parentEmail: String = "",
         parentPhone: String = "",
         secondParentName: String = "",
         secondParentEmail: String = "",
         secondParentPhone: String = "",
         dataCollectionConsent: Bool = false,
         consentDate: Date? = nil,
         coachResponsibilityAcknowledged: Bool = false,
         allowPhotoSharing: Bool = true,
         allowPublicSharing: Bool = true) {
        self.parentName = parentName
        self.parentEmail = parentEmail
        self.parentPhone = parentPhone
        self.secondParentName = secondParentName
        self.secondParentEmail = secondParentEmail
        self.secondParentPhone = secondParentPhone
        self.dataCollectionConsent = dataCollectionConsent
        self.consentDate = consentDate
        self.coachResponsibilityAcknowledged = coachResponsibilityAcknowledged
        self.allowPhotoSharing = allowPhotoSharing
        self.allowPublicSharing = allowPublicSharing
    }
    
    // MARK: - Default Initializer
    init() {
        // All properties use their default values from declarations above
    }
    
    // MARK: - CodingKeys
    private enum CodingKeys: String, CodingKey {
        case parentName
        case parentEmail
        case parentPhone
        case secondParentName
        case secondParentEmail
        case secondParentPhone
        case dataCollectionConsent
        case consentDate
        case coachResponsibilityAcknowledged
        case allowPhotoSharing
        case allowPublicSharing
    }
}
// MARK: - Player (UPDATED with per-season stats tracking)
struct Player: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var jerseyNumber: Int
    var positions: [String]
    var preferredPosition: String
    var phoneNumber: String?
    var email: String?
    var notes: String?
    var playerPhoto: Data?
    var isInjured: Bool?
    var seasonStats: PlayerStats = PlayerStats()              // KEEP: Legacy/current season stats
    var statsBySeason: [UUID: PlayerStats] = [:]              // NEW: Stats keyed by seasonId
    var parentInfo: ParentInfo = ParentInfo()
    var emergencyContact: String?
    var emergencyPhone: String?
    var medicalNotes: String?
    var privacySettings: PlayerPrivacySettings = PlayerPrivacySettings()
    
    var preferredPositionEnum: Position {
        Position(rawValue: preferredPosition) ?? .midfielder
    }
    
    // MARK: - NEW: Season Stats Helper Methods
    
    /// Get all-time stats across all seasons (combines statsBySeason + legacy seasonStats)
    var allTimeStats: PlayerStats {
        var allStats = Array(statsBySeason.values)
        // Include legacy seasonStats if it has data and we don't have season-specific stats
        if statsBySeason.isEmpty && !seasonStats.isEmpty {
            allStats.append(seasonStats)
        }
        return PlayerStats.combined(allStats)
    }
    
    /// Get stats for a specific season
    func stats(for seasonId: UUID) -> PlayerStats {
        return statsBySeason[seasonId] ?? PlayerStats()
    }
    
    /// Set stats for a specific season
    mutating func setStats(_ stats: PlayerStats, for seasonId: UUID) {
        statsBySeason[seasonId] = stats
    }
    
    /// Add to stats for a specific season (useful for incrementing during games)
    mutating func addToStats(for seasonId: UUID, goals: Int = 0, assists: Int = 0,
                             shots: Int = 0, saves: Int = 0, yellowCards: Int = 0,
                             redCards: Int = 0, minutesPlayed: Int = 0, gamesPlayed: Int = 0) {
        var currentStats = statsBySeason[seasonId] ?? PlayerStats()
        currentStats.goals += goals
        currentStats.assists += assists
        currentStats.shots += shots
        currentStats.saves += saves
        currentStats.yellowCards += yellowCards
        currentStats.redCards += redCards
        currentStats.minutesPlayed += minutesPlayed
        currentStats.gamesPlayed += gamesPlayed
        statsBySeason[seasonId] = currentStats
    }
    
    /// Get list of season IDs this player has stats for
    var seasonsWithStats: [UUID] {
        return Array(statsBySeason.keys)
    }
    
    /// Check if player has any stats recorded
    var hasAnyStats: Bool {
        return !statsBySeason.isEmpty || !seasonStats.isEmpty
    }
    
    // MARK: - Display Name Methods
    
    func displayName(for accessLevel: AccessLevel, viewerEmail: String? = nil) -> String {
        switch accessLevel {
        case .coach:
            return name
        case .parent:
            if let email = viewerEmail,
               (parentInfo.parentEmail.lowercased() == email.lowercased() ||
                parentInfo.secondParentEmail.lowercased() == email.lowercased()) {
                return name
            } else {
                return nameWithLastInitial()
            }
        case .viewer:
            return nameWithLastInitial()
        }
    }
    
    // MARK: - Calculated Display Stats
    func calculateDisplayStats(from games: [Game]) -> PlayerStats {
        var stats = PlayerStats()
        
        // Count from ALL game events
        for game in games {
            for event in game.gameEvents where event.playerId == self.id {
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
            
            // Count games played and minutes
            if let playerGameStats = game.playerStats.first(where: { $0.playerId == self.id }) {
                if game.isCompleted {
                    stats.gamesPlayed += 1
                }
                stats.minutesPlayed += playerGameStats.minutesPlayed
            }
        }
        
        // Add ALL season manual adjustments
        stats.goals += seasonStats.getTotalSeasonAdjustments("goals")
        stats.assists += seasonStats.getTotalSeasonAdjustments("assists")
        stats.shots += seasonStats.getTotalSeasonAdjustments("shots")
        stats.saves += seasonStats.getTotalSeasonAdjustments("saves")
        stats.goalsConceded += seasonStats.getTotalSeasonAdjustments("goalsConceded")
        stats.yellowCards += seasonStats.getTotalSeasonAdjustments("yellowCards")
        stats.redCards += seasonStats.getTotalSeasonAdjustments("redCards")
        stats.gamesPlayed += seasonStats.getTotalSeasonAdjustments("gamesPlayed")
        stats.minutesPlayed += seasonStats.getTotalSeasonAdjustments("minutesPlayed")
        
        // Add overall manual adjustments
        stats.goals += seasonStats.getManualAdjustment("goals")
        stats.assists += seasonStats.getManualAdjustment("assists")
        stats.shots += seasonStats.getManualAdjustment("shots")
        stats.saves += seasonStats.getManualAdjustment("saves")
        stats.goalsConceded += seasonStats.getManualAdjustment("goalsConceded")
        stats.yellowCards += seasonStats.getManualAdjustment("yellowCards")
        stats.redCards += seasonStats.getManualAdjustment("redCards")
        stats.gamesPlayed += seasonStats.getManualAdjustment("gamesPlayed")
        stats.minutesPlayed += seasonStats.getManualAdjustment("minutesPlayed")
        
        return stats
    }
    
    private func nameWithLastInitial() -> String {
        let components = name.components(separatedBy: " ")
        guard components.count > 1 else { return name }
        
        let firstName = components.first ?? ""
        if let lastChar = components.last?.first {
            let lastInitial = String(lastChar)
            return "\(firstName) \(lastInitial)."
        }
        return firstName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Coding Keys (UPDATED with statsBySeason)
    enum CodingKeys: String, CodingKey {
        case id, name, jerseyNumber, positions, preferredPosition
        case phoneNumber, email, notes, playerPhoto, isInjured
        case seasonStats, statsBySeason, parentInfo, emergencyContact, emergencyPhone
        case medicalNotes, privacySettings
    }
    
    // MARK: - Custom Decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        jerseyNumber = try container.decode(Int.self, forKey: .jerseyNumber)
        positions = try container.decode([String].self, forKey: .positions)
        preferredPosition = try container.decode(String.self, forKey: .preferredPosition)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        playerPhoto = try container.decodeIfPresent(Data.self, forKey: .playerPhoto)
        isInjured = try container.decodeIfPresent(Bool.self, forKey: .isInjured)
        seasonStats = try container.decodeIfPresent(PlayerStats.self, forKey: .seasonStats) ?? PlayerStats()
        statsBySeason = try container.decodeIfPresent([UUID: PlayerStats].self, forKey: .statsBySeason) ?? [:]  // NEW
        parentInfo = try container.decodeIfPresent(ParentInfo.self, forKey: .parentInfo) ?? ParentInfo()
        emergencyContact = try container.decodeIfPresent(String.self, forKey: .emergencyContact)
        emergencyPhone = try container.decodeIfPresent(String.self, forKey: .emergencyPhone)
        medicalNotes = try container.decodeIfPresent(String.self, forKey: .medicalNotes)
        privacySettings = try container.decodeIfPresent(PlayerPrivacySettings.self, forKey: .privacySettings) ?? PlayerPrivacySettings()
    }
    
    // MARK: - Encoder (UPDATED with statsBySeason)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(jerseyNumber, forKey: .jerseyNumber)
        try container.encode(positions, forKey: .positions)
        try container.encode(preferredPosition, forKey: .preferredPosition)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(playerPhoto, forKey: .playerPhoto)
        try container.encodeIfPresent(isInjured, forKey: .isInjured)
        try container.encode(seasonStats, forKey: .seasonStats)
        try container.encode(statsBySeason, forKey: .statsBySeason)  // NEW
        try container.encode(parentInfo, forKey: .parentInfo)
        try container.encodeIfPresent(emergencyContact, forKey: .emergencyContact)
        try container.encodeIfPresent(emergencyPhone, forKey: .emergencyPhone)
        try container.encodeIfPresent(medicalNotes, forKey: .medicalNotes)
        try container.encode(privacySettings, forKey: .privacySettings)
    }
    
    // MARK: - Standard initializer (UPDATED with statsBySeason)
    init(id: UUID = UUID(),
         name: String,
         jerseyNumber: Int,
         positions: [String],
         preferredPosition: String,
         phoneNumber: String? = nil,
         email: String? = nil,
         notes: String? = nil,
         playerPhoto: Data? = nil,
         isInjured: Bool? = nil,
         seasonStats: PlayerStats = PlayerStats(),
         statsBySeason: [UUID: PlayerStats] = [:],              // NEW
         parentInfo: ParentInfo = ParentInfo(),
         emergencyContact: String? = nil,
         emergencyPhone: String? = nil,
         medicalNotes: String? = nil,
         privacySettings: PlayerPrivacySettings = PlayerPrivacySettings()) {
        self.id = id
        self.name = name
        self.jerseyNumber = jerseyNumber
        self.positions = positions
        self.preferredPosition = preferredPosition
        self.phoneNumber = phoneNumber
        self.email = email
        self.notes = notes
        self.playerPhoto = playerPhoto
        self.isInjured = isInjured
        self.seasonStats = seasonStats
        self.statsBySeason = statsBySeason                      // NEW
        self.parentInfo = parentInfo
        self.emergencyContact = emergencyContact
        self.emergencyPhone = emergencyPhone
        self.medicalNotes = medicalNotes
        self.privacySettings = privacySettings
    }
    
    // MARK: - Equatable implementation (UPDATED with statsBySeason)
    static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.jerseyNumber == rhs.jerseyNumber &&
               lhs.positions == rhs.positions &&
               lhs.preferredPosition == rhs.preferredPosition &&
               lhs.phoneNumber == rhs.phoneNumber &&
               lhs.email == rhs.email &&
               lhs.notes == rhs.notes &&
               lhs.playerPhoto == rhs.playerPhoto &&
               lhs.isInjured == rhs.isInjured &&
               lhs.seasonStats == rhs.seasonStats &&
               lhs.statsBySeason == rhs.statsBySeason &&        // NEW
               lhs.parentInfo == rhs.parentInfo &&
               lhs.emergencyContact == rhs.emergencyContact &&
               lhs.emergencyPhone == rhs.emergencyPhone &&
               lhs.medicalNotes == rhs.medicalNotes &&
               lhs.privacySettings == rhs.privacySettings
    }
}

// MARK: - Team Extensions (Add privacy settings support)
extension Team {
    var privacySettings: TeamPrivacySettings {
        get {
            if let data = UserDefaults.standard.data(forKey: "teamPrivacy_\(id.uuidString)"),
               let settings = try? JSONDecoder().decode(TeamPrivacySettings.self, from: data) {
                return settings
            }
            return TeamPrivacySettings()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "teamPrivacy_\(id.uuidString)")
            }
        }
    }
    
    var shouldAutoDelete: Bool {
        let daysSinceActivity = Calendar.current.dateComponents(
            [.day],
            from: privacySettings.lastActivityDate,
            to: Date()
        ).day ?? 0
        
        return daysSinceActivity >= privacySettings.dataRetentionPeriod
    }
    
    mutating func updateActivityTimestamp() {
        var settings = privacySettings
        settings.lastActivityDate = Date()
        privacySettings = settings
    }
}

class COPPAComplianceManager: ObservableObject {
    static let shared = COPPAComplianceManager()
    
    private init() {}
    
    // MARK: - Enhanced Coach Responsibility
    func getEnhancedCoachResponsibilityDisclaimer() -> String {
        return """
        ENHANCED COACH DATA RESPONSIBILITY AGREEMENT
        
        By creating and managing teams in Coach Caddie, you acknowledge and agree that:
        
        • You have the authority as team coach to manage player information for team purposes
        • You are responsible for notifying parents about team management tools and data collection
        • You will only collect information necessary for team management (names, positions, basic stats)
        • You understand COPPA requirements and will obtain parental consent if collecting personal information from children under 13 for commercial purposes
        • Coach Caddie is a team management tool - you use it under your authority as coach, not as a commercial data collector
        • All player data will be automatically deleted after 180 days of team inactivity
        • You are responsible for informing parents about digital team management tools
        • Parents can contact you directly to request data removal or updates
        • You will provide parents with clear information about how their child's team information is managed
        • You understand that parents have the right to request traditional (non-digital) team management for their child
        
        COACH NOTIFICATION REQUIREMENTS:
        • You must notify all parents that you are using Coach Caddie for team management
        • You must provide parents with information about data collection and privacy protections
        • You must give parents a way to contact you with questions or concerns
        • You must respect any parent requests for alternative team management methods
        
        By continuing, you accept full responsibility for appropriate data handling, parent communication, and COPPA compliance.
        """
    }
    
    // MARK: - COPPA Compliant Parent Notice
    func getCOPPACompliantParentNotice(teamName: String, coachName: String, coachEmail: String, coachPhone: String = "") -> String {
        let contactInfo = coachPhone.isEmpty ? coachEmail : "\(coachEmail) | \(coachPhone)"
        
        return """
        TEAM MANAGEMENT NOTIFICATION
        
        Dear Parents/Guardians of \(teamName),
        
        I am using Coach Caddie, a digital team management app, to help organize our team activities. This notice explains how your child's information is managed:
        
        INFORMATION COLLECTED FOR TEAM MANAGEMENT:
        • Player name and jersey number
        • Parent contact information (your email/phone for team communication)
        • Basic team statistics (goals, assists, saves, shots)
        • Team participation records
        • Emergency contact information (for safety purposes)
        
        PRIVACY PROTECTIONS IN PLACE:
        • Information used ONLY for team management and communication
        • No commercial use, marketing, or third-party sharing
        • Automatic deletion after 180 days of team inactivity
        • No photos, videos, dates of birth, or unnecessary personal details collected
        • Secure, encrypted storage with role-based access controls
        • No public sharing capabilities
        
        YOUR RIGHTS AS PARENTS:
        • Contact me to view your child's team information
        • Request updates, corrections, or complete data removal
        • Ask questions about data management at any time
        • Request traditional (non-digital) team management if preferred
        
        COACH AUTHORITY & RESPONSIBILITY:
        This is a standard team management tool used under my authority as your child's coach, similar to traditional paper rosters and stat tracking. I take full responsibility for appropriate data handling and am your primary contact for any questions or concerns.
        
        If you prefer your child's information not be managed digitally, please contact me to discuss alternative arrangements. Otherwise, your child's participation in team activities indicates your understanding of this team management approach.
        
        Coach: \(coachName)
        Contact: \(contactInfo)
        
        Thank you,
        \(coachName)
        """
    }
    
    // MARK: - Parent Notice Requirements for Coaches
    func getParentNotificationRequirement() -> String {
        return """
        COACH REQUIREMENT: Parent Notification
        
        Before using Coach Caddie for team management, you MUST notify all parents about your use of digital team management tools.
        
        REQUIRED NOTIFICATION INCLUDES:
        • What information is collected (names, positions, basic stats)
        • How it's used (team management and communication only)
        • Privacy protections in place
        • How parents can contact you with questions
        • Option to manage their child's info traditionally if they prefer
        
        USE THE BUILT-IN NOTICE GENERATOR:
        Coach Caddie provides a parent notice generator that creates compliant notifications you can share via email, text, or team meetings.
        
        TIMING:
        • Send notice before first use of the app for your team
        • Re-send at the beginning of each season
        • Notify new parents when players join mid-season
        
        This notification requirement helps ensure COPPA compliance and builds trust with parents.
        """
    }
    
    // MARK: - Enhanced Data Deletion Warnings
    func shouldShowDataDeletionWarning(team: Team) -> Bool {
        let daysSinceActivity = Calendar.current.dateComponents(
            [.day],
            from: team.privacySettings.lastActivityDate,
            to: Date()
        ).day ?? 0
        
        return daysSinceActivity >= 60 // Warn 30 days before deletion
    }
    
    func daysUntilDeletion(team: Team) -> Int {
        let daysSinceActivity = Calendar.current.dateComponents(
            [.day],
            from: team.privacySettings.lastActivityDate,
            to: Date()
        ).day ?? 0
        
        return max(0, team.privacySettings.dataRetentionPeriod - daysSinceActivity)
    }
    
    // MARK: - COPPA Compliance Checklist
    func getCOPPAComplianceChecklist() -> [COPPAChecklistItem] {
        return [
            COPPAChecklistItem(
                title: "Coach Responsibility Acknowledged",
                description: "Coach has acknowledged responsibility for COPPA compliance and appropriate data handling",
                category: .coachResponsibility
            ),
            COPPAChecklistItem(
                title: "Parent Notification Sent",
                description: "Parents have been notified about digital team management tools and data collection",
                category: .parentNotification
            ),
            COPPAChecklistItem(
                title: "Minimal Data Collection",
                description: "Only essential team management information is collected (no DOB, photos, or unnecessary details)",
                category: .dataMinimization
            ),
            COPPAChecklistItem(
                title: "Automatic Data Deletion",
                description: "Team data automatically deletes after 180 days of inactivity",
                category: .dataRetention
            ),
            COPPAChecklistItem(
                title: "No Commercial Use",
                description: "Data is used only for team management, not commercial purposes",
                category: .dataUse
            ),
            COPPAChecklistItem(
                title: "Parent Contact Method",
                description: "Parents have a clear way to contact the coach with questions or requests",
                category: .parentRights
            )
        ]
    }
}

// MARK: - COPPA Checklist Item
struct COPPAChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: COPPACategory
}

enum COPPACategory: String, CaseIterable {
    case coachResponsibility = "Coach Responsibility"
    case parentNotification = "Parent Notification"
    case dataMinimization = "Data Minimization"
    case dataRetention = "Data Retention"
    case dataUse = "Data Use"
    case parentRights = "Parent Rights"
}

// MARK: - Player Stats (UPDATED with season aggregation support)
struct PlayerStats: Codable, Equatable {
    var gamesPlayed: Int = 0
    var goals: Int = 0
    var assists: Int = 0
    var shots: Int = 0
    var shotOnTarget: Int = 0
    var saves: Int = 0
    var goalsConceded: Int = 0
    var yellowCards: Int = 0
    var redCards: Int = 0
    var minutesPlayed: Int = 0
    
    // Store manual adjustments as offsets, not flags
    var manualAdjustments: [String: Int] = [:]  // e.g., ["goals": 5] means +5 to calculated value
    
    // NEW: Store season-specific manual adjustments
    // Key is Season UUID, value is dictionary of stat adjustments for that season
    var seasonManualAdjustments: [UUID: [String: Int]] = [:]
    
    // MARK: - Custom Decoding for Backward Compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        gamesPlayed = try container.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        goals = try container.decodeIfPresent(Int.self, forKey: .goals) ?? 0
        assists = try container.decodeIfPresent(Int.self, forKey: .assists) ?? 0
        shots = try container.decodeIfPresent(Int.self, forKey: .shots) ?? 0
        shotOnTarget = try container.decodeIfPresent(Int.self, forKey: .shotOnTarget) ?? 0
        saves = try container.decodeIfPresent(Int.self, forKey: .saves) ?? 0
        goalsConceded = try container.decodeIfPresent(Int.self, forKey: .goalsConceded) ?? 0
        yellowCards = try container.decodeIfPresent(Int.self, forKey: .yellowCards) ?? 0
        redCards = try container.decodeIfPresent(Int.self, forKey: .redCards) ?? 0
        minutesPlayed = try container.decodeIfPresent(Int.self, forKey: .minutesPlayed) ?? 0
        manualAdjustments = try container.decodeIfPresent([String: Int].self, forKey: .manualAdjustments) ?? [:]
        
        // NEW: Decode season manual adjustments with UUID key conversion (backward compatible - defaults to empty)
        if let seasonAdjustmentsStringKeys = try container.decodeIfPresent([String: [String: Int]].self, forKey: .seasonManualAdjustments) {
            var converted: [UUID: [String: Int]] = [:]
            for (key, value) in seasonAdjustmentsStringKeys {
                if let uuid = UUID(uuidString: key) {
                    converted[uuid] = value
                }
            }
            seasonManualAdjustments = converted
        } else {
            seasonManualAdjustments = [:]
        }
    }
    
    // MARK: - Custom Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(gamesPlayed, forKey: .gamesPlayed)
        try container.encode(goals, forKey: .goals)
        try container.encode(assists, forKey: .assists)
        try container.encode(shots, forKey: .shots)
        try container.encode(shotOnTarget, forKey: .shotOnTarget)
        try container.encode(saves, forKey: .saves)
        try container.encode(goalsConceded, forKey: .goalsConceded)
        try container.encode(yellowCards, forKey: .yellowCards)
        try container.encode(redCards, forKey: .redCards)
        try container.encode(minutesPlayed, forKey: .minutesPlayed)
        try container.encode(manualAdjustments, forKey: .manualAdjustments)
        
        // NEW: Encode season manual adjustments with String keys (JSON requires string keys)
        var stringKeyedSeasonAdjustments: [String: [String: Int]] = [:]
        for (uuid, adjustments) in seasonManualAdjustments {
            stringKeyedSeasonAdjustments[uuid.uuidString] = adjustments
        }
        try container.encode(stringKeyedSeasonAdjustments, forKey: .seasonManualAdjustments)
    }
    
    // MARK: - Default Initializer
    init() {
        // All properties use their default values from declarations above
    }
    
    // MARK: - Parameterized Initializer
    init(gamesPlayed: Int = 0, goals: Int = 0, assists: Int = 0, shots: Int = 0,
         shotOnTarget: Int = 0, saves: Int = 0, goalsConceded: Int = 0,
         yellowCards: Int = 0, redCards: Int = 0, minutesPlayed: Int = 0,
         manualAdjustments: [String: Int] = [:],
         seasonManualAdjustments: [UUID: [String: Int]] = [:]) {
        self.gamesPlayed = gamesPlayed
        self.goals = goals
        self.assists = assists
        self.shots = shots
        self.shotOnTarget = shotOnTarget
        self.saves = saves
        self.goalsConceded = goalsConceded
        self.yellowCards = yellowCards
        self.redCards = redCards
        self.minutesPlayed = minutesPlayed
        self.manualAdjustments = manualAdjustments
        self.seasonManualAdjustments = seasonManualAdjustments
    }
    
    // MARK: - CodingKeys
    private enum CodingKeys: String, CodingKey {
        case gamesPlayed
        case goals
        case assists
        case shots
        case shotOnTarget
        case saves
        case goalsConceded
        case yellowCards
        case redCards
        case minutesPlayed
        case manualAdjustments
        case seasonManualAdjustments
    }
    
    // MARK: - Manual Adjustment Methods (Overall)
    
    mutating func setManualAdjustment(_ statName: String, adjustment: Int) {
        manualAdjustments[statName] = adjustment
    }
    
    func getManualAdjustment(_ statName: String) -> Int {
        return manualAdjustments[statName] ?? 0
    }
    
    mutating func clearManualAdjustment(_ statName: String) {
        manualAdjustments.removeValue(forKey: statName)
    }
    
    mutating func clearAllManualAdjustments() {
        manualAdjustments.removeAll()
    }
    
    func hasManualAdjustment(_ statName: String) -> Bool {
        return manualAdjustments[statName] != nil
    }
    
    // MARK: - NEW: Season-Specific Manual Adjustment Methods
    
    mutating func setSeasonManualAdjustment(_ statName: String, adjustment: Int, forSeason seasonId: UUID) {
        if seasonManualAdjustments[seasonId] == nil {
            seasonManualAdjustments[seasonId] = [:]
        }
        seasonManualAdjustments[seasonId]?[statName] = adjustment
    }
    
    func getSeasonManualAdjustment(_ statName: String, forSeason seasonId: UUID) -> Int {
        return seasonManualAdjustments[seasonId]?[statName] ?? 0
    }
    
    mutating func clearSeasonManualAdjustment(_ statName: String, forSeason seasonId: UUID) {
        seasonManualAdjustments[seasonId]?.removeValue(forKey: statName)
        // Clean up empty dictionaries
        if seasonManualAdjustments[seasonId]?.isEmpty == true {
            seasonManualAdjustments.removeValue(forKey: seasonId)
        }
    }
    
    mutating func clearAllSeasonManualAdjustments(forSeason seasonId: UUID) {
        seasonManualAdjustments.removeValue(forKey: seasonId)
    }
    
    func hasSeasonManualAdjustment(_ statName: String, forSeason seasonId: UUID) -> Bool {
        return seasonManualAdjustments[seasonId]?[statName] != nil
    }
    
    /// Get total season manual adjustments for a stat across ALL seasons
    func getTotalSeasonAdjustments(_ statName: String) -> Int {
        var total = 0
        for (_, adjustments) in seasonManualAdjustments {
            total += adjustments[statName] ?? 0
        }
        return total
    }
    
    // MARK: - Season Aggregation Methods
    
    /// Combine stats from multiple PlayerStats objects (e.g., across seasons)
    static func combined(_ stats: [PlayerStats]) -> PlayerStats {
        var combined = PlayerStats()
        
        for stat in stats {
            combined.gamesPlayed += stat.gamesPlayed
            combined.goals += stat.goals
            combined.assists += stat.assists
            combined.shots += stat.shots
            combined.shotOnTarget += stat.shotOnTarget
            combined.saves += stat.saves
            combined.goalsConceded += stat.goalsConceded
            combined.yellowCards += stat.yellowCards
            combined.redCards += stat.redCards
            combined.minutesPlayed += stat.minutesPlayed
            
            // Merge manual adjustments (sum adjustments for same stat names)
            for (key, value) in stat.manualAdjustments {
                combined.manualAdjustments[key, default: 0] += value
            }
            
            // Merge season manual adjustments
            for (seasonId, adjustments) in stat.seasonManualAdjustments {
                if combined.seasonManualAdjustments[seasonId] == nil {
                    combined.seasonManualAdjustments[seasonId] = [:]
                }
                for (key, value) in adjustments {
                    combined.seasonManualAdjustments[seasonId]?[key, default: 0] += value
                }
            }
        }
        
        return combined
    }
    
    /// Add another PlayerStats to this one (mutating version)
    mutating func add(_ other: PlayerStats) {
        gamesPlayed += other.gamesPlayed
        goals += other.goals
        assists += other.assists
        shots += other.shots
        shotOnTarget += other.shotOnTarget
        saves += other.saves
        goalsConceded += other.goalsConceded
        yellowCards += other.yellowCards
        redCards += other.redCards
        minutesPlayed += other.minutesPlayed
        
        for (key, value) in other.manualAdjustments {
            manualAdjustments[key, default: 0] += value
        }
        
        for (seasonId, adjustments) in other.seasonManualAdjustments {
            if seasonManualAdjustments[seasonId] == nil {
                seasonManualAdjustments[seasonId] = [:]
            }
            for (key, value) in adjustments {
                seasonManualAdjustments[seasonId]?[key, default: 0] += value
            }
        }
    }
    
    /// Create a new PlayerStats by adding two together (non-mutating)
    static func + (lhs: PlayerStats, rhs: PlayerStats) -> PlayerStats {
        var result = lhs
        result.add(rhs)
        return result
    }
    
    // MARK: - Computed Properties for Display
    
    /// Goals per game average
    var goalsPerGame: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(goals) / Double(gamesPlayed)
    }
    
    /// Assists per game average
    var assistsPerGame: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(assists) / Double(gamesPlayed)
    }
    
    /// Shot accuracy percentage
    var shotAccuracy: Double {
        guard shots > 0 else { return 0 }
        return Double(shotOnTarget) / Double(shots) * 100
    }
    
    /// Average minutes per game
    var averageMinutesPerGame: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(minutesPlayed) / Double(gamesPlayed)
    }
    
    /// Goal contributions (goals + assists)
    var goalContributions: Int {
        return goals + assists
    }
    
    /// Check if stats are empty (no games played)
    var isEmpty: Bool {
        return gamesPlayed == 0 && goals == 0 && assists == 0 && saves == 0
    }
}

// MARK: - Game Audit Entry (UPDATED to be editable)
struct GameAuditEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var eventType: GameAuditEventType  // Made mutable for editing
    var gameTime: String               // Made mutable for editing
    let realTime: Date
    var details: String                // Made mutable for editing
    var playerName: String?            // Made mutable for editing
    var playerPosition: String?        // Made mutable for editing
    var playerId: UUID?                // NEW: Store player ID for easier editing

    init(eventType: GameAuditEventType, gameTime: String, details: String, playerName: String? = nil, playerPosition: String? = nil, playerId: UUID? = nil) {
        self.id = UUID()
        self.eventType = eventType
        self.gameTime = gameTime
        self.realTime = Date()
        self.details = details
        self.playerName = playerName
        self.playerPosition = playerPosition
        self.playerId = playerId
    }
}

// MARK: - Game Audit Event Type
enum GameAuditEventType: String, Codable, CaseIterable {
    case gameStart = "Game Started"
    case gameEnd = "Game Ended"
    case halfTime = "Half Time"
    case secondHalfStart = "2nd Half Started"
    case substitution = "Substitution"
    case goal = "Goal"
    case assist = "Assist"
    case yellowCard = "Yellow Card"
    case redCard = "Red Card"
    case injury = "Injury"
    case timeout = "Timeout"
    case gamePause = "Game Paused"
    case gameResume = "Game Resumed"
    case formationChange = "Formation Change"
    case save = "Save"
    case shot = "Shot"
    case shotOnTarget = "Shot on Target"
    case timerAdjustment = "Timer Adjusted"
    case freeKick = "Free Kick"
    case cornerKick = "Corner Kick"
    case penaltyKick = "Penalty Kick"
    case goalAgainst = "Goal Against"
    case positionChange = "Position Change"  // MOVED: Fixed comment placement

    var icon: String {
        switch self {
        case .gameStart, .gameResume: return "play.fill"
        case .gameEnd: return "stop.fill"
        case .halfTime, .secondHalfStart: return "timer"
        case .substitution: return "arrow.left.arrow.right"
        case .goal: return "soccerball"
        case .assist: return "hands.sparkles"
        case .yellowCard: return "rectangle.fill"
        case .redCard: return "rectangle.fill"
        case .injury: return "cross.fill"
        case .timeout, .gamePause: return "pause.fill"
        case .formationChange: return "square.grid.3x3"
        case .save: return "hand.raised.fill"
        case .shot: return "scope"
        case .shotOnTarget: return "target"
        case .timerAdjustment: return "pencil.circle"
        case .freeKick: return "arrow.up.circle"
        case .cornerKick: return "arrow.turn.up.right"
        case .penaltyKick: return "circle.dotted"
        case .goalAgainst: return "soccerball.inverse"
        case .positionChange: return "arrow.triangle.swap"  // ADDED
        }
    }

    var color: Color {
        switch self {
        case .goal, .assist: return .green
        case .yellowCard: return .yellow
        case .redCard, .injury: return .red
        case .gameStart, .gameEnd, .halfTime, .secondHalfStart: return .blue
        case .substitution: return .blue
        case .save: return .purple
        case .shot, .shotOnTarget: return .orange
        case .timerAdjustment: return .blue
        case .freeKick: return .cyan
        case .cornerKick: return .mint
        case .penaltyKick: return .gray
        case .goalAgainst: return .red
        case .positionChange: return .purple
        case .timeout, .gamePause, .gameResume: return .gray
        case .formationChange: return .orange
        }
    }
}

struct PlannedPositionChange: Identifiable, Codable, Equatable {
    var id = UUID()  // Changed from 'let' to 'var' to allow setting
    var playerId: UUID
    var fromPosition: Position
    var toPosition: Position
    var plannedMinute: Int
    var isExecuted: Bool = false
    var actualMinute: Int?
    var subGroupIndex: Int? = nil
    
    // Add custom initializer that accepts ID
    init(id: UUID = UUID(), playerId: UUID, fromPosition: Position, toPosition: Position, plannedMinute: Int) {
        self.id = id
        self.playerId = playerId
        self.fromPosition = fromPosition
        self.toPosition = toPosition
        self.plannedMinute = plannedMinute
    }
}



struct Game: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var seasonId: UUID?                     // Which season this game belongs to
    var date: Date
    var opponent: String
    var isHome: Bool = true
    var location: String?
    var formation: Formation?
    var startingLineup: [LineupPosition]?
    var result: GameResult?
    var gameEvents: [GameEvent] = []
    var playerStats: [PlayerGameStats] = []
    var substitutions: [Substitution] = []
    var notes: String?
    var auditLog: [GameAuditEntry]?
    var isCompleted: Bool = false
    var playerRSVPs: [UUID: RSVPStatus] = [:]
    var plannedSubstitutions: [PlannedSubstitution] = []
    var lineupPhases: [LineupPhase] = []
    var useAutoSubstitutions: Bool = false
    var actualStartingLineup: [LineupPosition]? = nil
    var plannedPositionChanges: [PlannedPositionChange] = []
    var substitutionNotes: String? = nil
    
    // OPTIMIZATION: Track whether subcollections have been loaded from Firebase
    // This is NOT persisted - it's a runtime flag only
    var subcollectionsLoaded: Bool = false
    
    // MARK: - Custom Decoding for Backward Compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        seasonId = try container.decodeIfPresent(UUID.self, forKey: .seasonId)
        date = try container.decode(Date.self, forKey: .date)
        opponent = try container.decode(String.self, forKey: .opponent)
        isHome = try container.decodeIfPresent(Bool.self, forKey: .isHome) ?? true
        location = try container.decodeIfPresent(String.self, forKey: .location)
        formation = try container.decodeIfPresent(Formation.self, forKey: .formation)
        startingLineup = try container.decodeIfPresent([LineupPosition].self, forKey: .startingLineup)
        result = try container.decodeIfPresent(GameResult.self, forKey: .result)
        gameEvents = try container.decodeIfPresent([GameEvent].self, forKey: .gameEvents) ?? []
        playerStats = try container.decodeIfPresent([PlayerGameStats].self, forKey: .playerStats) ?? []
        substitutions = try container.decodeIfPresent([Substitution].self, forKey: .substitutions) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        auditLog = try container.decodeIfPresent([GameAuditEntry].self, forKey: .auditLog)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        playerRSVPs = try container.decodeIfPresent([UUID: RSVPStatus].self, forKey: .playerRSVPs) ?? [:]
        plannedSubstitutions = try container.decodeIfPresent([PlannedSubstitution].self, forKey: .plannedSubstitutions) ?? []
        lineupPhases = try container.decodeIfPresent([LineupPhase].self, forKey: .lineupPhases) ?? []
        useAutoSubstitutions = try container.decodeIfPresent(Bool.self, forKey: .useAutoSubstitutions) ?? false
        actualStartingLineup = try container.decodeIfPresent([LineupPosition].self, forKey: .actualStartingLineup)
        plannedPositionChanges = try container.decodeIfPresent([PlannedPositionChange].self, forKey: .plannedPositionChanges) ?? []
        substitutionNotes = try container.decodeIfPresent(String.self, forKey: .substitutionNotes)
        
        // subcollectionsLoaded defaults to false - not decoded from storage
        // If we have auditLog/playerStats data, mark as loaded
        subcollectionsLoaded = (auditLog != nil && !(auditLog?.isEmpty ?? true)) || !playerStats.isEmpty
    }
    
    // MARK: - Standard Initializer
    init(id: UUID = UUID(),
         seasonId: UUID? = nil,
         date: Date,
         opponent: String,
         isHome: Bool = true,
         location: String? = nil,
         formation: Formation? = nil,
         startingLineup: [LineupPosition]? = nil,
         result: GameResult? = nil,
         notes: String? = nil) {
        self.id = id
        self.seasonId = seasonId
        self.date = date
        self.opponent = opponent
        self.isHome = isHome
        self.location = location
        self.formation = formation
        self.startingLineup = startingLineup
        self.result = result
        self.notes = notes
        self.subcollectionsLoaded = false
        // All other properties will use their default values
    }
    
    // MARK: - Coding Keys (subcollectionsLoaded is intentionally excluded - not persisted)
    enum CodingKeys: String, CodingKey {
        case id, seasonId, date, opponent, isHome, location, formation, startingLineup, result
        case gameEvents, playerStats, substitutions, notes, auditLog, isCompleted, playerRSVPs
        case plannedSubstitutions, lineupPhases, useAutoSubstitutions
        case actualStartingLineup, plannedPositionChanges, substitutionNotes
    }
}

// MARK: - Game Extension (KEEP EXISTING - no changes needed)
extension Game {
    /// Calculate presumed minutes played for a specific player
    func calculatePresumedMinutesPlayed(for playerId: UUID, with team: Team) -> Int {
        // Get total game time from team settings
        let totalGameTime = team.defaultHalfLength * 2
        
        // Check if player was in starting lineup
        var isInStartingLineup = false
        if let startingLineup = self.actualStartingLineup ?? self.startingLineup {
            isInStartingLineup = startingLineup.contains { $0.playerId == playerId }
        }
        
        // If game is completed, use actual time entries if available
        if self.isCompleted, !self.playerStats.isEmpty {
            if let playerStats = self.playerStats.first(where: { $0.playerId == playerId }) {
                // Calculate from time entries if available
                var totalMinutes = 0
                for entry in playerStats.timeEntries {
                    let entryStart = entry.enteredAt
                    let entryEnd = entry.exitedAt ?? totalGameTime
                    totalMinutes += max(0, entryEnd - entryStart)
                }
                
                // If we have time entries, use that calculation
                if !playerStats.timeEntries.isEmpty {
                    return totalMinutes
                }
                
                // Fall back to stored minutesPlayed if no time entries
                if playerStats.minutesPlayed > 0 {
                    return playerStats.minutesPlayed
                }
            }
        }
        
        // For active games or games without time entries, calculate presumed time
        var minutesPlayed = 0
        
        // Start with full game time if in starting lineup
        if isInStartingLineup {
            minutesPlayed = totalGameTime
        }
        
        // Apply executed substitutions first
        for substitution in self.substitutions {
            if substitution.playerOut == playerId {
                let minutesToSubtract = totalGameTime - substitution.minute
                minutesPlayed = max(0, minutesPlayed - minutesToSubtract)
            }
            
            if substitution.playerIn == playerId {
                let minutesToAdd = totalGameTime - substitution.minute
                minutesPlayed += minutesToAdd
            }
        }
        
        // Apply planned substitutions that haven't been executed yet
        for plannedSub in self.plannedSubstitutions.filter({ !$0.isExecuted }) {
            if plannedSub.playerOut == playerId {
                let minutesToSubtract = totalGameTime - plannedSub.plannedMinute
                minutesPlayed = max(0, minutesPlayed - minutesToSubtract)
            }
            
            if plannedSub.playerIn == playerId {
                let minutesToAdd = totalGameTime - plannedSub.plannedMinute
                minutesPlayed += minutesToAdd
            }
        }
        
        return max(0, minutesPlayed)
    }
    
    /// Update all player stats with presumed minutes played
    mutating func updateAllPresumedMinutes(with team: Team) {
        for index in playerStats.indices {
            playerStats[index].minutesPlayed = calculatePresumedMinutesPlayed(for: playerStats[index].playerId, with: team)
        }
        
        var playersInvolved: Set<UUID> = Set()
        
        if let lineup = actualStartingLineup ?? startingLineup {
            for position in lineup {
                if let playerId = position.playerId {
                    playersInvolved.insert(playerId)
                }
            }
        }
        
        for sub in substitutions {
            playersInvolved.insert(sub.playerIn)
            playersInvolved.insert(sub.playerOut)
        }
        
        for plannedSub in plannedSubstitutions {
            playersInvolved.insert(plannedSub.playerIn)
            playersInvolved.insert(plannedSub.playerOut)
        }
        
        for playerId in playersInvolved {
            if !playerStats.contains(where: { $0.playerId == playerId }) {
                var newStats = PlayerGameStats(playerId: playerId)
                newStats.minutesPlayed = calculatePresumedMinutesPlayed(for: playerId, with: team)
                playerStats.append(newStats)
            }
        }
    }
}

// MARK: - Game Result
struct GameResult: Codable, Equatable {
    var goalsFor: Int
    var goalsAgainst: Int
}

// MARK: - Game Event
struct GameEvent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var playerId: UUID
    var eventType: EventType
    var minute: Int
    var assistPlayerId: UUID?
    var notes: String?
}

// MARK: - Event Type (UPDATED with goalAgainst)
enum EventType: String, Codable, CaseIterable, Equatable {
    case goal = "Goal"
    case assist = "Assist"
    case shot = "Shot"
    case shotOnTarget = "Shot on Target"
    case save = "Save"
    case goalAgainst = "Goal Against"  // NEW
    case yellowCard = "Yellow Card"
    case redCard = "Red Card"
    case penaltyKick = "Penalty Kick"
    case freeKick = "Free Kick"
    case cornerKick = "Corner Kick"
}

// MARK: - Time Entry (NEW struct to replace tuple)
struct TimeEntry: Codable, Equatable {
    var enteredAt: Int
    var exitedAt: Int?
    
    init(enteredAt: Int, exitedAt: Int? = nil) {
        self.enteredAt = enteredAt
        self.exitedAt = exitedAt
    }
}

// MARK: - Player Game Stats (FIXED for backward compatibility)
struct PlayerGameStats: Codable, Equatable {
    var playerId: UUID
    var minutesPlayed: Int = 0
    var goals: Int = 0
    var assists: Int = 0
    var shots: Int = 0
    var saves: Int = 0
    var goalsConceded: Int = 0  // NEW
    var yellowCards: Int = 0
    var redCards: Int = 0
    var timeEntries: [TimeEntry] = []  // NEW
    
    // MARK: - Custom Decoding for Backward Compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        playerId = try container.decode(UUID.self, forKey: .playerId)
        minutesPlayed = try container.decodeIfPresent(Int.self, forKey: .minutesPlayed) ?? 0
        goals = try container.decodeIfPresent(Int.self, forKey: .goals) ?? 0
        assists = try container.decodeIfPresent(Int.self, forKey: .assists) ?? 0
        shots = try container.decodeIfPresent(Int.self, forKey: .shots) ?? 0
        saves = try container.decodeIfPresent(Int.self, forKey: .saves) ?? 0
        goalsConceded = try container.decodeIfPresent(Int.self, forKey: .goalsConceded) ?? 0  // NEW with default
        yellowCards = try container.decodeIfPresent(Int.self, forKey: .yellowCards) ?? 0
        redCards = try container.decodeIfPresent(Int.self, forKey: .redCards) ?? 0
        timeEntries = try container.decodeIfPresent([TimeEntry].self, forKey: .timeEntries) ?? []  // NEW with default
    }
    
    // MARK: - Standard initializer
    init(playerId: UUID) {
        self.playerId = playerId
    }
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case playerId, minutesPlayed, goals, assists, shots, saves, goalsConceded
        case yellowCards, redCards, timeEntries
    }
}

// MARK: - Substitution
struct Substitution: Codable, Equatable {
    var playerIn: UUID
    var playerOut: UUID
    var minute: Int
    var reason: SubstitutionReason
}

// MARK: - Substitution Reason
enum SubstitutionReason: String, Codable, CaseIterable, Equatable {
    case tactical = "Tactical"
    case injury = "Injury"
    case fatigue = "Fatigue"
    case yellowCard = "Yellow Card Risk"
    case performance = "Performance"
}

// MARK: - Practice (UPDATED with seasonId)
struct Practice: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var seasonId: UUID?                     // NEW: Which season this practice belongs to
    var date: Date
    var duration: Int
    var location: String?
    var notes: String?
    var attendees: [UUID] = []
    var drills: [Drill] = []
    var attendance: [UUID: Bool] = [:]
    var weather: String?
    var playerRSVPs: [UUID: RSVPStatus] = [:]
}

// MARK: - Drill
struct Drill: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var duration: Int // in minutes
    var category: String
    var difficulty: String
    var equipment: [String] = []
    var playerCount: String?
    var objectives: [String] = []
    var instructions: [String] = []
    var variations: [String] = []
    var videoURL: String?
}

// MARK: - Team Analytics
struct TeamAnalytics: Codable, Equatable {
    var totalGames: Int
    var wins: Int
    var losses: Int
    var draws: Int
    var goalsFor: Int
    var goalsAgainst: Int
    var topScorer: Player?
    var mostAssists: Player?
    var cleanSheets: Int
    
    // Computed properties
    var goalDifference: Int {
        goalsFor - goalsAgainst
    }
    
    var winPercentage: Double {
        guard totalGames > 0 else { return 0 }
        return Double(wins) / Double(totalGames) * 100
    }
}

// MARK: - Lineup Position
struct LineupPosition: Codable, Equatable {
    var playerId: UUID?
    var position: Position
    var fieldPosition: CGPoint
}

// MARK: - Active Game State (for live game tracking)
struct ActiveGameState: Identifiable {
    let id = UUID()
    let gameId: UUID
    let teamId: UUID
    let opponent: String
    var formation: Formation
    var lineupPositions: [LineupPosition]
    var startTime: Date
    var isRunning: Bool
    var isPaused: Bool
    var currentMinute: Int
    var currentSecond: Int
    var pausedTime: TimeInterval
    var isFirstHalf: Bool
    var auditLog: [GameAuditEntry]
    var halfLength: Int = 45
    var timeAdjustment: TimeInterval = 0  // Track manual time adjustments
    
    var statusText: String {
        if !isRunning { return "READY" }
        return isPaused ? "PAUSED" : "LIVE"
    }
    
    var statusColor: Color {
        if !isRunning { return .gray }
        return isPaused ? .orange : .red
    }
    
    var isInExtraTime: Bool {
        if isFirstHalf {
            return currentMinute >= halfLength
        } else {
            return currentMinute >= (halfLength * 2)
        }
    }
    
    var extraTimeMinutes: Int {
        if isFirstHalf {
            return max(0, currentMinute - halfLength)
        } else {
            return max(0, currentMinute - (halfLength * 2))
        }
    }
}

// MARK: - Game State Manager (for live game tracking)
class GameStateManager: ObservableObject {
    @Published var activeGameState: ActiveGameState?
    
    static let shared = GameStateManager()
    
    private var lastPersistTime: Date?
    private let persistInterval: TimeInterval = 30.0
    private let criticalPersistEvents: Set<GameAuditEventType> = [.goal, .substitution, .gameEnd, .halfTime]
    private init() {}
    
    func startGameSession(game: Game, team: Team, formation: Formation, lineupPositions: [LineupPosition], halfLength: Int = 45) {
        activeGameState = ActiveGameState(
            gameId: game.id,
            teamId: team.id,
            opponent: game.opponent,
            formation: formation,
            lineupPositions: lineupPositions,
            startTime: Date(),
            isRunning: true,
            isPaused: false,
            currentMinute: 0,
            currentSecond: 0,
            pausedTime: 0,
            isFirstHalf: true,
            auditLog: [],
            halfLength: halfLength,
            timeAdjustment: 0
        )
        
        addAuditEntry(
            eventType: .gameStart,
            gameTime: "0:00",
            details: "Game started vs \(game.opponent) (\(halfLength) min halves)"
        )
    }
    
    func updateGameState(_ gameState: ActiveGameState) {
        activeGameState = gameState
    }
    
    func updateGameTime(minute: Int, second: Int) {
        guard var state = activeGameState else { return }
        
        let oldTime = String(format: "%d:%02d", state.currentMinute, state.currentSecond)
        let newTime = String(format: "%d:%02d", minute, second)
        
        // Set absolute time instead of calculating adjustments
        state.currentMinute = minute
        state.currentSecond = second
        
        // Calculate total seconds for the new time
        let newTotalSeconds = minute * 60 + second
        
        // If game is running, adjust start time to reflect the new current time
        if state.isRunning && !state.isPaused {
            state.startTime = Date().addingTimeInterval(-Double(newTotalSeconds))
            state.timeAdjustment = 0 // Reset adjustment since we're setting absolute time
        } else if state.isPaused {
            // If paused, set the paused time to the new time
            state.pausedTime = Double(newTotalSeconds)
            state.timeAdjustment = 0 // Reset adjustment
        }
        
        activeGameState = state
        
        addAuditEntry(
            eventType: .timerAdjustment,
            gameTime: newTime,
            details: "Timer adjusted from \(oldTime) to \(newTime)"
        )
    }
    
    func pauseGame() {
        guard var state = activeGameState else { return }
        if !state.isPaused {
            let elapsed = Date().timeIntervalSince(state.startTime)
            let currentMinute = Int(elapsed / 60)
            let currentSecond = Int(elapsed.truncatingRemainder(dividingBy: 60))
            let currentTimeString = String(format: "%d:%02d", currentMinute, currentSecond)
            
            state.currentMinute = currentMinute
            state.currentSecond = currentSecond
            state.pausedTime = elapsed
            state.isPaused = true
            activeGameState = state
            
            addAuditEntry(
                eventType: .gamePause,
                gameTime: currentTimeString,
                details: "Game paused"
            )
        }
    }
    
    func resumeGame() {
        guard var state = activeGameState else { return }
        if state.isPaused {
            let resumeTimeString = String(format: "%d:%02d", state.currentMinute, state.currentSecond)
            
            state.startTime = Date() - state.pausedTime
            state.pausedTime = 0
            state.isPaused = false
            activeGameState = state
            
            addAuditEntry(
                eventType: .gameResume,
                gameTime: resumeTimeString,
                details: "Game resumed"
            )
        }
    }
    
    func startHalfTime() {
        guard var state = activeGameState else { return }
        
        // In soccer, second half starts at the official half length, not the actual end time
        let secondHalfStartTime = state.halfLength
        let currentTimeString = String(format: "%d:%02d", secondHalfStartTime, 0)
        
        // Switch to second half and start at the official half length
        state.isFirstHalf = false
        state.currentMinute = secondHalfStartTime
        state.currentSecond = 0
        
        // Set up the timer so when resumed, it starts from the half length
        let totalSecondsAtHalfLength = secondHalfStartTime * 60
        state.startTime = Date().addingTimeInterval(-Double(totalSecondsAtHalfLength))
        state.pausedTime = Double(totalSecondsAtHalfLength)
        state.isPaused = true
        state.timeAdjustment = 0
        
        activeGameState = state
        
        addAuditEntry(
            eventType: .halfTime,
            gameTime: currentTimeString,
            details: "Half time"
        )
    }
    
    func endGameSession() {
        activeGameState = nil
    }
    
    func addAuditEntry(eventType: GameAuditEventType, gameTime: String, playerName: String? = nil, playerId: UUID? = nil, details: String, additionalInfo: [String: String]? = nil) {
        guard var state = activeGameState else { return }
        
        let entry = GameAuditEntry(
            eventType: eventType,
            gameTime: gameTime,
            details: details,
            playerName: playerName,
            playerPosition: nil,
            playerId: playerId
        )
        
        state.auditLog.append(entry)
        activeGameState = state
        
        // Force persist for critical events
        let criticalEvents: Set<GameAuditEventType> = [.goal, .substitution, .gameEnd, .halfTime]
        if criticalEvents.contains(eventType) {
            forcePersistActiveGameState()
        }
    }
    
    // NEW: Edit audit entry
    func editAuditEntry(entryId: UUID, newEventType: GameAuditEventType, newGameTime: String, newPlayerName: String?, newPlayerId: UUID?, newDetails: String) {
        guard var state = activeGameState else { return }
        
        if let index = state.auditLog.firstIndex(where: { $0.id == entryId }) {
            state.auditLog[index].eventType = newEventType
            state.auditLog[index].gameTime = newGameTime
            state.auditLog[index].playerName = newPlayerName
            state.auditLog[index].playerId = newPlayerId
            state.auditLog[index].details = newDetails
            
            activeGameState = state
        }
    }
    
    // NEW: Delete audit entry
    func deleteAuditEntry(entryId: UUID) {
        guard var state = activeGameState else { return }
        
        state.auditLog.removeAll { $0.id == entryId }
        activeGameState = state
    }
    
    var calculatedMinute: Int {
        guard let state = activeGameState else { return 0 }
        
        if state.isRunning && !state.isPaused {
            let elapsed = Date().timeIntervalSince(state.startTime)
            let totalMinutes = Int(elapsed / 60)
            return totalMinutes
        } else {
            return state.currentMinute
        }
    }
    
    var calculatedSecond: Int {
        guard let state = activeGameState else { return 0 }
        
        if state.isRunning && !state.isPaused {
            let elapsed = Date().timeIntervalSince(state.startTime)
            return Int(elapsed.truncatingRemainder(dividingBy: 60))
        } else {
            return state.currentSecond
        }
    }
    
    var formattedTime: String {
        guard let state = activeGameState else { return "0:00" }
        
        let minutes = calculatedMinute
        let seconds = calculatedSecond
        
        if state.isFirstHalf && minutes >= state.halfLength {
            let extraMinutes = minutes - state.halfLength
            if extraMinutes > 0 {
                return "\(state.halfLength)+\(extraMinutes):\(String(format: "%02d", seconds))"
            } else {
                return "\(state.halfLength):\(String(format: "%02d", seconds))"
            }
        } else if !state.isFirstHalf && minutes >= (state.halfLength * 2) {
            let extraMinutes = minutes - (state.halfLength * 2)
            if extraMinutes > 0 {
                return "\(state.halfLength * 2)+\(extraMinutes):\(String(format: "%02d", seconds))"
            } else {
                return "\(state.halfLength * 2):\(String(format: "%02d", seconds))"
            }
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var auditLogTime: String {
        guard let state = activeGameState else { return "0:00" }
        
        let minutes = calculatedMinute
        let seconds = calculatedSecond
        
        if state.isFirstHalf && minutes >= state.halfLength {
            return "\(state.halfLength):\(String(format: "%02d", seconds))"
        } else if !state.isFirstHalf && minutes >= (state.halfLength * 2) {
            return "\(state.halfLength * 2):\(String(format: "%02d", seconds))"
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var isGameActive: Bool {
        activeGameState != nil
    }
    
    func persistActiveGameState() {
        // Check if enough time has passed since last persist
        if let lastTime = lastPersistTime,
           Date().timeIntervalSince(lastTime) < persistInterval {
            // Skip this persistence unless it's been 30+ seconds
            return
        }
        guard let activeState = activeGameState else {
            // Remove persisted state if no active game
            UserDefaults.standard.removeObject(forKey: "ActiveGameState")
            return
        }
        
        let persistedState = PersistedActiveGameState(from: activeState)
        
        if let encoded = try? JSONEncoder().encode(persistedState) {
            UserDefaults.standard.set(encoded, forKey: "ActiveGameState")
            lastPersistTime = Date()
            print("💾 Persisted active game state")
        }
    }
    
    func forcePersistActiveGameState() {
          guard let activeState = activeGameState else {
              UserDefaults.standard.removeObject(forKey: "ActiveGameState")
              return
          }
          
          let persistedState = PersistedActiveGameState(from: activeState)
          
          if let encoded = try? JSONEncoder().encode(persistedState) {
              UserDefaults.standard.set(encoded, forKey: "ActiveGameState")
              lastPersistTime = Date()
              print("💾 Force persisted active game state (critical event)")
          }
      }

    func restoreActiveGameState(from persistedState: PersistedActiveGameState) {
        // Create a new ActiveGameState from the persisted data
        let restoredState = ActiveGameState(
            gameId: persistedState.gameId,
            teamId: persistedState.teamId,
            opponent: persistedState.opponent,
            formation: persistedState.formation,
            lineupPositions: persistedState.lineupPositions,
            startTime: persistedState.startTime,
            isRunning: persistedState.isRunning,
            isPaused: persistedState.isPaused,
            currentMinute: 0, // Will be calculated
            currentSecond: 0, // Will be calculated
            pausedTime: persistedState.pausedTime ?? 0,
            isFirstHalf: persistedState.isFirstHalf,
            auditLog: persistedState.auditLog,
            halfLength: persistedState.halfLength,
            timeAdjustment: 0
        )
        
        // Set as the active game
        activeGameState = restoredState
        
        print("🔄 Restored active game state - Time: \(calculatedMinute):\(String(format: "%02d", calculatedSecond))")
    }

    func clearPersistedGameState() {
        UserDefaults.standard.removeObject(forKey: "ActiveGameState")
        print("🗑️ Cleared persisted game state")
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: .whitespacesAndNewlines))
        _ = scanner.scanString("#")

        var rgb: UInt64 = 0
        let success = scanner.scanHexInt64(&rgb)
        
        // FIXED: Safe handling of invalid hex values to prevent NaN
        if !success || hex.isEmpty {
            print("⚠️ Invalid hex color: \(hex), using fallback color")
            // Use a fallback color instead of creating invalid values
            self = Color.gray
            return
        }

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        // FIXED: Validate color components before creating Color
        let safeR = r.isNaN || r.isInfinite ? 0.5 : max(0, min(1, r))
        let safeG = g.isNaN || g.isInfinite ? 0.5 : max(0, min(1, g))
        let safeB = b.isNaN || b.isInfinite ? 0.5 : max(0, min(1, b))

        self = Color(red: safeR, green: safeG, blue: safeB)
    }

    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        
        // FIXED: Safe color component extraction
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            print("⚠️ Failed to get color components, using fallback")
            return "#808080" // Gray fallback
        }
        
        // FIXED: Validate components before conversion
        let safeRed = red.isNaN || red.isInfinite ? 0.5 : max(0, min(1, red))
        let safeGreen = green.isNaN || green.isInfinite ? 0.5 : max(0, min(1, green))
        let safeBlue = blue.isNaN || blue.isInfinite ? 0.5 : max(0, min(1, blue))
        
        let r = Int(safeRed * 255)
        let g = Int(safeGreen * 255)
        let b = Int(safeBlue * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Additional Safe Frame Extensions
extension CGFloat {
    /// Returns a safe CGFloat value, replacing NaN and infinite values with fallbacks
    var safeValue: CGFloat {
        if isNaN || isInfinite {
            return 0
        }
        return self
    }
}

extension CGSize {
    /// Returns a safe CGSize with validated width and height
    var safeSize: CGSize {
        return CGSize(
            width: max(0, width.safeValue),
            height: max(0, height.safeValue)
        )
    }
}

extension CGRect {
    /// Returns a safe CGRect with validated frame values
    var safeRect: CGRect {
        return CGRect(
            x: origin.x.safeValue,
            y: origin.y.safeValue,
            width: max(0, size.width.safeValue),
            height: max(0, size.height.safeValue)
        )
    }
}

// MARK: - App Settings Model
struct AppSettings: Codable, Equatable {
    var defaultFormation: Formation = .formation442
    var defaultHalfLength: Int = 45
    var enableNotifications: Bool = true
    var gameReminders: Bool = true
    var practiceReminders: Bool = true
    var reminderHoursBefore: Int = 24
    var defaultEventDuration: Int = 180  // minutes
    var enableHapticFeedback: Bool = true
    var autoSaveLineups: Bool = true
    var showPlayerPhotos: Bool = true
    var defaultSortOrder: PlayerSortOrder = .byNumber

    enum PlayerSortOrder: String, Codable, CaseIterable, Equatable {
        case byName = "Name"
        case byNumber = "Number"
        case byPosition = "Position"
    }
}

// MARK: - Lineup State for Persistence
struct LineupState: Codable {
    let teamId: UUID
    let formation: Formation
    let positions: [LineupPosition]
    let selectedGameId: UUID?
}

// MARK: - Persisted Active Game State
struct PersistedActiveGameState: Codable {
    let gameId: UUID
    let teamId: UUID
    let opponent: String
    let formation: Formation
    let lineupPositions: [LineupPosition]
    let startTime: Date
    let pausedTime: TimeInterval?
    let isFirstHalf: Bool
    let isPaused: Bool
    let isRunning: Bool
    let halfLength: Int
    let auditLog: [GameAuditEntry]
    
    init(from activeGameState: ActiveGameState) {
        self.gameId = activeGameState.gameId
        self.teamId = activeGameState.teamId
        self.opponent = activeGameState.opponent
        self.formation = activeGameState.formation
        self.lineupPositions = activeGameState.lineupPositions
        self.startTime = activeGameState.startTime
        self.pausedTime = activeGameState.pausedTime
        self.isFirstHalf = activeGameState.isFirstHalf
        self.isPaused = activeGameState.isPaused
        self.isRunning = activeGameState.isRunning
        self.halfLength = activeGameState.halfLength
        self.auditLog = activeGameState.auditLog
    }
}

// MARK: - Player Stats Type Alias for backward compatibility
typealias PlayerSeasonStats = PlayerStats
