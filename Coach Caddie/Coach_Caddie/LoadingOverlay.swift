import SwiftUI

// MARK: - Bouncing Soccer Ball
private struct BouncingSoccerBall: View {
    @State private var isUp = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "soccerball")
                .font(.system(size: 58, weight: .regular))
                .foregroundStyle(Color.white, Color.black.opacity(0.85))
                .rotationEffect(.degrees(isUp ? -18 : 18))
                .offset(y: isUp ? -44 : 0)
                .scaleEffect(x: isUp ? 1.0 : 1.12, y: isUp ? 1.0 : 0.88)
                .animation(
                    .interpolatingSpring(stiffness: 160, damping: 11)
                        .repeatForever(autoreverses: true),
                    value: isUp
                )

            // Ground shadow — shrinks/fades as ball rises
            Ellipse()
                .fill(Color.black.opacity(isUp ? 0.08 : 0.28))
                .frame(width: isUp ? 28 : 52, height: isUp ? 5 : 9)
                .blur(radius: isUp ? 3 : 1)
                .animation(
                    .interpolatingSpring(stiffness: 160, damping: 11)
                        .repeatForever(autoreverses: true),
                    value: isUp
                )
        }
        .onAppear {
            // Small delay so the first frame renders before animating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isUp = true
            }
        }
    }
}

// MARK: - Shared Soccer Loading Card
struct SoccerLoadingCard: View {
    let message: String
    var subMessage: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            BouncingSoccerBall()

            VStack(spacing: 5) {
                Text(message)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if let sub = subMessage {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.50, blue: 0.27),
                            Color(red: 0.08, green: 0.30, blue: 0.16)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 10)
        )
    }
}

// MARK: - Full Loading Overlay (startup / data load)
struct LoadingOverlay: View {
    @State private var showTimeout = false
    let timeoutDuration: TimeInterval = 10

    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()

            SoccerLoadingCard(
                message: "Loading...",
                subMessage: showTimeout ? "This is taking longer than usual" : nil
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutDuration) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showTimeout = true
                }
            }
        }
    }
}

// MARK: - Reconnecting Overlay
struct ReconnectingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()

            SoccerLoadingCard(message: "Reconnecting...")
        }
    }
}

// MARK: - Minimal syncing dots (unchanged — used elsewhere)
struct MinimalLoadingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }

            Text("Syncing")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .onAppear { isAnimating = true }
    }
}

// MARK: - Loading State Wrapper
struct LoadingStateView<Content: View>: View {
    let isLoading: Bool
    let useMinimal: Bool
    let content: Content

    init(isLoading: Bool, useMinimal: Bool = false, @ViewBuilder content: () -> Content) {
        self.isLoading = isLoading
        self.useMinimal = useMinimal
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .disabled(isLoading)

            if isLoading {
                LoadingOverlay()
            }
        }
    }
}

// MARK: - Preview
#Preview("Loading") {
    ZStack {
        Color(red: 0.1, green: 0.12, blue: 0.15).ignoresSafeArea()
        LoadingOverlay()
    }
}

#Preview("Reconnecting") {
    ZStack {
        Color(red: 0.1, green: 0.12, blue: 0.15).ignoresSafeArea()
        ReconnectingOverlay()
    }
}
