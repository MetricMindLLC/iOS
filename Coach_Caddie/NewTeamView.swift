import SwiftUI

struct NewTeamView: View {
    @ObservedObject var teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var format: GameFormat = .elevenVEleven
    @State private var defaultFormation: Formation = .formation442
    @State private var selectedColor = Color(red: 0.13, green: 0.47, blue: 0.25)
    @State private var ageGroup = ""
    @State private var season = ""
    @State private var showingColorPicker = false
    @State private var errorMessage: String?
    @State private var hasAcknowledgedResponsibility = false
    @State private var showingResponsibilityDisclaimer = false
    @State private var showingParentNoticeGenerator = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Team Name", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Team Details")
                } footer: {
                    if let warning = teamLimitWarning {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Show team count information
                if let authManager = teamManager.authManager,
                   let currentUser = authManager.currentUser,
                   currentUser.maxTeamsAllowed < 999 { // Don't show for unlimited accounts
                    Section {
                        HStack {
                            Image(systemName: "number.circle.fill")
                                .foregroundColor(.blue)
                            Text("Teams")
                            Spacer()
                            Text("\(teamManager.teams.count)/\(currentUser.maxTeamsAllowed)")
                                .foregroundColor(teamManager.teams.count >= currentUser.maxTeamsAllowed ? .red : .secondary)
                                .fontWeight(teamManager.teams.count >= currentUser.maxTeamsAllowed ? .semibold : .regular)
                        }
                        
                        if teamManager.teams.count >= currentUser.maxTeamsAllowed {
                            Button("Upgrade Plan") {
                                // Handle upgrade navigation
                                // presentationMode.wrappedValue.dismiss()
                                // showingUpgradeView = true
                            }
                            .foregroundColor(.orange)
                        }
                    } header: {
                        Text("Plan Limits")
                    } footer: {
                        Text("Your \(currentUser.subscriptionLevel.displayName) plan allows up to \(currentUser.maxTeamsAllowed) team\(currentUser.maxTeamsAllowed == 1 ? "" : "s").")
                    }
                }
                
                Section {
                    Picker("Game Format", selection: $format) {
                        ForEach(GameFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    
                    Picker("Formation", selection: $defaultFormation) {
                        ForEach(format.availableFormations, id: \.self) { formation in
                            Text(formation.displayName).tag(formation)
                        }
                    }
                } header: {
                    Text("Game Settings")
                }
                
                Section {
                    // Replace ColorSelector with inline color picker
                    Button(action: {
                        showingColorPicker = true
                    }) {
                        HStack {
                            Text("Team Color")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                } header: {
                    Text("Team Colors")
                }
                
                Section {
                    TextField("Age Group (Optional)", text: $ageGroup)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Season (Optional)", text: $season)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Additional Info")
                }
                
                // COPPA Responsibility Section
                Section {
                    Button(action: {
                        showingResponsibilityDisclaimer = true
                    }) {
                        HStack {
                            Image(systemName: hasAcknowledgedResponsibility ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(hasAcknowledgedResponsibility ? .green : .orange)
                                .font(.title2)
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Coach Responsibility")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text(hasAcknowledgedResponsibility ? "Acknowledged" : "Required for COPPA compliance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                            
                            if !hasAcknowledgedResponsibility {
                                Button("Review") {
                                    showingResponsibilityDisclaimer = true
                                }
                                .foregroundColor(.blue)
                                .font(.subheadline)
                            }
                        }
                        
                        if !hasAcknowledgedResponsibility {
                            Text("You must acknowledge your responsibilities for team data management and COPPA compliance before creating a team.")
                                .font(.caption)
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 8)
                        }
                    }
                } header: {
                    Text("COPPA Compliance")
                }
                
                // Parent Notice Generator Section
                Section {
                    Button(action: {
                        showingParentNoticeGenerator = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Generate Parent Notice")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("Create COPPA-compliant parent notification")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Parent Communication")
                } footer: {
                    Text("Generate a professional notice to inform parents about team data collection and privacy practices.")
                }
                
                // Tips section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("You can add players after creating the team", systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Label("Team format determines available formations", systemImage: "info.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Label("Parent notification helps ensure COPPA compliance", systemImage: "shield.checkered")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                    }
                }
            }
            .navigationTitle("New Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createTeam()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canCreateTeam)
                }
            }
            .sheet(isPresented: $showingColorPicker) {
                NavigationView {
                    ColorPicker("Choose Team Color", selection: $selectedColor)
                        .padding()
                        .navigationTitle("Custom Color")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingColorPicker = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingResponsibilityDisclaimer) {
                CoachResponsibilityDisclaimerView(
                    onAcknowledge: {
                        hasAcknowledgedResponsibility = true
                    }
                )
            }
            .sheet(isPresented: $showingParentNoticeGenerator) {
                EnhancedParentNoticeGeneratorView(
                    team: Team(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        format: format,
                        defaultFormation: defaultFormation,
                        primaryColor: selectedColor,
                        ageGroup: ageGroup.isEmpty ? nil : ageGroup,
                        season: season.isEmpty ? nil : season
                    )
                )
            }
            .onChange(of: format) { _ in
                // Update default formation when format changes
                defaultFormation = format.defaultFormation
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canCreateTeam: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard hasAcknowledgedResponsibility else { return false }
        
        // Check team limits
        if let authManager = teamManager.authManager,
           let currentUser = authManager.currentUser {
            return teamManager.teams.count < currentUser.maxTeamsAllowed
        }
        
        return true
    }
    
    private var teamLimitWarning: String? {
        guard let authManager = teamManager.authManager,
              let currentUser = authManager.currentUser else { return nil }
        
        let currentTeams = teamManager.teams.count
        let maxTeams = currentUser.maxTeamsAllowed
        let planName = currentUser.subscriptionLevel.displayName
        
        if currentTeams >= maxTeams {
            if maxTeams == 1 {
                return "You've reached your team limit for the \(planName) plan. Upgrade to create more teams."
            } else {
                return "You've reached your maximum of \(maxTeams) teams for the \(planName) plan. Upgrade to create more teams."
            }
        } else if currentTeams == maxTeams - 1 {
            return "This will be your last team on the \(planName) plan. Consider upgrading for more teams."
        }
        
        return nil
    }
    
    // MARK: - Methods
    
    private func createTeam() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a team name"
            return
        }
        
        guard hasAcknowledgedResponsibility else {
            errorMessage = "Please acknowledge coach responsibility for COPPA compliance"
            return
        }
        
        // Enhanced team limit checking
        if let authManager = teamManager.authManager,
           let currentUser = authManager.currentUser {
            let currentTeams = teamManager.teams.count
            let maxTeams = currentUser.maxTeamsAllowed
            
            if currentTeams >= maxTeams {
                let planName = currentUser.subscriptionLevel.displayName
                if maxTeams == 1 {
                    errorMessage = "You've reached your team limit for the \(planName) plan. Please upgrade to create more teams."
                } else {
                    errorMessage = "You've reached your maximum of \(maxTeams) teams for the \(planName) plan. Please upgrade to create more teams."
                }
                return
            }
            
            // Fixed: Use subscriptionLevel.canCreateTeams instead of currentUser.canCreateTeams
            if !currentUser.subscriptionLevel.canCreateTeams {
                switch currentUser.subscriptionLevel {
                case .sharedAccess:
                    errorMessage = "Shared access users cannot create teams. Ask a coach to invite you to their team."
                case .cancelled, .expired:
                    errorMessage = "Your subscription has expired. Please renew your subscription to create teams."
                default:
                    errorMessage = "Your current plan doesn't allow team creation. Please upgrade your subscription."
                }
                return
            }
        }
        
        // Check for duplicate team names
        if teamManager.teams.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            errorMessage = "A team with this name already exists"
            return
        }

        let newTeam = Team(
            name: trimmedName,
            format: format,
            defaultFormation: defaultFormation,
            primaryColor: selectedColor,
            ageGroup: ageGroup.isEmpty ? nil : ageGroup,
            season: season.isEmpty ? nil : season
        )

        teamManager.addTeam(newTeam)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Team Format Extensions
extension TeamFormat {
    var displayName: String {
        switch self {
        case .fiveVFive: return "5v5 (Youth)"
        case .sevenVSeven: return "7v7 (Youth)"
        case .nineVNine: return "9v9 (Youth)"
        case .elevenVEleven: return "11v11 (Full Field)"
        }
    }
}

// MARK: - Formation Extensions
extension Formation {
    var displayName: String {
        switch self {
        // 5v5 formations - UPDATED TO MATCH CURRENT FORMATIONS
        case .formation5v5_1211: return "1-2-1-1 (Diamond)"
        case .formation5v5_2111: return "2-1-1-1 (Defensive)"
        case .formation5v5_131: return "1-3-1 (Midfield Heavy)"
        case .formation5v5_221: return "2-2-1 (Balanced)"
        case .formation5v5_23: return "2-3 (Attacking)"
        case .formation5v5_32: return "3-2 (Defensive)"
            
        // 7v7 formations - UPDATED TO MATCH CURRENT FORMATIONS
        case .formation7v7_312: return "3-1-2 (Balanced)"
        case .formation7v7_213: return "2-1-3 (Attacking)"
        case .formation7v7_321: return "3-2-1 (Defensive)"
        case .formation7v7_222: return "2-2-2 (Box)"
            
        // 9v9 formations - UPDATED TO MATCH CURRENT FORMATIONS
        case .formation9v9_3212: return "3-2-1-2 (Balanced)"
        case .formation9v9_3131: return "3-1-3-1 (Diamond)"
        case .formation9v9_4121: return "4-1-2-1 (Defensive)"
        case .formation9v9_413: return "4-1-3 (Attacking)"
        case .formation9v9_323: return "3-2-3 (Attack)"
        case .formation9v9_332: return "3-3-2 (Midfield)"
        case .formation9v9_233: return "2-3-3 (Ultra Attack)"
            
        // 11v11 formations - UPDATED TO INCLUDE NEW FORMATION
        case .formation442: return "4-4-2 (Classic)"
        case .formation433: return "4-3-3 (Attacking)"
        case .formation352: return "3-5-2 (Midfield)"
        case .formation451: return "4-5-1 (Defensive)"
        case .formation343: return "3-4-3 (Wide)"
        case .formation4231: return "4-2-3-1 (Modern)"
        case .formation532: return "5-3-2 (Defensive)"
        case .formation541: return "5-4-1 (Ultra Defensive)"
        case .formation41212: return "4-1-2-1-2 (Diamond)"
            
        // Default case for any other formations
        default: return self.rawValue
        }
    }
}
