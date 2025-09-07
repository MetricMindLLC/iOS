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
    case trial = "trial"             // 3-day free trial
    case pro = "pro"                // $4.99/month
    case premium = "premium"         // $9.99/month
    case club = "club"              // $79.99/month for clubs
    case sharedAccess = "sharedAccess"  // FREE: Access to shared teams only
    case cancelled = "cancelled"     // Cancelled but data retained
    case expired = "expired"         // Hard deleted after 180 days
    
    var displayName: String {
        switch self {
        case .free: return "Legacy (Unlimited)"
        case .trial: return "Free Trial"
        case .pro: return "Pro Coach"
        case .premium: return "Premium Coach"
        case .club: return "Club Administrator"
        case .sharedAccess: return "Shared Team Access"
        case .cancelled: return "Cancelled"
        case .expired: return "Expired"
        }
    }
    
    var monthlyPrice: String {
        switch self {
        case .free: return "Free Forever"
        case .trial: return "Free for 3 days"
        case .pro: return "$4.99/month"
        case .premium: return "$9.99/month"
        case .club: return "$79.99/month"
        case .sharedAccess: return "Free (Shared Access)"
        case .cancelled, .expired: return "Inactive"
        }
    }
    
    var yearlyPrice: String {
        switch self {
        case .free: return "Free Forever"
        case .trial: return "Free for 3 days"
        case .pro: return "$49.99/year"
        case .premium: return "$99.99/year"
        case .club: return "$799.99/year"
        case .sharedAccess: return "Free (Shared Access)"
        case .cancelled, .expired: return "Inactive"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .free, .trial, .pro, .premium, .club, .sharedAccess: return true
        case .cancelled, .expired: return false
        }
    }
    
    var canCreateTeams: Bool {
        switch self {
        case .sharedAccess: return false  // Cannot create own teams
        case .free, .trial, .pro, .premium, .club: return true
        case .cancelled, .expired: return false
        }
    }
    
    var canGenerateInvites: Bool {
        switch self {
        case .free, .trial, .pro, .premium, .club, .sharedAccess: return true
        case .cancelled, .expired: return false
        }
    }
    
    var maxTeams: Int {
        switch self {
        case .free: return 999        // UNLIMITED for legacy accounts
        case .trial: return 1
        case .pro: return 1
        case .premium: return 3
        case .club: return 20
        case .sharedAccess: return 0  // Cannot create own teams
        case .cancelled, .expired: return 0
        }
    }
    
    var maxCoachInvitesPerTeam: Int {
        switch self {
        case .free: return 999        // UNLIMITED for legacy accounts
        case .trial: return 1
        case .pro: return 2
        case .premium: return 3
        case .club: return 3
        case .sharedAccess: return 3  // Inherit max from premium teams they can access
        case .cancelled, .expired: return 0
        }
    }
    
    var maxParentInvitesPerTeam: Int {
        switch self {
        case .free: return 999        // UNLIMITED for legacy accounts
        case .trial: return 10
        case .pro: return 20
        case .premium: return 20
        case .club: return 20
        case .sharedAccess: return 20 // Same as premium since they're coaching shared teams
        case .cancelled, .expired: return 0
        }
    }
    
    var maxViewerInvitesPerTeam: Int {
        switch self {
        case .free: return 999        // UNLIMITED for legacy accounts
        case .trial: return 10
        case .pro: return 20
        case .premium: return 20
        case .club: return 20
        case .sharedAccess: return 20 // Same as premium since they're coaching shared teams
        case .cancelled, .expired: return 0
        }
    }
    
    // NEW: Club-specific permissions
    var canManageClub: Bool {
        switch self {
        case .club: return true
        default: return false
        }
    }
    
    var canViewClubAnalytics: Bool {
        switch self {
        case .club: return true
        default: return false
        }
    }
    
    var canTransferPlayers: Bool {
        switch self {
        case .club: return true
        default: return false
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "🎉 Legacy Account - Free Forever!",
                "Unlimited teams",
                "Unlimited invites",
                "All premium features"
            ]
        case .trial:
            return [
                "3-day free trial",
                "1 team",
                "1 coach invite",
                "10 parent invites",
                "10 viewer invites",
                "Full team management"
            ]
        case .pro:
            return [
                "1 team",
                "2 coach invites",
                "20 parent invites",
                "20 viewer invites",
                "Advanced statistics",
                "Export data"
            ]
        case .premium:
            return [
                "3 teams",
                "3 coach invites per team",
                "20 parent/viewer invites per team",
                "Advanced statistics",
                "Export data",
                "Priority support"
            ]
        case .club:
            return [
                "20 teams per club",
                "3 coach invites per team",
                "20 parent/viewer invites per team",
                "Club administrator controls",
                "Priority support"
            ]
        case .sharedAccess:
            return [
                "🎯 Shared Team Access",
                "Full coach access to shared teams",
                "Generate invites for your teams",
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
        let trialEndDate = Calendar.current.date(byAdding: .day, value: 3, to: trialStartDate) ?? trialStartDate
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
        let trialEndDate = Calendar.current.date(byAdding: .day, value: 3, to: trialStartDate) ?? trialStartDate
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

struct Team: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var format: TeamFormat
    var defaultFormation: Formation
    var defaultHalfLength: Int = 45  // NEW: Team-specific half length
    var players: [Player]           // KEEP for backward compatibility
    var games: [Game]               // KEEP for backward compatibility
    var practices: [Practice]       // KEEP for backward compatibility
    var primaryColor: Color
    var logoData: Data?
    var ageGroup: String?
    var season: String?
    var dateCreated: Date
    var coachUID: String? // Made optional for backward compatibility
    var expirationDate: Date? // TTL field for automatic deletion
    var lastActivityTimestamp: Date = Date() // Track team activity
    
    // NEW: Subcollection support (optional)
    var useSubcollections: Bool = false  // Flag to enable subcollection mode
    var lastSyncDate: Date = Date()      // Track when subcollections were last synced

    enum CodingKeys: String, CodingKey {
        case id, name, format, defaultFormation, defaultHalfLength, players, games, practices
        case primaryColorHex, logoData, ageGroup, season, dateCreated, coachUID
        case expirationDate, lastActivityTimestamp // ADDED: TTL fields
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
        self.primaryColor = primaryColor
        self.logoData = logoData
        self.ageGroup = ageGroup
        self.season = season
        self.dateCreated = dateCreated
        self.coachUID = coachUID
        self.lastActivityTimestamp = Date()
        // Set initial expiration to 180 days from now (changed from 180)
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
        useSubcollections = try container.decodeIfPresent(Bool.self, forKey: .useSubcollections) ?? false
        lastSyncDate = try container.decodeIfPresent(Date.self, forKey: .lastSyncDate) ?? Date()
        
        // ADDED: Handle TTL fields with backward compatibility
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
        try container.encode(useSubcollections, forKey: .useSubcollections)
        try container.encode(lastSyncDate, forKey: .lastSyncDate)
        try container.encode(primaryColor.toHex(), forKey: .primaryColorHex)
        try container.encodeIfPresent(logoData, forKey: .logoData)
        try container.encodeIfPresent(ageGroup, forKey: .ageGroup)
        try container.encodeIfPresent(season, forKey: .season)
        try container.encode(dateCreated, forKey: .dateCreated)
        try container.encodeIfPresent(coachUID, forKey: .coachUID)
        
        // ADDED: Encode TTL fields
        try container.encode(lastActivityTimestamp, forKey: .lastActivityTimestamp)
        try container.encodeIfPresent(expirationDate, forKey: .expirationDate)
    }

    // KEEP: All your existing computed properties
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
    
    // Added for LineupView compatibility
    var activePlayers: [Player] {
        players.filter { !($0.isInjured ?? false) }
    }
    
    // FIXED: Update activity and expiration date
    mutating func updateActivityForTTL() {
        lastActivityTimestamp = Date()
        // Set expiration to 180 days from now
        expirationDate = Calendar.current.date(byAdding: .day, value: 180, to: Date())
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
// MARK: - Player (UPDATED for COPPA Compliance - REMOVED dateOfBirth)
struct Player: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var jerseyNumber: Int
    var positions: [String]
    var preferredPosition: String
    var phoneNumber: String?
    var email: String?
    // REMOVED: var dateOfBirth: Date? - COPPA compliance
    var notes: String?
    var playerPhoto: Data?
    var isInjured: Bool?
    var seasonStats: PlayerStats = PlayerStats()
    var parentInfo: ParentInfo = ParentInfo()
    var emergencyContact: String?
    var emergencyPhone: String?
    var medicalNotes: String?
    
    // NEW: Privacy settings for COPPA compliance
    var privacySettings: PlayerPrivacySettings = PlayerPrivacySettings()
    
    // REMOVED: age computed property - no longer needed without DOB
    
    var preferredPositionEnum: Position {
        Position(rawValue: preferredPosition) ?? .midfielder
    }
    
    // NEW: Display name based on viewer access level
    func displayName(for accessLevel: AccessLevel, viewerEmail: String? = nil) -> String {
        switch accessLevel {
        case .coach:
            return name // Coaches see full name
        case .parent:
            // Parents see full name only for their own children
            if let email = viewerEmail,
               (parentInfo.parentEmail.lowercased() == email.lowercased() ||
                parentInfo.secondParentEmail.lowercased() == email.lowercased()) {
                return name
            } else {
                return nameWithLastInitial()
            }
        case .viewer:
            return nameWithLastInitial() // Viewers see first name + last initial
        }
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
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id, name, jerseyNumber, positions, preferredPosition
        case phoneNumber, email, notes, playerPhoto, isInjured
        case seasonStats, parentInfo, emergencyContact, emergencyPhone
        case medicalNotes, privacySettings
        // Note: dateOfBirth removed for COPPA compliance
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
        parentInfo = try container.decodeIfPresent(ParentInfo.self, forKey: .parentInfo) ?? ParentInfo()
        emergencyContact = try container.decodeIfPresent(String.self, forKey: .emergencyContact)
        emergencyPhone = try container.decodeIfPresent(String.self, forKey: .emergencyPhone)
        medicalNotes = try container.decodeIfPresent(String.self, forKey: .medicalNotes)
        privacySettings = try container.decodeIfPresent(PlayerPrivacySettings.self, forKey: .privacySettings) ?? PlayerPrivacySettings()
        
        // Handle legacy dateOfBirth field if present (ignore it for COPPA compliance)
        // This ensures backward compatibility while removing DOB
    }
    
    // MARK: - Encoder
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
        try container.encode(parentInfo, forKey: .parentInfo)
        try container.encodeIfPresent(emergencyContact, forKey: .emergencyContact)
        try container.encodeIfPresent(emergencyPhone, forKey: .emergencyPhone)
        try container.encodeIfPresent(medicalNotes, forKey: .medicalNotes)
        try container.encode(privacySettings, forKey: .privacySettings)
        
        // Note: dateOfBirth intentionally not encoded for COPPA compliance
    }
    
    // MARK: - Standard initializer
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
        self.parentInfo = parentInfo
        self.emergencyContact = emergencyContact
        self.emergencyPhone = emergencyPhone
        self.medicalNotes = medicalNotes
        self.privacySettings = privacySettings
    }
    
    // MARK: - Equatable implementation
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

// MARK: - Player Stats (UPDATED with goalsConceded)
struct PlayerStats: Codable, Equatable {
    var gamesPlayed: Int = 0
    var goals: Int = 0
    var assists: Int = 0
    var shots: Int = 0
    var shotOnTarget: Int = 0
    var saves: Int = 0
    var goalsConceded: Int = 0  // NEW: For goalkeepers
    var yellowCards: Int = 0
    var redCards: Int = 0
    var minutesPlayed: Int = 0
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



// MARK: - Game (FIXED for backward compatibility)
struct Game: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
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
    var isCompleted: Bool = false  // Track if game is finalized
    var playerRSVPs: [UUID: RSVPStatus] = [:]
    var plannedSubstitutions: [PlannedSubstitution] = []  // NEW
    var lineupPhases: [LineupPhase] = []  // NEW
    var useAutoSubstitutions: Bool = false  // NEW
    var actualStartingLineup: [LineupPosition]? = nil
    var plannedPositionChanges: [PlannedPositionChange] = []
    var substitutionNotes: String? = nil 
    // MARK: - Custom Decoding for Backward Compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode existing properties normally
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
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
        
        // NEW: Decode new properties with defaults for backward compatibility
        plannedSubstitutions = try container.decodeIfPresent([PlannedSubstitution].self, forKey: .plannedSubstitutions) ?? []
        lineupPhases = try container.decodeIfPresent([LineupPhase].self, forKey: .lineupPhases) ?? []
        useAutoSubstitutions = try container.decodeIfPresent(Bool.self, forKey: .useAutoSubstitutions) ?? false
    }
    
    init(id: UUID = UUID(),
         date: Date,
         opponent: String,
         isHome: Bool = true,
         location: String? = nil,
         formation: Formation? = nil,
         startingLineup: [LineupPosition]? = nil,
         result: GameResult? = nil,
         notes: String? = nil) {
        self.id = id
        self.date = date
        self.opponent = opponent
        self.isHome = isHome
        self.location = location
        self.formation = formation
        self.startingLineup = startingLineup
        self.result = result
        self.notes = notes
        // All other properties will use their default values
    }
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id, date, opponent, isHome, location, formation, startingLineup, result
        case gameEvents, playerStats, substitutions, notes, auditLog, isCompleted, playerRSVPs
        case plannedSubstitutions, lineupPhases, useAutoSubstitutions
    }
}

