//
//  TeamInvite.swift
//  Coach_Caddie
//
//  Created by Jason Hutches on 7/14/25.
//


import Foundation

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
        }
    }
}