import Foundation
import FirebaseFirestore

// MARK: - Firebase-Specific Models

struct TeamInvite: Codable, Identifiable {
    let id: String
    let teamId: String
    let teamName: String
    let accessLevel: AccessLevel
    let createdBy: String
    let createdAt: Date
    let expiresAt: Date
    let usedCount: Int
    let maxUses: Int
}

// MARK: - Team Member Info (ADD THIS TO FirebaseModels.swift)
struct TeamMemberInfo: Identifiable, Codable {
    let id = UUID()
    let userId: String
    let email: String
    let accessLevel: AccessLevel
    let joinedAt: Date
    
    var displayName: String {
        // Extract name from email if no display name available
        return email.components(separatedBy: "@").first?.capitalized ?? email
    }
}

struct ChatMessage: Codable, Identifiable {
    let id: String
    let teamId: String
    let senderId: String
    let senderName: String
    let message: String
    let timestamp: Date
    let isCoach: Bool
}

enum AccessLevel: String, Codable, CaseIterable {
    case coach = "coach"
    case parent = "parent"
    case viewer = "viewer"
    
    var displayName: String {
        switch self {
        case .coach: return "Coach (Full Access)"
        case .parent: return "Parent (Edit Access)"
        case .viewer: return "Viewer (Read Only)"
        }
    }
    
    var canEdit: Bool {
        return self == .coach || self == .parent
    }
}

struct GeneratedInvite: Identifiable {
    let id = UUID()
    let code: String
    let accessLevel: AccessLevel
    let maxUses: Int
    let currentUses: Int
    let expiresAt: Date
}

// MARK: - Firebase Errors
enum FirebaseError: LocalizedError {
    case notAuthenticated
    case invalidInviteCode
    case expiredInviteCode
    case teamNotFound
    case accessDenied
    case seasonRequired      // NEW
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .invalidInviteCode:
            return "Invalid invite code"
        case .expiredInviteCode:
            return "This invite code has expired"
        case .teamNotFound:
            return "Team not found"
        case .accessDenied:
            return "Access denied"
        case .seasonRequired:       // NEW
            return "Please create a season before adding games or practices"
        }
    }
    // MARK: - Team Member Model
    struct TeamMember: Codable, Identifiable {
        let id: String
        let userId: String
        let email: String
        let accessLevel: AccessLevel
        let joinedAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case userId
            case email
            case accessLevel
            case joinedAt
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            userId = try container.decode(String.self, forKey: .userId)
            email = try container.decode(String.self, forKey: .email)
            accessLevel = try container.decode(AccessLevel.self, forKey: .accessLevel)
            
            let timestamp = try container.decode(Timestamp.self, forKey: .joinedAt)
            joinedAt = timestamp.dateValue()
        }
    }
}
