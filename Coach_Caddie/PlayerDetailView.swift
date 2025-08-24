import SwiftUI
import FirebaseAuth

struct PlayerDetailView: View {
    @Binding var player: Player
    @Binding var team: Team
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var teamManager: TeamManager
    
    @State private var showingEditPlayer = false
    @State private var showingDeleteAlert = false
    @State private var userRole: AccessLevel?
    @State private var canEditThisPlayer = false
    @State private var isLoadingPermissions = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Player Photo Section
                playerPhotoSection
                
                // Basic Info Section
                basicInfoSection
                
                // Stats Section
                statsSection
                
                // Contact Info Section (conditional based on role)
                if canEditThisPlayer || userRole == .coach {
                    contactInfoSection
                } else if userRole == .parent {
                    limitedContactInfoSection
                }
                
                // Medical/Emergency Info Section (conditional based on role)
                if canEditThisPlayer || userRole == .coach {
                    medicalInfoSection
                }
                
                // Coach Notes Section (conditional based on role)
                if userRole == .coach && !(player.notes?.isEmpty ?? true) {
                    coachNotesSection
                }
                
                // Action Buttons Section - FIXED: Added proper spacing and layout
                if canEditThisPlayer || userRole == .coach {
                    VStack(spacing: 16) {
                        // Edit Button
                        if canEditThisPlayer {
                            Button(action: {
                                showingEditPlayer = true
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Edit")
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Delete Button (only for coaches)
                        if userRole == .coach {
                            Button(action: {
                                showingDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Player")
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                }
                
                // Add bottom padding to ensure content doesn't get cut off
                Color.clear
                    .frame(height: 50)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditPlayer) {
            EditPlayerView(player: $player, team: $team)
        }
        .alert("Delete Player", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                removePlayer()
            }
        } message: {
            Text("Are you sure you want to remove \(player.displayName(for: userRole ?? .viewer, viewerEmail: Auth.auth().currentUser?.email)) from the team? This action cannot be undone.")
        }
        .onAppear {
            checkPermissions()
        }
        .overlay {
            if isLoadingPermissions {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
    }
    
    private var playerPhotoSection: some View {
        VStack(spacing: 12) {
            if let photoData = player.playerPhoto, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    )
            } else {
                Circle()
                    .fill(team.primaryColor.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text(String(player.displayName(for: userRole ?? .viewer, viewerEmail: Auth.auth().currentUser?.email).prefix(1)).uppercased())
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(team.primaryColor)
                    )
            }
            
            VStack(spacing: 4) {
                Text(player.displayName(for: userRole ?? .viewer, viewerEmail: Auth.auth().currentUser?.email))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("#\(player.jerseyNumber)")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                if !player.positions.isEmpty {
                    Text(player.positions.joined(separator: " • "))
                        .font(.subheadline)
                        .foregroundColor(team.primaryColor)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Player Information")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                // REMOVED: Age and Date of Birth for COPPA compliance
                
                if !player.positions.isEmpty {
                    InfoRow(label: "Positions", value: player.positions.joined(separator: ", "))
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 2)
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Season Stats")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                StatRowView(icon: "gamecontroller.fill", title: "Games Played", value: "\(player.seasonStats.gamesPlayed)")
                Divider().padding(.horizontal)
                
                StatRowView(icon: "soccerball", title: "Goals", value: "\(player.seasonStats.goals)")
                Divider().padding(.horizontal)
                
                StatRowView(icon: "hands.and.sparkles.fill", title: "Assists", value: "\(player.seasonStats.assists)")
                Divider().padding(.horizontal)
                
                StatRowView(icon: "scope", title: "Shots", value: "\(player.seasonStats.shots)")  // NEW
                Divider().padding(.horizontal)
                
                StatRowView(icon: "hand.raised.fill", title: "Saves", value: "\(player.seasonStats.saves)")
            }
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 2)
            .padding(.horizontal)
        }
    }
    
    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact Information")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                if !player.parentInfo.parentName.isEmpty {
                    ContactRow(icon: "person.fill", text: player.parentInfo.parentName, color: .blue)
                }
                
                if !player.parentInfo.parentPhone.isEmpty {
                    ContactRow(icon: "phone.fill", text: player.parentInfo.parentPhone, color: .green)
                }
                
                if !player.parentInfo.parentEmail.isEmpty {
                    ContactRow(icon: "envelope.fill", text: player.parentInfo.parentEmail, color: .orange)
                }
                
                if !player.parentInfo.secondParentName.isEmpty {
                    ContactRow(icon: "person.fill", text: "\(player.parentInfo.secondParentName) (2nd Parent)", color: .blue)
                }
                
                if !player.parentInfo.secondParentPhone.isEmpty {
                    ContactRow(icon: "phone.fill", text: "\(player.parentInfo.secondParentPhone) (2nd Parent)", color: .green)
                }
                
                if !player.parentInfo.secondParentEmail.isEmpty {
                    ContactRow(icon: "envelope.fill", text: "\(player.parentInfo.secondParentEmail) (2nd Parent)", color: .orange)
                }
            }
        }
    }
    
