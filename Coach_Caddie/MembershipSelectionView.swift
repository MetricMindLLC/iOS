import SwiftUI
import FirebaseAuth

struct MembershipSelectionView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var selectedMembershipType: MembershipType = .coach
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                
                Text("Choose Your Role")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Select how you'll be using Coach Caddie")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Membership Options
            VStack(spacing: 16) {
                ForEach(MembershipType.allCases, id: \.self) { membershipType in
                    MembershipOptionCard(
                        membershipType: membershipType,
                        isSelected: selectedMembershipType == membershipType
                    ) {
                        selectedMembershipType = membershipType
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Error Message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            // Continue Button
            Button(action: saveMembershipType) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(isLoading ? "Setting up..." : "Continue")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 0.05, green: 0.15, blue: 0.35))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading)
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func saveMembershipType() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.updateMembershipType(selectedMembershipType)
                await MainActor.run {
                    isLoading = false
                    // The auth manager will handle navigation
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct MembershipOptionCard: View {
    let membershipType: MembershipType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: iconForMembershipType(membershipType))
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : Color(red: 0.05, green: 0.15, blue: 0.35))
                    .frame(width: 30)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(membershipType.displayName)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(membershipType.description)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(red: 0.05, green: 0.15, blue: 0.35) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(red: 0.05, green: 0.15, blue: 0.35) : Color(.systemGray4),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconForMembershipType(_ type: MembershipType) -> String {
        switch type {
        case .coach: return "whistle.fill"
        case .parent: return "person.2.fill"
        case .viewer: return "eye.fill"
        }
    }
}

#Preview {
    MembershipSelectionView()
        .environmentObject(FirebaseAuthManager())
}