// MARK: - Game Extension (FIXED - handles different substitution types properly)
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
                    let entryEnd = entry.exitedAt ?? totalGameTime // If still playing, assume full game
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
            // Player being substituted out - reduce their minutes
            if substitution.playerOut == playerId {
                let minutesToSubtract = totalGameTime - substitution.minute
                minutesPlayed = max(0, minutesPlayed - minutesToSubtract)
            }
            
            // Player being substituted in - add their minutes
            if substitution.playerIn == playerId {
                let minutesToAdd = totalGameTime - substitution.minute
                minutesPlayed += minutesToAdd
            }
        }
        
        // Apply planned substitutions that haven't been executed yet
        for plannedSub in self.plannedSubstitutions.filter({ !$0.isExecuted }) {
            // Player being substituted out - reduce their minutes
            if plannedSub.playerOut == playerId {
                let minutesToSubtract = totalGameTime - plannedSub.plannedMinute
                minutesPlayed = max(0, minutesPlayed - minutesToSubtract)
            }
            
            // Player being substituted in - add their minutes
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
        
        // Also create stats entries for players who don't have them but should
        // (players in starting lineup or involved in substitutions)
        var playersInvolved: Set<UUID> = Set()
        
        // Add starting lineup players
        if let lineup = actualStartingLineup ?? startingLineup {
            for position in lineup {
                if let playerId = position.playerId {
                    playersInvolved.insert(playerId)
                }
            }
        }
        
        // Add players involved in executed substitutions
        for sub in substitutions {
            playersInvolved.insert(sub.playerIn)
            playersInvolved.insert(sub.playerOut)
        }
        
        // Add players involved in planned substitutions
        for plannedSub in plannedSubstitutions {
            playersInvolved.insert(plannedSub.playerIn)
            playersInvolved.insert(plannedSub.playerOut)
        }
        
        // Create missing player stats entries
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

// MARK: - Practice
struct Practice: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var duration: Int // in minutes
    var location: String?
    var notes: String?
    var attendees: [UUID] = [] // Player IDs who attended
    var drills: [Drill] = []
    var attendance: [UUID: Bool] = [:] // Player ID to attendance status
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
