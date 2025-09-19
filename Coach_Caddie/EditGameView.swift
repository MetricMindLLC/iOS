import SwiftUI
import MapKit

struct EditGameView: View {
    @Binding var game: Game
    @Binding var team: Team
    @EnvironmentObject var teamManager: TeamManager
    @State private var opponent: String
    @State private var gameDate: Date
    @State private var isHome: Bool
    @State private var location: String
    @State private var address: String
    @State private var notes: String
    @State private var showingLocationPicker = false
    @State private var selectedLocation: GameLocation?
    
    // Score editing states
    @State private var hasScore: Bool
    @State private var goalsFor: Int
    @State private var goalsAgainst: Int
    
    @Environment(\.presentationMode) var presentationMode
    
    // Common locations for quick selection
    let commonLocations = [
        GameLocation(name: "Home Field", address: "Main Soccer Complex", isDefault: true),
        GameLocation(name: "North Park", address: "123 North Park Dr"),
        GameLocation(name: "South Complex", address: "456 South Complex Rd"),
        GameLocation(name: "Central Stadium", address: "789 Central Ave")
    ]
    
    init(game: Binding<Game>, team: Binding<Team>) {
        self._game = game
        self._team = team
        
        // Initialize state variables with game data
        self._opponent = State(initialValue: game.wrappedValue.opponent)
        self._gameDate = State(initialValue: game.wrappedValue.date)
        self._isHome = State(initialValue: game.wrappedValue.isHome)
        self._notes = State(initialValue: game.wrappedValue.notes ?? "")
        
        // Initialize score states
        self._hasScore = State(initialValue: game.wrappedValue.result != nil)
        self._goalsFor = State(initialValue: game.wrappedValue.result?.goalsFor ?? 0)
        self._goalsAgainst = State(initialValue: game.wrappedValue.result?.goalsAgainst ?? 0)
        
        // Parse location if it exists
        let gameLocation = game.wrappedValue.location ?? ""
        if gameLocation.contains(" - ") {
            let parts = gameLocation.components(separatedBy: " - ")
            self._location = State(initialValue: parts[0])
            self._address = State(initialValue: parts.count > 1 ? parts[1] : "")
        } else {
            self._location = State(initialValue: gameLocation)
            self._address = State(initialValue: "")
        }
    }
    
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
                            .foregroundColor(.blue)
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
                        
                        // Score Section
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Game Result", systemImage: "target")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(spacing: 16) {
                                    HStack {
                                        Toggle("Add Final Score", isOn: $hasScore)
                                            .tint(.green)
                                        Spacer()
                                    }
                                    
