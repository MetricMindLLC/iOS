import SwiftUI

struct SuperEnhancedNewGameView: View {
    @Binding var team: Team
    @EnvironmentObject var teamManager: TeamManager
    @State private var opponent = ""
    @State private var gameDate = Date()
    @State private var isHome = true
    @State private var location = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var showingLocationPicker = false
    @State private var selectedLocation: GameLocation?
    @Environment(\.presentationMode) var presentationMode
    
    // Common locations for quick selection
    let commonLocations = [
        GameLocation(name: "Home Field", address: "Main Soccer Complex", isDefault: true),
        GameLocation(name: "North Park", address: "123 North Park Dr"),
        GameLocation(name: "South Complex", address: "456 South Complex Rd"),
        GameLocation(name: "Central Stadium", address: "789 Central Ave")
    ]
    
    var isFormValid: Bool {
        !opponent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Image
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                            .padding(.top, 20)
                        
                        // Game Details Section
                        VStack(spacing: 20) {
                            // Opponent Field
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Opponent", systemImage: "person.3.fill")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Enter opponent team name", text: $opponent)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            
                            // Date and Time Field
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Date & Time", systemImage: "calendar")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                DatePicker(
                                    "",
                                    selection: $gameDate,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Home/Away Toggle
                        VStack(spacing: 16) {
                            Label("Game Type", systemImage: "sportscourt.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            Picker("", selection: $isHome) {
                                Text("Home").tag(true)
                                Text("Away").tag(false)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                            .onChange(of: isHome) { newValue in
                                if newValue && selectedLocation == nil {
                                    // Auto-select home field when switching to home game
                                    if let homeField = commonLocations.first(where: { $0.isDefault }) {
                                        location = homeField.name
                                        address = homeField.address
                                    }
                                } else if !newValue {
                                    // Clear location for away games
                                    location = ""
                                    address = ""
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Location Section
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Location", systemImage: "location.fill")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if !commonLocations.isEmpty {
                                        Button(action: { showingLocationPicker = true }) {
                                            Text("Quick Select")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                
                                TextField(isHome ? "Field name" : "Opponent's field name", text: $location)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Address", systemImage: "map.fill")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Field address (optional)", text: $address)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            
                            // Notes Section
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Notes", systemImage: "note.text")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextEditor(text: $notes)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Game Summary Preview
                        if isFormValid {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Game Summary")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "person.3.fill")
                                            .foregroundColor(.green)
                                            .frame(width: 30)
                                        Text("vs \(opponent)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.blue)
                                            .frame(width: 30)
                                        Text(gameDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                            .font(.subheadline)
                                    }
                                    
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(.orange)
                                            .frame(width: 30)
                                        Text(gameDate.formatted(.dateTime.hour().minute()))
                                            .font(.subheadline)
                                    }
                                    
                                    HStack {
                                        Image(systemName: "sportscourt.fill")
                                            .foregroundColor(.purple)
                                            .frame(width: 30)
                                        Text(isHome ? "HOME" : "AWAY")
                                            .font(.caption)
                                            .bold()
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(isHome ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                            .foregroundColor(isHome ? .green : .orange)
                                            .cornerRadius(8)
                                    }
                                    
                                    if !location.isEmpty {
                                        HStack(alignment: .top) {
                                            Image(systemName: "location.fill")
                                                .foregroundColor(.blue)
                                                .frame(width: 30)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(location)
                                                    .font(.subheadline)
                                                if !address.isEmpty {
                                                    Text(address)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    
                                    if !notes.isEmpty {
                                        HStack(alignment: .top) {
                                            Image(systemName: "note.text")
                                                .foregroundColor(.orange)
                                                .frame(width: 30)
                                            
                                            Text(notes)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    Color(.systemBackground)
                                )
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Spacer
                        Color.clear.frame(height: 20)
                    }
                }
            }
            .navigationTitle("Schedule Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGame()
                    }
                    .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                GameLocationPickerView(
                    locations: commonLocations,
                    selectedLocation: $selectedLocation,
                    customLocation: $location,
                    customAddress: $address
                )
            }
        }
    }
    
    func createGame() {
        // FIXED: Removed 'address' parameter since Game struct doesn't have it
        // If address is needed, combine it with location
        let gameLocation: String? = {
            if location.isEmpty {
                return nil
            } else if !address.isEmpty {
                return "\(location) - \(address)"
            } else {
                return location
            }
        }()
        
        let game = Game(
            date: gameDate,
            opponent: opponent.trimmingCharacters(in: .whitespacesAndNewlines),
            isHome: isHome,
            location: gameLocation,
            notes: notes.isEmpty ? nil : notes
        )
        
        // Update the team's games array
        team.games.append(game)
        
        // Update in TeamManager
        teamManager.updateTeam(team)
        
        presentationMode.wrappedValue.dismiss()
    }
}

// Game Location Picker View - RENAMED FROM LocationPickerView
struct GameLocationPickerView: View {
    let locations: [GameLocation]
    @Binding var selectedLocation: GameLocation?
    @Binding var customLocation: String
    @Binding var customAddress: String
    @Environment(\.presentationMode) var presentationMode
    @State private var isAddingCustom = false
    @State private var tempLocation = ""
    @State private var tempAddress = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Common Locations") {
                    ForEach(locations) { location in
                        Button(action: {
                            selectedLocation = location
                            customLocation = location.name
                            customAddress = location.address
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(location.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(location.address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if location.isDefault {
                                    Text("Home")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        isAddingCustom = true
                    }) {
                        Label("Add Custom Location", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $isAddingCustom) {
                NavigationView {
                    Form {
                        Section("Location Details") {
                            TextField("Location Name", text: $tempLocation)
                            TextField("Address", text: $tempAddress)
                        }
                    }
                    .navigationTitle("Custom Location")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                isAddingCustom = false
                                tempLocation = ""
                                tempAddress = ""
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                customLocation = tempLocation
                                customAddress = tempAddress
                                isAddingCustom = false
                                presentationMode.wrappedValue.dismiss()
                            }
                            .disabled(tempLocation.isEmpty)
                        }
                    }
                }
            }
        }
    }
}

// Game Location Model
struct GameLocation: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    var isDefault: Bool = false
}
