import Foundation

/// Centralized manager for world progression, unlocks, and per-world stats
class WorldProgressManager {
    
    static let shared = WorldProgressManager()
    
    private init() {
        loadData()
    }
    
    // MARK: - Unlock Requirements
    
    /// Score needed in each world to help unlock the NEXT world
    /// These are designed to be achievable without dying (completing the world = ~800-1200 base)
    /// Boss bonus = 500-1000, Clone survival = 500-2500, Total = ~2000-4000 per successful run
    static let scoreRequirements: [Int] = [
        1500,   // Score 1500 in Forest to unlock City (achievable with boss defeat + some coins)
        3000,   // Score 3000 in City to unlock Volcano (need good performance + boss)
        5000,   // Score 5000 in Volcano to unlock Ice (need to survive well)
        7000,   // Score 7000 in Ice to unlock Space (skilled play required)
        9000,   // Score 9000 in Space to unlock Neon (expert level)
        12000   // Score 12000 in Neon (for mastery/3 stars)
    ]
    
    // MARK: - Per-World Data
    
    /// Best score achieved when STARTING from each world
    private(set) var worldBestScores: [Int] = [0, 0, 0, 0, 0, 0]
    
    /// Whether the boss has been defeated in each world
    private(set) var bossDefeated: [Bool] = [false, false, false, false, false, false]
    
    // MARK: - Unlock Logic
    
    /// Check if a world is unlocked
    /// World 0 (Forest) is always unlocked
    /// Other worlds require: beat previous boss AND reach score threshold in previous world
    func isWorldUnlocked(_ worldIndex: Int) -> Bool {
        if worldIndex == 0 { return true }
        if worldIndex < 0 || worldIndex > 5 { return false }
        
        let previousWorld = worldIndex - 1
        let previousBossDefeated = bossDefeated[previousWorld]
        let previousScore = worldBestScores[previousWorld]
        let requiredScore = WorldProgressManager.scoreRequirements[previousWorld]
        
        return previousBossDefeated && previousScore >= requiredScore
    }
    
    /// Get unlock progress for a locked world (0.0 to 1.0)
    func unlockProgress(forWorld worldIndex: Int) -> (scoreProgress: CGFloat, bossDefeated: Bool) {
        if worldIndex == 0 { return (1.0, true) }
        
        let previousWorld = worldIndex - 1
        let previousScore = worldBestScores[previousWorld]
        let requiredScore = WorldProgressManager.scoreRequirements[previousWorld]
        
        let scoreProgress = min(1.0, CGFloat(previousScore) / CGFloat(requiredScore))
        let bossStatus = bossDefeated[previousWorld]
        
        return (scoreProgress, bossStatus)
    }
    
    /// Get requirement text for a locked world
    func unlockRequirementText(forWorld worldIndex: Int) -> String {
        if worldIndex == 0 { return "Unlocked" }
        
        let previousWorld = worldIndex - 1
        let requiredScore = WorldProgressManager.scoreRequirements[previousWorld]
        let worldName = WorldType(rawValue: previousWorld)?.name ?? "World \(previousWorld + 1)"
        
        return "Score \(requiredScore) & beat boss in \(worldName)"
    }
    
    // MARK: - Recording Progress
    
    /// Record a score for a world (call when game ends)
    func recordScore(_ score: Int, forStartingWorld worldIndex: Int) {
        guard worldIndex >= 0 && worldIndex < 6 else { return }
        
        if score > worldBestScores[worldIndex] {
            worldBestScores[worldIndex] = score
            saveData()
            #if DEBUG
            print("DEBUG: New best score \(score) for world \(worldIndex)")
            #endif
        }
    }
    
    /// Record that a boss was defeated
    func recordBossDefeated(inWorld worldIndex: Int) {
        guard worldIndex >= 0 && worldIndex < 6 else { return }
        
        if !bossDefeated[worldIndex] {
            bossDefeated[worldIndex] = true
            saveData()
            #if DEBUG
            print("DEBUG: Boss defeated in world \(worldIndex)")
            #endif
        }
    }
    
    /// Get best score for a specific world
    func bestScore(forWorld worldIndex: Int) -> Int {
        guard worldIndex >= 0 && worldIndex < 6 else { return 0 }
        return worldBestScores[worldIndex]
    }
    
    /// Check if boss was defeated in a world
    func isBossDefeated(inWorld worldIndex: Int) -> Bool {
        guard worldIndex >= 0 && worldIndex < 6 else { return false }
        return bossDefeated[worldIndex]
    }
    
    // MARK: - Star Rating
    
    /// Calculate stars for a world based on best score (0-3 stars)
    func starsForWorld(_ worldIndex: Int) -> Int {
        guard worldIndex >= 0 && worldIndex < 6 else { return 0 }
        
        let score = worldBestScores[worldIndex]
        let requirement = WorldProgressManager.scoreRequirements[worldIndex]
        
        if score >= requirement * 3 { return 3 }      // 3x requirement = 3 stars
        if score >= requirement * 2 { return 2 }      // 2x requirement = 2 stars
        if score >= requirement { return 1 }          // 1x requirement = 1 star
        return 0
    }
    
    /// Get star display string
    func starDisplayForWorld(_ worldIndex: Int) -> String {
        let stars = starsForWorld(worldIndex)
        var display = ""
        for i in 0..<3 {
            display += i < stars ? "⭐" : "☆"
        }
        return display
    }
    
    // MARK: - Persistence
    
    private func loadData() {
        for i in 0..<6 {
            worldBestScores[i] = UserDefaults.standard.integer(forKey: "worldBestScore_\(i)")
            bossDefeated[i] = UserDefaults.standard.bool(forKey: "bossDefeated_\(i)")
        }
    }
    
    private func saveData() {
        for i in 0..<6 {
            UserDefaults.standard.set(worldBestScores[i], forKey: "worldBestScore_\(i)")
            UserDefaults.standard.set(bossDefeated[i], forKey: "bossDefeated_\(i)")
        }
    }
    
    /// Reset all progress (for testing or settings reset)
    func resetAllProgress() {
        worldBestScores = [0, 0, 0, 0, 0, 0]
        bossDefeated = [false, false, false, false, false, false]
        saveData()
    }
    
    // MARK: - Debug
    
    #if DEBUG
    func debugUnlockAll() {
        for i in 0..<6 {
            worldBestScores[i] = 20000
            bossDefeated[i] = true
        }
        saveData()
    }

    func printStatus() {
        print("=== World Progress ===")
        for i in 0..<6 {
            let worldName = WorldType(rawValue: i)?.name ?? "World \(i)"
            let unlocked = isWorldUnlocked(i)
            let score = worldBestScores[i]
            let boss = bossDefeated[i]
            print("\(worldName): Unlocked=\(unlocked), Best=\(score), Boss=\(boss)")
        }
    }
    #endif
}
