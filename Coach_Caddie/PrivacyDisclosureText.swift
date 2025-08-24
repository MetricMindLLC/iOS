import SwiftUI
import FirebaseAuth

// MARK: - Privacy Disclosure Text
struct PrivacyDisclosureText {
    static let coachDisclaimer = """
    COACH DATA RESPONSIBILITY AGREEMENT
    
    By creating and managing teams in Coach Caddie, you acknowledge and agree that:
    
    - You have the authority to manage team information for your players
    
    - You are responsible for ensuring proper communication with parents/guardians about team management activities
    
    - Coach Caddie is designed as a team management tool where coaches input and manage team data
    
    - All player data is limited to essential team management information (names, positions, contact info)
    
    - No sensitive personal information (dates of birth, ages, etc.) is collected
    
    - Team data will be automatically deleted after 180 days of inactivity unless otherwise specified
    
    - You are responsible for team communication and ensuring parents are aware of team management activities
    
    - All data remains private to team members only - no public sharing or commercial use
    
    By continuing, you accept responsibility for appropriate team data management and parent communication.
    """
    
    static let parentNotice = """
    TEAM MANAGEMENT NOTICE FOR PARENTS
    
    Your child's coach is using Coach Caddie to manage team activities. Here's what you should know:
    
    INFORMATION MANAGED:
    - Player names and jersey numbers
    - Parent contact information (for team communication)
    - Emergency contact information
    - Team participation and game statistics
    - Practice and game scheduling
    
    HOW INFORMATION IS USED:
    - Team communication and coordination
    - Emergency contact purposes
    - Tracking participation and performance
    - Organizing games and practices
    - Basic team statistics
    
    PRIVACY PROTECTION:
    - Information is private to team members only
    - No sharing with third parties or commercial use
    - No sensitive personal data collected (no birth dates, ages, etc.)
    - Automatic deletion after 180 days of team inactivity
    - You can request data removal at any time
    
    YOUR RIGHTS:
    - Contact the coach to view your child's information
    - Request updates or corrections
    - Request complete data removal
    - Ask questions about team data management
    
    This is a standard team management tool used by coaches. If you have concerns about your child's participation in digital team management, please discuss with your coach.
    """
    
    
    
    // MARK: - COPPA Compliant Team Settings View
    struct COPPATeamSettingsView: View {
        @Binding var team: Team
        @EnvironmentObject var teamManager: TeamManager
        @Environment(\.presentationMode) var presentationMode
        
        @State private var showingDataDeletionAlert = false
        @State private var showingPrivacyDisclosure = false
        @State private var showingParentNoticeGenerator = false
        @State private var currentPrivacySettings: TeamPrivacySettings
        
        init(team: Binding<Team>) {
            self._team = team
            self._currentPrivacySettings = State(initialValue: team.wrappedValue.privacySettings)
        }
        
