import SwiftUI
import FirebaseAuth

// MARK: - Privacy Disclosure Text
struct PrivacyDisclosureText {
    static let coachDisclaimer = """
    COACH DATA RESPONSIBILITY AGREEMENT
    
    By creating and managing teams in Coach Caddie, you acknowledge and agree that:
    
    • You are responsible for ensuring compliance with all applicable privacy laws, including COPPA (Children's Online Privacy Protection Act) if applicable.
    
    • You will only collect and store player information with proper parental consent for players under 13 years of age.
    
    • You understand that Coach Caddie is a coaching tool and does not collect, store, or share personal information for commercial purposes.
    
    • All player data will be automatically deleted after 90 days of team inactivity unless otherwise specified.
    
    • You are responsible for obtaining necessary permissions before sharing team information or photos.
    
    • Coach Caddie is designed for team management purposes only and places full responsibility for privacy compliance on the team coach/administrator.
    
    By continuing, you accept full responsibility for proper data handling and privacy compliance for your team.
    """
    
    static let parentNotice = """
    NOTICE TO PARENTS/GUARDIANS
    
    Your child's coach has invited them to join a team managed through Coach Caddie. This notice explains how your child's information will be used:
    
    INFORMATION COLLECTED:
    • Player name and jersey number
    • Your contact information (email, phone)
    • Emergency contact information
    • Basic team participation and statistics
    
    HOW INFORMATION IS USED:
    • Team communication and coordination
    • Emergency contact purposes
    • Tracking participation and performance
    • Organizing games and practices
    
    DATA PROTECTION:
    • Information is private to team members only
    • No sharing with third parties
    • Automatic deletion after 90 days of team inactivity
    • You can request data deletion at any time
    
    YOUR RIGHTS:
    • View all information collected about your child
    • Request corrections or updates
    • Request complete data deletion
    • Control photo sharing permissions
    
    If you have questions about your child's data, please contact the team coach or email CoachCaddie@metric-mind.com for privacy support.
    """
}

