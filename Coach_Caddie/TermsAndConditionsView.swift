import SwiftUI

// MARK: - Enhanced Terms and Conditions View with COPPA Compliance
struct TermsAndConditionsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Service & Privacy Policy")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    TermsSection(
                        title: "1. Acceptance of Terms",
                        content: "By using Coach Caddie, you agree to these terms. The app helps soccer coaches manage teams, track stats, and communicate with players under the coach's authority as team manager."
                    )
                    
                    TermsSection(
                        title: "2. COPPA Compliance & Child Privacy",
                        content: """
                        Coach Caddie is designed as a team management tool for coaches. When coaches use our app to manage teams with players under 13:
                        
                        • Coaches act under their authority as team managers, not as commercial data collectors
                        • We collect only essential team management information (names, positions, basic stats)
                        • No personal profiles, detailed tracking, or commercial use of child data
                        • Automatic data deletion after 180 days of team inactivity
                        • Parents can contact coaches directly for data access, correction, or removal
                        • Coaches are responsible for parent notification and appropriate data handling
                        • No dates of birth, ages, or unnecessary personal information collected
                        
                        This approach aligns with industry standards for youth sports team management applications.
                        """
                    )
                    
                    TermsSection(
                        title: "3. Privacy Protection & Data Minimization",
                        content: """
                        We protect your data and players' information through privacy-first design:
                        
                        • All data encrypted and stored securely
                        • Used only for app functionality and team management
                        • No selling or sharing of personal information
                        • Minimal data collection philosophy
                        • Role-based access controls
                        • No public sharing capabilities
                        • Regular automatic data deletion
                        """
                    )
                    
                    TermsSection(
                        title: "4. Coach Responsibilities",
                        content: """
                        Coaches using Coach Caddie agree to:
                        
                        • Notify parents about digital team management tools
                        • Use appropriate judgment when inputting player information
                        • Communicate with parents about team management activities
                        • Respect player and family privacy
                        • Only collect information necessary for team management
                        • Ensure parents are aware of digital team organization
                        • Provide parents with contact information for questions
                        • Respect parent requests for alternative management methods
                        """
                    )
                    
                    TermsSection(
                        title: "5. Data Usage & Retention",
                        content: """
                        We collect team info, player stats, and usage data to improve the app:
                        
                        • Player names and jersey numbers only
                        • Parent contact information for team communication
                        • Basic team statistics (goals, assists, saves, shots)
                        • Emergency contact information for safety
                        • No dates of birth, ages, or detailed personal profiles
                        • Automatic deletion after 180 days of team inactivity
                        • Parents can control their child's information and delete it anytime
                        """
                    )
                    
                    TermsSection(
                        title: "6. Parent Rights",
                        content: """
                        Parents have the right to:
                        
                        • Contact the coach to view their child's team information
                        • Request updates, corrections, or complete data removal
                        • Ask questions about team data management
                        • Request traditional (non-digital) team management if preferred
                        • Understand how their child's information is being used
                        • Receive clear notification about digital team tools
                        """
                    )
                    
                    TermsSection(
                        title: "7. Subscription Terms",
                        content: "Premium features require subscription. Auto-renewal can be cancelled anytime through your device settings. Free trial converts to paid unless cancelled before trial period ends."
                    )
                    
                    VStack(spacing: 12) {
                        Text("Contact Us")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("CoachCaddie@metric-mind.com")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Text("For team-specific questions, contact your coach directly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.top, 20)
                    
                    Text("Last Updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Terms & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct TermsSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 12)
    }
}
