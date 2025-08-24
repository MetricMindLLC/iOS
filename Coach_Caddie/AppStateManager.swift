import Foundation
import Combine

final class AppStateManager: ObservableObject {
    @Published var isOffline: Bool = false
    @Published var pendingSyncItems: Int = 0

    func triggerSync() {
        // Insert sync logic here
        print("🔁 Triggering data sync...")
    }
}