// MARK: - COPPA Compliant Team Settings View
struct COPPATeamSettingsView: View {
    @Binding var team: Team
    @EnvironmentObject var teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingDataDeletionAlert = false
    @State private var showingConsentFormGenerator = false
    @State private var showingPrivacyDisclosure = false
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
                coppaComplianceSection
                dataRetentionSection
                consentManagementSection
            }
            .navigationTitle("Privacy & Compliance")
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
            .sheet(isPresented: $showingConsentFormGenerator) {
                ConsentFormGeneratorView(team: team, teamManager: teamManager)
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
                Toggle("Allow public roster viewing", isOn: .constant(false))
                    .disabled(true)
            }
            .foregroundColor(.secondary)
            
            HStack {
                Toggle("Allow public statistics", isOn: .constant(false))
                    .disabled(true)
            }
            .foregroundColor(.secondary)
            
            HStack {
                Toggle("Allow public photos", isOn: .constant(false))
                    .disabled(true)
            }
            .foregroundColor(.secondary)
            
        } header: {
            Text("Privacy Settings")
        } footer: {
            Text("Public sharing is disabled to ensure COPPA compliance. All team information remains private to team members only.")
        }
    }
    
    private var coppaComplianceSection: some View {
        Section {
            HStack {
                Image(systemName: currentPrivacySettings.coppaComplianceAcknowledged ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(currentPrivacySettings.coppaComplianceAcknowledged ? .green : .orange)
                
                VStack(alignment: .leading) {
                    Text("COPPA Compliance Acknowledged")
                        .font(.subheadline)
                    if let date = currentPrivacySettings.coppaAcknowledgmentDate {
                        Text("Acknowledged: \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !currentPrivacySettings.coppaComplianceAcknowledged {
                    Button("Acknowledge") {
                        acknowledgeCompliance()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            Button("View Privacy Disclosure") {
                showingPrivacyDisclosure = true
            }
            .foregroundColor(.blue)
            
        } header: {
            Text("COPPA Compliance")
        } footer: {
            Text("As team coach, you acknowledge responsibility for obtaining proper parental consent and complying with applicable privacy laws.")
        }
    }
    
    private var dataRetentionSection: some View {
        Section {
            HStack {
                Text("Data Retention Period")
                Spacer()
                Text("\(currentPrivacySettings.dataRetentionPeriod) days")
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
            
            Button("Extend Data Retention") {
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
    
    private var consentManagementSection: some View {
        Section {
            let playersNeedingConsent = team.players.filter { !$0.parentInfo.dataCollectionConsent }
            
            HStack {
                Text("Players with Consent")
                Spacer()
                Text("\(team.players.count - playersNeedingConsent.count) / \(team.players.count)")
                    .foregroundColor(playersNeedingConsent.isEmpty ? .green : .orange)
            }
            
            if !playersNeedingConsent.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Players needing consent:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(playersNeedingConsent, id: \.id) { player in
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(player.name)
                                .font(.caption)
                        }
                    }
                }
            }
            
            Button("Generate Consent Forms") {
                showingConsentFormGenerator = true
            }
            .foregroundColor(.blue)
            
        } header: {
            Text("Parental Consent Management")
        } footer: {
            Text("Track which players have provided proper parental consent for data collection.")
        }
    }
    
    private func acknowledgeCompliance() {
        currentPrivacySettings.coppaComplianceAcknowledged = true
        currentPrivacySettings.coppaAcknowledgmentDate = Date()
        currentPrivacySettings.coachDataResponsibility = true
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

// MARK: - Consent Form Generator View
struct ConsentFormGeneratorView: View {
    let team: Team
    let teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPlayers: Set<UUID> = []
    @State private var includeAllPlayers = true
    @State private var coachName = ""
    
    var playersNeedingConsent: [Player] {
        team.players.filter { !$0.parentInfo.dataCollectionConsent }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Generate Consent Forms")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Create printable consent forms for parents to sign")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Forms
                Form {
                    Section {
                        TextField("Coach Name", text: $coachName)
                    } header: {
                        Text("Coach Information")
                    } footer: {
                        Text("This name will appear on the consent forms")
                    }
                    
                    Section {
                        Toggle("Include all players needing consent", isOn: $includeAllPlayers)
                        
                        if !includeAllPlayers {
                            ForEach(playersNeedingConsent, id: \.id) { player in
                                HStack {
                                    Button(action: {
                                        if selectedPlayers.contains(player.id) {
                                            selectedPlayers.remove(player.id)
                                        } else {
                                            selectedPlayers.insert(player.id)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: selectedPlayers.contains(player.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedPlayers.contains(player.id) ? .blue : .gray)
                                            Text(player.name)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                    } header: {
                        Text("Select Players (\(playersNeedingConsent.count) need consent)")
                    }
                }
                
                // Generate Button
                Button(action: generateForms) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Generate & Share Forms")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(coachName.isEmpty || playersNeedingConsent.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(coachName.isEmpty || playersNeedingConsent.isEmpty)
                
                if playersNeedingConsent.isEmpty {
                    Text("All players have consent on file!")
                        .foregroundColor(.green)
                        .font(.caption)
                } else if coachName.isEmpty {
                    Text("Please enter coach name to generate forms")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                Spacer()
            }
            .navigationTitle("Consent Forms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Pre-fill coach name if available
                if let currentUser = Auth.auth().currentUser,
                   let displayName = currentUser.displayName,
                   !displayName.isEmpty {
                    coachName = displayName
                }
            }
        }
    }
    
    private func generateForms() {
        let playersToInclude = includeAllPlayers ? playersNeedingConsent : 
                              playersNeedingConsent.filter { selectedPlayers.contains($0.id) }
        
        var formsText = ""
        
        for (index, player) in playersToInclude.enumerated() {
            let consentForm = COPPAComplianceManager.shared.getParentalConsentFormText(
                teamName: team.name,
                coachName: coachName
            )
            
            formsText += "CONSENT FORM FOR: \(player.name.uppercased())\n"
            formsText += String(repeating: "=", count: 50) + "\n\n"
            formsText += consentForm
            
            // Add page break between forms (except for last one)
            if index < playersToInclude.count - 1 {
                formsText += "\n\n" + String(repeating: "-", count: 50) + "\n"
                formsText += "PAGE BREAK - NEXT PLAYER\n"
                formsText += String(repeating: "-", count: 50) + "\n\n"
            }
        }
        
        // Share the forms
        let activityVC = UIActivityViewController(
            activityItems: [formsText],
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = UIApplication.shared.windows.first
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            topController.present(activityVC, animated: true)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Privacy Disclosure View
struct PrivacyDisclosureView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy & Data Protection")
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
                            • Player names and jersey numbers
                            • Parent/guardian contact information
                            • Emergency contact details
                            • Team participation and statistics
                            • Coach notes (private to coaches)
                            
                            We do NOT collect:
                            • Dates of birth or ages
                            • Social security numbers
                            • Financial information
                            • Unnecessary personal details
                            """,
                            icon: "list.clipboard"
                        )
                        
                        DisclosureSection(
                            title: "How We Protect Data",
                            content: """
                            • All data stored securely with encryption
                            • No sharing with third parties
                            • Automatic deletion after 90 days of inactivity
                            • Role-based access controls
                            • No public sharing without explicit consent
                            • Privacy-first design approach
                            """,
                            icon: "lock.shield"
                        )
                        
                        DisclosureSection(
                            title: "Your Rights",
                            content: """
                            • Request data deletion at any time
                            • Control what information is visible
                            • Modify consent preferences
                            • Access all stored information
                            • Contact support for privacy questions
                            • Withdraw consent and remove data
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