        var body: some View {
            NavigationView {
                Form {
                    teamInfoSection
                    privacySettingsSection
                    coachResponsibilitySection
                    dataRetentionSection
                    parentCommunicationSection
                }
                .navigationTitle("Privacy & Team Management")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveSettings()
                        }
                    }
                }
                .alert("Data Deletion Warning", isPresented: $showingDataDeletionAlert) {
                    Button("Keep Data") {
                        team.updateActivityTimestamp()
                        teamManager.updateTeam(team)
                    }
                    Button("Delete Team", role: .destructive) {
                        teamManager.deleteTeam(team)
                        presentationMode.wrappedValue.dismiss()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This team will be automatically deleted in \(COPPAComplianceManager.shared.daysUntilDeletion(team: team)) days due to inactivity. Would you like to keep the data or delete it now?")
                }
                .sheet(isPresented: $showingParentNoticeGenerator) {
                    ParentNoticeGeneratorView(team: team)
                }
                .sheet(isPresented: $showingPrivacyDisclosure) {
                    PrivacyDisclosureView()
                }
                .onAppear {
                    checkDataRetention()
                }
            }
        }
        
        private var teamInfoSection: some View {
            Section {
                HStack {
                    Text("Team Name")
                    Spacer()
                    Text(team.name)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Players")
                    Spacer()
                    Text("\(team.players.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Last Activity")
                    Spacer()
                    Text(currentPrivacySettings.lastActivityDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Team Information")
            }
        }
        
        private var privacySettingsSection: some View {
            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Private team data only")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No sensitive personal data collected")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Automatic data deletion after 180 days")
                    Spacer()
                }
                
            } header: {
                Text("Privacy Protections")
            } footer: {
                Text("Coach Caddie uses privacy-first design. No public sharing, no commercial use, and minimal data collection.")
            }
        }
        
        private var coachResponsibilitySection: some View {
            Section {
                HStack {
                    Image(systemName: currentPrivacySettings.coachDataResponsibility ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(currentPrivacySettings.coachDataResponsibility ? .green : .orange)
                    
                    VStack(alignment: .leading) {
                        Text("Coach Responsibility Acknowledged")
                            .font(.subheadline)
                        if let date = currentPrivacySettings.coppaAcknowledgmentDate {
                            Text("Acknowledged: \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if !currentPrivacySettings.coachDataResponsibility {
                        Button("Acknowledge") {
                            acknowledgeResponsibility()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                Button("View Full Privacy Policy") {
                    showingPrivacyDisclosure = true
                }
                .foregroundColor(.blue)
                
            } header: {
                Text("Coach Responsibility")
            } footer: {
                Text("As team coach, you acknowledge responsibility for appropriate team data management and parent communication.")
            }
        }
        
        private var dataRetentionSection: some View {
            Section {
                HStack {
                    Text("Data Retention Period")
                    Spacer()
                    Text("\(currentPrivacySettings.dataRetentionPeriod) days of inactivity")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Days Until Auto-Deletion")
                    Spacer()
                    let daysLeft = COPPAComplianceManager.shared.daysUntilDeletion(team: team)
                    Text("\(daysLeft)")
                        .foregroundColor(daysLeft <= 30 ? .red : .secondary)
                }
                
                if COPPAComplianceManager.shared.shouldShowDataDeletionWarning(team: team) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Data will be automatically deleted soon due to inactivity")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Button("Reset Activity Timer") {
                    team.updateActivityTimestamp()
                    teamManager.updateTeam(team)
                    currentPrivacySettings = team.privacySettings // Refresh the display
                }
                .foregroundColor(.blue)
                
            } header: {
                Text("Data Retention")
            } footer: {
                Text("Team data is automatically deleted after \(currentPrivacySettings.dataRetentionPeriod) days of inactivity to protect player privacy.")
            }
        }
        
        private var parentCommunicationSection: some View {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Keep parents informed about team management activities")
                        .font(.subheadline)
                    
                    Text("• Share team management notices with parents\n• Ensure parents know about digital team organization\n• Provide contact information for questions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("Generate Parent Notice") {
                    showingParentNoticeGenerator = true
                }
                .foregroundColor(.blue)
                
            } header: {
                Text("Parent Communication")
            } footer: {
                Text("Good communication helps parents understand how their child's team is being managed.")
            }
        }
        
        private func acknowledgeResponsibility() {
            currentPrivacySettings.coachDataResponsibility = true
            currentPrivacySettings.coppaAcknowledgmentDate = Date()
        }
        
        private func saveSettings() {
            // Update the team's privacy settings
            team.privacySettings = currentPrivacySettings
            team.updateActivityTimestamp()
            teamManager.updateTeam(team)
            presentationMode.wrappedValue.dismiss()
        }
        
        private func checkDataRetention() {
            if COPPAComplianceManager.shared.shouldShowDataDeletionWarning(team: team) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingDataDeletionAlert = true
                }
            }
        }
    }
    

    struct ParentNoticeGeneratorView: View {
        let team: Team
        @Environment(\.presentationMode) var presentationMode
        @State private var coachName = ""
        @State private var coachEmail = ""
        @State private var coachPhone = ""
        @State private var includeTeamInfo = true
        @State private var includePrivacyInfo = true
        @State private var includeCOPPAInfo = true
        @State private var includeContactInfo = true
        @State private var noticeStyle: NoticeStyle = .comprehensive
        @State private var generatedNotice = ""
        @State private var showingShareSheet = false
        
        enum NoticeStyle: String, CaseIterable {
            case brief = "Brief Notice"
            case comprehensive = "Comprehensive Notice"
            case emailTemplate = "Email Template"
        }
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Form
                    Form {
                        coachInfoSection
                        noticeOptionsSection
                        previewSection
                    }
                    
                    // Generate Button
                    generateButtonSection
                }
                .navigationTitle("Parent Notice Generator")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .onAppear {
                    loadCoachInfo()
                }
                .sheet(isPresented: $showingShareSheet) {
                    ActivityShareSheet(activityItems: [generatedNotice])
                }
            }
        }
        
        // MARK: - View Sections
        private var headerSection: some View {
            VStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Generate COPPA-Compliant Parent Notice")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Create a notice to share with parents about team management")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemGray6))
        }
        
        private var coachInfoSection: some View {
            Section {
                TextField("Coach Name", text: $coachName)
                TextField("Coach Email", text: $coachEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                TextField("Coach Phone (Optional)", text: $coachPhone)
                    .keyboardType(.phonePad)
            } header: {
                Text("Coach Contact Information")
            } footer: {
                Text("This information will be included in the parent notice for questions and concerns.")
            }
        }
        
        private var noticeOptionsSection: some View {
            Section {
                Picker("Notice Style", selection: $noticeStyle) {
                    ForEach(NoticeStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Toggle("Include Team Information", isOn: $includeTeamInfo)
                Toggle("Include Privacy Details", isOn: $includePrivacyInfo)
                Toggle("Include COPPA Compliance Info", isOn: $includeCOPPAInfo)
                Toggle("Include Coach Contact Info", isOn: $includeContactInfo)
                
            } header: {
                Text("Notice Content Options")
            } footer: {
                Text("Customize what information to include in your parent notification.")
            }
        }
        
        private var previewSection: some View {
            Section {
                if !generatedNotice.isEmpty {
                    ScrollView {
                        Text(generatedNotice)
                            .font(.caption)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 200)
                    
                    Button("Share Notice") {
                        showingShareSheet = true
                    }
                    .foregroundColor(.green)
                } else {
                    Text("Generated notice will appear here")
                        .foregroundColor(.secondary)
                        .italic()
                }
                
            } header: {
                Text("Notice Preview")
            }
        }
        
        private var generateButtonSection: some View {
            VStack(spacing: 12) {
                Button(action: generateNotice) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        Text("Generate Parent Notice")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(coachName.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(coachName.isEmpty)
                
                if coachName.isEmpty {
                    Text("Please enter coach name to generate notice")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        
        // MARK: - Helper Functions
        private func loadCoachInfo() {
            // You can manually set coach info or load from your existing auth system
            // For now, we'll leave these empty for manual entry
            coachName = ""
            coachEmail = ""
        }
        
        private func generateNotice() {
            switch noticeStyle {
            case .brief:
                generatedNotice = generateBriefNotice()
            case .comprehensive:
                generatedNotice = generateComprehensiveNotice()
            case .emailTemplate:
                generatedNotice = generateEmailTemplate()
            }
        }
        
        private func generateBriefNotice() -> String {
            return """
            TEAM NOTIFICATION: \(team.name)
            
            Dear Parents,
            
            I'm using Coach Caddie for team management. This app helps me organize our team activities and track basic stats.
            
            INFORMATION MANAGED:
            • Player names and positions
            • Basic team statistics
            • Team communication
            
            PRIVACY PROTECTIONS:
            • Information used only for team management
            • No personal details collected beyond the essentials
            • Data automatically deleted after 180 days of inactivity
            
            Questions? Contact me directly.
            
            Coach \(coachName)
            \(includeContactInfo ? coachEmail : "")
            """
        }
        
        private func generateComprehensiveNotice() -> String {
            return COPPAComplianceManager.shared.getCOPPACompliantParentNotice(
                teamName: team.name,
                coachName: coachName,
                coachEmail: coachEmail,
                coachPhone: coachPhone
            )
        }
        
        private func generateEmailTemplate() -> String {
            let contactInfo = coachPhone.isEmpty ? coachEmail : "\(coachEmail) | \(coachPhone)"
            
            return """
            Subject: Team Management Notification - \(team.name)
            
            Dear \(team.name) Parents and Guardians,
            
            I hope this message finds you well. I'm writing to inform you about the digital tools I'm using to manage our team this season.
            
            TEAM MANAGEMENT TOOL:
            I am using Coach Caddie, a team management app, to help organize \(team.name)'s activities, track basic statistics, and facilitate team communication.
            
            INFORMATION COLLECTED:
            • Player names and jersey numbers
            • Parent contact information for team communication
            • Basic team statistics (goals, assists, saves, shots)
            • Emergency contact information for safety
            
            PRIVACY & SAFETY MEASURES:
            • All information is used solely for team management
            • No commercial use or third-party sharing
            • Automatic data deletion after 180 days of inactivity
            • No dates of birth, ages, or detailed personal information collected
            • Secure, encrypted storage with restricted access
            
            YOUR RIGHTS:
            • Contact me to view your child's team information
            • Request corrections or data removal at any time
            • Ask questions about data management
            • Request traditional team management if preferred
            
            COACH RESPONSIBILITY:
            I take full responsibility for appropriate data handling and am your primary contact for any questions or concerns about team management.
            
            If you have any questions or prefer alternative arrangements for your child's team participation, please don't hesitate to reach out.
            
            Thank you for your continued support of \(team.name)!
            
            Best regards,
            Coach \(coachName)
            \(includeContactInfo ? contactInfo : "")
            
            ---
            This notification ensures compliance with privacy regulations while maintaining effective team management.
            """
        }
    }

    // MARK: - Activity Share Sheet Component (ADD this new component)
    struct ActivityShareSheet: UIViewControllerRepresentable {
        let activityItems: [Any]
        @Environment(\.presentationMode) var presentationMode
        
        func makeUIViewController(context: Context) -> UIActivityViewController {
            let controller = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            
            controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
            
            return controller
        }
        
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }
    
    // MARK: - Privacy Disclosure View
    struct PrivacyDisclosureView: View {
        @Environment(\.presentationMode) var presentationMode
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Privacy & Team Management")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.bottom)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            DisclosureSection(
                                title: "Coach Responsibility",
                                content: PrivacyDisclosureText.coachDisclaimer,
                                icon: "person.badge.shield.checkmark"
                            )
                            
                            DisclosureSection(
                                title: "Parent Information",
                                content: PrivacyDisclosureText.parentNotice,
                                icon: "hand.raised.fill"
                            )
                            
                            DisclosureSection(
                                title: "Data We Collect",
                                content: """
                            ESSENTIAL TEAM MANAGEMENT DATA ONLY:
                            • Player names and jersey numbers
                            • Parent/guardian contact information
                            • Emergency contact details
                            • Team participation and basic statistics
                            • Coach notes (private to coaches)
                            
                            WE DO NOT COLLECT:
                            • Dates of birth or ages
                            • Social security numbers
                            • Financial information
                            • Unnecessary personal details
                            """,
                                icon: "list.clipboard"
                            )
                            
                            DisclosureSection(
                                title: "Privacy Protection",
                                content: """
                            • Privacy-first design approach
                            • All data encrypted and secure
                            • No sharing with third parties
                            • No commercial use of data
                            • Automatic deletion after 180 days of inactivity
                            • Role-based access controls
                            • No public sharing capabilities
                            • Minimal data collection philosophy
                            """,
                                icon: "lock.shield"
                            )
                            
                            DisclosureSection(
                                title: "Implied Consent Model",
                                content: """
                            Coach Caddie uses an implied consent model similar to other sports team management apps:
                            
                            • Coaches input team data as part of their team management authority
                            • Parents are informed about digital team management
                            • Only essential team management data is collected
                            • No sensitive personal information is required
                            • Data can be removed upon request
                            • Standard practice in youth sports management
                            """,
                                icon: "checkmark.shield"
                            )
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                }
                .navigationTitle("Privacy Policy")
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
    
    // MARK: - Disclosure Section Component
    struct DisclosureSection: View {
        let title: String
        let content: String
        let icon: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text(content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}
