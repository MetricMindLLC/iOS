import SwiftUI
import MapKit

// MARK: - Enhanced Drill Library with Local Customization
class DrillLibrary: ObservableObject {
    static let shared = DrillLibrary()
    
    @Published var customDrills: [Drill] = []
    @Published var modifiedPreloadedDrills: [UUID: Drill] = [:] // Store edited versions of preloaded drills
    @Published var hiddenPreloadedDrillIds: Set<UUID> = [] // Track "deleted" preloaded drills
    
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let customDrillsFileName = "customDrills.json"
    private let modifiedDrillsFileName = "modifiedPreloadedDrills.json"
    private let hiddenDrillsFileName = "hiddenPreloadedDrills.json"
    
    private var preloadedDrills: [Drill] = []
    
    private init() {
        preloadedDrills = getPrePopulatedDrills()
        loadCustomDrills()
        loadModifiedDrills()
        loadHiddenDrills()
    }
    
    // MARK: - Get All Drills (with local modifications applied)
    func getAllDrills() -> [Drill] {
        var allDrills: [Drill] = []
        
        // Add preloaded drills (with modifications applied, excluding hidden ones)
        for drill in preloadedDrills {
            // Skip if this drill has been "deleted" locally
            if hiddenPreloadedDrillIds.contains(drill.id) {
                continue
            }
            
            // Use modified version if it exists, otherwise use original
            if let modifiedDrill = modifiedPreloadedDrills[drill.id] {
                allDrills.append(modifiedDrill)
            } else {
                allDrills.append(drill)
            }
        }
        
        // Add custom drills
        allDrills.append(contentsOf: customDrills)
        
        return allDrills
    }
    
    func getDrills(for category: String) -> [Drill] {
        let allDrills = getAllDrills()
        return allDrills.filter { $0.category == category }
    }
    
    // MARK: - Drill Type Detection
    private func isPreloadedDrill(_ drill: Drill) -> Bool {
        return preloadedDrills.contains { $0.id == drill.id }
    }
    
    private func isCustomDrill(_ drill: Drill) -> Bool {
        return customDrills.contains { $0.id == drill.id }
    }
    
    // MARK: - Permissions
    func canEditDrill(_ drill: Drill) -> Bool {
        // Can edit custom drills or any preloaded drill (local modification)
        return isCustomDrill(drill) || isPreloadedDrill(drill)
    }
    
    func canDeleteDrill(_ drill: Drill) -> Bool {
        // Can delete custom drills or "hide" preloaded drills
        return isCustomDrill(drill) || isPreloadedDrill(drill)
    }
    
    func isPreloadedDrillModified(_ drill: Drill) -> Bool {
        return modifiedPreloadedDrills.keys.contains(drill.id)
    }
    
    // MARK: - Custom Drill Management (unchanged)
    func addCustomDrill(_ drill: Drill) {
        customDrills.append(drill)
        saveCustomDrills()
    }
    
    func updateCustomDrill(_ drill: Drill) {
        if let index = customDrills.firstIndex(where: { $0.id == drill.id }) {
            customDrills[index] = drill
            saveCustomDrills()
        }
    }
    
    func deleteCustomDrill(_ drill: Drill) {
        customDrills.removeAll { $0.id == drill.id }
        saveCustomDrills()
    }
    
    // MARK: - Universal Edit/Delete Methods
    func editDrill(_ drill: Drill, newDrill: Drill) {
        if isCustomDrill(drill) {
            // Edit custom drill directly
            updateCustomDrill(newDrill)
        } else if isPreloadedDrill(drill) {
            // Store modified version of preloaded drill
            modifiedPreloadedDrills[drill.id] = newDrill
            saveModifiedDrills()
        }
    }
    
    func deleteDrill(_ drill: Drill) {
        if isCustomDrill(drill) {
            // Actually delete custom drill
            deleteCustomDrill(drill)
        } else if isPreloadedDrill(drill) {
            // Hide preloaded drill
            hiddenPreloadedDrillIds.insert(drill.id)
            // Also remove any local modifications
            modifiedPreloadedDrills.removeValue(forKey: drill.id)
            saveHiddenDrills()
            saveModifiedDrills()
        }
    }
    
    // MARK: - Reset Functionality
    func resetDrillToDefault(_ drill: Drill) {
        if isPreloadedDrill(drill) {
            // Remove local modifications and unhide
            modifiedPreloadedDrills.removeValue(forKey: drill.id)
            hiddenPreloadedDrillIds.remove(drill.id)
            saveModifiedDrills()
            saveHiddenDrills()
        }
    }
    
    func resetAllDrillsToDefault() {
        modifiedPreloadedDrills.removeAll()
        hiddenPreloadedDrillIds.removeAll()
        saveModifiedDrills()
        saveHiddenDrills()
    }
    
    func getOriginalDrill(for drill: Drill) -> Drill? {
        return preloadedDrills.first { $0.id == drill.id }
    }
    
    // MARK: - Data Persistence
    private var customDrillsFileURL: URL {
        documentsDirectory.appendingPathComponent(customDrillsFileName)
    }
    
    private var modifiedDrillsFileURL: URL {
        documentsDirectory.appendingPathComponent(modifiedDrillsFileName)
    }
    
    private var hiddenDrillsFileURL: URL {
        documentsDirectory.appendingPathComponent(hiddenDrillsFileName)
    }
    
