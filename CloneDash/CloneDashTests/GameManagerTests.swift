import Testing
@testable import CloneDash

// Tests run serially to prevent shared-singleton state interference.
@Suite("GameManager", .serialized)
struct GameManagerTests {

    init() {
        GameManager.shared.resetAllData()
        GameManager.shared.loadGameData()
        // Clear the review prompt tracking so milestone tests are predictable
        UserDefaults.standard.removeObject(forKey: "lastReviewPromptRun")
    }

    // MARK: - Coins

    @Test("addCoins increases balance")
    func addCoinsIncreasesBalance() {
        GameManager.shared.addCoins(100)
        #expect(GameManager.shared.coins == 100)
    }

    @Test("addCoins is cumulative")
    func addCoinsCumulative() {
        GameManager.shared.addCoins(50)
        GameManager.shared.addCoins(75)
        #expect(GameManager.shared.coins == 125)
    }

    @Test("spendCoins deducts when sufficient")
    func spendCoinsSuccess() {
        GameManager.shared.addCoins(200)
        let result = GameManager.shared.spendCoins(150)
        #expect(result == true)
        #expect(GameManager.shared.coins == 50)
    }

    @Test("spendCoins returns false when insufficient")
    func spendCoinsFailure() {
        GameManager.shared.addCoins(50)
        let result = GameManager.shared.spendCoins(100)
        #expect(result == false)
        #expect(GameManager.shared.coins == 50)  // balance unchanged
    }

    @Test("coins never go negative")
    func coinsNeverNegative() {
        let result = GameManager.shared.spendCoins(1)
        #expect(result == false)
        #expect(GameManager.shared.coins == 0)
    }

    @Test("spendCoins exact balance succeeds")
    func spendCoinsExactBalance() {
        GameManager.shared.addCoins(100)
        let result = GameManager.shared.spendCoins(100)
        #expect(result == true)
        #expect(GameManager.shared.coins == 0)
    }

    // MARK: - Gems

    @Test("addGems increases balance")
    func addGemsIncreasesBalance() {
        GameManager.shared.addGems(5)
        #expect(GameManager.shared.gems == 5)
    }

    @Test("spendGems deducts when sufficient")
    func spendGemsSuccess() {
        GameManager.shared.addGems(10)
        let result = GameManager.shared.spendGems(7)
        #expect(result == true)
        #expect(GameManager.shared.gems == 3)
    }

    @Test("spendGems returns false when insufficient")
    func spendGemsFailure() {
        let result = GameManager.shared.spendGems(1)
        #expect(result == false)
        #expect(GameManager.shared.gems == 0)
    }

    // MARK: - High Score

    @Test("recordRun sets initial high score")
    func recordRunSetsHighScore() {
        GameManager.shared.recordRun(score: 500, coins: 0, distance: 0)
        #expect(GameManager.shared.highScore == 500)
    }

    @Test("recordRun updates high score when higher")
    func recordRunUpdatesHighScore() {
        GameManager.shared.recordRun(score: 500, coins: 0, distance: 0)
        GameManager.shared.recordRun(score: 1500, coins: 0, distance: 0)
        #expect(GameManager.shared.highScore == 1500)
    }

    @Test("recordRun does not lower high score")
    func recordRunKeepsHighScore() {
        GameManager.shared.recordRun(score: 1000, coins: 0, distance: 0)
        GameManager.shared.recordRun(score: 200, coins: 0, distance: 0)
        #expect(GameManager.shared.highScore == 1000)
    }

    @Test("recordRun with equal score does not change high score")
    func recordRunEqualScore() {
        GameManager.shared.recordRun(score: 1000, coins: 0, distance: 0)
        GameManager.shared.recordRun(score: 1000, coins: 0, distance: 0)
        #expect(GameManager.shared.highScore == 1000)
    }

    // MARK: - Run Stats

    @Test("recordRun increments totalRuns")
    func recordRunIncrementsTotalRuns() {
        GameManager.shared.recordRun(score: 0, coins: 0, distance: 0)
        GameManager.shared.recordRun(score: 0, coins: 0, distance: 0)
        GameManager.shared.recordRun(score: 0, coins: 0, distance: 0)
        #expect(GameManager.shared.totalRuns == 3)
    }

    @Test("recordRun accumulates distance")
    func recordRunAccumulatesDistance() {
        GameManager.shared.recordRun(score: 0, coins: 0, distance: 300)
        GameManager.shared.recordRun(score: 0, coins: 0, distance: 500)
        #expect(GameManager.shared.totalDistance == 800)
    }

    @Test("recordRun accumulates coins collected")
    func recordRunAccumulatesCoins() {
        GameManager.shared.recordRun(score: 0, coins: 40, distance: 0)
        GameManager.shared.recordRun(score: 0, coins: 60, distance: 0)
        #expect(GameManager.shared.totalCoinsCollected == 100)
    }

    // MARK: - Max Clones

