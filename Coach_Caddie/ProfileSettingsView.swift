import SwiftUI
import FirebaseAuth
import UniformTypeIdentifiers

// MARK: - CSV Share Item
class CSVShareItem: NSObject, UIActivityItemSource {
    let data: Data
    let filename: String
    
    init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return data
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return data
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return filename
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return UTType.commaSeparatedText.identifier
    }
}

// MARK: - Import Result
struct ImportResult {
    let success: Bool
    let teamsImported: Int
    let playersImported: Int
    let message: String
}

// MARK: - Import Options View
struct ImportOptionsView: View {
    let teamManager: TeamManager
    @Binding var showingImportPicker: Bool
    let onImportResult: (ImportResult) -> Void
    let onModeSelected: (ImportMode, UUID?) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTeamId: UUID?
    @State private var importMode: ImportMode = .completeTeams
    
    enum ImportMode: String, CaseIterable {
        case completeTeams = "Complete Teams"
        case playersOnly = "Players Only"
        
        var description: String {
            switch self {
            case .completeTeams:
                return "Import entire teams with players, games, and practices"
            case .playersOnly:
                return "Import players to an existing team (ignores team names in CSV)"
            }
        }
    }
    
    var selectedTeam: Team? {
        guard let teamId = selectedTeamId else { return nil }
        return teamManager.teams.first { $0.id == teamId }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Import Mode", selection: $importMode) {
                        ForEach(ImportMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text(importMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Import Type")
                }
                
                if importMode == .playersOnly {
                    Section {
                        if teamManager.teams.isEmpty {
                            Text("No teams available")
                                .foregroundColor(.secondary)
                        } else {
                            Picker("Select Team", selection: $selectedTeamId) {
                                Text("Choose a team").tag(Optional<UUID>.none)
                                ForEach(teamManager.teams, id: \.id) { team in
                                    Text("\(team.name) (\(team.players.count) players)").tag(Optional<UUID>.some(team.id))
                                }
                            }
                        }
                    } header: {
                        Text("Target Team")
                    } footer: {
                        Text("All players from the CSV will be added to this team, regardless of the team name in the CSV file.")
                    }
                }
                
                Section {
                    Button("Select File to Import") {
                        // Store the selected mode and team
                        onModeSelected(importMode, selectedTeamId)
                        
                        // Close current sheet first, then open file picker
                        presentationMode.wrappedValue.dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingImportPicker = true
                        }
                    }
                    .disabled(importMode == .playersOnly && selectedTeam == nil)
                } footer: {
                    Text("Select a CSV file with the correct format. Download the template to see the expected structure.")
                }
            }
            .navigationTitle("Import Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct TeamRowView: View {
    let team: Team
    
    var body: some View {
        HStack {
            Circle()
                .fill(team.primaryColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading) {
                Text(team.name)
                Text("\(team.players.count) players")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct LinkRowView: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Share Settings View
struct ShareSettingsView: View {
    @ObservedObject var teamManager: TeamManager
    @State private var joinCode = ""
    @State private var isJoining = false
    
    var body: some View {
        Form {
            joinTeamSection
            yourTeamsSection
        }
        .navigationTitle("Team Sharing")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var joinTeamSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("Enter Code", text: $joinCode)
                        .textCase(.uppercase)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                    
                    Button("Join") {
                        joinTeam()
                    }
                    .disabled(joinCode.count != 6 || isJoining)
                    .foregroundColor(joinCode.count == 6 ? Color(red: 0.13, green: 0.47, blue: 0.25) : .gray)
                }
                
                if isJoining {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Joining team...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Join Team")
        } footer: {
            Text("Enter a 6-character invite code shared by a team coach.")
        }
    }
    
    private var yourTeamsSection: some View {
        Section {
            if teamManager.teams.isEmpty {
                Text("No teams yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(teamManager.teams, id: \.id) { team in
                    NavigationLink(destination: TeamSettingsDetailView(team: team, teamManager: teamManager)) {
                        TeamRowView(team: team)
                    }
                }
            }
        } header: {
            Text("Your Teams")
        }
    }
    
    private func joinTeam() {
        isJoining = true
        
        Task {
            let success = await teamManager.joinTeamWithCode(joinCode.uppercased())
            
            await MainActor.run {
                isJoining = false
                if success {
                    joinCode = ""
                } else {
                    // Error - the teamManager should have set an error message
                }
            }
        }
    }
}

struct TeamSettingsDetailView: View {
    let team: Team
    @ObservedObject var teamManager: TeamManager
    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var showingShareCode = false
    @State private var generatedCodes: [GeneratedInvite] = []
    @State private var showCopiedFeedback = false
    @State private var teamMembers: [TeamMemberInfo] = []
    @State private var isLoadingMembers = true
    @State private var showingRevokeConfirmation = false
    @State private var memberToRevoke: TeamMemberInfo?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            teamInfoSection
            
            if isUserTeamCoach {
                memberManagementSection
                inviteManagementSection
            } else {
                // Show read-only info for non-coaches
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("Only team coaches can manage invites and members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            deleteSection
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isUserTeamCoach {
                loadTeamMembers()
            }
        }
        .sheet(isPresented: $showingShareCode) {
            TeamInviteGeneratorView(
                team: team,
                teamManager: teamManager,
                onInviteGenerated: { invite in
                    generatedCodes.append(invite)
                }
            )
        }
        .alert("Revoke Access?", isPresented: $showingRevokeConfirmation) {
            Button("Cancel", role: .cancel) {
                memberToRevoke = nil
            }
            Button("Revoke", role: .destructive) {
                if let member = memberToRevoke {
                    revokeAccess(for: member)
                }
            }
        } message: {
            if let member = memberToRevoke {
                Text("Are you sure you want to revoke access for \(member.displayName)? They will no longer be able to access \(team.name).")
            }
        }
    }
    
    // MARK: - Team Member Management Section (NEW)
    private var memberManagementSection: some View {
        Section {
            if isLoadingMembers {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading team members...")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if teamMembers.isEmpty {
                Text("No invited members yet")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(teamMembers) { member in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.displayName)
                                .font(.headline)
                            
                            HStack {
                                Text(member.accessLevel.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(accessLevelColor(member.accessLevel))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                
                                Text("Joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(member.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Don't allow revoking the team creator
                        if member.userId != Auth.auth().currentUser?.uid {
                            Button("Revoke") {
                                memberToRevoke = member
                                showingRevokeConfirmation = true
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            HStack {
                Text("Team Members")
                Spacer()
                if !isLoadingMembers {
                    Button("Refresh") {
                        loadTeamMembers()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        } footer: {
            if !teamMembers.isEmpty {
                Text("Team members can access the team based on their assigned role. You cannot revoke your own access.")
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
                Text("Created")
                Spacer()
                Text(team.dateCreated.formatted(date: .abbreviated, time: .omitted))
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Team Information")
        }
    }
    
    private var inviteManagementSection: some View {
        Section {
            Button(action: { showingShareCode = true }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                    Text("Generate Invite Code")
                    Spacer()
                }
            }
            
            // Display active invite codes
            if !generatedCodes.isEmpty {
                ForEach(generatedCodes) { invite in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(invite.code)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = invite.code
                                showCopiedFeedback = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopiedFeedback = false
                                }
                            }) {
                                Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                    .foregroundColor(showCopiedFeedback ? .green : Color(red: 0.13, green: 0.47, blue: 0.25))
                            }
                        }
                        
                        HStack {
                            Text("Access: \(invite.accessLevel.rawValue.capitalized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Uses: \(invite.currentUses)/\(invite.maxUses)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Generate New Invites")
        } footer: {
            Text("Generate codes for coaches (full access) or parents (limited access). Once someone joins using an invite, they'll appear in the Team Members section above.")
        }
    }

    private var isUserTeamCoach: Bool {
        guard let currentUser = Auth.auth().currentUser else {
            print("🔍 No current Firebase user")
            return false
        }
        print("🔍 TeamSettings - Current user UID: \(currentUser.uid)")
        print("🔍 TeamSettings - Team coachUID: \(team.coachUID ?? "nil")")
        print("🔍 TeamSettings - Match: \(team.coachUID == currentUser.uid)")
        return team.coachUID == currentUser.uid
    }
    
    private var deleteSection: some View {
        Section {
            Button(action: {
                teamManager.deleteTeam(team)
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Spacer()
                    Text("Delete Team")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Helper Methods (NEW)
    
    private func loadTeamMembers() {
        isLoadingMembers = true
        
        Task {
            do {
                let members = try await teamManager.firebaseManager.getTeamMembers(for: team.id.uuidString)
                await MainActor.run {
                    self.teamMembers = members.sorted { $0.joinedAt < $1.joinedAt }
                    self.isLoadingMembers = false
                }
            } catch {
                print("❌ Failed to load team members: \(error)")
                await MainActor.run {
                    self.isLoadingMembers = false
                }
            }
        }
    }
    
    private func revokeAccess(for member: TeamMemberInfo) {
        Task {
            do {
                try await teamManager.firebaseManager.revokeTeamAccess(
                    userId: member.userId,
                    teamId: team.id.uuidString
                )
                
                await MainActor.run {
                    // Remove from local list
                    teamMembers.removeAll { $0.userId == member.userId }
                    memberToRevoke = nil
                    
                    // Refresh the invite counts in case they want to generate new invites
                    // The available invite count should increase after revoking access
                }
                
                print("✅ Successfully revoked access for \(member.email)")
                
            } catch {
                print("❌ Failed to revoke access: \(error)")
                await MainActor.run {
                    memberToRevoke = nil
                }
            }
        }
    }
    
    private func accessLevelColor(_ level: AccessLevel) -> Color {
        switch level {
        case .coach: return .blue
        case .parent: return .green
        case .viewer: return .gray
        }
    }
}
// MARK: - Team Invite Generator View
struct TeamInviteGeneratorView: View {
    let team: Team
    let teamManager: TeamManager
    let onInviteGenerated: (GeneratedInvite) -> Void
    
    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var selectedAccessLevel: AccessLevel = .coach
    @State private var expirationDays = 7
    @State private var generatedCode: String?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var viewDidAppear = false
    @State private var showCopiedFeedback = false
    @Environment(\.presentationMode) var presentationMode
    
    // State for remaining invites (loaded from Firebase)
    @State private var remainingCoachInvites: Int = 0
    @State private var remainingParentInvites: Int = 0
    @State private var remainingViewerInvites: Int = 0
    @State private var isLoadingLimits = true
    
    private var remainingInvitesForSelectedLevel: Int {
        switch selectedAccessLevel {
        case .coach: return remainingCoachInvites
        case .parent: return remainingParentInvites
        case .viewer: return remainingViewerInvites
        }
    }
    
    private var canGenerateInvite: Bool {
        return remainingInvitesForSelectedLevel > 0 && !isLoadingLimits
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    if isLoadingLimits {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading invite limits...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Picker("Access Level", selection: $selectedAccessLevel) {
                            HStack {
                                Text("Coach (Full Access)")
                                Spacer()
                                if remainingCoachInvites == 0 {
                                    Text("None Left")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                } else {
                                    Text("\(remainingCoachInvites) left")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }.tag(AccessLevel.coach)
                            
                            HStack {
                                Text("Parent (Limited Access)")
                                Spacer()
                                if remainingParentInvites == 0 {
                                    Text("None Left")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                } else {
                                    Text("\(remainingParentInvites) left")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }.tag(AccessLevel.parent)
                            
                            HStack {
                                Text("Viewer (Read Only)")
                                Spacer()
                                if remainingViewerInvites == 0 {
                                    Text("None Left")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                } else {
                                    Text("\(remainingViewerInvites) left")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }.tag(AccessLevel.viewer)
                        }
                        .pickerStyle(WheelPickerStyle())
                        
                        // Show remaining invites for selected access level
                        HStack {
                            Text("Remaining Invites")
                            Spacer()
                            Text("\(remainingInvitesForSelectedLevel)")
                                .foregroundColor(remainingInvitesForSelectedLevel > 0 ? .primary : .red)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Expires In")
                            Spacer()
                            Stepper(value: $expirationDays, in: 1...30) {
                                Text("\(expirationDays) day\(expirationDays == 1 ? "" : "s")")
                            }
                        }
                    }
                } header: {
                    Text("Invite Settings")
                } footer: {
                    if !canGenerateInvite && !isLoadingLimits {
                        Text("You've reached the maximum number of \(selectedAccessLevel.rawValue) invites for your \(authManager.currentUser?.subscriptionLevel.displayName ?? "current") plan. Upgrade to generate more invites.")
                            .foregroundColor(.red)
                    } else {
                        Text("Choose the access level and expiration for this invite code.")
                    }
                }
                
                // Subscription info section
                if let user = authManager.currentUser, !isLoadingLimits {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Plan: \(user.subscriptionLevel.displayName)")
                                .font(.headline)
                            
                            HStack {
                                Text("Coach Invites:")
                                Spacer()
                                Text("\(remainingCoachInvites)/\(user.effectiveMaxCoachInvites)")
                            }
                            
                            HStack {
                                Text("Parent Invites:")
                                Spacer()
                                Text("\(remainingParentInvites)/\(user.effectiveMaxParentInvites)")
                            }
                            
                            HStack {
                                Text("Viewer Invites:")
                                Spacer()
                                Text("\(remainingViewerInvites)/\(user.effectiveMaxViewerInvites)")
                            }
                        }
                        
                        if user.subscriptionLevel == .trial || user.subscriptionLevel == .pro {
                            Button("Upgrade Plan") {
                                // Handle upgrade - you can implement this later
                                // For now, just show that it's available
                            }
                            .foregroundColor(.blue)
                        }
                    } header: {
                        Text("Plan Limits")
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if let code = generatedCode {
                    Section {
                        VStack(spacing: 16) {
                            // Code Display
                            VStack(spacing: 8) {
                                Text("Invite Code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(code)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .textSelection(.enabled)
                            }
                            
                            // Action Buttons
                            HStack(spacing: 20) {
                                Button(action: copyCode) {
                                    HStack {
                                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                        Text(showCopiedFeedback ? "Copied!" : "Copy")
                                    }
                                    .foregroundColor(showCopiedFeedback ? .green : .blue)
                                }
                                
                                Button(action: shareCode) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share")
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                            
                            // Preview Message
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Share Message Preview:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(createShareMessage(code: code))
                                    .font(.caption2)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Generated Code")
                    } footer: {
                        Text("This code can be used once and expires in \(expirationDays) day\(expirationDays == 1 ? "" : "s").")
                    }
                }
            }
            .navigationTitle("Generate Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(generatedCode == nil ? "Generate" : "Done") {
                        if generatedCode == nil {
                            generateCode()
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .disabled(isGenerating || !viewDidAppear || !canGenerateInvite)
                }
            }
            .onAppear {
                loadRemainingInvites()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewDidAppear = true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadRemainingInvites() {
        guard let user = authManager.currentUser else { return }
        
        isLoadingLimits = true
        
        Task {
            do {
                // Load remaining invites for each access level
                async let coachRemaining = teamManager.getRemainingInvites(for: team, accessLevel: .coach)
                async let parentRemaining = teamManager.getRemainingInvites(for: team, accessLevel: .parent)
                async let viewerRemaining = teamManager.getRemainingInvites(for: team, accessLevel: .viewer)
                
                let (coach, parent, viewer) = try await (coachRemaining, parentRemaining, viewerRemaining)
                
                await MainActor.run {
                    self.remainingCoachInvites = coach
                    self.remainingParentInvites = parent
                    self.remainingViewerInvites = viewer
                    self.isLoadingLimits = false
                }
                
            } catch {
                print("❌ Failed to load remaining invites: \(error)")
                await MainActor.run {
                    // Fallback to computed values if Firebase fails
                    if let user = authManager.currentUser {
                        self.remainingCoachInvites = max(0, user.effectiveMaxCoachInvites)
                        self.remainingParentInvites = max(0, user.effectiveMaxParentInvites)
                        self.remainingViewerInvites = max(0, user.effectiveMaxViewerInvites)
                    }
                    self.isLoadingLimits = false
                }
            }
        }
    }
    
    private func generateCode() {
        print("🔍 Starting generateCode process")
        isGenerating = true
        errorMessage = nil
        
        // First check if user has permission to generate codes
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "Not authenticated. Please sign in again."
            isGenerating = false
            return
        }
        
        // Check if user is team coach
        guard team.coachUID == currentUser.uid else {
            errorMessage = "Only team coaches can generate invite codes."
            isGenerating = false
            return
        }
        
        // ENFORCE SUBSCRIPTION LIMITS
        guard canGenerateInvite else {
            let planName = authManager.currentUser?.subscriptionLevel.displayName ?? "current plan"
            errorMessage = "You've reached the maximum number of \(selectedAccessLevel.rawValue) invites for your \(planName). Upgrade to generate more invites."
            isGenerating = false
            return
        }
        
        Task {
            do {
                print("🔍 Checking subscription limits before generating invite")
                
                // Double-check limits before generating (in case of race conditions)
                let currentUsage = getCurrentInviteUsage(for: selectedAccessLevel)
                let maxAllowed: Int
                switch selectedAccessLevel {
                case .coach: maxAllowed = authManager.currentUser?.effectiveMaxCoachInvites ?? 0
                case .parent: maxAllowed = authManager.currentUser?.effectiveMaxParentInvites ?? 0
                case .viewer: maxAllowed = authManager.currentUser?.effectiveMaxViewerInvites ?? 0
                }
                
                if currentUsage >= maxAllowed {
                    await MainActor.run {
                        self.errorMessage = "Subscription limit reached for \(selectedAccessLevel.rawValue) invites."
                        self.isGenerating = false
                    }
                    return
                }
                
                print("✅ Subscription limits check passed - generating invite")
                
                // Use the regular method for now (you can implement the new one later)
                if let code = await teamManager.generateInviteCode(for: team, accessLevel: selectedAccessLevel) {
                    let invite = GeneratedInvite(
                        code: code,
                        accessLevel: selectedAccessLevel,
                        maxUses: 1, // Each invite code can only be used once
                        currentUses: 0,
                        expiresAt: Calendar.current.date(byAdding: .day, value: expirationDays, to: Date()) ?? Date()
                    )
                    
                    await MainActor.run {
                        print("✅ Code generated successfully: \(code)")
                        self.generatedCode = code
                        self.onInviteGenerated(invite)
                        self.isGenerating = false
                        
                        // Reload remaining invites after successful generation
                        self.loadRemainingInvites()
                    }
                } else {
                    await MainActor.run {
                        print("❌ generateInviteCode returned nil")
                        self.errorMessage = teamManager.errorMessage ?? "Failed to generate invite code. Please try again."
                        self.isGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Exception during code generation: \(error)")
                    self.errorMessage = "Failed to generate invite code: \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func getCurrentInviteUsage(for accessLevel: AccessLevel) -> Int {
        // This method is kept for backward compatibility
        // The actual counting is now done in loadRemainingInvites()
        return 0
    }
    
    private func copyCode() {
        guard let code = generatedCode else { return }
        UIPasteboard.general.string = code
        showCopiedFeedback = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedFeedback = false
        }
    }
    
    private func createShareMessage(code: String) -> String {
        let accessDescription: String
        let accessDetails: String
        
        switch selectedAccessLevel {
        case .coach:
            accessDescription = "Coach"
            accessDetails = "full team management access"
        case .parent:
            accessDescription = "Parent"
            accessDetails = "access to view team info and edit your child's details"
        case .viewer:
            accessDescription = "Viewer"
            accessDetails = "read-only access to team information"
        }
        
        // App Store link - replace with your actual App Store URL
        let appStoreURL = "https://apps.apple.com/app/coach-caddie/id123456789"
        
        let message = """
        🏆 You've been invited to join "\(team.name)" as a \(accessDescription)!
        
        This gives you \(accessDetails).
        
        📱 To join:
        1. Download Coach Caddie: \(appStoreURL)
        2. Create your account or sign in
        3. Use invite code: \(code)
        
        If you already have Coach Caddie:
        Go to Profile → Manage Team Invites → Enter Code
        
        This code expires in \(expirationDays) day\(expirationDays == 1 ? "" : "s") and can be used once.
        
        Welcome to the team! ⚽️
        """
        
        return message
    }
    
    private func shareCode() {
        guard let code = generatedCode else { return }
        
        let message = createShareMessage(code: code)
        
        // Create the activity view controller
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = UIApplication.shared.windows.first
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Find the topmost view controller
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            topController.present(activityVC, animated: true)
        }
    }
}
// MARK: - Team Export Picker View
struct TeamExportPickerView: View {
    let teams: [Team]
    let onTeamSelected: (Team) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(teams, id: \.id) { team in
                        Button(action: {
                            onTeamSelected(team)
                        }) {
                            HStack {
                                Circle()
                                    .fill(team.primaryColor)
                                    .frame(width: 24, height: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(team.name)
                                        .foregroundColor(.primary)
                                        .font(.headline)
                                    
                                    Text("\(team.players.count) players")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Select Team to Export")
                } footer: {
                    Text("Choose which team's player data you want to export as CSV.")
                }
            }
            .navigationTitle("Export Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Main Profile Settings View
struct ProfileSettingsView: View {
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var showingImportPicker = false
    @State private var showingImportOptions = false
    @State private var showingAbout = false
    @State private var showingDeleteConfirmation = false
    @State private var teamToDelete: Team?
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var showingTeamExportPicker = false
    @State private var selectedExportTeam: Team?
    @State private var isPreparingExport = false
    @State private var isPreparingTemplate = false
    @State private var importMode: ImportOptionsView.ImportMode = .completeTeams
    @State private var targetTeamId: UUID?
    
    // NEW STATE VARIABLES FOR SUBSCRIPTION:
    @State private var showingSubscription = false
    @State private var showingTrialAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                userProfileSection
                subscriptionSection // NEW SECTION
                appSettingsSection
                defaultSettingsSection
                teamsSection
                teamSharingSection
                dataManagementSection
                aboutSection
                accountSection
            }
            .alert("Delete Team?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let team = teamToDelete {
                        teamManager.deleteTeam(team)
                    }
                }
            } message: {
                if let team = teamToDelete {
                    Text("Are you sure you want to delete \(team.name)? This action cannot be undone.")
                }
            }
            .alert("Import Complete", isPresented: $showingImportResult) {
                Button("OK") { }
            } message: {
                if let result = importResult {
                    Text(result.message)
                }
            }
            // NEW SHEET PRESENTATIONS:
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
                    .environmentObject(authManager)
            }
            .alert("Trial Ending Soon", isPresented: $showingTrialAlert) {
                Button("Upgrade Now") {
                    showingSubscription = true
                }
                Button("Later", role: .cancel) { }
            } message: {
                if let user = authManager.currentUser {
                    Text("Your trial expires in \(user.trialDaysRemaining) day\(user.trialDaysRemaining == 1 ? "" : "s"). Upgrade to continue using Coach Caddie.")
                }
            }
            .sheet(isPresented: $showingImportOptions) {
                ImportOptionsView(
                    teamManager: teamManager,
                    showingImportPicker: $showingImportPicker,
                    onImportResult: { result in
                        importResult = result
                        showingImportResult = true
                    },
                    onModeSelected: { mode, teamId in
                        importMode = mode
                        targetTeamId = teamId
                    }
                )
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.commaSeparatedText],
                onCompletion: handleCSVImport
            )
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingShareSheet, onDismiss: {
                shareItems.removeAll()
            }) {
                if !shareItems.isEmpty {
                    ShareSheet(activityItems: shareItems)
                }
            }
            .sheet(isPresented: $showingTeamExportPicker) {
                TeamExportPickerView(teams: teamManager.teams) { selectedTeam in
                    showingTeamExportPicker = false
                    exportSelectedTeam(selectedTeam)
                }
            }
            // NEW TRIAL CHECK:
            .onAppear {
                checkTrialStatus()
            }
        }
        .navigationTitle("Settings")
    }
    
    // NEW SUBSCRIPTION SECTION - FIXED:
    private var subscriptionSection: some View {
        Section {
            if let user = authManager.currentUser {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Plan")
                            .font(.headline)
                        Text(user.subscriptionLevel.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if user.subscriptionLevel == .trial {
                            Text("\(user.trialDaysRemaining) days remaining")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    // FIXED: Only show upgrade button for trial, pro, or premium users
                    // Do NOT show for sharedAccess, free (legacy), cancelled, or expired
                    if shouldShowUpgradeButton(for: user.subscriptionLevel) {
                        Button("Upgrade") {
                            showingSubscription = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                // FIXED: Show features based on membership type and subscription level
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(getFeaturesForUser(user).prefix(3), id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(feature)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        } header: {
            Text("Subscription")
        } footer: {
            // ADDED: Footer with cancellation instructions for paid users
            if let user = authManager.currentUser,
               isActivePaidSubscription(user.subscriptionLevel) {
                Text("To manage or cancel your subscription, go to Settings > [Your Name] > Subscriptions on your device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // ADDED: Helper to check if user has an active paid subscription
    private func isActivePaidSubscription(_ level: SubscriptionLevel) -> Bool {
        switch level {
        case .pro, .premium, .club:
            return true
        case .trial, .free, .sharedAccess, .cancelled, .expired:
            return false
        }
    }

    // ADDED: Helper function to determine who should see upgrade button
    private func shouldShowUpgradeButton(for subscriptionLevel: SubscriptionLevel) -> Bool {
        switch subscriptionLevel {
        case .trial:
            return true  // Trial users should be able to upgrade
        case .pro:
            return true  // Pro users can upgrade to Premium/Club
        case .premium:
            return true  // Premium users can upgrade to Club
        case .sharedAccess:
            return false // Shared access users get free access, no need to upgrade
        case .free:
            return false // Legacy free users already have everything
        case .club:
            return false // Already at highest tier
        case .cancelled, .expired:
            return true  // Allow reactivation
        }
    }

    // ADDED: Get appropriate features based on user's actual role and subscription
    private func getFeaturesForUser(_ user: User) -> [String] {
        // For shared access users, show features based on their membership type
        if user.subscriptionLevel == .sharedAccess {
            switch user.membershipType {
            case .coach:
                return [
                    "Full coaching access to shared teams",
                    "Manage players and games",
                    "View team statistics"
                ]
            case .parent:
                return [
                    "View team information",
                    "Edit your child's details",
                    "RSVP to games and practices"
                ]
            case .viewer:
                return [
                    "View team information",
                    "View games and practices",
                    "Read-only access"
                ]
            case .teamInvite:
                return [
                    "Access to invited teams",
                    "Role-based permissions",
                    "Team communication"
                ]
            case .none:
                return ["Access to shared teams"]
            }
        } else {
            // For other subscription levels, use the standard features
            return user.subscriptionLevel.features
        }
    }
    
    // NEW HELPER METHOD:
    private func checkTrialStatus() {
        guard let user = authManager.currentUser else { return }
        
        // Show alert when trial is ending (1 day left)
        if user.subscriptionLevel == .trial && user.trialDaysRemaining <= 1 {
            showingTrialAlert = true
        }
        
        // Check for expired trial
        Task {
            try? await authManager.checkTrialStatus()
        }
    }
    
    // MARK: - View Sections
    
    private var userProfileSection: some View {
        Section {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                VStack(alignment: .leading, spacing: 4) {
                    if let displayName = Auth.auth().currentUser?.displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    } else {
                        Text("Update your name")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Text(authManager.currentUser?.email ?? "Not signed in")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        } header: {
            Text("Profile")
        }
    }
    
    private var appSettingsSection: some View {
        Section {
            Toggle("Auto-save Lineups", isOn: $teamManager.appSettings.autoSaveLineups)
            
            Toggle("Haptic Feedback", isOn: $teamManager.appSettings.enableHapticFeedback)
        } header: {
            Text("App Settings")
        }
    }
    
    private var defaultSettingsSection: some View {
        Section {
            Picker("Player Sort Order", selection: $teamManager.appSettings.defaultSortOrder) {
                ForEach(AppSettings.PlayerSortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
        } header: {
            Text("Default Settings")
        }
    }
    
  private var teamsSection: some View {
        Section {
            // Team limit information
            if let currentUser = authManager.currentUser,
               currentUser.maxTeamsAllowed < 999 { // Don't show for unlimited accounts
                HStack {
                    Image(systemName: "number.circle.fill")
                        .foregroundColor(.blue)
                    Text("Teams")
                    Spacer()
                    Text("\(teamManager.teams.count)/\(currentUser.maxTeamsAllowed)")
                        .foregroundColor(teamManager.teams.count >= currentUser.maxTeamsAllowed ? .red : .secondary)
                        .fontWeight(teamManager.teams.count >= currentUser.maxTeamsAllowed ? .semibold : .regular)
                }
                .padding(.vertical, 2)
            }
            
            // Team list
            if teamManager.teams.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    Text("No teams yet")
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    // Show create team button if user can create teams
                    if teamManager.canCreateMoreTeams() {
                        Button("Create Team") {
                            // Handle team creation navigation
                            // This would need to be passed in or handled via a delegate
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            } else {
                ForEach(teamManager.teams, id: \.id) { team in
                    NavigationLink(destination: TeamSettingsDetailView(team: team, teamManager: teamManager)) {
                        TeamRowView(team: team)
                    }
                }
                .onDelete(perform: deleteTeams)
            }
            
            // Show upgrade suggestion if at limit
            if let currentUser = authManager.currentUser,
               teamManager.teams.count >= currentUser.maxTeamsAllowed,
               currentUser.maxTeamsAllowed < 999 {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade Plan")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Create more teams")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Upgrade") {
                        // Handle upgrade navigation
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Text("Your Teams")
                
                if let currentUser = authManager.currentUser,
                   currentUser.maxTeamsAllowed < 999 {
                    Spacer()
                    Text("\(teamManager.teams.count)/\(currentUser.maxTeamsAllowed)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } footer: {
            if let currentUser = authManager.currentUser {
                let planName = currentUser.subscriptionLevel.displayName
                let maxTeams = currentUser.maxTeamsAllowed
                
                if maxTeams < 999 {
                    if teamManager.teams.count >= maxTeams {
                        Text("You've reached your team limit for the \(planName) plan. Upgrade to create more teams.")
                    } else {
                        Text("Your \(planName) plan allows up to \(maxTeams) team\(maxTeams == 1 ? "" : "s").")
                    }
                } else {
                    Text("Unlimited teams on your \(planName) plan.")
                }
            }
        }
    }
    
    private var teamSharingSection: some View {
        Section {
            NavigationLink(destination: ShareSettingsView(teamManager: teamManager)) {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                    Text("Manage Team Invites")
                }
            }
        } header: {
            Text("Team Sharing")
        } footer: {
            Text("Generate invite codes to add coaches or parents to your teams.")
        }
    }
    
    private var dataManagementSection: some View {
        Section {
            Button(action: {
                handleExportAction()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(isPreparingExport ? .gray : Color(red: 0.13, green: 0.47, blue: 0.25))
                    if isPreparingExport {
                        Text("Preparing Export...")
                    } else {
                        Text("Export Teams")
                    }
                }
            }
            .disabled(teamManager.teams.isEmpty || isPreparingExport)
            
            // Only show import options to coaches
            if canImportData {
                Button(action: {
                    handleTemplateDownload()
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(isPreparingTemplate ? .gray : Color(red: 0.13, green: 0.47, blue: 0.25))
                        if isPreparingTemplate {
                            Text("Preparing Template...")
                        } else {
                            Text("Download Template")
                        }
                    }
                }
                .disabled(isPreparingTemplate)
                
                Button(action: {
                    // Add small delay to prevent sheet conflicts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingImportOptions = true
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(Color(red: 0.13, green: 0.47, blue: 0.25))
                        Text("Import Data")
                    }
                }
            }
        } header: {
            Text("Data Management")
        } footer: {
            if canImportData {
                Text("Download the template to see the correct format for importing players or teams.")
            } else {
                Text("Import functionality is only available to team coaches.")
            }
        }
    }
    
    private var aboutSection: some View {
        Section {
            Button(action: {
                if let emailURL = URL(string: "mailto:CoachCaddie@metric-mind.com?subject=Coach Caddie Support Request") {
                    if UIApplication.shared.canOpenURL(emailURL) {
                        UIApplication.shared.open(emailURL)
                    } else {
                        UIPasteboard.general.string = "CoachCaddie@metric-mind.com"
                    }
                }
            }) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                    Text("Help & Support")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "envelope")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://www.metric-mind.com/coachcaddieprivacy")!) {
                LinkRowView(icon: "shield", text: "Privacy Policy", color: Color(red: 0.05, green: 0.15, blue: 0.35))
            }
            
            Button(action: { showingAbout = true }) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.35))
                    Text("About Coach Caddie")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("About")
        } footer: {
            Text("Need help? Contact our support team at CoachCaddie@metric-mind.com")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var accountSection: some View {
        Section {
            HStack {
                Image(systemName: "calendar.circle")
                    .foregroundColor(.gray)
                Text("Member since \(authManager.currentUser?.dateJoined.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            Button(action: {
                authManager.signOutUser()
            }) {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .foregroundColor(.red)
                    Text("Sign Out")
                        .foregroundColor(.red)
                }
            }
        } header: {
            Text("Account")
        }
    }
    
    // MARK: - Helper Properties
    
    private var canImportData: Bool {
        // Only coaches with teams can import data, or coaches with the ability to create teams
        return teamManager.canCreateTeams() || hasCoachRoleInAnyTeam
    }
    
    private var hasCoachRoleInAnyTeam: Bool {
        guard let currentUser = Auth.auth().currentUser else { return false }
        return teamManager.teams.contains { team in
            team.coachUID == currentUser.uid
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleExportAction() {
        isPreparingExport = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if teamManager.teams.count == 1 {
                // If only one team, export it directly
                exportSelectedTeam(teamManager.teams.first!)
            } else if teamManager.teams.count > 1 {
                // If multiple teams, show picker
                isPreparingExport = false
                showingTeamExportPicker = true
            } else {
                // No teams to export
                isPreparingExport = false
            }
        }
    }
    
    private func handleTemplateDownload() {
        isPreparingTemplate = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            downloadTemplate()
        }
    }
    
    private func cleanCSVField(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "\"", with: "\"\"")
        if cleaned.contains(",") || cleaned.contains("\"") || cleaned.contains("\n") {
            return "\"\(cleaned)\""
        }
        return cleaned
    }
    
    private func deleteTeams(offsets: IndexSet) {
        for index in offsets {
            let team = teamManager.teams[index]
            teamToDelete = team
            showingDeleteConfirmation = true
        }
    }
    
    private func exportSelectedTeam(_ team: Team) {
        // Your existing export logic stays the same...
        DispatchQueue.main.async {
            // Create CSV export for selected team
            var csvContent = "Team Name,Player Name,Jersey Number,Positions,Age,Date of Birth,Parent Name,Parent Email,Parent Phone,Second Parent Name,Second Parent Email,Second Parent Phone,Emergency Contact,Emergency Phone,Medical Notes,Coach Notes\n"
            
            for player in team.players {

                
                // Clean up text fields to handle commas and quotes
                let cleanTeamName = self.cleanCSVField(team.name)
                let cleanPlayerName = self.cleanCSVField(player.name)
                let cleanParentName = self.cleanCSVField(player.parentInfo.parentName)
                let cleanParentEmail = self.cleanCSVField(player.parentInfo.parentEmail)
                let cleanParentPhone = self.cleanCSVField(player.parentInfo.parentPhone)
                let cleanSecondParentName = self.cleanCSVField(player.parentInfo.secondParentName)
                let cleanSecondParentEmail = self.cleanCSVField(player.parentInfo.secondParentEmail)
                let cleanSecondParentPhone = self.cleanCSVField(player.parentInfo.secondParentPhone)
                let cleanEmergencyContact = self.cleanCSVField(player.emergencyContact ?? "")
                let cleanEmergencyPhone = self.cleanCSVField(player.emergencyPhone ?? "")
                let cleanMedicalNotes = self.cleanCSVField(player.medicalNotes ?? "")
                let cleanCoachNotes = self.cleanCSVField(player.notes ?? "")
                
                csvContent += "\(cleanTeamName),\(cleanPlayerName),\(player.jerseyNumber),\(cleanParentName),\(cleanParentEmail),\(cleanParentPhone),\(cleanSecondParentName),\(cleanSecondParentEmail),\(cleanSecondParentPhone),\(cleanEmergencyContact),\(cleanEmergencyPhone),\(cleanMedicalNotes),\(cleanCoachNotes)\n"
            }
            
            // Create data with filename for sharing
            let fileName = "\(team.name.replacingOccurrences(of: " ", with: "_"))_export.csv"
            guard let csvData = csvContent.data(using: .utf8) else {
                print("Failed to create CSV data")
                self.isPreparingExport = false
                return
            }
            
            // Create a temporary item for sharing with a suggested filename
            let tempItem = CSVShareItem(data: csvData, filename: fileName)
            
            // Ensure share items are properly set before showing sheet
            self.shareItems = [tempItem]
            
            // Longer delay to ensure proper state management
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isPreparingExport = false
                
                // Double check that share items are still valid
                if !self.shareItems.isEmpty {
                    self.showingShareSheet = true
                } else {
                    print("❌ Share items were cleared before presentation")
                }
            }
        }
    }
    
    private func downloadTemplate() {
        // Your existing template logic stays the same...
        DispatchQueue.main.async {
            let csvTemplate = """
Team Name,Player Name,Jersey Number,Positions,Age,Date of Birth,Parent Name,Parent Email,Parent Phone,Second Parent Name,Second Parent Email,Second Parent Phone,Emergency Contact,Emergency Phone,Medical Notes,Coach Notes
Lightning Bolts U12,John Smith,10,MID|FWD,13,3/15/2010,Michael Smith,michael.smith@email.com,(555) 123-4567,Sarah Smith,sarah.smith@email.com,(555) 765-4321,Emergency Contact Name,(555) 999-0000,No known allergies,Great team player
Lightning Bolts U12,Emma Johnson,7,DEF,12,8/22/2011,David Johnson,david.johnson@email.com,(555) 234-5678,,,,,,,Excellent defender
Thunder Hawks U12,Alex Rodriguez,1,GK,13,5/10/2010,Carlos Rodriguez,carlos.rodriguez@email.com,(555) 345-6789,Maria Rodriguez,maria.rodriguez@email.com,(555) 987-6543,Carlos Rodriguez,(555) 345-6789,Wears contact lenses,Excellent reflexes

INSTRUCTIONS:
1. Fill in player data using the format above
2. Use | to separate multiple positions (e.g., MID|FWD)
3. Date format: M/D/YYYY (e.g., 3/15/2010)
4. Required fields: Team Name, Player Name, Jersey Number
5. All other fields are optional
6. You can import players to existing teams or create new teams
7. Delete these instruction rows before importing
"""
            
            // Create data with filename for sharing
            let fileName = "team_import_template.csv"
            guard let csvData = csvTemplate.data(using: .utf8) else {
                print("Failed to create template data")
                self.isPreparingTemplate = false
                return
            }
            
            // Create a temporary item for sharing with a suggested filename
            let tempItem = CSVShareItem(data: csvData, filename: fileName)
            
            // Ensure share items are properly set before showing sheet
            self.shareItems = [tempItem]
            
            // Longer delay to ensure proper state management
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isPreparingTemplate = false
                
                // Double check that share items are still valid
                if !self.shareItems.isEmpty {
                    self.showingShareSheet = true
                } else {
                    print("❌ Template share items were cleared before presentation")
                }
            }
        }
    }
    
    private func handleCSVImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("📁 Selected file: \(url.lastPathComponent)")
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importResult = ImportResult(
                    success: false,
                    teamsImported: 0,
                    playersImported: 0,
                    message: "Unable to access the selected file. Please try again."
                )
                showingImportResult = true
                return
            }
            
            defer {
                // Always stop accessing the resource when done
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                let csvContent = try String(contentsOf: url, encoding: .utf8)
                print("📄 Successfully read file content (\(csvContent.count) characters)")
                
                let result = processCSVImport(csvContent)
                importResult = result
                showingImportResult = true
                
            } catch {
                print("❌ Failed to read CSV file: \(error)")
                importResult = ImportResult(
                    success: false,
                    teamsImported: 0,
                    playersImported: 0,
                    message: "Failed to read CSV file: \(error.localizedDescription)"
                )
                showingImportResult = true
            }
            
        case .failure(let error):
            print("❌ File picker failed: \(error)")
            importResult = ImportResult(
                success: false,
                teamsImported: 0,
                playersImported: 0,
                message: "Import failed: \(error.localizedDescription)"
            )
            showingImportResult = true
        }
    }
    
    private func processCSVImport(_ csvContent: String) -> ImportResult {
        // Your existing CSV processing logic...
        let lines = csvContent.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            return ImportResult(
                success: false,
                teamsImported: 0,
                playersImported: 0,
                message: "CSV file appears to be empty or invalid"
            )
        }
        
        // Skip header row and instruction rows
        let dataLines = lines.dropFirst().filter { line in
            !line.isEmpty &&
            !line.hasPrefix("INSTRUCTIONS:") &&
            !line.hasPrefix("1.") &&
            !line.hasPrefix("2.") &&
            !line.hasPrefix("3.") &&
            !line.hasPrefix("4.") &&
            !line.hasPrefix("5.") &&
            !line.hasPrefix("6.") &&
            !line.hasPrefix("7.")
        }
        
        var playersImported = 0
        var teamsImported = 0
        var errors: [String] = []
        
        // Get target team for "Players Only" mode
        var targetTeam: Team?
        if importMode == .playersOnly, let teamId = targetTeamId {
            if let teamIndex = teamManager.teams.firstIndex(where: { $0.id == teamId }) {
                targetTeam = teamManager.teams[teamIndex]
            }
        }
        
        // Process each line individually and update teams immediately
        for line in dataLines {
            let fields = parseCSVLine(line)
            guard fields.count >= 3 else {
                continue
            }
            
            let csvTeamName = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let playerName = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let jerseyNumberString = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !csvTeamName.isEmpty, !playerName.isEmpty else {
                continue
            }
            guard let jerseyNumber = Int(jerseyNumberString) else {
                errors.append("Invalid jersey number for \(playerName): \(jerseyNumberString)")
                continue
            }
            
            // Determine which team to use
            let teamName: String
            let useTargetTeam: Bool
            
            if importMode == .playersOnly, let target = targetTeam {
                teamName = target.name
                useTargetTeam = true
            } else {
                teamName = csvTeamName
                useTargetTeam = false
            }
            
            // Parse positions
            let positionsString = fields.count > 3 ? fields[3] : ""
            let positions = positionsString.isEmpty ? ["MID"] : positionsString.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            // Parse date of birth (optional)
            var dateOfBirth: Date?
            if fields.count > 5 && !fields[5].isEmpty {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "M/d/yyyy"
                dateOfBirth = dateFormatter.date(from: fields[5])
            }
            
            // Create player
            var player = Player(
                name: playerName,
                jerseyNumber: jerseyNumber,
                positions: positions,
                preferredPosition: positions.first ?? "MID",
                seasonStats: PlayerStats(),
                parentInfo: ParentInfo(
                    parentName: fields.count > 6 ? fields[6] : "",
                    parentEmail: fields.count > 7 ? fields[7] : "",
                    parentPhone: fields.count > 8 ? fields[8] : "",
                    secondParentName: fields.count > 9 ? fields[9] : "",
                    secondParentEmail: fields.count > 10 ? fields[10] : "",
                    secondParentPhone: fields.count > 11 ? fields[11] : ""
                )
            )
            
            player.emergencyContact = fields.count > 12 && !fields[12].isEmpty ? fields[12] : nil
            player.emergencyPhone = fields.count > 13 && !fields[13].isEmpty ? fields[13] : nil
            player.medicalNotes = fields.count > 14 && !fields[14].isEmpty ? fields[14] : nil
            player.notes = fields.count > 15 && !fields[15].isEmpty ? fields[15] : nil
            
            // Find or create team and add player immediately
            if let existingTeamIndex = teamManager.teams.firstIndex(where: { $0.name == teamName }) {
                // Found existing team
                let existingTeam = teamManager.teams[existingTeamIndex]
                
                // Check for duplicate jersey numbers ONLY in this specific team
                let duplicateInThisTeam = existingTeam.players.contains { $0.jerseyNumber == jerseyNumber }
                if duplicateInThisTeam {
                    errors.append("Duplicate jersey number \(jerseyNumber) in team \(teamName)")
                    continue
                }
                
                teamManager.teams[existingTeamIndex].players.append(player)
                
                // Force update the team
                teamManager.updateTeam(teamManager.teams[existingTeamIndex])
                playersImported += 1
                
            } else if !useTargetTeam {
                // Create new team (only in Complete Teams mode)
                var newTeam = Team(
                    name: teamName,
                    format: .elevenVEleven,
                    defaultFormation: .formation442,
                    primaryColor: .blue,
                    logoData: nil,
                    ageGroup: nil,
                    season: nil
                )
                
                // Set coach UID for new teams
                if let currentUser = Auth.auth().currentUser {
                    newTeam.coachUID = currentUser.uid
                }
                
                newTeam.players.append(player)
                
                teamManager.addTeam(newTeam)
                teamsImported += 1
                playersImported += 1
            } else {
                // This shouldn't happen in Players Only mode
                errors.append("Target team not found")
            }
        }
        
        // Create result message
        var message = "Successfully imported \(playersImported) player(s)"
        if teamsImported > 0 {
            message += " and created \(teamsImported) new team(s)"
        }
        if !errors.isEmpty {
            message += "\n\nWarnings:\n" + errors.prefix(5).joined(separator: "\n")
            if errors.count > 5 {
                message += "\n... and \(errors.count - 5) more warnings"
            }
        }
        
        return ImportResult(
            success: playersImported > 0,
            teamsImported: teamsImported,
            playersImported: playersImported,
            message: message
        )
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                if insideQuotes && i < line.index(before: line.endIndex) && line[line.index(after: i)] == "\"" {
                    // Escaped quote
                    currentField += "\""
                    i = line.index(after: i)
                } else {
                    // Toggle quote state
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                // Field separator
                fields.append(currentField)
                currentField = ""
            } else {
                currentField += String(char)
            }
            
            i = line.index(after: i)
        }
        
        // Add the last field
        fields.append(currentField)
        
        return fields
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var viewDidAppear = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    appIconSection
                    descriptionSection
                    comingSoonSection // NEW SECTION
                    footerSection
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if viewDidAppear {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewDidAppear = true
                }
            }
        }
    }
    
    private var appIconSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 0.13, green: 0.47, blue: 0.25), Color(red: 0.10, green: 0.40, blue: 0.22)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            
            Text("Coach Caddie")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var descriptionSection: some View {
        VStack(spacing: 12) {
            Text("The complete coaching companion for soccer teams")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Manage your teams, track player performance, plan strategies, and stay organized throughout the season.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // NEW COMING SOON SECTION
    private var comingSoonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Coming Soon")
                    .font(.title2)
                    .bold()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Features
            VStack(alignment: .leading, spacing: 14) {
                // AI Drill Coach
                ComingSoonFeatureRow(
                    icon: "sparkles",
                    iconColor: .purple,
                    title: "AI Drill Coach",
                    description: "Get personalized drill variations and coaching tips powered by AI. Ask questions about any drill and receive instant suggestions to adapt for your team's skill level."
                )
                
                // Team Messaging
                ComingSoonFeatureRow(
                    icon: "message.badge",
                    iconColor: .green,
                    title: "Team Messaging",
                    description: "Built-in chat for coaches, players, and parents. Send announcements, coordinate schedules, and keep everyone connected."
                )
                
                // Season Planner
                ComingSoonFeatureRow(
                    icon: "calendar.badge.clock",
                    iconColor: .orange,
                    title: "Season Planner",
                    description: "Toggle between seasons for long term tracking and seasonal comparison"
                )
                
                // Player Development
                ComingSoonFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .blue,
                    title: "Player Progress Tracking",
                    description: "Track individual player skill development with metrics and progress reports for parents."
                )
                
                // Tournament Manager
                ComingSoonFeatureRow(
                    icon: "trophy.fill",
                    iconColor: .yellow,
                    title: "Tournament Manager",
                    description: "Organize and track tournament brackets, schedules, and results all in one place."
                )
                
                // Weather Integration
                ComingSoonFeatureRow(
                    icon: "cloud.sun.fill",
                    iconColor: .cyan,
                    title: "Smart Weather Alerts",
                    description: "Automatic weather monitoring for practice and game days with push notifications for changes."
                )
                
                // Drill Sharing
                ComingSoonFeatureRow(
                    icon: "square.and.arrow.up.on.square",
                    iconColor: .indigo,
                    title: "Drill Library Sharing",
                    description: "Share your custom drills with other coaches and access community-created practice plans."
                )
            }
            
            // Footer note
            Text("We're constantly working to make Coach Caddie better. Have a feature request? Send us an email at CoachCaddie@metric-mind.com")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Made for coaches by coaches")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Coach Caddie - a MetricMind Product")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }
}

// MARK: - Coming Soon Feature Row Component
struct ComingSoonFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // Set completion handler to properly dismiss
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
