import SwiftUI
import FirebaseAuth

// MARK: - Team Invite Management View
struct TeamInviteView: View {
    let team: Team
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var firebaseManager: FirebaseManager
    @State private var showingInviteSheet = false
    @State private var showingJoinSheet = false
    @State private var generatedCodes: [GeneratedInvite] = []
    @State private var isLoading = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Team Invitations")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Invite coaches and parents to join \(team.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Quick Actions
                VStack(spacing: 16) {
                    Button(action: { showingInviteSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("Generate Invite Code")
                                    .font(.headline)
                                Text("Create a new invitation code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { showingJoinSheet = true }) {
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Join Another Team")
                                    .font(.headline)
                                Text("Enter an invite code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .foregroundColor(.primary)
                }
                .padding(.horizontal)
                
                // Generated Codes
                if !generatedCodes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Invite Codes")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(generatedCodes) { invite in
                                    InviteCodeCard(invite: invite)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                GenerateInviteSheet(team: team, teamManager: teamManager) { invite in
                    generatedCodes.append(invite)
                }
            }
            .sheet(isPresented: $showingJoinSheet) {
                JoinTeamSheet(teamManager: teamManager)
            }
        }
    }
}

// MARK: - Generate Invite Sheet
struct GenerateInviteSheet: View {
    let team: Team
    let teamManager: TeamManager
    let onInviteGenerated: (GeneratedInvite) -> Void
    
    @State private var selectedAccessLevel: AccessLevel = .parent
    @State private var maxUses = 5
    @State private var expirationDays = 7
    @State private var isGenerating = false
    @State private var generatedCode: String?
    @State private var showCopiedFeedback = false
    @State private var viewDidAppear = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section("Access Level") {
                    Picker("Access Level", selection: $selectedAccessLevel) {
                        Text("Coach (Full Access)").tag(AccessLevel.coach)
                        Text("Parent (Edit Access)").tag(AccessLevel.parent)
                        Text("Viewer (Read Only)").tag(AccessLevel.viewer)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Usage Limits") {
                    HStack {
                        Text("Maximum Uses")
                        Spacer()
                        Stepper("\(maxUses)", value: $maxUses, in: 1...20)
                    }
                    
                    HStack {
                        Text("Expires in (days)")
                        Spacer()
                        Stepper("\(expirationDays)", value: $expirationDays, in: 1...30)
                    }
                }
                
                if let code = generatedCode {
                    Section("Generated Code") {
                        HStack {
                            Text(code)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = code
                                showCopiedFeedback = true
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    showCopiedFeedback = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                    if showCopiedFeedback {
                                        Text("Copied!")
                                            .font(.caption)
                                    }
                                }
                                .foregroundColor(showCopiedFeedback ? .green : Color(red: 0.05, green: 0.15, blue: 0.35))
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        Button(action: shareCode) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Code")
                            }
                            .frame(maxWidth: .infinity)
                        }
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
                    .disabled(isGenerating)
                }
            }
        }
    }
    
    private func generateCode() {
        print("🔍 === DEBUG INVITE GENERATION ===")
        if let currentUser = Auth.auth().currentUser {
            print("🔍 Auth.auth().currentUser?.uid: \(currentUser.uid)")
        } else {
            print("🔍 Auth.auth().currentUser is nil")
        }
        print("🔍 team.coachUID: \(team.coachUID ?? "nil")")
        print("🔍 UIDs match: \(team.coachUID == Auth.auth().currentUser?.uid)")
        print("🔍 === END DEBUG ===")
        
        isGenerating = true
        
        Task {
            if let code = await teamManager.generateInviteCode(for: team, accessLevel: selectedAccessLevel) {
                let invite = GeneratedInvite(
                    code: code,
                    accessLevel: selectedAccessLevel,
                    maxUses: maxUses,
                    currentUses: 0,
                    expiresAt: Calendar.current.date(byAdding: .day, value: expirationDays, to: Date()) ?? Date()
                )
                
                await MainActor.run {
                    self.generatedCode = code
                    self.onInviteGenerated(invite)
                    self.isGenerating = false
                }
            } else {
                await MainActor.run {
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func shareCode() {
        guard let code = generatedCode else { return }
        
        let message = "Join our team '\(team.name)' on Coach Caddie! Use invite code: \(code)"
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Join Team Sheet
struct JoinTeamSheet: View {
    let teamManager: TeamManager
    @State private var inviteCode = ""
    @State private var isJoining = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Join a Team")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter the invite code shared with you")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    TextField("Enter invite code", text: $inviteCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.title3)
                        .textCase(.uppercase)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                    
                    Button(action: joinTeam) {
                        HStack {
                            if isJoining {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(isJoining ? "Joining..." : "Join Team")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(inviteCode.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(inviteCode.isEmpty || isJoining)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Join Team")
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
    
    private func joinTeam() {
        isJoining = true
        
        Task {
            let success = await teamManager.joinTeamWithCode(inviteCode.uppercased())
            
            await MainActor.run {
                self.isJoining = false
                if success {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - Team Chat View
struct TeamChatView: View {
    let team: Team
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""
    @State private var isLoading = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Messages
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        ChatMessageBubble(
                            message: message,
                            isCurrentUser: isCurrentUser(message: message)
                        )
                    }
                }
                .padding()
            }
            
            // Message Input
            messageInputView
        }
        .navigationTitle("\(team.name) Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupChatListener()
        }
        .onDisappear {
            firebaseManager.stopListeningToChat(for: team)
        }
    }
    
    private func isCurrentUser(message: ChatMessage) -> Bool {
        return message.senderId == authManager.currentUser?.id.uuidString
    }
    
    private var messageInputView: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $newMessage, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(1...4)
            
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(newMessage.isEmpty ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
            .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func setupChatListener() {
        firebaseManager.startListeningToChat(for: team) { messages in
            self.messages = messages
            self.isLoading = false
        }
    }
    
    private func sendMessage() {
        guard let user = authManager.currentUser,
              !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageText = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        newMessage = ""
        
        Task {
            do {
                try await firebaseManager.sendMessage(messageText, to: team, from: user)
            } catch {
                // Handle error - could show an alert or add to pending messages
                print("Failed to send message: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views
struct InviteCodeCard: View {
    let invite: GeneratedInvite
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(invite.code)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button(action: {
                        UIPasteboard.general.string = invite.code
                    }) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.blue)
                    }
                }
                
                Text(invite.accessLevel.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(invite.accessLevel.canEdit ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                    .cornerRadius(4)
                
                HStack {
                    Text("Uses: \(invite.currentUses)/\(invite.maxUses)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Expires: \(invite.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ChatMessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.message)
                    .padding(12)
                    .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 250, alignment: isCurrentUser ? .trailing : .leading)
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
}