    private func saveCustomDrills() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(customDrills)
            try data.write(to: customDrillsFileURL)
            print("✅ Custom drills saved successfully")
        } catch {
            print("❌ Failed to save custom drills: \(error)")
        }
    }
    
    private func loadCustomDrills() {
        guard FileManager.default.fileExists(atPath: customDrillsFileURL.path) else {
            print("📱 No custom drills found")
            return
        }
        
        do {
            let data = try Data(contentsOf: customDrillsFileURL)
            customDrills = try JSONDecoder().decode([Drill].self, from: data)
            print("✅ Loaded \(customDrills.count) custom drills")
        } catch {
            print("❌ Failed to load custom drills: \(error)")
            customDrills = []
        }
    }
    
    private func saveModifiedDrills() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(modifiedPreloadedDrills)
            try data.write(to: modifiedDrillsFileURL)
            print("✅ Modified drills saved successfully")
        } catch {
            print("❌ Failed to save modified drills: \(error)")
        }
    }
    
    private func loadModifiedDrills() {
        guard FileManager.default.fileExists(atPath: modifiedDrillsFileURL.path) else {
            print("📱 No modified drills found")
            return
        }
        
        do {
            let data = try Data(contentsOf: modifiedDrillsFileURL)
            modifiedPreloadedDrills = try JSONDecoder().decode([UUID: Drill].self, from: data)
            print("✅ Loaded \(modifiedPreloadedDrills.count) modified drills")
        } catch {
            print("❌ Failed to load modified drills: \(error)")
            modifiedPreloadedDrills = [:]
        }
    }
    
    private func saveHiddenDrills() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(Array(hiddenPreloadedDrillIds))
            try data.write(to: hiddenDrillsFileURL)
            print("✅ Hidden drills saved successfully")
        } catch {
            print("❌ Failed to save hidden drills: \(error)")
        }
    }
    
    private func loadHiddenDrills() {
        guard FileManager.default.fileExists(atPath: hiddenDrillsFileURL.path) else {
            print("📱 No hidden drills found")
            return
        }
        
        do {
            let data = try Data(contentsOf: hiddenDrillsFileURL)
            let hiddenIds = try JSONDecoder().decode([UUID].self, from: data)
            hiddenPreloadedDrillIds = Set(hiddenIds)
            print("✅ Loaded \(hiddenPreloadedDrillIds.count) hidden drills")
        } catch {
            print("❌ Failed to load hidden drills: \(error)")
            hiddenPreloadedDrillIds = []
        }
    }
    
    // MARK: - Search
    func searchDrills(query: String) -> [Drill] {
        guard !query.isEmpty else { return getAllDrills() }
        
        return getAllDrills().filter { drill in
            drill.name.localizedCaseInsensitiveContains(query) ||
            drill.description.localizedCaseInsensitiveContains(query) ||
            drill.category.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - Categories
    var allCategories: [String] {
        Array(Set(getAllDrills().map { $0.category })).sorted()
    }
    
    // MARK: - Statistics
    var customizationStats: (modified: Int, hidden: Int, custom: Int) {
        return (
            modified: modifiedPreloadedDrills.count,
            hidden: hiddenPreloadedDrillIds.count,
            custom: customDrills.count
        )
    }
    
    // MARK: - Expanded Pre-populated Drills
    private func getPrePopulatedDrills() -> [Drill] {
        return [
            // WARM-UP DRILLS
            Drill(
                name: "Dynamic Warm-up Circuit",
                description: "Complete warm-up routine with dynamic movements",
                duration: 10,
                category: "Warm-up",
                difficulty: "Easy",
                equipment: ["Cones"],
                instructions: [
                    "Light jog around the field (2 laps)",
                    "High knees - 20 yards",
                    "Butt kicks - 20 yards",
                    "Side shuffles - 20 yards each direction",
                    "Karaoke/Carioca - 20 yards each direction",
                    "Walking lunges - 10 each leg",
                    "Leg swings - 10 each direction",
                    "Arm circles and stretching"
                ]
            ),
            Drill(
                name: "Ball Juggling Progression",
                description: "Individual ball control warm-up with progressive difficulty",
                duration: 8,
                category: "Warm-up",
                difficulty: "Easy",
                equipment: ["Soccer balls"],
                instructions: [
                    "Start with catching ball after one bounce",
                    "Progress to keeping ball in air with feet only",
                    "Add thighs to the juggling sequence",
                    "Include head touches when comfortable",
                    "Challenge: Alternate feet with each touch",
                    "Advanced: Around the world juggling pattern"
                ]
            ),
            Drill(
                name: "Partner Passing Warm-up",
                description: "Two-player passing sequence to warm up touch and passing",
                duration: 10,
                category: "Warm-up",
                difficulty: "Easy",
                equipment: ["Soccer balls"],
                instructions: [
                    "Partners 10 yards apart, two-touch passing",
                    "Progress to one-touch passing",
                    "Add movement - pass and follow",
                    "Inside foot only for 2 minutes",
                    "Outside foot only for 2 minutes",
                    "Alternate feet with each pass"
                ]
            ),
            
            // PASSING DRILLS
            Drill(
                name: "Triangle Passing",
                description: "Three players passing in a triangle to work on accuracy and movement",
                duration: 15,
                category: "Passing",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Set up triangle with 3 cones, 10 yards apart",
                    "Pass clockwise for 5 minutes",
                    "Switch to counter-clockwise",
                    "Focus on first touch away from pressure",
                    "Progress to two-touch maximum",
                    "Advanced: One-touch passing only"
                ]
            ),
            Drill(
                name: "Rondo 4v2",
                description: "Possession game focusing on quick passing and movement",
                duration: 15,
                category: "Passing",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "Create 10x10 yard square",
                    "4 players keep possession, 2 defend",
                    "Maximum 2 touches for passers",
                    "Defenders switch after 1 minute or when they win ball",
                    "Count consecutive passes",
                    "Goal: 10 passes = point"
                ]
            ),
            Drill(
                name: "Long Ball Accuracy",
                description: "Practice long passing and first touch control",
                duration: 20,
                category: "Passing",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones", "Goals or targets"],
                instructions: [
                    "Partners 30-40 yards apart",
                    "Drive ball to partner's feet",
                    "Control with first touch, pass back with second",
                    "Progress to aerial passes",
                    "Add targets/gates to pass through",
                    "Competition: most accurate passes in 2 minutes"
                ]
            ),
            Drill(
                name: "Combination Play",
                description: "Work on give-and-go, overlaps, and third-man runs",
                duration: 20,
                category: "Passing",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Mannequins (optional)"],
                instructions: [
                    "Groups of 3-4 players",
                    "Practice wall passes (give-and-go)",
                    "Add overlap runs",
                    "Practice third-man running",
                    "Use mannequins as defenders",
                    "Rotate positions every 5 minutes"
                ]
            ),
            
            // PASSING DRILLS
            Drill(
                name: "Four-Cone Passing Square",
                description: "Pass and follow drill with emphasis on movement and awareness",
                duration: 15,
                category: "Passing",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Set up square with 4 cones, 10 yards apart",
                    "Pass to next player and follow your pass",
                    "Receiver controls ball and passes to next cone",
                    "Focus on weight and accuracy of pass",
                    "Add second ball for complexity",
                    "Progress: Change direction on command",
                    "Advanced: One-touch passing only"
                ]
            ),
            Drill(
                name: "Pass One Way, Move Another",
                description: "Drill for passing and movement",
                duration: 12,
                category: "Passing",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Set up 4 cones in diamond shape",
                    "Pass ball one direction",
                    "Immediately move in opposite direction",
                    "Receiver must anticipate movement",
                    "Focus on coordination and timing",
                    "Change pattern every 3 minutes"
                ]
            ),
            
            // SHOOTING DRILLS
            Drill(
                name: "1v1 Finishing",
                description: "Players practice finishing under pressure from defender",
                duration: 20,
                category: "Shooting",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals", "Cones"],
                instructions: [
                    "Set up 20x15 yard area with goal",
                    "Attacker receives ball from coach 25 yards out",
                    "Defender pressures from behind",
                    "Attacker has 5 seconds to score",
                    "Rotate every 3 attempts",
                    "Track goals scored"
                ]
            ),
            Drill(
                name: "Shooting Circuit",
                description: "Multiple shooting stations for varied finishing practice",
                duration: 25,
                category: "Shooting",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals", "Cones", "Agility ladder"],
                instructions: [
                    "Station 1: Shoot after dribbling through cones",
                    "Station 2: One-touch finish from cross",
                    "Station 3: Turn and shoot in box",
                    "Station 4: Long-range shooting",
                    "3 minutes per station",
                    "Keep score at each station"
                ]
            ),
            Drill(
                name: "Crossing and Finishing",
                description: "Practice crossing accuracy and heading/volleying",
                duration: 20,
                category: "Shooting",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Goals", "Cones"],
                instructions: [
                    "Wingers on both sides with balls",
                    "2-3 attackers in the box",
                    "Alternate crosses from left and right",
                    "Focus on timing of runs",
                    "Practice headers and volleys",
                    "Add defender for realism"
                ]
            ),
            
            // DEFENDING DRILLS
            Drill(
                name: "1v1 Defending",
                description: "Individual defending technique in isolated situations",
                duration: 18,
                category: "Defending",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Set up 15x10 yard channels",
                    "Attacker tries to dribble past defender to end line",
                    "Defender focuses on body positioning",
                    "Stay on feet - no diving in",
                    "Force attacker to weaker foot",
                    "Switch roles every 3 attempts"
                ]
            ),
            Drill(
                name: "Defensive Shape 4v4",
                description: "Team defending focusing on compactness and communication",
                duration: 25,
                category: "Defending",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "Half field with one goal",
                    "4 defenders vs 4 attackers",
                    "Defenders work on staying compact",
                    "Pressure, cover, balance principles",
                    "Communication is key",
                    "Offside line at 25 yards"
                ]
            ),
            Drill(
                name: "Pressing Triggers",
                description: "Learn when and how to press as a team",
                duration: 20,
                category: "Defending",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "8v8 on half field",
                    "Identify pressing triggers (bad touch, backward pass)",
                    "Front 3 press together",
                    "Midfield supports and cuts passing lanes",
                    "Win ball and counter quickly",
                    "Reset if ball goes out"
                ]
            ),
            
            // BATTLE BOX DRILL
            Drill(
                name: "Battle Box",
                description: "1v1 attacking and defending with back-to-pressure situations",
                duration: 20,
                category: "Defending",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "Create 8-15 yard square for 5-6 players",
                    "Place different colored cones on opposing sides",
                    "Divide players between the two cone lines",
                    "Attacking player runs to corner cone and touches it",
                    "Teammate passes ball as defender applies pressure",
                    "Attacker must receive with back to pressure",
                    "Try to score on opposite end line",
                    "Rotate roles every attempt"
                ]
            ),
            
            // DRIBBLING DRILLS
            Drill(
                name: "Cone Weaving",
                description: "Improve close control and change of direction",
                duration: 15,
                category: "Dribbling",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Set up 8 cones in a line, 2 yards apart",
                    "Dribble through using only right foot",
                    "Return using only left foot",
                    "Use inside and outside of both feet",
                    "Add speed when comfortable",
                    "Competition: fastest time wins"
                ]
            ),
            Drill(
                name: "1v1 Mirror Dribbling",
                description: "Reactive dribbling against passive defender",
                duration: 15,
                category: "Dribbling",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "10x10 yard squares",
                    "Attacker tries to stop ball on any line",
                    "Defender mirrors but cannot tackle",
                    "Work on body feints and changes of pace",
                    "30 seconds then switch",
                    "Progress to active defending"
                ]
            ),
            Drill(
                name: "Skill Moves Circuit",
                description: "Practice specific dribbling moves and tricks",
                duration: 20,
                category: "Dribbling",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Mannequins"],
                instructions: [
                    "Station 1: Stepovers around mannequin",
                    "Station 2: Cut and turn moves",
                    "Station 3: Fake shot and go",
                    "Station 4: Elastico/flip-flap",
                    "2 minutes per station",
                    "Use in 1v1 at end"
                ]
            ),
            
            // FITNESS DRILLS
            Drill(
                name: "Shuttle Runs",
                description: "Build speed endurance with short sprints",
                duration: 15,
                category: "Fitness",
                difficulty: "Hard",
                equipment: ["Cones"],
                instructions: [
                    "Cones at 5, 10, 15, 20 yards",
                    "Sprint to 5 and back",
                    "Sprint to 10 and back",
                    "Continue to 15 and 20",
                    "Rest 90 seconds",
                    "Repeat 4-6 times"
                ]
            ),
            Drill(
                name: "Box-to-Box Running",
                description: "Soccer-specific endurance training",
                duration: 20,
                category: "Fitness",
                difficulty: "Hard",
                equipment: ["Cones", "Soccer balls"],
                instructions: [
                    "Start at one penalty box",
                    "Sprint to opposite box",
                    "Jog back along sideline",
                    "Sprint diagonally to opposite corner",
                    "Add ball dribbling for variation",
                    "30 seconds on, 30 seconds rest"
                ]
            ),
            Drill(
                name: "Agility Ladder Complex",
                description: "Footwork and coordination training",
                duration: 15,
                category: "Fitness",
                difficulty: "Medium",
                equipment: ["Agility ladder", "Cones"],
                instructions: [
                    "Two feet in each box",
                    "Lateral shuffles",
                    "In-in-out-out pattern",
                    "Single leg hops",
                    "Icky shuffle",
                    "Finish with 10-yard sprint"
                ]
            ),
            
            // GOALKEEPING DRILLS
            Drill(
                name: "Shot Stopping",
                description: "Basic handling and positioning for goalkeepers",
                duration: 20,
                category: "Goalkeeping",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals", "Cones"],
                instructions: [
                    "Shots from various angles",
                    "Work on proper hand positioning",
                    "Practice diving technique",
                    "Low balls - get body behind ball",
                    "High balls - catch at highest point",
                    "10 shots then rotate keepers"
                ]
            ),
            Drill(
                name: "Distribution Practice",
                description: "Improve goalkeeper throwing and kicking",
                duration: 15,
                category: "Goalkeeping",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Practice roll outs to feet",
                    "Overhand throws to targets",
                    "Punts for distance and accuracy",
                    "Goal kicks to specific areas",
                    "Quick distribution drills",
                    "Work both feet for kicking"
                ]
            ),
            
            // SMALL SIDED GAMES
            Drill(
                name: "3v3 No Goalkeepers",
                description: "Fast-paced game focusing on quick decisions",
                duration: 20,
                category: "Small Sided Games",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Small goals or cones", "Bibs"],
                instructions: [
                    "20x30 yard field",
                    "Small goals (or cone goals)",
                    "No goalkeepers",
                    "Quick restarts",
                    "3-minute games",
                    "Winning team stays on"
                ]
            ),
            Drill(
                name: "4v4 Plus Neutrals",
                description: "Possession game with neutral players",
                duration: 25,
                category: "Small Sided Games",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs (3 colors)"],
                instructions: [
                    "30x40 yard field",
                    "2 neutral players on outside",
                    "Neutrals play with team in possession",
                    "Creates 6v4 when attacking",
                    "Neutrals limited to 1-2 touches",
                    "Switch neutrals every 5 minutes"
                ]
            ),
            
            // POWERBALL
            Drill(
                name: "Powerball",
                description: "1v1 multi-target scoring game inspired by American Gladiators",
                duration: 20,
                category: "Small Sided Games",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Create 20x20 yard area",
                    "Set up 4 triangle scoring pods in corners (1 point each)",
                    "Place center square scoring pod (5 points)",
                    "Teams line up behind starting cones",
                    "Attackers try to stop ball in any pod",
                    "Defenders try to prevent scoring",
                    "2-3 minute rounds with point tracking"
                ]
            ),
            
            // SET PIECES
            Drill(
                name: "Corner Kick Routines",
                description: "Practice set corner kick plays",
                duration: 20,
                category: "Set Pieces",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals", "Cones"],
                instructions: [
                    "Practice 3 different corner routines",
                    "Near post flick on",
                    "Far post header",
                    "Short corner combinations",
                    "Work on timing of runs",
                    "Both left and right corners"
                ]
            ),
            Drill(
                name: "Free Kick Scenarios",
                description: "Direct and indirect free kick practice",
                duration: 20,
                category: "Set Pieces",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Goals", "Mannequins"],
                instructions: [
                    "Set up from various distances",
                    "Practice direct shots",
                    "Work on set plays for indirect kicks",
                    "Use mannequins for wall",
                    "Designate primary and secondary kickers",
                    "Practice defensive organization too"
                ]
            ),
            
            // SCRIMMAGE DRILLS (NEW CATEGORY)
            Drill(
                name: "Conditioned Scrimmage",
                description: "Game with specific conditions to work on tactics",
                duration: 30,
                category: "Scrimmage",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals", "Bibs"],
                instructions: [
                    "Two teams play normal rules",
                    "Add conditions: 3-touch maximum",
                    "Must make 5 passes before scoring",
                    "All players must touch ball in attacking half",
                    "Change conditions every 10 minutes",
                    "Keep score normally"
                ]
            ),
            Drill(
                name: "Zone Scrimmage",
                description: "Game played in specific field zones",
                duration: 25,
                category: "Scrimmage",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Goals", "Cones", "Bibs"],
                instructions: [
                    "Divide field into thirds",
                    "Maximum 4 players per zone at one time",
                    "Forces spread and movement",
                    "Work on switching play",
                    "Penalty for zone violations",
                    "Rotate every 8 minutes"
                ]
            ),
            Drill(
                name: "Numbers Up Scrimmage",
                description: "Constantly changing team numbers during play",
                duration: 20,
                category: "Scrimmage",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals", "Bibs"],
                instructions: [
                    "Start 7v7",
                    "Coach calls out different numbers",
                    "Players adjust to create overloads",
                    "Practice quick numerical advantages",
                    "Develops decision making",
                    "Reset every 3 minutes"
                ]
            ),
            
            // RELAY DRILLS (NEW CATEGORY)
            Drill(
                name: "Dribbling Relay Race",
                description: "Team relay focusing on ball control and speed",
                duration: 15,
                category: "Relay",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Teams line up behind starting cone",
                    "Dribble to far cone and back",
                    "Pass ball to next teammate",
                    "Vary dribbling requirements each round",
                    "Right foot only, left foot only, both feet",
                    "First team to finish wins"
                ]
            ),
            Drill(
                name: "Passing Relay Challenge",
                description: "Accuracy and speed relay with passing gates",
                duration: 18,
                category: "Relay",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Set up multiple passing gates",
                    "Teams must pass through each gate",
                    "Can't advance until successful pass",
                    "Return and tag next player",
                    "Add pressure with time limits",
                    "Track team accuracy and speed"
                ]
            ),
            Drill(
                name: "Shooting Relay Competition",
                description: "Fast-paced finishing relay with multiple goals",
                duration: 20,
                category: "Relay",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals or targets", "Cones"],
                instructions: [
                    "Set up 3-4 shooting stations",
                    "Players must score before advancing",
                    "Sprint to next station after goal",
                    "Complete circuit and tag teammate",
                    "Vary shooting requirements each round",
                    "Time pressure adds intensity"
                ]
            ),
            
            // POSSESSION DRILLS (NEW CATEGORY)
            Drill(
                name: "Keep Ball Away",
                description: "Simple possession game with numerical advantage",
                duration: 15,
                category: "Possession",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "6v3 in 30x20 yard area",
                    "Possession team gets point for 6 passes",
                    "Defending team becomes possession on turnover",
                    "Rotate defending team every 2 minutes",
                    "Progress to smaller areas",
                    "Add touch restrictions"
                ]
            ),
            Drill(
                name: "Target Man Possession",
                description: "Possession with target players in end zones",
                duration: 20,
                category: "Possession",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "Two target players in opposite end zones",
                    "6v6 in middle area",
                    "Point for playing ball to target player",
                    "Target player plays ball back",
                    "Switch target players every 3 minutes",
                    "Emphasize quick switching of play"
                ]
            ),
            
            // TRANSITION DRILLS (NEW CATEGORY)
            Drill(
                name: "Quick Counter Attack",
                description: "Practice transitioning from defense to attack",
                duration: 20,
                category: "Transition",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Goals", "Cones", "Bibs"],
                instructions: [
                    "Set up with one team defending",
                    "On turnover, immediate counter attack",
                    "Must shoot within 10 seconds",
                    "Defending team drops back quickly",
                    "Work on switching mentality",
                    "Rotate roles every 5 minutes"
                ]
            ),
            Drill(
                name: "Box to Box Transition",
                description: "Full field transition between penalty boxes",
                duration: 25,
                category: "Transition",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Goals", "Bibs"],
                instructions: [
                    "Start with ball in one penalty box",
                    "Play out and create chance in opposite box",
                    "Immediate transition on turnover",
                    "Emphasize speed of play changes",
                    "Work both attacking and defending transitions",
                    "Rest between reps"
                ]
            ),
            
            // COOL DOWN
            Drill(
                name: "Light Jog and Stretch",
                description: "Gradual cool down with static stretching",
                duration: 10,
                category: "Cool Down",
                difficulty: "Easy",
                equipment: [],
                instructions: [
                    "Light jog for 3 minutes",
                    "Walking for 1 minute",
                    "Static stretching sequence:",
                    "Hamstrings, quads, calves",
                    "Hip flexors and groin",
                    "Hold each stretch 20 seconds"
                ]
            ),
            Drill(
                name: "Passing Circle Cool Down",
                description: "Easy passing while body cools down",
                duration: 10,
                category: "Cool Down",
                difficulty: "Easy",
                equipment: ["Soccer balls"],
                instructions: [
                    "Large circle, one ball",
                    "Easy passes across circle",
                    "Stretch while waiting for ball",
                    "No pressure, focus on technique",
                    "Gradually reduce pace",
                    "End with team huddle"
                ]
            ),
            // INFORMATIONAL DRILLS
            Drill(
                name: "Team Formation Review",
                description: "Walkthrough of team formations and positioning",
                duration: 15,
                category: "Informational",
                difficulty: "Easy",
                equipment: ["Whiteboard or cones", "Bibs"],
                instructions: [
                    "Gather team in classroom or on field",
                    "Review chosen formation (4-4-2, 4-3-3, etc.)",
                    "Walk through each position's responsibilities",
                    "Discuss defensive shape and compactness",
                    "Cover attacking patterns and movement",
                    "Q&A session for player questions"
                ]
            ),
            Drill(
                name: "Match Video Analysis",
                description: "Review game footage to identify areas for improvement",
                duration: 20,
                category: "Informational",
                difficulty: "Easy",
                equipment: ["Video equipment", "Whiteboard"],
                instructions: [
                    "Show highlights from recent match",
                    "Pause to discuss key moments",
                    "Identify what went well",
                    "Point out areas for improvement",
                    "Individual player feedback",
                    "Set goals for next match"
                ]
            ),
            Drill(
                name: "Rules and Offside Training",
                description: "Educational session on soccer rules and offside law",
                duration: 15,
                category: "Informational",
                difficulty: "Easy",
                equipment: ["Cones", "Whiteboard"],
                instructions: [
                    "Explain offside rule with diagrams",
                    "Walk through common scenarios",
                    "Practice offside trap as defenders",
                    "Discuss when to play offside line",
                    "Review other important rules",
                    "Practice scenarios on field"
                ]
            ),

            // GAME DRILLS
            Drill(
                name: "World Cup",
                description: "Tournament-style small sided games",
                duration: 30,
                category: "Game",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "Create 4 teams representing countries",
                    "Set up two small fields",
                    "5-minute games",
                    "Winners play for championship",
                    "Losers play for 3rd place",
                    "Track goals and celebrate winners"
                ]
            ),
            Drill(
                name: "King of the Hill",
                description: "Winner stays on possession game",
                duration: 20,
                category: "Game",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "3 teams of 4-5 players",
                    "Two teams play 4v4 in grid",
                    "First to 3 goals wins and stays",
                    "Losing team replaced by waiting team",
                    "Quick transitions between games",
                    "Crown the 'king' team at end"
                ]
            ),
            Drill(
                name: "Soccer Tennis",
                description: "Volleyball-style game with soccer ball",
                duration: 15,
                category: "Game",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones or net"],
                instructions: [
                    "Set up court with center 'net' (cones)",
                    "Teams of 2-3 players",
                    "Ball can bounce once per side",
                    "Maximum 3 touches per side",
                    "Must volley over net height",
                    "Play to 11 points, win by 2"
                ]
            ),
            Drill(
                name: "Capture the Flag",
                description: "Team game combining soccer skills with strategy",
                duration: 25,
                category: "Game",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs", "Flags or pinnies"],
                instructions: [
                    "Each team protects a 'flag' in their zone",
                    "Players must dribble soccer ball at all times",
                    "Try to steal opponent's flag and return to base",
                    "Tagged players frozen until teammate unfreezes",
                    "Can only be tagged in opponent's half",
                    "First team to capture flag 3 times wins"
                ]
            ),
            Drill(
                name: "4-Square Zone Game",
                description: "4v4 game with four quadrants requiring players to stay in zones",
                duration: 20,
                category: "Small Sided Games",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs", "Small goals"],
                instructions: [
                    "Divide field into 4 equal quadrants",
                    "One player from each team per quadrant",
                    "Players cannot leave their zone",
                    "Must pass to teammate in adjacent zone to advance",
                    "Goals only count from attacking zones",
                    "Rotate zones every 5 minutes",
                    "Teaches spacing and positional awareness"
                ]
            ),

            Drill(
                name: "2v2 End Zone",
                description: "Fast-paced 2v2 game with end zones instead of goals",
                duration: 15,
                category: "Small Sided Games",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "20x15 yard field with 3-yard end zones",
                    "Score by stopping ball in opponent's end zone",
                    "Restart from end zone after each score",
                    "Quick games to 3 goals",
                    "Winners stay, losers rotate off",
                    "Great for 1v1 skills and combination play"
                ]
            ),

            Drill(
                name: "3v3 Line Soccer",
                description: "End-to-end game scoring by dribbling across the line",
                duration: 18,
                category: "Small Sided Games",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "25x20 yard field",
                    "Score by dribbling ball across opponent's end line",
                    "Ball must be under control when crossing",
                    "No goalkeepers - all field players",
                    "Encourages 1v1 attacking and team defending",
                    "Play 3-minute games, winners stay"
                ]
            ),

            Drill(
                name: "4v4 Channel Game",
                description: "Game with wide channels for wing play",
                duration: 20,
                category: "Small Sided Games",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs", "Small goals"],
                instructions: [
                    "30x25 yard field with 5-yard wide channels on each side",
                    "Only one attacker allowed in each channel",
                    "Must use channels to score - cross from channel required",
                    "Teaches width in attack and defending crosses",
                    "Rotate channel players every 4 minutes",
                    "Goals from crosses worth 2 points"
                ]
            ),

            Drill(
                name: "2v2 Four Goals",
                description: "Directional awareness game with multiple scoring options",
                duration: 15,
                category: "Small Sided Games",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "20x20 yard square",
                    "Small cone goals on all four sides",
                    "Teams can score on any of opponent's two goals",
                    "Forces quick changes of direction",
                    "Develops scanning and awareness",
                    "First to 5 goals wins"
                ]
            ),

            Drill(
                name: "3v3 Plus Target Players",
                description: "Possession and penetration with target players on end lines",
                duration: 20,
                category: "Small Sided Games",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "25x20 yard field",
                    "One target player from each team on opposite end lines",
                    "Point for passing to your target and receiving return",
                    "Target players limited to 2 touches",
                    "Play through to target to create scoring chances",
                    "Rotate target players every 3 minutes"
                ]
            ),

            Drill(
                name: "4v4 Switch Play Game",
                description: "Game rewarding switching the point of attack",
                duration: 20,
                category: "Small Sided Games",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones", "Bibs", "Small goals"],
                instructions: [
                    "35x25 yard field with goals",
                    "Divide field into 3 vertical zones",
                    "Must play ball through all 3 zones before scoring",
                    "Encourages switching play and width",
                    "Ball cannot go backward through zones",
                    "2 points for goals after full switch"
                ]
            ),

            Drill(
                name: "2v2 Box Battles",
                description: "Intense 1v1 and 2v2 battles in tight space",
                duration: 15,
                category: "Small Sided Games",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "12x12 yard box",
                    "2v2 with small cone goals on each end",
                    "30-second battles",
                    "Winning team stays, new challengers enter",
                    "Quick transitions and tight space control",
                    "Track consecutive wins"
                ]
            ),

            Drill(
                name: "3v3 Three Zone",
                description: "Game with mandatory player distribution across zones",
                duration: 18,
                category: "Small Sided Games",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs", "Small goals"],
                instructions: [
                    "30x20 yard field divided into thirds",
                    "One player per team must be in each zone",
                    "Players can move within their zone only",
                    "Teaches defensive shape and attacking movement",
                    "Goals can only be scored from attacking third",
                    "Rotate zones clockwise every 4 minutes"
                ]
            ),

            Drill(
                name: "4v4 Transition Boxes",
                description: "Quick transition game between two adjacent areas",
                duration: 22,
                category: "Small Sided Games",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones", "Bibs", "Goals"],
                instructions: [
                    "Two 20x20 boxes side by side",
                    "4v4 in active box, other box empty",
                    "On goal or out of bounds, ball goes to other box",
                    "All 8 players sprint to new box",
                    "Team that lost possession defends first",
                    "Builds fitness and transition mentality"
                ]
            ),

            // MARK: - ADDITIONAL RELAY DRILLS

            Drill(
                name: "Agility Cone Relay",
                description: "Speed and agility relay with directional changes",
                duration: 12,
                category: "Relay",
                difficulty: "Easy",
                equipment: ["Cones"],
                instructions: [
                    "Set up 5 cones in zigzag pattern",
                    "Sprint forward, touch each cone",
                    "Backpedal to start",
                    "Tag next teammate",
                    "Vary movement patterns each round",
                    "Side shuffles, carioca, etc."
                ]
            ),

            Drill(
                name: "Ball Control Relay",
                description: "Relay emphasizing close ball control under speed",
                duration: 15,
                category: "Relay",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Dribble through tight cone gates",
                    "Perform a skill move at middle cone",
                    "Turn and dribble back",
                    "Clean pass to next teammate",
                    "Penalty for missed gates or bad passes",
                    "First team to complete 4 rounds wins"
                ]
            ),

            Drill(
                name: "Juggling Relay",
                description: "Team relay keeping ball in the air while moving",
                duration: 12,
                category: "Relay",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Juggle ball to far cone and back",
                    "If ball drops, continue from that spot",
                    "Must juggle at least 5 times before reaching cone",
                    "Pass with volley to next teammate",
                    "Dropped passes = start that leg over",
                    "First team to finish wins"
                ]
            ),

            Drill(
                name: "Headers Relay",
                description: "Heading accuracy relay to targets",
                duration: 15,
                category: "Relay",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Targets or goals"],
                instructions: [
                    "Partner tosses ball for header",
                    "Must hit target/score to advance",
                    "Sprint back and tag next pair",
                    "Vary distances and target sizes",
                    "Competition between multiple teams",
                    "Track successful headers"
                ]
            ),

            Drill(
                name: "Dribble and Shoot Relay",
                description: "Speed dribbling with finishing under fatigue",
                duration: 18,
                category: "Relay",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Goals"],
                instructions: [
                    "Dribble through cone course at speed",
                    "Finish on goal from 18 yards",
                    "Must score to complete leg",
                    "Retrieve ball and pass to next player",
                    "Miss = go to back of shooting line",
                    "First team with all players scored wins"
                ]
            ),

            Drill(
                name: "Passing Gates Relay",
                description: "Precision passing relay through multiple gates",
                duration: 15,
                category: "Relay",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Set up 4 gates at various distances",
                    "Must pass through each gate in order",
                    "Partner receives and sets up next pass",
                    "Both players sprint back after last gate",
                    "Missed gate = retry that pass",
                    "Emphasize accuracy over speed initially"
                ]
            ),

            Drill(
                name: "Obstacle Course Relay",
                description: "Multi-skill relay combining dribbling, passing, and agility",
                duration: 20,
                category: "Relay",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones", "Hurdles", "Agility ladder"],
                instructions: [
                    "Station 1: Dribble through cones",
                    "Station 2: Pass through gate to partner",
                    "Station 3: Agility ladder footwork",
                    "Station 4: Receive ball, turn, sprint to finish",
                    "Full course takes 30-45 seconds",
                    "Team competition with time tracking"
                ]
            ),

            Drill(
                name: "Knockout Relay",
                description: "Elimination relay where slowest player sits out each round",
                duration: 15,
                category: "Relay",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "All players line up for dribbling relay",
                    "Last player to finish each round is eliminated",
                    "Course gets harder each round",
                    "Continue until one player remains",
                    "Winner gets to choose next drill or leads stretches",
                    "Builds competitive intensity"
                ]
            ),

            // MARK: - EXPANDED GOALKEEPER DRILLS

            Drill(
                name: "Rapid Fire Shot Stopping",
                description: "High-intensity consecutive shots for reaction training",
                duration: 15,
                category: "Goalkeeping",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Goals"],
                instructions: [
                    "3-4 shooters with balls lined up",
                    "Shots fired in quick succession",
                    "Keeper must recover between each",
                    "10 shots then rotate keepers",
                    "Mix low, medium, and high shots",
                    "Track saves out of 10"
                ]
            ),

            Drill(
                name: "Diving Technique",
                description: "Progressive diving drill building proper form",
                duration: 18,
                category: "Goalkeeping",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals", "Mats (optional)"],
                instructions: [
                    "Start from knees - dive to side",
                    "Progress to crouching position",
                    "Full standing position dives",
                    "Emphasize leading with hands",
                    "Land on side, not stomach",
                    "Push off with inside foot"
                ]
            ),

            Drill(
                name: "Footwork and Positioning",
                description: "Improve goalkeeper movement and angles",
                duration: 15,
                category: "Goalkeeping",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Cones", "Goals"],
                instructions: [
                    "Set cones at various angles to goal",
                    "Keeper shuffles to each cone position",
                    "Shot taken when keeper sets position",
                    "Focus on staying balanced and set",
                    "Small adjustment steps, never cross feet",
                    "Cover the angle efficiently"
                ]
            ),

            Drill(
                name: "High Ball Claiming",
                description: "Practice catching crosses and high balls",
                duration: 18,
                category: "Goalkeeping",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals"],
                instructions: [
                    "Crosses served from both wings",
                    "Keeper calls and catches at highest point",
                    "Progress to contested catches (with attacker)",
                    "Practice punching when necessary",
                    "Work on communication - 'Keeper!'",
                    "Vary service - driven and floated"
                ]
            ),

            Drill(
                name: "1v1 Breakaway Saves",
                description: "Training for one-on-one situations",
                duration: 20,
                category: "Goalkeeping",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Goals", "Cones"],
                instructions: [
                    "Attacker starts 30 yards out with ball",
                    "Keeper decides when to come off line",
                    "Make yourself big, stay on feet as long as possible",
                    "Practice spreading techniques",
                    "Work on timing of when to commit",
                    "Rotate attackers, track saves"
                ]
            ),

            Drill(
                name: "Reflex Training",
                description: "Quick reaction saves from close range",
                duration: 12,
                category: "Goalkeeping",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Goals", "Rebounder (optional)"],
                instructions: [
                    "Shooter 8-10 yards out",
                    "Rapid volleys and half-volleys",
                    "Keeper focuses on hand positioning",
                    "Use rebounder for unpredictable bounces",
                    "Sets of 10 shots with rest",
                    "Track reaction saves"
                ]
            ),

            Drill(
                name: "Goalkeeper Distribution Circuit",
                description: "Comprehensive distribution practice",
                duration: 20,
                category: "Goalkeeping",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Goals"],
                instructions: [
                    "Station 1: Roll out to feet",
                    "Station 2: Overhand throw to target",
                    "Station 3: Javelin throw for distance",
                    "Station 4: Punt to zones",
                    "Station 5: Goal kick accuracy",
                    "Rotate through stations, 3 min each"
                ]
            ),

            Drill(
                name: "Shot Stopping Angles",
                description: "Understanding and cutting down angles",
                duration: 15,
                category: "Goalkeeping",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals", "Cones"],
                instructions: [
                    "Mark shooting positions around the box",
                    "Keeper adjusts position for each angle",
                    "Coach checks angle coverage before shot",
                    "Shots from various angles in sequence",
                    "Emphasize being set before shot",
                    "Review positioning between rounds"
                ]
            ),

            Drill(
                name: "Crosses with Traffic",
                description: "Dealing with crosses in a crowded box",
                duration: 20,
                category: "Goalkeeping",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Goals", "Bibs"],
                instructions: [
                    "2 attackers and 2 defenders in box",
                    "Crosses served from wide positions",
                    "Keeper must claim or punch clear",
                    "Navigate through traffic safely",
                    "Communication essential with defenders",
                    "Progress to game-realistic scenarios"
                ]
            ),

            Drill(
                name: "Recovery Saves",
                description: "Getting up quickly for second and third shots",
                duration: 15,
                category: "Goalkeeping",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Goals"],
                instructions: [
                    "Save first shot, parry to side",
                    "Recover immediately for follow-up shot",
                    "Third shot comes quickly after",
                    "Focus on quick recovery to feet",
                    "Spring up, don't roll to standing",
                    "Builds match stamina and reactions"
                ]
            ),

            Drill(
                name: "Goalkeeper Handling",
                description: "Secure catching technique for various heights",
                duration: 15,
                category: "Goalkeeping",
                difficulty: "Easy",
                equipment: ["Soccer balls"],
                instructions: [
                    "Partner serves balls at different heights",
                    "Low: scoop and secure to chest",
                    "Medium: basket catch (W hands)",
                    "High: catch above head, bring to chest",
                    "Emphasize soft hands and cushioning",
                    "50 catches total with focus on technique"
                ]
            ),

            Drill(
                name: "Penalty Kick Practice",
                description: "Reading shooters and penalty save technique",
                duration: 20,
                category: "Goalkeeping",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals"],
                instructions: [
                    "Study shooter's body position and approach",
                    "Practice staying big until last moment",
                    "Work on explosive lateral movement",
                    "Mix up guessing vs reading",
                    "Track save percentage",
                    "Discuss tells and patterns after"
                ]
            ),

            // MARK: - TECHNICAL DRILLS

            Drill(
                name: "Wall Passing Sequence",
                description: "Individual technical work using wall or rebounder",
                duration: 15,
                category: "Technical",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Wall or rebounder"],
                instructions: [
                    "Inside foot pass and control - both feet",
                    "Two-touch: control and pass",
                    "One-touch passing rhythm",
                    "Volleys against wall",
                    "Headers from self-toss off wall",
                    "Combine moves in sequence"
                ]
            ),

            Drill(
                name: "First Touch Circuit",
                description: "Receiving and controlling from various angles",
                duration: 18,
                category: "Technical",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Partner serves ball from different positions",
                    "Control with inside, outside, sole of foot",
                    "Control and turn in one touch",
                    "Chest control to feet",
                    "Thigh control and volley back",
                    "Progress to moving while receiving"
                ]
            ),

            Drill(
                name: "Receiving Under Pressure",
                description: "Controlling ball with defender closing",
                duration: 20,
                category: "Technical",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "Receiver checks to ball",
                    "Passive defender applies pressure from behind",
                    "Shield, turn, or play back",
                    "Progress to active defending",
                    "Work on body positioning",
                    "Rotate roles every 3 minutes"
                ]
            ),

            Drill(
                name: "2v2 Zones",
                description: "Technical 2v2 in tight spaces with zone transitions",
                duration: 20,
                category: "Technical",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Bibs"],
                instructions: [
                    "Create two 12x12 yard adjacent zones",
                    "2v2 in one zone, 2 waiting in other",
                    "Complete 5 passes to transfer to other zone",
                    "Defending pair becomes attacking in new zone",
                    "Continuous play between zones",
                    "Emphasize quick combinations and support"
                ]
            ),

            Drill(
                name: "Turning with the Ball",
                description: "Practice various turns under pressure",
                duration: 15,
                category: "Technical",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Inside hook turn",
                    "Outside hook turn",
                    "Cruyff turn",
                    "Drag back and go",
                    "Step over turn",
                    "Practice each turn, then combine in sequence"
                ]
            ),

            Drill(
                name: "Restarts",
                description: "Practice ball striking while a ball is not moving",
                duration: 15,
                category: "Technical",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Cones", "Goals"],
                instructions: [
                    "Passing: Place balls in a line, pass to targets with a stopped ball",
                    "Shooting: Place balls in and around the box. Shoot on goal without moving the ball before striking",
                    "Crossing: Send in dead ball crosses to target players",
                    "Focus on good clean contact without needing to settle the ball first"
                ]
            ),

            // MARK: - ADDITIONAL ATTACKING DRILLS

            Drill(
                name: "Overlapping Runs",
                description: "Practice timing and execution of overlapping runs",
                duration: 20,
                category: "Attacking",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Goals"],
                instructions: [
                    "Wide player receives ball and holds",
                    "Fullback/midfielder makes overlapping run",
                    "Time the pass into stride",
                    "Cross or cut back from byline",
                    "Rotate positions after each rep",
                    "Work both sides of field"
                ]
            ),

            Drill(
                name: "Third Man Runs",
                description: "Combination play involving third player movement",
                duration: 20,
                category: "Attacking",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones", "Mannequins"],
                instructions: [
                    "Groups of 3 players",
                    "Player 1 passes to Player 2",
                    "Player 3 makes run as ball travels",
                    "Player 2 sets ball for Player 3's run",
                    "Finish with shot or final pass",
                    "Timing of run is crucial"
                ]
            ),

            Drill(
                name: "Quick Combination Finishing",
                description: "Fast passing sequences ending with shots",
                duration: 20,
                category: "Attacking",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Goals"],
                instructions: [
                    "3 attackers start at edge of box",
                    "1-2 pass sequence to create shooting chance",
                    "Maximum 4 passes before shot",
                    "Reset and go again immediately",
                    "Vary the combination patterns",
                    "Track goals from each pattern"
                ]
            ),

            // MARK: - FUN/COMPETITION GAMES

            Drill(
                name: "Sharks and Minnows",
                description: "Fun dribbling game with taggers",
                duration: 12,
                category: "Game",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "All players (minnows) have a ball in large square",
                    "2-3 sharks without balls try to kick balls out",
                    "If your ball is kicked out, you become a shark",
                    "Last minnow standing wins",
                    "Teaches shielding and awareness",
                    "Great for younger players"
                ]
            ),

            Drill(
                name: "Knockout",
                description: "Dribbling protection game",
                duration: 12,
                category: "Game",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "All players dribble in defined area",
                    "Protect your ball while kicking others out",
                    "Once your ball leaves the area, you're out",
                    "Area shrinks as players are eliminated",
                    "Last player with ball wins",
                    "Develops close control and awareness"
                ]
            ),

            Drill(
                name: "Numbers Game",
                description: "Reaction game where numbers create teams",
                duration: 18,
                category: "Game",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals", "Bibs"],
                instructions: [
                    "Players numbered 1-6 on each team",
                    "Teams start on opposite end lines",
                    "Coach calls a number - those players compete",
                    "Ball played into center for 1v1",
                    "Call multiple numbers for 2v2, 3v3, etc.",
                    "Quick transitions and intensity"
                ]
            ),

            Drill(
                name: "Golden Goal",
                description: "High-pressure sudden death games",
                duration: 20,
                category: "Game",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals", "Bibs"],
                instructions: [
                    "4v4 or 5v5 games",
                    "First goal wins - game over",
                    "Losing team does fitness (5 push-ups, etc.)",
                    "New game starts immediately",
                    "Creates match-like pressure",
                    "Track wins and losses"
                ]
            ),

            Drill(
                name: "Target Goal",
                description: "Shooting game with points for different targets",
                duration: 15,
                category: "Game",
                difficulty: "Easy",
                equipment: ["Soccer balls", "Goals", "Targets"],
                instructions: [
                    "Place targets in different areas of goal",
                    "Corners worth 3 points",
                    "Upper 90s worth 5 points",
                    "Center of goal worth 1 point",
                    "Each player gets 5 shots",
                    "Track individual and team scores"
                ]
            ),

            Drill(
                name: "World Cup Headers",
                description: "Heading game with tournament format",
                duration: 15,
                category: "Game",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals"],
                instructions: [
                    "Groups of 4-6 players per goal",
                    "One server, others compete for headers",
                    "Must score with header",
                    "First to 3 goals advances",
                    "Last player relegated",
                    "Rotate servers regularly"
                ]
            ),

            // MARK: - CONDITIONING WITH BALL

            Drill(
                name: "Dribble Fitness",
                description: "Conditioning while maintaining ball control",
                duration: 15,
                category: "Fitness",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "Dribble length of field at 75% pace",
                    "Jog back without ball",
                    "Repeat 6-8 times",
                    "Focus on keeping ball close at speed",
                    "Vary dribbling technique each rep",
                    "Builds soccer-specific endurance"
                ]
            ),

            Drill(
                name: "Passing Under Fatigue",
                description: "Technical work while tired to simulate match conditions",
                duration: 18,
                category: "Fitness",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones"],
                instructions: [
                    "30-second sprint",
                    "Immediately into passing sequence",
                    "20-second rest",
                    "Repeat 8 times",
                    "Emphasize technique when tired",
                    "Track passing accuracy"
                ]
            ),

            // MARK: - HEADING DRILLS

            Drill(
                name: "Heading Progression",
                description: "Build heading technique from basics to advanced",
                duration: 15,
                category: "Technical",
                difficulty: "Easy",
                equipment: ["Soccer balls"],
                instructions: [
                    "Self-toss and head to partner",
                    "Partner toss and head back",
                    "Heading for distance",
                    "Heading for accuracy to target",
                    "Jumping headers",
                    "Defensive clearing headers"
                ]
            ),

            Drill(
                name: "Heading Accuracy Challenge",
                description: "Competitive heading to targets",
                duration: 12,
                category: "Technical",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Targets", "Cones"],
                instructions: [
                    "Set up targets at various heights",
                    "Partner tosses ball for header",
                    "Points for hitting different targets",
                    "5 attempts each, track score",
                    "Progress to moving before heading",
                    "Add defensive pressure"
                ]
            ),

            // MARK: - DEFENSIVE DRILLS

            Drill(
                name: "Defensive Positioning 2v1",
                description: "Learn to delay when outnumbered",
                duration: 18,
                category: "Defending",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Cones", "Goals"],
                instructions: [
                    "2 attackers vs 1 defender",
                    "Defender's job is to delay",
                    "Force attackers wide or backwards",
                    "Buy time for recovering defender",
                    "Track how long defender delays",
                    "Rotate roles regularly"
                ]
            ),

            Drill(
                name: "Recovery Runs",
                description: "Practice tracking back and recovering position",
                duration: 18,
                category: "Defending",
                difficulty: "Hard",
                equipment: ["Soccer balls", "Cones", "Goals"],
                instructions: [
                    "Defender starts at halfway line",
                    "Attacker starts with ball near box",
                    "On whistle, defender sprints to recover",
                    "Must get goal side before shot",
                    "Track successful recoveries",
                    "Add second defender for variation"
                ]
            ),

            Drill(
                name: "Blocking Shots",
                description: "Technique for blocking shots in the box",
                duration: 15,
                category: "Defending",
                difficulty: "Medium",
                equipment: ["Soccer balls", "Goals"],
                instructions: [
                    "Defender 6 yards from shooter",
                    "Close down and block shot",
                    "Stay big, don't turn away",
                    "Use body to block, not just legs",
                    "Practice from various angles",
                    "Builds bravery and technique"
                ]
            )
        ]
    }
}

// Singleton instance for app-wide access
extension DrillLibrary {
    static var categories: [String] {
        shared.allCategories
    }
}
