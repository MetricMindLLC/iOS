import SwiftUI

struct OfflineIndicator: View {
    let pendingSyncItems: Int
    let onRetry: () -> Void

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Offline")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    if pendingSyncItems > 0 {
                        Text("\(pendingSyncItems) pending changes")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Button("Retry", action: onRetry)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)

            Spacer()
        }
    }
}