import SwiftUI
import MapKit

// MARK: - Enhanced Practice Management View (UPDATED with flexible time management)
struct ImprovedNewPracticeView: View {
    @Binding var team: Team
    @EnvironmentObject var teamManager: TeamManager
    @State private var practiceDate = Date()
    @State private var selectedHour = 4 // Default to 4 PM
    @State private var selectedMinute = 0 // Default to :00
    @State private var selectedPeriod = 1 // 0 = AM, 1 = PM
    @State private var duration = 60 // Default 60 minutes
    @State private var selectedDrills: [DrillWithCustomTime] = []
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showingDrillDetail = false
    @State private var selectedDrill: Drill?
    @State private var showingCustomDrill = false
    @State private var location = ""
    @State private var notes = ""
    @State private var weather = "Clear"
    @State private var showingLocationPicker = false
    @State private var selectedMapItem: MKMapItem?
    @Environment(\.presentationMode) var presentationMode
    
    let weatherOptions = ["Clear", "Cloudy", "Rainy", "Windy", "Hot", "Cold", "Indoor"]
    let durationOptions = [30, 45, 60, 75, 90, 105, 120] // 15-minute intervals
    let hours = Array(1...12)
    let minutes = [0, 15, 30, 45]
    let periods = ["AM", "PM"]
    
    var totalDrillDuration: Int {
        selectedDrills.reduce(0) { $0 + $1.customDuration }
    }
    
    var remainingTime: Int {
        duration - totalDrillDuration
    }
    
    var timeStatus: TimeStatus {
        if totalDrillDuration == duration {
            return .perfect
        } else if totalDrillDuration < duration {
            return .under
        } else {
            return .over
        }
    }
    
    var filteredDrills: [Drill] {
        let allDrills = DrillLibrary.shared.getAllDrills()
        let categoryFiltered = selectedCategory == "All" ?
        allDrills :
        allDrills.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var categories: [String] {
        ["All"] + DrillLibrary.shared.allCategories
    }
    
    var formattedTime: String {
        let hourDisplay = selectedHour == 0 ? 12 : selectedHour
        let minuteString = String(format: "%02d", selectedMinute)
        return "\(hourDisplay):\(minuteString) \(periods[selectedPeriod])"
    }
    
    var finalPracticeDateTime: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: practiceDate)
        let hour24 = selectedPeriod == 0 ? (selectedHour == 12 ? 0 : selectedHour) : (selectedHour == 12 ? 12 : selectedHour + 12)
        components.hour = hour24
        components.minute = selectedMinute
        return Calendar.current.date(from: components) ?? practiceDate
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Compact Header
                compactPracticeHeader
                
                // Selected Drills Timeline (only if drills selected)
                if !selectedDrills.isEmpty {
                    selectedDrillsTimeline
                }
                
                // Search and Filter
                searchAndFilterSection
                