    private var limitedContactInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact Information")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                // Parents can only see their own contact info
                if let userEmail = Auth.auth().currentUser?.email?.lowercased() {
                    let parentEmail = player.parentInfo.parentEmail.lowercased()
                    let secondParentEmail = player.parentInfo.secondParentEmail.lowercased()
                    
                    if parentEmail == userEmail && !player.parentInfo.parentName.isEmpty {
                        ContactRow(icon: "person.fill", text: player.parentInfo.parentName, color: .blue)
                        if !player.parentInfo.parentPhone.isEmpty {
                            ContactRow(icon: "phone.fill", text: player.parentInfo.parentPhone, color: .green)
                        }
                        ContactRow(icon: "envelope.fill", text: player.parentInfo.parentEmail, color: .orange)
                    }
                    
                    if secondParentEmail == userEmail && !player.parentInfo.secondParentName.isEmpty {
                        ContactRow(icon: "person.fill", text: "\(player.parentInfo.secondParentName) (2nd Parent)", color: .blue)
                        if !player.parentInfo.secondParentPhone.isEmpty {
                            ContactRow(icon: "phone.fill", text: "\(player.parentInfo.secondParentPhone) (2nd Parent)", color: .green)
                        }
                        ContactRow(icon: "envelope.fill", text: "\(player.parentInfo.secondParentEmail) (2nd Parent)", color: .orange)
                    }
                }
            }
        }
    }
    
    private var medicalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Medical & Emergency")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                if !(player.emergencyContact?.isEmpty ?? true) {
                    ContactRow(icon: "phone.badge.plus.fill", text: "Emergency: \(player.emergencyContact!)", color: .red)
                }
                
                if !(player.emergencyPhone?.isEmpty ?? true) {
                    ContactRow(icon: "phone.fill", text: player.emergencyPhone!, color: .red)
                }
                
                if !(player.medicalNotes?.isEmpty ?? true) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cross.fill")
                                .foregroundColor(.red)
                            Text("Medical Notes")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                        
                        Text(player.medicalNotes!)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .shadow(radius: 2)
                }
            }
        }
    }
    
    private var coachNotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coach Notes")
                .font(.headline)
                .padding(.horizontal)
            
            Text(player.notes ?? "")
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
    
    private func checkPermissions() {
        Task { @MainActor in
            let role = await teamManager.getCurrentUserRole(for: team)
            let canEdit = await teamManager.canCurrentUserEdit(player: player, in: team)
            
            userRole = role
            canEditThisPlayer = canEdit
            isLoadingPermissions = false
        }
    }
    
    func removePlayer() {
        if let index = team.players.firstIndex(where: { $0.id == player.id }) {
            team.players.remove(at: index)
            teamManager.updateTeam(team)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Player Stat Box (renamed to avoid conflict)
struct PlayerStatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title)
                .bold()
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ContactRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
    }
}

// MARK: - Edit Player View (UPDATED FOR COPPA COMPLIANCE AND FIREBASE PERSISTENCE)
struct EditPlayerView: View {
    @Binding var player: Player
    @Binding var team: Team
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var teamManager: TeamManager
    
