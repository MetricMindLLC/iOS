import SwiftUI
import Firebase

// MARK: - Enhanced Parent Notice Generator View
struct EnhancedParentNoticeGeneratorView: View {
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
                ShareSheet(activityItems: [generatedNotice])
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
        if let currentUser = Auth.auth().currentUser {
            if let displayName = currentUser.displayName, !displayName.isEmpty {
                coachName = displayName
            }
            if let email = currentUser.email, !email.isEmpty {
                coachEmail = email
            }
        }
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
        • No photos or personal details collected
        • Data automatically deleted after 90 days of inactivity
        
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
        • Automatic data deletion after 90 days of inactivity
        • No photos, videos, or dates of birth collected
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

// MARK: - Share Sheet Component
struct ShareSheet: UIViewControllerRepresentable {
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