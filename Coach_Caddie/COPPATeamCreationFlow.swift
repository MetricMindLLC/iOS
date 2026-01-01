import SwiftUI

// MARK: - COPPA-Compliant Team Creation Flow
struct COPPATeamCreationFlow: View {
    @EnvironmentObject var teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentStep = 0
    @State private var teamName = ""
    @State private var hasAcknowledgedResponsibility = false
    @State private var showingResponsibilityDisclaimer = false
    @State private var showingParentNoticeGenerator = false
    @State private var hasNotifiedParents = false
    
    private let steps = [
        "Team Info",
        "COPPA Compliance",
        "Parent Notification",
        "Complete"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Indicator
                progressIndicator
                
                // Step Content
                TabView(selection: $currentStep) {
                    teamInfoStep.tag(0)
                    coppaComplianceStep.tag(1)
                    parentNotificationStep.tag(2)
                    completionStep.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation Buttons
                navigationButtons
            }
            .navigationTitle("Create Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
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
                        name: teamName,
                        format: .elevenVEleven,
                        players: [],
                        games: [],
                        practices: []
                    )
                )
            }
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(0..<steps.count, id: \.self) { index in
                    HStack {
                        Circle()
                            .fill(index <= currentStep ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                        
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(index < currentStep ? Color.green : Color.gray.opacity(0.3))
                                .frame(height: 2)
                        }
                    }
                }
            }
            
            Text(steps[currentStep])
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Step 1: Team Info
    private var teamInfoStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Team Information")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Let's start by setting up your team's basic information")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Team Name *")
                        .font(.headline)
                    TextField("Enter team name", text: $teamName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 2: COPPA Compliance
    private var coppaComplianceStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("COPPA Compliance")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Ensure your team management meets privacy requirements for youth sports")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                COPPAFeatureCard(
                    icon: "checkmark.circle.fill",
                    title: "Privacy-First Design",
                    description: "No photos, no birth dates, minimal data collection",
                    color: .green
                )
                
                COPPAFeatureCard(
                    icon: "trash.circle.fill",
                    title: "Automatic Data Deletion",
                    description: "Team data automatically deletes after 180 days of inactivity",
                    color: .orange
                )
                
                COPPAFeatureCard(
                    icon: "person.badge.shield.checkmark.fill",
                    title: "Coach Authority Model",
                    description: "You manage team data under your authority as coach",
                    color: .blue
                )
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: hasAcknowledgedResponsibility ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(hasAcknowledgedResponsibility ? .green : .orange)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Coach Responsibility")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text(hasAcknowledgedResponsibility ? "Acknowledged" : "Required")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !hasAcknowledgedResponsibility {
                            Button("Review") {
                                showingResponsibilityDisclaimer = true
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    if !hasAcknowledgedResponsibility {
                        Text("You must acknowledge your responsibilities for COPPA compliance and team data management")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 3: Parent Notification
    private var parentNotificationStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Parent Notification")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Notify parents about your use of digital team management tools")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Why Notify Parents?")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        NotificationReasonRow(
                            icon: "checkmark.circle.fill",
                            text: "Builds trust and transparency",
                            color: .green
                        )
                        NotificationReasonRow(
                            icon: "checkmark.circle.fill",
                            text: "Ensures COPPA compliance",
                            color: .green
                        )
                        NotificationReasonRow(
                            icon: "checkmark.circle.fill",
                            text: "Gives parents a voice in team management",
                            color: .green
                        )
                        NotificationReasonRow(
                            icon: "checkmark.circle.fill",
                            text: "Establishes clear communication channel",
                            color: .green
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                VStack(spacing: 16) {
                    Button("Generate Parent Notice") {
                        showingParentNoticeGenerator = true
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
                    
                    HStack {
                        Button(action: { hasNotifiedParents.toggle() }) {
                            HStack(spacing: 8) {
                                Image(systemName: hasNotifiedParents ? "checkmark.square.fill" : "square")
                                    .foregroundColor(hasNotifiedParents ? .green : .gray)
                                Text("I have notified parents about team management")
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Text("You can complete this step after creating your team")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 4: Completion
    private var completionStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Team Ready!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your COPPA-compliant team has been created successfully")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                TeamSummaryCard(teamName: teamName)
                
                ComplianceSummaryCard(
                    hasAcknowledgedResponsibility: hasAcknowledgedResponsibility,
                    hasNotifiedParents: hasNotifiedParents
                )
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                Text("Next Steps:")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    NextStepRow(number: "1", text: "Add players to your team")
                    NextStepRow(number: "2", text: "Schedule practices and games")
                    NextStepRow(number: "3", text: "Start tracking team statistics")
                    if !hasNotifiedParents {
                        NextStepRow(number: "4", text: "Send parent notification", isHighlighted: true)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button("Previous") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            if currentStep < steps.count - 1 {
                Button("Next") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(canProceed ? Color.blue : Color.gray)
                .cornerRadius(8)
                .disabled(!canProceed)
            } else {
                Button("Create Team") {
                    createTeam()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.green)
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return !teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            return hasAcknowledgedResponsibility
        case 2:
            return true // Parent notification can be completed later
        default:
            return true
        }
    }
    
    // MARK: - Helper Functions
    private func createTeam() {
        let newTeam = Team(
            name: teamName,
            format: .elevenVEleven,
            players: [],
            games: [],
            practices: []
        )
        
        // Set COPPA compliance settings
        var privacySettings = TeamPrivacySettings()
        privacySettings.coachDataResponsibility = hasAcknowledgedResponsibility
        privacySettings.coppaComplianceAcknowledged = hasAcknowledgedResponsibility
        privacySettings.coppaAcknowledgmentDate = Date()
        
        var mutableTeam = newTeam
        mutableTeam.privacySettings = privacySettings
        
        teamManager.addTeam(mutableTeam)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Supporting Components

struct COPPAFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct NotificationReasonRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(text)
                .font(.caption)
            Spacer()
        }
    }
}

struct TeamSummaryCard: View {
    let teamName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sportscourt.fill")
                    .foregroundColor(.green)
                Text("Team Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Name:")
                        .fontWeight(.medium)
                    Text(teamName)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ComplianceSummaryCard: View {
    let hasAcknowledgedResponsibility: Bool
    let hasNotifiedParents: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.blue)
                Text("COPPA Compliance")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ComplianceStatusRow(
                    text: "Coach responsibility acknowledged",
                    isCompleted: hasAcknowledgedResponsibility
                )
                ComplianceStatusRow(
                    text: "Parent notification completed",
                    isCompleted: hasNotifiedParents
                )
                ComplianceStatusRow(
                    text: "Privacy-first design implemented",
                    isCompleted: true
                )
                ComplianceStatusRow(
                    text: "Automatic data deletion enabled",
                    isCompleted: true
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ComplianceStatusRow: View {
    let text: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .gray)
                .font(.caption)
            Text(text)
                .font(.caption)
                .strikethrough(isCompleted)
                .foregroundColor(isCompleted ? .secondary : .primary)
            Spacer()
        }
    }
}

struct NextStepRow: View {
    let number: String
    let text: String
    let isHighlighted: Bool
    
    init(number: String, text: String, isHighlighted: Bool = false) {
        self.number = number
        self.text = text
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(isHighlighted ? Color.orange : Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
                .fontWeight(isHighlighted ? .semibold : .regular)
                .foregroundColor(isHighlighted ? .orange : .secondary)
            
            Spacer()
        }
    }
}
