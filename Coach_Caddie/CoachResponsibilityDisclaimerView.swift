import SwiftUI

// MARK: - Coach Responsibility Disclaimer View
struct CoachResponsibilityDisclaimerView: View {
    @Environment(\.presentationMode) var presentationMode
    let onAcknowledge: () -> Void
    
    @State private var hasReadDisclaimer = false
    @State private var acknowledgesCOPPA = false
    @State private var acknowledgesParentNotification = false
    @State private var acknowledgesDataResponsibility = false
    @State private var scrollPosition: CGFloat = 0
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Disclaimer Content
                disclaimerContentSection
                
                // Acknowledgment Checkboxes
                acknowledgmentSection
                
                // Action Buttons
                actionButtonsSection
            }
            .navigationTitle("Coach Responsibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Responsibility Acknowledged", isPresented: $showingConfirmation) {
                Button("Continue") {
                    onAcknowledge()
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("You have acknowledged your responsibility for COPPA compliance and appropriate team data management.")
            }
        }
    }
    
    // MARK: - View Sections
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.shield.checkmark.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Coach Data Responsibility")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Please review and acknowledge your responsibilities for team data management and COPPA compliance")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var disclaimerContentSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DisclaimerSection(
                    title: "Team Management Authority",
                    content: """
                    As a team coach, you have the authority to manage player information for legitimate team management purposes. This includes organizing rosters, tracking basic statistics, and facilitating team communication.
                    """,
                    icon: "person.3.fill"
                )
                
                DisclaimerSection(
                    title: "COPPA Compliance Requirements",
                    content: """
                    You understand that the Children's Online Privacy Protection Act (COPPA) requires special protections for children under 13. Coach Caddie uses an implied consent model where you manage team data under your authority as coach, not as a commercial data collector.
                    
                    You are responsible for:
                    • Understanding COPPA requirements
                    • Using appropriate judgment in data collection
                    • Ensuring data is used only for team management
                    • Obtaining additional consent if needed for activities beyond basic team management
                    """,
                    icon: "checkmark.shield.fill"
                )
                
                DisclaimerSection(
                    title: "Parent Notification Requirement",
                    content: """
                    You must notify parents about your use of digital team management tools. This includes:
                    
                    • What information is collected
                    • How it's used (team management only)
                    • Privacy protections in place
                    • How parents can contact you with questions
                    • Option for traditional management if parents prefer
                    
                    Coach Caddie provides tools to help you create appropriate parent notifications.
                    """,
                    icon: "envelope.fill"
                )
                
                DisclaimerSection(
                    title: "Data Protection Responsibilities",
                    content: """
                    You agree to:
                    
                    • Collect only information necessary for team management
                    • Use data solely for team purposes (no commercial use)
                    • Respect privacy and handle data appropriately
                    • Respond to parent questions and requests promptly
                    • Allow data deletion upon request
                    • Maintain confidentiality of player information
                    • Report any data issues to support@coachcaddie.com
                    """,
                    icon: "lock.shield.fill"
                )
                
                DisclaimerSection(
                    title: "Built-in Privacy Protections",
                    content: """
                    Coach Caddie is designed with privacy-first principles:
                    
                    • No dates of birth or age collection
                    • No photo/video uploads
                    • Minimal data collection (names, positions, basic stats)
                    • Automatic data deletion after 180 days of inactivity
                    • No commercial use or third-party sharing
                    • Secure, encrypted storage
                    • Role-based access controls
                    """,
                    icon: "checkmark.circle.fill"
                )
            }
            .padding()
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ScrollPositionKey.self,
                    value: proxy.frame(in: .named("scroll")).minY
                )
            }
        )
        .onPreferenceChange(ScrollPositionKey.self) { value in
            scrollPosition = value
            // Consider disclaimer "read" if user has scrolled to bottom
            if value <= -200 { // Adjust this value based on content height
                hasReadDisclaimer = true
            }
        }
        .coordinateSpace(name: "scroll")
    }
    
    private var acknowledgmentSection: some View {
        VStack(spacing: 16) {
            Divider()
            
            VStack(spacing: 12) {
                Text("Required Acknowledgments")
                    .font(.headline)
                    .fontWeight(.bold)
                
                AcknowledgmentCheckbox(
                    text: "I have read and understand the coach responsibilities above",
                    isChecked: $hasReadDisclaimer,
                    isRequired: true
                )
                
                AcknowledgmentCheckbox(
                    text: "I understand COPPA requirements and will ensure compliance",
                    isChecked: $acknowledgesCOPPA,
                    isRequired: true
                )
                
                AcknowledgmentCheckbox(
                    text: "I will notify parents about digital team management tools",
                    isChecked: $acknowledgesParentNotification,
                    isRequired: true
                )
                
                AcknowledgmentCheckbox(
                    text: "I accept responsibility for appropriate team data handling",
                    isChecked: $acknowledgesDataResponsibility,
                    isRequired: true
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingConfirmation = true
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Acknowledge Responsibility")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canAcknowledge ? Color.green : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!canAcknowledge)
            
            if !canAcknowledge {
                Text("Please read the disclaimer and check all acknowledgments")
                    .foregroundColor(.orange)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Computed Properties
    private var canAcknowledge: Bool {
        return hasReadDisclaimer && acknowledgesCOPPA && acknowledgesParentNotification && acknowledgesDataResponsibility
    }
}

// MARK: - Disclaimer Section Component
struct DisclaimerSection: View {
    let title: String
    let content: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Acknowledgment Checkbox Component
struct AcknowledgmentCheckbox: View {
    let text: String
    @Binding var isChecked: Bool
    let isRequired: Bool
    
    var body: some View {
        Button(action: { isChecked.toggle() }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? .green : .gray)
                    .font(.title3)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 4) {
                        Text(text)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                        
                        if isRequired {
                            Text("*")
                                .foregroundColor(.red)
                                .fontWeight(.bold)
                                .padding(.top, -2)
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Scroll Position Preference Key
struct ScrollPositionKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
