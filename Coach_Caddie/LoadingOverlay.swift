import SwiftUI

// MARK: - Improved Loading Overlay
struct LoadingOverlay: View {
    @State private var animationRotation: Double = 0
    @State private var showTimeout = false
    let timeoutDuration: TimeInterval = 10 // Show timeout warning after 10 seconds
    
    var body: some View {
        ZStack {
            // Less opaque background - more subtle
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Custom loading spinner
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(animationRotation))
                        .animation(
                            Animation.linear(duration: 1)
                                .repeatForever(autoreverses: false),
                            value: animationRotation
                        )
                }
                
                VStack(spacing: 4) {
                    Text("Loading…")
                        .foregroundColor(.white)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    if showTimeout {
                        Text("This is taking longer than usual")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)
                            .transition(.opacity)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
        }
        .onAppear {
            animationRotation = 360
            
            // Show timeout message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutDuration) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showTimeout = true
                }
            }
        }
    }
}

// MARK: - Alternative Minimal Loading Indicator
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
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Top Bar Loading Indicator (Alternative to full overlay)
struct TopBarLoadingIndicator: View {
    @State private var progress: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geometry.size.width * progress, height: 3)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
            .frame(height: 3)
            .background(Color.green.opacity(0.2))
            
            Spacer()
        }
        .onAppear {
            // Simulate indeterminate progress
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                progress = 1.0
            }
        }
    }
}

// MARK: - Loading State Wrapper View
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
                if useMinimal {
                    VStack {
                        TopBarLoadingIndicator()
                        Spacer()
                    }
                } else {
                    LoadingOverlay()
                }
            }
        }
    }
}

// MARK: - Preview
struct LoadingOverlay_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Full overlay
            ZStack {
                Color.blue.ignoresSafeArea()
                LoadingOverlay()
            }
            .previewDisplayName("Full Overlay")
            
            // Minimal indicator
            VStack {
                Text("Some content here")
                MinimalLoadingIndicator()
                Text("More content")
            }
            .padding()
            .previewDisplayName("Minimal Indicator")
            
            // Top bar indicator
            ZStack {
                VStack {
                    Text("App Content")
                    Spacer()
                }
                TopBarLoadingIndicator()
            }
            .previewDisplayName("Top Bar")
        }
    }
}