    @State private var playerName: String
    @State private var jerseyNumber: String
    @State private var selectedPositions: Set<String>
    // REMOVED: @State private var birthDate: Date - COPPA compliance
    @State private var parentName: String
    @State private var parentPhone: String
    @State private var parentEmail: String
    @State private var secondParentName: String
    @State private var secondParentPhone: String
    @State private var secondParentEmail: String
    @State private var emergencyContact: String
    @State private var emergencyPhone: String
    @State private var medicalNotes: String
    @State private var notes: String
    @State private var showingDuplicateAlert = false
    @State private var showingSaveConfirmation = false
    
    // Role-based permissions
    @State private var userRole: AccessLevel?
    @State private var canEditThisPlayer = false
    @State private var isLoadingPermissions = true
    
    let positions = ["GK", "DEF", "MID", "FWD"]
    
    init(player: Binding<Player>, team: Binding<Team>) {
        self._player = player
        self._team = team
        
        // Initialize state variables with correct property structure
        self._playerName = State(initialValue: player.wrappedValue.name)
        self._jerseyNumber = State(initialValue: "\(player.wrappedValue.jerseyNumber)")
        self._selectedPositions = State(initialValue: Set(player.wrappedValue.positions))
        // REMOVED: birthDate initialization - COPPA compliance
        self._parentName = State(initialValue: player.wrappedValue.parentInfo.parentName)
        self._parentPhone = State(initialValue: player.wrappedValue.parentInfo.parentPhone)
        self._parentEmail = State(initialValue: player.wrappedValue.parentInfo.parentEmail)
        self._secondParentName = State(initialValue: player.wrappedValue.parentInfo.secondParentName)
        self._secondParentPhone = State(initialValue: player.wrappedValue.parentInfo.secondParentPhone)
        self._secondParentEmail = State(initialValue: player.wrappedValue.parentInfo.secondParentEmail)
        self._emergencyContact = State(initialValue: player.wrappedValue.emergencyContact ?? "")
        self._emergencyPhone = State(initialValue: player.wrappedValue.emergencyPhone ?? "")
        self._medicalNotes = State(initialValue: player.wrappedValue.medicalNotes ?? "")
        self._notes = State(initialValue: player.wrappedValue.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoadingPermissions {
                    ProgressView("Loading permissions...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !canEditThisPlayer {
                    VStack(spacing: 20) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Access Restricted")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(getAccessMessage())
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    editForm
                }
            }
            .navigationTitle("Edit Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if canEditThisPlayer {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            savePlayer()
                        }
                        .disabled(!isFormValid)
                    }
                }
            }
        }
        .onAppear {
            checkPermissions()
        }
        .alert("Duplicate Jersey Number", isPresented: $showingDuplicateAlert) {
            Button("OK") { }
        } message: {
            Text("Another player already uses jersey number \(jerseyNumber). Please choose a different number.")
        }
        .alert("Player Updated", isPresented: $showingSaveConfirmation) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("\(playerName) has been updated successfully.")
        }
    }
    
    // MARK: - Form Views
    private var editForm: some View {
        Form {
            basicInfoSection
            positionsSection
            
            // Contact info based on role
            if userRole == .coach {
                coachContactInfoSection
            } else if userRole == .parent {
                parentContactInfoSection
            }
            
            // Emergency/Medical (coaches and parents)
            if userRole == .coach || userRole == .parent {
                emergencyMedicalSection
            }
            
            // Coach notes (only coaches)
            if userRole == .coach {
                coachNotesSection
            }
        }
    }
    
    private var basicInfoSection: some View {
        Section {
            HStack {
                Text("Name")
                    .fontWeight(.medium)
                TextField("Player Name", text: $playerName)
                    .multilineTextAlignment(.trailing)
            }
            
            HStack {
                Text("Jersey #")
                    .fontWeight(.medium)
                TextField("Jersey Number", text: $jerseyNumber)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Basic Information")
        }
    }
    
    private var positionsSection: some View {
        Section {
            ForEach(positions, id: \.self) { position in
                HStack {
                    Text(positionFullName(position))
                    Spacer()
                    if selectedPositions.contains(position) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    togglePosition(position)
                }
            }
        } header: {
            Text("Positions")
        } footer: {
            Text("Select at least one position.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var coachContactInfoSection: some View {
        Section {
            Group {
                HStack {
                    Text("Parent Name")
                        .fontWeight(.medium)
                    TextField("Full Name", text: $parentName)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Parent Phone")
                        .fontWeight(.medium)
                    TextField("Phone Number", text: $parentPhone)
                        .keyboardType(.phonePad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Parent Email")
                        .fontWeight(.medium)
                    TextField("Email Address", text: $parentEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("2nd Parent Name")
                        .fontWeight(.medium)
                    TextField("Full Name", text: $secondParentName)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("2nd Parent Phone")
                        .fontWeight(.medium)
                    TextField("Phone Number", text: $secondParentPhone)
                        .keyboardType(.phonePad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("2nd Parent Email")
                        .fontWeight(.medium)
                    TextField("Email Address", text: $secondParentEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Text("Contact Information")
        }
    }
    
    private var parentContactInfoSection: some View {
        Section {
            Group {
                // Parents can only edit their own contact info
                if let userEmail = Auth.auth().currentUser?.email?.lowercased() {
                    let parentEmail = player.parentInfo.parentEmail.lowercased()
                    let secondParentEmail = player.parentInfo.secondParentEmail.lowercased()
                    
                    if parentEmail == userEmail {
                        HStack {
                            Text("Your Name")
                                .fontWeight(.medium)
                            TextField("Full Name", text: $parentName)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Your Phone")
                                .fontWeight(.medium)
                            TextField("Phone Number", text: $parentPhone)
                                .keyboardType(.phonePad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Your Email")
                                .fontWeight(.medium)
                            Text(parentEmail)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    if secondParentEmail == userEmail {
                        HStack {
                            Text("Your Name")
                                .fontWeight(.medium)
                            TextField("Full Name", text: $secondParentName)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Your Phone")
                                .fontWeight(.medium)
                            TextField("Phone Number", text: $secondParentPhone)
                                .keyboardType(.phonePad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Your Email")
                                .fontWeight(.medium)
                            Text(secondParentEmail)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        } header: {
            Text("Your Contact Information")
        } footer: {
            Text("You can only edit your own contact information.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var emergencyMedicalSection: some View {
        Section {
            HStack {
                Text("Emergency Contact")
                    .fontWeight(.medium)
                TextField("Contact Name", text: $emergencyContact)
                    .multilineTextAlignment(.trailing)
            }
            
            HStack {
                Text("Emergency Phone")
                    .fontWeight(.medium)
                TextField("Phone Number", text: $emergencyPhone)
                    .keyboardType(.phonePad)
                    .multilineTextAlignment(.trailing)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Medical Notes")
                    .fontWeight(.medium)
                TextField("Allergies, medications, conditions...", text: $medicalNotes, axis: .vertical)
                    .lineLimit(3...6)
            }
        } header: {
            Text("Emergency & Medical")
        }
    }
    
    private var coachNotesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Coach Notes")
                    .fontWeight(.medium)
                TextField("Private notes about player performance, behavior, etc.", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        } header: {
            Text("Coach Notes (Private)")
        } footer: {
            Text("These notes are only visible to coaches.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var isFormValid: Bool {
        !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !jerseyNumber.isEmpty &&
        Int(jerseyNumber) != nil
    }
    
    private func getAccessMessage() -> String {
        switch userRole {
        case .parent:
            return "As a parent, you can only edit your own child's information. This player's contact information doesn't match your account."
        case .viewer:
            return "You have view-only access to this team. Contact the coach to request edit permissions."
        case .coach:
            return "You have full access to edit all players."
        case .none:
            return "Unable to determine your access level. Please try again."
        }
    }
    
    private func checkPermissions() {
        Task { @MainActor in
            let role = await teamManager.getCurrentUserRole(for: team)
            let canEdit = await teamManager.canCurrentUserEdit(player: player, in: team)
            
            userRole = role
            canEditThisPlayer = canEdit
            isLoadingPermissions = false
        }
    }
    
    private func togglePosition(_ position: String) {
        if selectedPositions.contains(position) {
            selectedPositions.remove(position)
        } else {
            selectedPositions.insert(position)
        }
    }
    
    private func positionFullName(_ position: String) -> String {
        switch position {
        case "GK": return "Goalkeeper"
        case "DEF": return "Defender"
        case "MID": return "Midfielder"
        case "FWD": return "Forward"
        default: return position
        }
    }
    
    // MARK: - Save Player (FIXED FOR FIREBASE PERSISTENCE)
    private func savePlayer() {
        // Validate jersey number
        guard let newJerseyNumber = Int(jerseyNumber) else { return }
        
        // Check for duplicate jersey numbers
        if newJerseyNumber != player.jerseyNumber &&
           team.players.contains(where: { $0.jerseyNumber == newJerseyNumber && $0.id != player.id }) {
            showingDuplicateAlert = true
            return
        }
        
        // Update player based on role permissions
        player.name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        player.jerseyNumber = newJerseyNumber
        player.positions = Array(selectedPositions).sorted()
        // REMOVED: player.dateOfBirth = birthDate - COPPA compliance
        
        // Update contact info based on role
        if userRole == .coach {
            // Coaches can edit all contact info
            player.parentInfo.parentName = parentName
            player.parentInfo.parentPhone = parentPhone
            player.parentInfo.parentEmail = parentEmail
            player.parentInfo.secondParentName = secondParentName
            player.parentInfo.secondParentPhone = secondParentPhone
            player.parentInfo.secondParentEmail = secondParentEmail
        } else if userRole == .parent {
            // Parents can only edit their own contact info
            if let userEmail = Auth.auth().currentUser?.email?.lowercased() {
                let currentParentEmail = player.parentInfo.parentEmail.lowercased()
                let currentSecondParentEmail = player.parentInfo.secondParentEmail.lowercased()
                
                if currentParentEmail == userEmail {
                    player.parentInfo.parentName = parentName
                    player.parentInfo.parentPhone = parentPhone
                    player.parentInfo.parentEmail = parentEmail
                }
                
                if currentSecondParentEmail == userEmail {
                    player.parentInfo.secondParentName = secondParentName
                    player.parentInfo.secondParentPhone = secondParentPhone
                    player.parentInfo.secondParentEmail = secondParentEmail
                }
            }
        }
        
        // Emergency/Medical info (coaches and parents can edit)
        if userRole == .coach || userRole == .parent {
            player.emergencyContact = emergencyContact.isEmpty ? nil : emergencyContact
            player.emergencyPhone = emergencyPhone.isEmpty ? nil : emergencyPhone
            player.medicalNotes = medicalNotes.isEmpty ? nil : medicalNotes
        }
        
        // Coach notes (only coaches can edit)
        if userRole == .coach {
            player.notes = notes.isEmpty ? nil : notes
        }
        
        // Update in team
        if let index = team.players.firstIndex(where: { $0.id == player.id }) {
            team.players[index] = player
        }
        
        // FIXED: Save to Firebase via TeamManager
        // This was missing - causing the data to only save locally
        teamManager.updateTeam(team)
        
        showingSaveConfirmation = true
    }
}

// MARK: - Add Player View (UPDATED FOR COPPA COMPLIANCE)
struct AddPlayerView: View {
    @Binding var team: Team
    @EnvironmentObject var teamManager: TeamManager
    @State private var playerName = ""
    @State private var jerseyNumber = ""
    @State private var selectedPositions: Set<String> = []
    // REMOVED: @State private var birthDate = Date() - COPPA compliance
    @State private var parentName = ""
    @State private var parentPhone = ""
    @State private var parentEmail = ""
    @State private var secondParentName = ""
    @State private var secondParentPhone = ""
    @State private var secondParentEmail = ""
    @State private var emergencyContact = ""
    @State private var emergencyPhone = ""
    @State private var medicalNotes = ""
    @State private var notes = ""
    @State private var showingDuplicateAlert = false
    @State private var isSaving = false
    @Environment(\.presentationMode) var presentationMode
    
    let positions = ["GK", "DEF", "MID", "FWD"]
    
    var isFormValid: Bool {
        !playerName.isEmpty &&
        !jerseyNumber.isEmpty &&
        !selectedPositions.isEmpty &&
        Int(jerseyNumber) != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Player Information") {
                    TextField("Player Name", text: $playerName)
                    
                    TextField("Jersey Number", text: $jerseyNumber)
                        .keyboardType(.numberPad)
                    
                    // REMOVED: DatePicker for Date of Birth - COPPA compliance
                }
                
                // Positions Section
                Section("Positions") {
                    ForEach(positions, id: \.self) { position in
                        HStack {
                            Text(positionFullName(position))
                            Spacer()
                            if selectedPositions.contains(position) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedPositions.contains(position) {
                                selectedPositions.remove(position)
                            } else {
                                selectedPositions.insert(position)
                            }
                        }
                    }
                }
                
                // Parent Information
                Section("Parent/Guardian Information") {
                    TextField("Parent Name", text: $parentName)
                    TextField("Parent Phone", text: $parentPhone)
                        .keyboardType(.phonePad)
                    TextField("Parent Email", text: $parentEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                
                // Second Parent Information
                Section("Second Parent/Guardian (Optional)") {
                    TextField("Second Parent Name", text: $secondParentName)
                    TextField("Second Parent Phone", text: $secondParentPhone)
                        .keyboardType(.phonePad)
                    TextField("Second Parent Email", text: $secondParentEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                
                // Emergency Contact
                Section("Emergency Contact") {
                    TextField("Emergency Contact Name", text: $emergencyContact)
                    TextField("Emergency Contact Phone", text: $emergencyPhone)
                        .keyboardType(.phonePad)
                }
                
                // Medical Notes
                Section("Medical Information") {
                    TextField("Medical Notes", text: $medicalNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Coach Notes
                Section("Coach Notes") {
                    TextField("Additional Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlayer()
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .alert("Duplicate Jersey Number", isPresented: $showingDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A player with jersey number \(jerseyNumber) already exists on this team.")
            }
        }
    }
    
    // Helper functions
    private func positionFullName(_ position: String) -> String {
        switch position {
        case "GK": return "Goalkeeper"
        case "DEF": return "Defender"
        case "MID": return "Midfielder"
        case "FWD": return "Forward"
        default: return position
        }
    }
    
    // MARK: - Save Player (UPDATED FOR COPPA COMPLIANCE)
    private func savePlayer() {
        // Check for duplicate jersey number
        if let jerseyNum = Int(jerseyNumber),
           team.players.contains(where: { $0.jerseyNumber == jerseyNum }) {
            showingDuplicateAlert = true
            return
        }
        
        isSaving = true
        
        // Create new player WITHOUT dateOfBirth for COPPA compliance
        var newPlayer = Player(
            name: playerName,
            jerseyNumber: Int(jerseyNumber) ?? 0,
            positions: Array(selectedPositions),
            preferredPosition: selectedPositions.first ?? "MID",
            seasonStats: PlayerStats(),
            parentInfo: ParentInfo()
        )
        
        // Set parent info
        newPlayer.parentInfo.parentName = parentName
        newPlayer.parentInfo.parentEmail = parentEmail
        newPlayer.parentInfo.parentPhone = parentPhone
        newPlayer.parentInfo.secondParentName = secondParentName
        newPlayer.parentInfo.secondParentEmail = secondParentEmail
        newPlayer.parentInfo.secondParentPhone = secondParentPhone
        
        // Set optional properties
        // REMOVED: newPlayer.dateOfBirth = birthDate - COPPA compliance
        newPlayer.emergencyContact = emergencyContact.isEmpty ? nil : emergencyContact
        newPlayer.emergencyPhone = emergencyPhone.isEmpty ? nil : emergencyPhone
        newPlayer.medicalNotes = medicalNotes.isEmpty ? nil : medicalNotes
        newPlayer.notes = notes.isEmpty ? nil : notes
        // REMOVED: newPlayer.playerPhoto = playerPhoto?.jpegData(compressionQuality: 0.8)
        
        // Add to team
        team.players.append(newPlayer)
        
        // Update activity timestamp for data retention
        team.updateActivityTimestamp()
        
        // Save to Firebase via TeamManager
        teamManager.updateTeam(team)
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
    }
}