                // Available Drills (Main Focus)
                availableDrillsSection
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plan Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createPractice()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedDrills.isEmpty)
                }
            }
            .sheet(isPresented: $showingDrillDetail) {
                if let drill = selectedDrill {
                    DrillDetailView(drill: drill)
                }
            }
            .sheet(isPresented: $showingCustomDrill) {
                ImprovedCustomDrillView { newDrill in
                    DrillLibrary.shared.addCustomDrill(newDrill)
                    selectedDrills.append(DrillWithCustomTime(drill: newDrill, customDuration: newDrill.duration))
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedMapItem: $selectedMapItem)
                    .onDisappear {
                        if let mapItem = selectedMapItem {
                            location = mapItem.name ?? ""
                        }
                    }
            }
        }
    }
    
    // MARK: - Compact Practice Header
    @ViewBuilder
    private var compactPracticeHeader: some View {
        VStack(spacing: 12) {
            // Date and Time Row
            HStack(spacing: 16) {
                // Date Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $practiceDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                }
                
                // Time Pickers
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        // Hour
                        Picker("Hour", selection: $selectedHour) {
                            ForEach(hours, id: \.self) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 60)
                        
                        Text(":")
                            .fontWeight(.medium)
                        
                        // Minute
                        Picker("Minute", selection: $selectedMinute) {
                            ForEach(minutes, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 70)
                        
                        // AM/PM
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(Array(periods.enumerated()), id: \.offset) { index, period in
                                Text(period).tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 70)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Duration and Details Row
            HStack(spacing: 16) {
                // Duration
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Duration", selection: $duration) {
                        ForEach(durationOptions, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Location
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button(action: { showingLocationPicker = true }) {
                        HStack {
                            Text(location.isEmpty ? "Add Location" : location)
                                .foregroundColor(location.isEmpty ? .blue : .primary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Weather
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Weather", selection: $weather) {
                        ForEach(weatherOptions, id: \.self) { option in
                            HStack {
                                Image(systemName: weatherIcon(for: option))
                                Text(option)
                            }
                            .tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .onAppear {
            // Set default time to 4:00 PM
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: Date())
            if let hour = components.hour {
                if hour == 0 {
                    selectedHour = 12
                    selectedPeriod = 0 // AM
                } else if hour <= 12 {
                    selectedHour = hour
                    selectedPeriod = hour == 12 ? 1 : 0 // PM if 12, otherwise AM
                } else {
                    selectedHour = hour - 12
                    selectedPeriod = 1 // PM
                }
            }
            if let minute = components.minute {
                // Round to nearest 15-minute increment
                selectedMinute = (minute / 15) * 15
            }
        }
    }
    
    @ViewBuilder
    private var selectedDrillsTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Practice Timeline")
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(totalDrillDuration) / \(duration) min")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(timeStatus.textColor)
                    
                    Text(timeStatus.message)
                        .font(.caption)
                        .foregroundColor(timeStatus.textColor)
                }
            }
            .padding(.horizontal)
            
            // Time status indicator
            if timeStatus == .over {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Practice may run longer than scheduled. Consider adjusting drill times or practice duration.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(selectedDrills.enumerated()), id: \.element.id) { index, drillWithTime in
                        SelectedDrillCard(
                            drillWithTime: drillWithTime,
                            index: index + 1,
                            onRemove: {
                                selectedDrills.removeAll { $0.id == drillWithTime.id }
                            },
                            onMoveUp: index > 0 ? {
                                selectedDrills.swapAt(index, index - 1)
                            } : nil,
                            onMoveDown: index < selectedDrills.count - 1 ? {
                                selectedDrills.swapAt(index, index + 1)
                            } : nil,
                            onTimeChange: { newTime in
                                selectedDrills[index].customDuration = newTime
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search drills...", text: $searchText)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        CategoryChip(
                            title: category,
                            isSelected: selectedCategory == category,
                            count: category == "All" ?
                            DrillLibrary.shared.getAllDrills().count :
                                DrillLibrary.shared.getDrills(for: category).count
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var availableDrillsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Drills")
                    .font(.headline)
                Spacer()
                Button(action: { showingCustomDrill = true }) {
                    Label("Create Custom", systemImage: "plus.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                if filteredDrills.isEmpty {
                    EmptyDrillsView()
                } else {
                    // LIST FORMAT instead of grid
                    LazyVStack(spacing: 8) {
                        ForEach(filteredDrills) { drill in
                            DrillListRow(
                                drill: drill,
                                isSelected: selectedDrills.contains { $0.drill.id == drill.id },
                                onTap: {
                                    toggleDrillSelection(drill)
                                },
                                onInfo: {
                                    selectedDrill = drill
                                    showingDrillDetail = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Bottom padding for tab bar
                Color.clear.frame(height: 100)
            }
        }
    }
    
    // MARK: - Methods
    private func toggleDrillSelection(_ drill: Drill) {
        if selectedDrills.contains(where: { $0.drill.id == drill.id }) {
            selectedDrills.removeAll { $0.drill.id == drill.id }
        } else {
            selectedDrills.append(DrillWithCustomTime(drill: drill, customDuration: drill.duration))
        }
    }
    
    private func weatherIcon(for weather: String) -> String {
        switch weather {
        case "Clear": return "sun.max.fill"
        case "Cloudy": return "cloud.fill"
        case "Rainy": return "cloud.rain.fill"
        case "Windy": return "wind"
        case "Hot": return "thermometer.sun.fill"
        case "Cold": return "thermometer.snowflake"
        case "Indoor": return "house.fill"
        default: return "questionmark.circle"
        }
    }
    
    private func createPractice() {
        let practice = Practice(
            date: finalPracticeDateTime,
            duration: duration,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes,
            attendees: [],
            drills: selectedDrills.map { $0.drill },
            attendance: Dictionary(uniqueKeysWithValues: team.players.map { ($0.id, false) }),
            weather: weather
        )
        
        // Use TeamManager method instead of binding manipulation
        teamManager.addPractice(to: team, practice: practice)
        
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Helper Models
struct DrillWithCustomTime: Identifiable {
    let id = UUID()
    let drill: Drill
    var customDuration: Int
    
    init(drill: Drill, customDuration: Int) {
        self.drill = drill
        self.customDuration = customDuration
    }
}

enum TimeStatus {
    case perfect
    case under
    case over
    
    var textColor: Color {
        switch self {
        case .perfect: return .green
        case .under: return .blue
        case .over: return .orange
        }
    }
    
    var message: String {
        switch self {
        case .perfect: return "Perfect timing!"
        case .under: return "Time remaining"
        case .over: return "Over scheduled time"
        }
    }
}

// MARK: - Updated Drill List Row (No time restrictions)
struct DrillListRow: View {
    let drill: Drill
    let isSelected: Bool
    let onTap: () -> Void
    let onInfo: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Drill Info
            VStack(alignment: .leading, spacing: 4) {
                Text(drill.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(drill.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label("\(drill.duration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(drill.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text(drill.difficulty)
                        .font(.caption)
                        .foregroundColor(difficultyColor(for: drill.difficulty))
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                
                Button(action: onTap) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundColor(isSelected ? .green : .blue)
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 0.5)
                )
        )
    }
    
    private func difficultyColor(for difficulty: String) -> Color {
        switch difficulty {
        case "Easy": return .green
        case "Medium": return .orange
        case "Hard": return .red
        default: return .gray
        }
    }
}

// MARK: - Updated Selected Drill Card with Time Editing
struct SelectedDrillCard: View {
    let drillWithTime: DrillWithCustomTime
    let index: Int
    let onRemove: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let onTimeChange: (Int) -> Void
    
    @State private var showingTimeEditor = false
    
    let timeOptions = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 75, 90]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.blue))
                
                Spacer()
                
                Menu {
                    Menu("Change Time") {
                        ForEach(timeOptions, id: \.self) { time in
                            Button("\(time) min") {
                                onTimeChange(time)
                            }
                        }
                    }
                    
                    Divider()
                    
                    if let moveUp = onMoveUp {
                        Button(action: moveUp) {
                            Label("Move Up", systemImage: "arrow.up")
                        }
                    }
                    if let moveDown = onMoveDown {
                        Button(action: moveDown) {
                            Label("Move Down", systemImage: "arrow.down")
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(drillWithTime.drill.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Time display with edit capability
                Button(action: { showingTimeEditor = true }) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(drillWithTime.customDuration) min")
                            .font(.caption2)
                        if drillWithTime.customDuration != drillWithTime.drill.duration {
                            Text("(was \(drillWithTime.drill.duration))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.blue)
                }
                .sheet(isPresented: $showingTimeEditor) {
                    NavigationView {
                        VStack(spacing: 20) {
                            Text("Adjust Time for \(drillWithTime.drill.name)")
                                .font(.headline)
                                .padding()
                            
                            Text("Default: \(drillWithTime.drill.duration) minutes")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                ForEach(timeOptions, id: \.self) { time in
                                    Button(action: {
                                        onTimeChange(time)
                                        showingTimeEditor = false
                                    }) {
                                        Text("\(time) min")
                                            .font(.subheadline)
                                            .foregroundColor(time == drillWithTime.customDuration ? .white : .blue)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(time == drillWithTime.customDuration ? Color.blue : Color.blue.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding()
                            
                            Spacer()
                        }
                        .navigationTitle("Adjust Time")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingTimeEditor = false
                                }
                            }
                        }
                    }
                }
                
                Text(drillWithTime.drill.category)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .frame(width: 120)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("(\(count))")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Empty Drills View
struct EmptyDrillsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sportscourt.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No drills found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try a different category or search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Edit Practice View
struct EditPracticeView: View {
    @Binding var practice: Practice
    @Binding var team: Team
    @EnvironmentObject var teamManager: TeamManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var practiceDate: Date
    @State private var duration: Int
    @State private var selectedDrills: [Drill]
    @State private var location: String
    @State private var notes: String
    @State private var weather: String
    @State private var attendance: [UUID: Bool]
    
    @State private var showingDrillPicker = false
    @State private var showingAttendance = false
    @State private var hasChanges = false
    
    let weatherOptions = ["Clear", "Cloudy", "Rainy", "Windy", "Hot", "Cold", "Indoor"]
    let durationOptions = [30, 45, 60, 75, 90, 105, 120]
    
    init(practice: Binding<Practice>, team: Binding<Team>) {
        self._practice = practice
        self._team = team
        
        // Initialize state from existing practice
        self._practiceDate = State(initialValue: practice.wrappedValue.date)
        self._duration = State(initialValue: practice.wrappedValue.duration)
        self._selectedDrills = State(initialValue: practice.wrappedValue.drills)
        self._location = State(initialValue: practice.wrappedValue.location ?? "")
        self._notes = State(initialValue: practice.wrappedValue.notes ?? "")
        self._weather = State(initialValue: practice.wrappedValue.weather ?? "Clear")
        self._attendance = State(initialValue: practice.wrappedValue.attendance)
    }
    
    var totalDrillDuration: Int {
        selectedDrills.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Date and Duration Section
                Section("Schedule") {
                    DatePicker("Date & Time", selection: $practiceDate)
                        .onChange(of: practiceDate) { _ in hasChanges = true }
                    
                    Picker("Duration", selection: $duration) {
                        ForEach(durationOptions, id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .onChange(of: duration) { _ in hasChanges = true }
                }
                
                // Location and Weather Section
                Section("Details") {
                    TextField("Location", text: $location)
                        .onChange(of: location) { _ in hasChanges = true }
                    
                    Picker("Weather", selection: $weather) {
                        ForEach(weatherOptions, id: \.self) { option in
                            HStack {
                                Image(systemName: weatherIcon(for: option))
                                Text(option)
                            }
                            .tag(option)
                        }
                    }
                    .onChange(of: weather) { _ in hasChanges = true }
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: notes) { _ in hasChanges = true }
                }
                
                // Drills Section
                Section("Drills") {
                    HStack {
                        Text("Total Duration: \(totalDrillDuration) min")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Manage Drills") {
                            showingDrillPicker = true
                        }
                    }
                    
                    if !selectedDrills.isEmpty {
                        ForEach(selectedDrills) { drill in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(drill.name)
                                        .font(.subheadline)
                                    Text("\(drill.duration) min • \(drill.category)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .onChange(of: selectedDrills) { _ in hasChanges = true }
                
                // Attendance Section
                Section("Attendance") {
                    Button(action: { showingAttendance = true }) {
                        HStack {
                            Text("Manage Attendance")
                            Spacer()
                            Text("\(attendance.values.filter { $0 }.count) / \(team.players.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePractice()
                    }
                    .disabled(!hasChanges)
                }
            }
            .sheet(isPresented: $showingDrillPicker) {
                DrillPickerView(
                    selectedDrills: $selectedDrills,
                    maxDuration: duration
                ) { drills in
                    selectedDrills = drills
                }
            }
            .sheet(isPresented: $showingAttendance) {
                AttendanceView(
                    team: team,
                    attendance: $attendance
                ) { newAttendance in
                    attendance = newAttendance
                    hasChanges = true
                }
            }
        }
    }
    
    private func weatherIcon(for weather: String) -> String {
        switch weather {
        case "Clear": return "sun.max.fill"
        case "Cloudy": return "cloud.fill"
        case "Rainy": return "cloud.rain.fill"
        case "Windy": return "wind"
        case "Hot": return "thermometer.sun.fill"
        case "Cold": return "thermometer.snowflake"
        case "Indoor": return "house.fill"
        default: return "questionmark.circle"
        }
    }
    
    private func savePractice() {
        practice.date = practiceDate
        practice.duration = duration
        practice.drills = selectedDrills
        practice.location = location.isEmpty ? nil : location
        practice.notes = notes.isEmpty ? nil : notes
        practice.weather = weather.isEmpty ? nil : weather
        practice.attendance = attendance
        
        teamManager.updateTeam(team)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Drill Picker View
struct DrillPickerView: View {
    @Binding var selectedDrills: [Drill]
    let maxDuration: Int
    let onSave: ([Drill]) -> Void
    
    @State private var tempSelectedDrills: [Drill] = []
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @Environment(\.presentationMode) var presentationMode
    
    var categories: [String] {
        ["All"] + DrillLibrary.shared.allCategories
    }
    
    var filteredDrills: [Drill] {
        let allDrills = DrillLibrary.shared.getAllDrills()
        let categoryFiltered = selectedCategory == "All" ?
        allDrills :
        allDrills.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var totalDuration: Int {
        tempSelectedDrills.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        Text("Select Drills")
                            .font(.largeTitle)
                            .bold()
                        Spacer()
                    }
                    
                    HStack {
                        Text("Selected: \(tempSelectedDrills.count)")
                            .font(.subheadline)
                        Spacer()
                        Text("Duration: \(totalDuration) / \(maxDuration) min")
                            .font(.subheadline)
                            .foregroundColor(totalDuration > maxDuration ? .red : .primary)
                    }
                    .padding(.horizontal)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search drills...", text: $searchText)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                CategoryChip(
                                    title: category,
                                    isSelected: selectedCategory == category,
                                    count: category == "All" ?
                                    DrillLibrary.shared.getAllDrills().count :
                                        DrillLibrary.shared.getDrills(for: category).count
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                }
                .padding()
                
                // Drills List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredDrills) { drill in
                            DrillPickerRow(
                                drill: drill,
                                isSelected: tempSelectedDrills.contains { $0.id == drill.id },
                                onToggle: {
                                    if tempSelectedDrills.contains(where: { $0.id == drill.id }) {
                                        tempSelectedDrills.removeAll { $0.id == drill.id }
                                    } else {
                                        tempSelectedDrills.append(drill)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .overlay(
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                        
                        Button("Save") {
                            onSave(tempSelectedDrills)
                            presentationMode.wrappedValue.dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            )
        }
        .onAppear {
            tempSelectedDrills = selectedDrills
        }
    }
}

// MARK: - Drill Picker Row
struct DrillPickerRow: View {
    let drill: Drill
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(drill.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Label("\(drill.duration) min", systemImage: "clock")
                        .font(.caption)
                    Text("•")
                    Text(drill.category)
                        .font(.caption)
                    Text("•")
                    Text(drill.difficulty)
                        .font(.caption)
                        .foregroundColor(difficultyColor(for: drill.difficulty))
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .onTapGesture {
            onToggle()
        }
    }
    
    private func difficultyColor(for difficulty: String) -> Color {
        switch difficulty {
        case "Easy": return .green
        case "Medium": return .orange
        case "Hard": return .red
        default: return .gray
        }
    }
}

// MARK: - Attendance View
struct AttendanceView: View {
    let team: Team
    @Binding var attendance: [UUID: Bool]
    let onSave: ([UUID: Bool]) -> Void
    
    @State private var tempAttendance: [UUID: Bool]
    @Environment(\.presentationMode) var presentationMode
    
    init(team: Team, attendance: Binding<[UUID: Bool]>, onSave: @escaping ([UUID: Bool]) -> Void) {
        self.team = team
        self._attendance = attendance
        self.onSave = onSave
        self._tempAttendance = State(initialValue: attendance.wrappedValue)
    }
    
    var attendanceCount: Int {
        tempAttendance.values.filter { $0 }.count
    }
    
    var sortedPlayers: [Player] {
        team.players.sorted(by: { $0.jerseyNumber < $1.jerseyNumber })
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Attendance")
                            .font(.largeTitle)
                            .bold()
                        Text("\(attendanceCount) / \(team.players.count) Present")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    // Quick Actions
                    Menu {
                        Button("Mark All Present") {
                            for player in team.players {
                                tempAttendance[player.id] = true
                            }
                        }
                        Button("Mark All Absent") {
                            for player in team.players {
                                tempAttendance[player.id] = false
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                    }
                }
                .padding()
                
                // Players List
                List(sortedPlayers, id: \.id) { player in
                    AttendanceRowView(
                        player: player,
                        isPresent: tempAttendance[player.id] ?? false,
                        onToggle: {
                            tempAttendance[player.id] = !(tempAttendance[player.id] ?? false)
                        }
                    )
                }
                .listStyle(InsetListStyle())
                
                // Save/Cancel Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    
                    Button("Save") {
                        onSave(tempAttendance)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Attendance Row View
struct AttendanceRowView: View {
    let player: Player
    let isPresent: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            // Jersey Number
            Text("#\(player.jerseyNumber)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.blue)
                .clipShape(Circle())
            
            // Player Name
            VStack(alignment: .leading) {
                Text(player.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(player.preferredPosition)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Attendance Toggle
            Button(action: onToggle) {
                Image(systemName: isPresent ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isPresent ? .green : .gray)
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Practice Detail View (UPDATED with Share Functionality)
struct PracticeDetailView: View {
    @Binding var practice: Practice
    @Binding var team: Team
    @EnvironmentObject var teamManager: TeamManager
    @State private var showingEditPractice = false
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showingDeleteAlert = false
    @State private var showingOptionsMenu = false
    @Environment(\.presentationMode) var presentationMode
    
    var attendanceCount: Int {
        practice.attendance.values.filter { $0 }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header with Ellipsis Menu
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Practice Details")
                            .font(.largeTitle)
                            .bold()
                        Text(practice.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Ellipsis Menu Button
                    Button(action: {
                        showingOptionsMenu = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                            Text("\(practice.duration) minutes")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Location and Weather
                    if practice.location != nil || practice.weather != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            if let location = practice.location {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.red)
                                        .frame(width: 30)
                                    Text(location)
                                        .font(.subheadline)
                                }
                            }
                            
                            if let weather = practice.weather {
                                HStack {
                                    Image(systemName: weatherIcon(for: weather))
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    Text(weather)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Practice Plan
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Practice Plan")
                                .font(.headline)
                            Spacer()
                            Text("\(practice.drills.count) drills")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        if practice.drills.isEmpty {
                            Text("No drills added yet")
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .padding(.horizontal)
                        } else {
                            ForEach(Array(practice.drills.enumerated()), id: \.element.id) { index, drill in
                                PracticeDrillRow(drill: drill, index: index + 1)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Attendance
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Attendance")
                                .font(.headline)
                            Spacer()
                            Text("\(attendanceCount) / \(team.players.count)")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(team.players.sorted(by: { $0.jerseyNumber < $1.jerseyNumber })) { player in
                                if let attended = practice.attendance[player.id] {
                                    HStack {
                                        Image(systemName: attended ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(attended ? .green : .red)
                                        Text(player.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Notes
                    if let notes = practice.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Text(notes)
                                .font(.subheadline)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationBarHidden(true)
        .actionSheet(isPresented: $showingOptionsMenu) {
            ActionSheet(
                title: Text("Practice Options"),
                buttons: [
                    .default(Text("Edit Practice")) {
                        showingEditPractice = true
                    },
                    .default(Text("Share Practice Report")) {
                        sharePracticeReport()
                    },
                    .destructive(Text("Delete Practice")) {
                        showingDeleteAlert = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingEditPractice) {
            EditPracticeView(practice: $practice, team: $team)
                .environmentObject(teamManager)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
        .alert("Delete Practice", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePractice()
            }
        } message: {
            Text("Are you sure you want to permanently delete this practice session? This action cannot be undone.")
        }
    }
    
    private func deletePractice() {
        print("🗑️ Attempting to delete practice with ID: \(practice.id)")
        
        // Use TeamManager method instead of direct binding manipulation
        teamManager.deletePractice(from: team, practiceId: practice.id)
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func weatherIcon(for weather: String) -> String {
        switch weather.lowercased() {
        case "clear", "sunny": return "sun.max.fill"
        case "cloudy", "overcast": return "cloud.fill"
        case "rainy", "rain": return "cloud.rain.fill"
        case "windy": return "wind"
        case "hot": return "thermometer.sun.fill"
        case "cold": return "thermometer.snowflake"
        case "indoor": return "house.fill"
        default: return "cloud.sun.fill"
        }
    }
    
    // MARK: - Share Practice Report
    private func sharePracticeReport() {
        let fullContentView = VStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Practice Session")
                            .font(.title2)
                            .bold()
                        
                        Text(practice.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Practice Report")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(practice.duration) min")
                            .font(.title2)
                            .bold()
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            
            FullCapturePracticeContent(practice: practice, team: team)
        }
            .background(Color(.systemGroupedBackground))
        
        let hostingController = UIHostingController(rootView: fullContentView)
        hostingController.view.backgroundColor = UIColor.systemGroupedBackground
        
        let screenWidth = UIScreen.main.bounds.width
        let maxHeight: CGFloat = 10000
        
        let targetSize = CGSize(width: screenWidth, height: maxHeight)
        hostingController.view.frame = CGRect(origin: .zero, size: targetSize)
        
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        let fittingSize = hostingController.view.systemLayoutSizeFitting(
            CGSize(width: screenWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        let finalSize = CGSize(width: screenWidth, height: max(fittingSize.height + 100, 400))
        
        hostingController.view.frame = CGRect(origin: .zero, size: finalSize)
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        let renderer = UIGraphicsImageRenderer(size: finalSize)
        let image = renderer.image { context in
            hostingController.view.drawHierarchy(in: CGRect(origin: .zero, size: finalSize), afterScreenUpdates: true)
        }
        
        shareImage = image
        showingShareSheet = true
    }
}

// MARK: - Full Capture Practice Content (Non-scrollable version for sharing)
struct FullCapturePracticeContent: View {
    let practice: Practice
    let team: Team
    
    var attendanceCount: Int {
        practice.attendance.values.filter { $0 }.count
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Practice Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Practice Summary")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Date & Time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(practice.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Text("Duration")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(practice.duration) minutes")
                            .font(.subheadline)
                    }
                    
                    if let location = practice.location {
                        HStack {
                            Text("Location")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(location)
                                .font(.subheadline)
                        }
                    }
                    
                    if let weather = practice.weather {
                        HStack {
                            Text("Weather")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(weather)
                                .font(.subheadline)
                        }
                    }
                    
                    
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)
            }
            
            // Practice Plan
            if !practice.drills.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Practice Plan (\(practice.drills.count) drills)")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // ALL drills without ScrollView - this will show everything
                    VStack(spacing: 12) {
                        ForEach(Array(practice.drills.enumerated()), id: \.element.id) { index, drill in
                            FullCapturePracticeDrillRow(drill: drill, index: index + 1)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            
            
            // Notes
            if let notes = practice.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text(notes)
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Full Capture Practice Drill Row (Non-scrollable version)
struct FullCapturePracticeDrillRow: View {
    let drill: Drill
    let index: Int
    
    private var displayInstructions: [String] {
        if !drill.instructions.isEmpty {
            return drill.instructions
        } else {
            return getDefaultInstructions(for: drill)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("\(index)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.blue))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(drill.name)
                        .font(.subheadline)
                        .bold()
                    
                    HStack {
                        Label("\(drill.duration) min", systemImage: "clock")
                        Text("•")
                        Text(drill.category)
                        Text("•")
                        Text(drill.difficulty)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Always show instructions for sharing
            VStack(alignment: .leading, spacing: 8) {
                Text("Instructions:")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.blue)
                
                ForEach(Array(displayInstructions.enumerated()), id: \.offset) { stepIndex, instruction in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(stepIndex + 1).")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        
                        Text(instruction)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                    .padding(.leading, 32)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
    
    private func getDefaultInstructions(for drill: Drill) -> [String] {
        switch drill.category.lowercased() {
        case "warm-up":
            return [
                "Start with light jogging to warm up muscles",
                "Perform dynamic stretches focusing on legs and core",
                "Gradually increase intensity with movement exercises",
                "Ensure all players are properly warmed up before continuing"
            ]
        case "passing":
            return [
                "Set up players in pairs or small groups",
                "Focus on accuracy over power",
                "Use both feet when passing",
                "Encourage communication between players",
                "Progress from stationary to moving passes"
            ]
        case "shooting":
            return [
                "Set up shooting stations with proper angles",
                "Practice with both feet",
                "Focus on placement before power",
                "Work on different types of shots (low, high, side-foot)",
                "Include shots under pressure"
            ]
        case "defending":
            return [
                "Practice proper defensive stance",
                "Focus on staying between player and goal",
                "Work on timing of challenges",
                "Practice communication with teammates",
                "Emphasize patience and positioning"
            ]
        case "dribbling":
            return [
                "Set up cones or markers for direction changes",
                "Practice with both feet",
                "Keep ball close to body",
                "Focus on head up while dribbling",
                "Vary pace and direction"
            ]
        case "fitness":
            return [
                "Ensure proper form throughout exercise",
                "Monitor players for fatigue",
                "Provide adequate rest between sets",
                "Encourage proper breathing technique",
                "Scale intensity based on fitness levels"
            ]
        default:
                return [
                    "Set up the drill according to description",
                    "Ensure all players understand their roles",
                    "Focus on technique and safety",
                    "Provide feedback and encouragement",
                    "Adapt difficulty based on skill level"
                ]
            }
        }
    }

    // MARK: - Enhanced Practice Drill Row with Always-Visible Expand
    struct PracticeDrillRow: View {
        let drill: Drill
        let index: Int
        @State private var isExpanded = false
        
        private var displayInstructions: [String] {
            if !drill.instructions.isEmpty {
                return drill.instructions
            } else {
                return getDefaultInstructions(for: drill)
            }
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text("\(index)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.blue))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(drill.name)
                            .font(.subheadline)
                            .bold()
                        
                        HStack {
                            Label("\(drill.duration) min", systemImage: "clock")
                            Text("•")
                            Text(drill.category)
                            Text("•")
                            Text(drill.difficulty)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("\(displayInstructions.count) steps")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(displayInstructions.enumerated()), id: \.offset) { stepIndex, instruction in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(stepIndex + 1).")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                                
                                Text(instruction)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                            }
                            .padding(.leading, 32)
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
        
        private func getDefaultInstructions(for drill: Drill) -> [String] {
            switch drill.category.lowercased() {
            case "warm-up":
                return [
                    "Start with light jogging to warm up muscles",
                    "Perform dynamic stretches focusing on legs and core",
                    "Gradually increase intensity with movement exercises",
                    "Ensure all players are properly warmed up before continuing"
                ]
            case "passing":
                return [
                    "Set up players in pairs or small groups",
                    "Focus on accuracy over power",
                    "Use both feet when passing",
                    "Encourage communication between players",
                    "Progress from stationary to moving passes"
                ]
            case "shooting":
                return [
                    "Set up shooting stations with proper angles",
                    "Practice with both feet",
                    "Focus on placement before power",
                    "Work on different types of shots (low, high, side-foot)",
                    "Include shots under pressure"
                ]
            case "defending":
                return [
                    "Practice proper defensive stance",
                    "Focus on staying between player and goal",
                    "Work on timing of challenges",
                    "Practice communication with teammates",
                    "Emphasize patience and positioning"
                ]
            case "dribbling":
                return [
                    "Set up cones or markers for direction changes",
                    "Practice with both feet",
                    "Keep ball close to body",
                    "Focus on head up while dribbling",
                    "Vary pace and direction"
                ]
            case "fitness":
                return [
                    "Ensure proper form throughout exercise",
                    "Monitor players for fatigue",
                    "Provide adequate rest between sets",
                    "Encourage proper breathing technique",
                    "Scale intensity based on fitness levels"
                ]
            default:
                return [
                    "Set up the drill according to description",
                    "Ensure all players understand their roles",
                    "Focus on technique and safety",
                    "Provide feedback and encouragement",
                    "Adapt difficulty based on skill level"
                ]
            }
        }
    }

    // MARK: - Drill Detail View
    struct DrillDetailView: View {
        let drill: Drill
        @State private var showingEditDrill = false
        @Environment(\.presentationMode) var presentationMode
        
        var canEdit: Bool {
            DrillLibrary.shared.canEditDrill(drill)
        }
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(drill.name)
                                        .font(.largeTitle)
                                        .bold()
                                    
                                    HStack(spacing: 12) {
                                        Label("\(drill.duration) min", systemImage: "clock")
                                            .font(.subheadline)
                                        
                                        Text(drill.category)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(8)
                                        
                                        Text(drill.difficulty)
                                            .font(.subheadline)
                                            .foregroundColor(difficultyColor(for: drill.difficulty))
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        .padding()
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            Text(drill.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Equipment
                        if !drill.equipment.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Equipment Needed")
                                    .font(.headline)
                                ForEach(drill.equipment, id: \.self) { item in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text(item)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instructions")
                                .font(.headline)
                            
                            let instructions = drill.instructions.isEmpty ?
                            getDefaultInstructions(for: drill.category) :
                            drill.instructions
                            
                            ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Color.blue))
                                    
                                    Text(step)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        Color.clear.frame(height: 40)
                    }
                }
                .background(Color(.systemGroupedBackground))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if canEdit {
                            Button("Edit") {
                                showingEditDrill = true
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingEditDrill) {
                    EditCustomDrillView(drill: drill)
                }
            }
        }
        
        private func difficultyColor(for difficulty: String) -> Color {
            switch difficulty {
            case "Easy": return .green
            case "Medium": return .orange
            case "Hard": return .red
            default: return .gray
            }
        }
        
        private func getDefaultInstructions(for category: String) -> [String] {
            switch category.lowercased() {
            case "warm-up":
                return [
                    "Start with light jogging",
                    "Perform dynamic stretches",
                    "Gradually increase intensity",
                    "Ensure all players are properly warmed up"
                ]
            case "passing":
                return [
                    "Set up players in appropriate formation",
                    "Focus on accuracy and weight of pass",
                    "Use both feet",
                    "Progress from stationary to moving"
                ]
            default:
                return [
                    "Set up drill as described",
                    "Demonstrate proper technique",
                    "Provide feedback and encouragement",
                    "Adapt difficulty as needed"
                ]
            }
        }
    }

    // MARK: - Edit Custom Drill View
    struct EditCustomDrillView: View {
        let drill: Drill
        @State private var name: String
        @State private var description: String
        @State private var duration: Int
        @State private var category: String
        @State private var difficulty: String
        @State private var equipment: [String]
        @State private var newEquipment = ""
        @State private var instructions: [String]
        @State private var newInstruction = ""
        @Environment(\.presentationMode) var presentationMode
        
        let categories = DrillLibrary.categories
        let difficulties = ["Easy", "Medium", "Hard"]
        let durationOptions = [5, 10, 15, 20, 25, 30, 45, 60]
        
        init(drill: Drill) {
            self.drill = drill
            self._name = State(initialValue: drill.name)
            self._description = State(initialValue: drill.description)
            self._duration = State(initialValue: drill.duration)
            self._category = State(initialValue: drill.category)
            self._difficulty = State(initialValue: drill.difficulty)
            self._equipment = State(initialValue: drill.equipment)
            self._instructions = State(initialValue: drill.instructions)
        }
        
        var body: some View {
            NavigationView {
                Form {
                    Section("Basic Information") {
                        TextField("Drill Name", text: $name)
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                    }
                    
                    Section("Details") {
                        Picker("Duration", selection: $duration) {
                            ForEach(durationOptions, id: \.self) { minutes in
                                Text("\(minutes) minutes").tag(minutes)
                            }
                        }
                        
                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        
                        Picker("Difficulty", selection: $difficulty) {
                            ForEach(difficulties, id: \.self) { diff in
                                Text(diff).tag(diff)
                            }
                        }
                    }
                    
                    Section("Equipment") {
                        ForEach(equipment, id: \.self) { item in
                            HStack {
                                Text(item)
                                Spacer()
                                Button(action: {
                                    equipment.removeAll { $0 == item }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        HStack {
                            TextField("Add equipment...", text: $newEquipment)
                            Button("Add") {
                                if !newEquipment.isEmpty {
                                    equipment.append(newEquipment)
                                    newEquipment = ""
                                }
                            }
                            .disabled(newEquipment.isEmpty)
                        }
                    }
                    
                    Section("Instructions") {
                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack {
                                Text("\(index + 1).")
                                    .fontWeight(.medium)
                                    .frame(width: 25, alignment: .leading)
                                Text(instruction)
                                Spacer()
                                Button(action: {
                                    instructions.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        HStack {
                            TextField("Add instruction step...", text: $newInstruction)
                            Button("Add") {
                                if !newInstruction.isEmpty {
                                    instructions.append(newInstruction)
                                    newInstruction = ""
                                }
                            }
                            .disabled(newInstruction.isEmpty)
                        }
                    }
                }
                .navigationTitle("Edit Drill")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            updateDrill()
                        }
                        .disabled(name.isEmpty || description.isEmpty)
                    }
                }
            }
        }
        
        private func updateDrill() {
            var updatedDrill = drill
            updatedDrill.name = name
            updatedDrill.description = description
            updatedDrill.duration = duration
            updatedDrill.category = category
            updatedDrill.difficulty = difficulty
            updatedDrill.equipment = equipment
            updatedDrill.instructions = instructions
            
            DrillLibrary.shared.updateCustomDrill(updatedDrill)
            presentationMode.wrappedValue.dismiss()
        }
    }

    // MARK: - Location Picker View
    struct LocationPickerView: View {
        @Binding var selectedMapItem: MKMapItem?
        @State private var searchText = ""
        @State private var searchResults: [MKMapItem] = []
        @State private var isSearching = false
        @Environment(\.presentationMode) var presentationMode
        
        let commonLocations = [
            "Main Field",
            "Training Ground",
            "School Field",
            "Community Center",
            "Sports Complex",
            "Park Field"
        ]
        
        var body: some View {
            NavigationView {
                VStack {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search for a location...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                searchLocations()
                            }
                        
                        if isSearching {
                            ProgressView()
                        }
                    }
                    .padding()
                    
                    List {
                        // Common Locations
                        Section("Common Locations") {
                            ForEach(commonLocations, id: \.self) { location in
                                Button(action: {
                                    let item = MKMapItem()
                                    item.name = location
                                    selectedMapItem = item
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: "location.circle.fill")
                                            .foregroundColor(.blue)
                                        Text(location)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                        // Search Results
                        if !searchResults.isEmpty {
                            Section("Search Results") {
                                ForEach(searchResults, id: \.self) { item in
                                    Button(action: {
                                        selectedMapItem = item
                                        presentationMode.wrappedValue.dismiss()
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name ?? "Unknown Location")
                                                .foregroundColor(.primary)
                                            if let address = item.placemark.title {
                                                Text(address)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
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
            }
        }
        
        private func searchLocations() {
            isSearching = true
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchText
            
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                DispatchQueue.main.async {
                    self.isSearching = false
                    if let response = response {
                        self.searchResults = response.mapItems
                    }
                }
            }
        }
    }

    // MARK: - Improved Custom Drill Creation
    struct ImprovedCustomDrillView: View {
        @State private var name = ""
        @State private var description = ""
        @State private var duration = 15
        @State private var category = "Technical"
        @State private var difficulty = "Medium"
        @State private var equipment: [String] = []
        @State private var newEquipment = ""
        @State private var instructions: [String] = []
        @State private var newInstruction = ""
        @Environment(\.presentationMode) var presentationMode
        
        let categories = DrillLibrary.categories
        let difficulties = ["Easy", "Medium", "Hard"]
        let durationOptions = [5, 10, 15, 20, 25, 30, 45, 60]
        
        let onSave: (Drill) -> Void
        
        var body: some View {
            NavigationView {
                Form {
                    Section("Basic Information") {
                        TextField("Drill Name", text: $name)
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                            .overlay(
                                Text("Describe the drill objectives and key points...")
                                    .foregroundColor(.secondary)
                                    .opacity(description.isEmpty ? 1 : 0)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false),
                                alignment: .topLeading
                            )
                    }
                    
                    Section("Details") {
                        Picker("Duration", selection: $duration) {
                            ForEach(durationOptions, id: \.self) { minutes in
                                Text("\(minutes) minutes").tag(minutes)
                            }
                        }
                        
                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        
                        Picker("Difficulty", selection: $difficulty) {
                            ForEach(difficulties, id: \.self) { diff in
                                Text(diff).tag(diff)
                            }
                        }
                    }
                    
                    Section("Equipment") {
                        ForEach(equipment, id: \.self) { item in
                            HStack {
                                Text(item)
                                Spacer()
                                Button(action: {
                                    equipment.removeAll { $0 == item }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        HStack {
                            TextField("Add equipment...", text: $newEquipment)
                            Button("Add") {
                                if !newEquipment.isEmpty {
                                    equipment.append(newEquipment)
                                    newEquipment = ""
                                }
                            }
                            .disabled(newEquipment.isEmpty)
                        }
                    }
                    
                    Section("Instructions") {
                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack {
                                Text("\(index + 1).")
                                    .fontWeight(.medium)
                                    .frame(width: 25, alignment: .leading)
                                Text(instruction)
                                Spacer()
                                Button(action: {
                                    instructions.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        HStack {
                            TextField("Add instruction step...", text: $newInstruction)
                            Button("Add") {
                                if !newInstruction.isEmpty {
                                    instructions.append(newInstruction)
                                    newInstruction = ""
                                }
                            }
                            .disabled(newInstruction.isEmpty)
                        }
                    }
                }
                .navigationTitle("Create Custom Drill")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveDrill()
                        }
                        .disabled(name.isEmpty || description.isEmpty)
                    }
                }
            }
        }
        
        private func saveDrill() {
            let drill = Drill(
                name: name,
                description: description,
                duration: duration,
                category: category,
                difficulty: difficulty,
                equipment: equipment,
                playerCount: nil,
                objectives: [],
                instructions: instructions,
                variations: [],
                videoURL: nil
            )
            
            onSave(drill)
            presentationMode.wrappedValue.dismiss()
        }
    }