                                    if hasScore {
                                        VStack(spacing: 20) {
                                            Text("Final Score")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            HStack(spacing: 40) {
                                                // Goals For
                                                VStack(spacing: 12) {
                                                    Text("Goals For")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                    
                                                    HStack(spacing: 16) {
                                                        Button(action: {
                                                            if goalsFor > 0 {
                                                                goalsFor -= 1
                                                            }
                                                        }) {
                                                            Image(systemName: "minus.circle.fill")
                                                                .font(.title2)
                                                                .foregroundColor(goalsFor > 0 ? .red : .gray)
                                                        }
                                                        .disabled(goalsFor <= 0)
                                                        
                                                        Text("\(goalsFor)")
                                                            .font(.largeTitle)
                                                            .fontWeight(.bold)
                                                            .frame(minWidth: 60)
                                                            .foregroundColor(.primary)
                                                        
                                                        Button(action: {
                                                            goalsFor += 1
                                                        }) {
                                                            Image(systemName: "plus.circle.fill")
                                                                .font(.title2)
                                                                .foregroundColor(.green)
                                                        }
                                                    }
                                                }
                                                
                                                Text("vs")
                                                    .font(.title2)
                                                    .foregroundColor(.secondary)
                                                
                                                // Goals Against
                                                VStack(spacing: 12) {
                                                    Text("Goals Against")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                    
                                                    HStack(spacing: 16) {
                                                        Button(action: {
                                                            if goalsAgainst > 0 {
                                                                goalsAgainst -= 1
                                                            }
                                                        }) {
                                                            Image(systemName: "minus.circle.fill")
                                                                .font(.title2)
                                                                .foregroundColor(goalsAgainst > 0 ? .red : .gray)
                                                        }
                                                        .disabled(goalsAgainst <= 0)
                                                        
                                                        Text("\(goalsAgainst)")
                                                            .font(.largeTitle)
                                                            .fontWeight(.bold)
                                                            .frame(minWidth: 60)
                                                            .foregroundColor(.primary)
                                                        
                                                        Button(action: {
                                                            goalsAgainst += 1
                                                        }) {
                                                            Image(systemName: "plus.circle.fill")
                                                                .font(.title2)
                                                                .foregroundColor(.green)
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // Result Summary
                                            VStack(spacing: 8) {
                                                Text("Result")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                
                                                let resultText = goalsFor > goalsAgainst ? "Win" : goalsFor < goalsAgainst ? "Loss" : "Draw"
                                                let resultColor: Color = goalsFor > goalsAgainst ? .green : goalsFor < goalsAgainst ? .red : .orange
                                                
                                                Text(resultText)
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(resultColor)
                                                    .padding(.horizontal, 20)
                                                    .padding(.vertical, 8)
                                                    .background(resultColor.opacity(0.15))
                                                    .cornerRadius(12)
                                            }
                                        }
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 20)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                                        )
                                    }
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
                                Text("Updated Game Summary")
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
                                    
                                    // Score in summary
                                    if hasScore {
                                        HStack {
                                            Image(systemName: "target")
                                                .foregroundColor(.blue)
                                                .frame(width: 30)
                                            
                                            HStack(spacing: 8) {
                                                Text("\(goalsFor) - \(goalsAgainst)")
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                
                                                let resultText = goalsFor > goalsAgainst ? "Win" : goalsFor < goalsAgainst ? "Loss" : "Draw"
                                                let resultColor: Color = goalsFor > goalsAgainst ? .green : goalsFor < goalsAgainst ? .red : .orange
                                                
                                                Text("(\(resultText))")
                                                    .font(.caption)
                                                    .foregroundColor(resultColor)
                                                    .fontWeight(.medium)
                                            }
                                        }
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
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Spacer
                        Color.clear.frame(height: 20)
                    }
                }
            }
            .navigationTitle("Edit Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGameChanges()
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
    
    func saveGameChanges() {
        print("🔄 EditGameView: Starting saveGameChanges()")
        print("   Game ID: \(game.id)")
        print("   Team ID: \(team.id)")
        print("   Original opponent: '\(game.opponent)'")
        print("   New opponent: '\(opponent.trimmingCharacters(in: .whitespacesAndNewlines))'")
        print("   Original date: \(game.date)")
        print("   New date: \(gameDate)")
        print("   Original isHome: \(game.isHome)")
        print("   New isHome: \(isHome)")
        print("   Original location: '\(game.location ?? "nil")'")
        print("   New location parts: location='\(location)', address='\(address)'")
        print("   Has score: \(hasScore)")
        if hasScore {
            print("   Goals for: \(goalsFor), Goals against: \(goalsAgainst)")
        }
        
        let gameLocation: String? = {
            if location.isEmpty {
                return nil
            } else if !address.isEmpty {
                return "\(location) - \(address)"
            } else {
                return location
            }
        }()
        
        print("   Computed new location: '\(gameLocation ?? "nil")'")
        
        // Update the game object
        var updatedGame = game
        updatedGame.opponent = opponent.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedGame.date = gameDate
        updatedGame.isHome = isHome
        updatedGame.location = gameLocation
        updatedGame.notes = notes.isEmpty ? nil : notes
        
        // Handle score
        if hasScore {
            if updatedGame.result == nil {
                updatedGame.result = GameResult(goalsFor: goalsFor, goalsAgainst: goalsAgainst)
                print("   Created new GameResult: \(goalsFor)-\(goalsAgainst)")
            } else {
                updatedGame.result?.goalsFor = goalsFor
                updatedGame.result?.goalsAgainst = goalsAgainst
                print("   Updated existing GameResult: \(goalsFor)-\(goalsAgainst)")
            }
        } else {
            updatedGame.result = nil
            print("   Removed game result (no score)")
        }
        
        print("   Updated game object created")
        print("   Calling teamManager.updateGame()")
        
        // Update the game in the team using TeamManager
        teamManager.updateGame(in: team, game: updatedGame)
        
        print("   teamManager.updateGame() completed")
        print("   Updating binding and dismissing view")
        
        // Update the binding
        game = updatedGame
        
        // Add a small delay to see if persistence happens
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("   0.5s after save - checking if game persisted in team...")
            if let foundGame = team.games.first(where: { $0.id == updatedGame.id }) {
                print("   ✅ Game found in team: opponent='\(foundGame.opponent)', date=\(foundGame.date)")
                if let result = foundGame.result {
                    print("   ✅ Game result: \(result.goalsFor)-\(result.goalsAgainst)")
                } else {
                    print("   ✅ Game has no result (as expected)")
                }
            } else {
                print("   ❌ Game NOT found in team after save!")
            }
        }
        
        presentationMode.wrappedValue.dismiss()
    }
    
    // Game Location Model (reused from SuperEnhancedNewGameView)
    struct GameLocation: Identifiable {
        let id = UUID()
        let name: String
        let address: String
        var isDefault: Bool = false
    }
    
    // Game Location Picker View (reused from SuperEnhancedNewGameView)
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
}
