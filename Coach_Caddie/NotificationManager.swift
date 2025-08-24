import SwiftUI
import UserNotifications
import Foundation

// MARK: - Notification Manager
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notifications: [AppNotification] = []
    @Published var hasPermission = false
    
    private init() {
        checkPermissionStatus()
    }
    
    // MARK: - Permission Management
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                if granted {
                    print("Notification permission granted")
                } else {
                    print("Notification permission denied")
                }
            }
        }
    }
    
    private func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - In-App Notifications
    func showNotification(_ notification: AppNotification) {
        DispatchQueue.main.async {
            self.notifications.append(notification)
            
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.dismissNotification(notification)
            }
        }
    }
    
    func dismissNotification(_ notification: AppNotification) {
        DispatchQueue.main.async {
            self.notifications.removeAll { $0.id == notification.id }
        }
    }
    
    func dismissAllNotifications() {
        DispatchQueue.main.async {
            self.notifications.removeAll()
        }
    }
    
    // MARK: - Convenience Methods
    func showSuccess(_ message: String) {
        let notification = AppNotification(
            type: .success,
            title: "Success",
            message: message
        )
        showNotification(notification)
    }
    
    func showError(_ message: String) {
        let notification = AppNotification(
            type: .error,
            title: "Error",
            message: message
        )
        showNotification(notification)
    }
    
    func showInfo(_ message: String) {
        let notification = AppNotification(
            type: .info,
            title: "Info",
            message: message
        )
        showNotification(notification)
    }
    
    func showWarning(_ message: String) {
        let notification = AppNotification(
            type: .warning,
            title: "Warning",
            message: message
        )
        showNotification(notification)
    }
}

// MARK: - App Notification Model
struct AppNotification: Identifiable, Equatable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let message: String
    let timestamp = Date()
    
    // Equatable conformance
    static func == (lhs: AppNotification, rhs: AppNotification) -> Bool {
        return lhs.id == rhs.id
    }
    
    enum NotificationType {
        case success, error, warning, info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
}