    @Test("recordMaxClones updates when higher")
    func recordMaxClonesUpdatesWhenHigher() {
        GameManager.shared.recordMaxClones(3)
        #expect(GameManager.shared.maxClonesEver == 3)

        GameManager.shared.recordMaxClones(5)
        #expect(GameManager.shared.maxClonesEver == 5)
    }

    @Test("recordMaxClones does not lower existing record")
    func recordMaxClonesKeepsHighest() {
        GameManager.shared.recordMaxClones(5)
        GameManager.shared.recordMaxClones(2)
        #expect(GameManager.shared.maxClonesEver == 5)
    }

    // MARK: - App Store Review Prompts

    @Test("shouldRequestReview triggers at run 5")
    func shouldRequestReviewAtRun5() {
        for _ in 0..<5 {
            GameManager.shared.recordRun(score: 0, coins: 0, distance: 0)
        }
        #expect(GameManager.shared.shouldRequestReview() == true)
    }

    @Test("shouldRequestReview does not repeat at same threshold")
    func shouldRequestReviewNoRepeat() {
        for _ in 0..<5 {
            GameManager.shared.recordRun(score: 0, coins: 0, distance: 0)
        }
        _ = GameManager.shared.shouldRequestReview()  // consume the trigger
        #expect(GameManager.shared.shouldRequestReview() == false)
    }

    @Test("shouldRequestReview is false before any threshold")
    func shouldRequestReviewFalseBeforeThreshold() {
        for _ in 0..<4 {
            GameManager.shared.recordRun(score: 0, coins: 0, distance: 0)
        }
        #expect(GameManager.shared.shouldRequestReview() == false)
    }

    // MARK: - Achievements

    @Test("no achievements unlocked at start")
    func noAchievementsAtStart() {
        for achievement in Achievement.allCases {
            #expect(GameManager.shared.isAchievementUnlocked(achievement) == false)
        }
    }

    @Test("score 1000 unlocks score1000 achievement")
    func achievementScore1000() {
        let unlocked = GameManager.shared.checkAchievements(score: 1000, clones: 1, distance: 0)
        #expect(unlocked.contains(.score1000))
        #expect(GameManager.shared.isAchievementUnlocked(.score1000) == true)
    }

    @Test("score 5000 unlocks score1000 and score5000 achievements")
    func achievementScore5000UnlocksBoth() {
        let unlocked = GameManager.shared.checkAchievements(score: 5000, clones: 1, distance: 0)
        #expect(unlocked.contains(.score1000))
        #expect(unlocked.contains(.score5000))
    }

    @Test("score below threshold does not unlock achievement")
    func achievementNotUnlockedBelowThreshold() {
        let unlocked = GameManager.shared.checkAchievements(score: 999, clones: 1, distance: 0)
        #expect(!unlocked.contains(.score1000))
    }

    @Test("achievement is not re-awarded once unlocked")
    func achievementNotRepeated() {
        _ = GameManager.shared.checkAchievements(score: 1000, clones: 1, distance: 0)
        let secondCheck = GameManager.shared.checkAchievements(score: 1000, clones: 1, distance: 0)
        #expect(!secondCheck.contains(.score1000))
    }

    @Test("clones 3 achievement unlocks correctly")
    func achievementClones3() {
        let unlocked = GameManager.shared.checkAchievements(score: 0, clones: 3, distance: 0)
        #expect(unlocked.contains(.clones3))
    }

    @Test("clones 5 achievement unlocks clones3 and clones5")
    func achievementClones5UnlocksBoth() {
        let unlocked = GameManager.shared.checkAchievements(score: 0, clones: 5, distance: 0)
        #expect(unlocked.contains(.clones3))
        #expect(unlocked.contains(.clones5))
    }

    @Test("distance 1000 achievement unlocks correctly")
    func achievementDistance1000() {
        let unlocked = GameManager.shared.checkAchievements(score: 0, clones: 1, distance: 1000)
        #expect(unlocked.contains(.distance1000))
    }

    @Test("checkFirstPowerUp returns achievement once then nil")
    func checkFirstPowerUpIdempotent() {
        let first = GameManager.shared.checkFirstPowerUp()
        #expect(first == .firstPowerUp)

        let second = GameManager.shared.checkFirstPowerUp()
        #expect(second == nil)
    }

    @Test("checkBossAchievement returns achievement once then nil")
    func checkBossAchievementIdempotent() {
        let first = GameManager.shared.checkBossAchievement()
        #expect(first == .bossSlayer)

        let second = GameManager.shared.checkBossAchievement()
        #expect(second == nil)
    }

    // MARK: - Leaderboard Data

    @Test("getLeaderboardData contains expected keys")
    func getLeaderboardDataKeys() {
        let data = GameManager.shared.getLeaderboardData()
        #expect(data["highScore"] != nil)
        #expect(data["totalDistance"] != nil)
        #expect(data["maxClones"] != nil)
    }
}
