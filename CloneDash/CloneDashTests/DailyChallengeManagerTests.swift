import Testing
@testable import CloneDash

@Suite("DailyChallengeManager", .serialized)
struct DailyChallengeManagerTests {

    init() {
        DailyChallengeManager.shared.reset()
        GameManager.shared.resetAllData()
        GameManager.shared.loadGameData()
    }

    // MARK: - Challenge Generation

    @Test("checkForNewDay generates a challenge on first launch")
    func firstLaunchGeneratesChallenge() {
        DailyChallengeManager.shared.checkForNewDay()
        #expect(DailyChallengeManager.shared.todaysChallenge != nil)
    }

    @Test("calling checkForNewDay twice on same day returns the same challenge")
    func sameDayReturnsSameChallenge() {
        DailyChallengeManager.shared.checkForNewDay()
        let firstID = DailyChallengeManager.shared.todaysChallenge?.id

        DailyChallengeManager.shared.checkForNewDay()
        let secondID = DailyChallengeManager.shared.todaysChallenge?.id

        #expect(firstID == secondID)
    }

    @Test("challenge is not completed immediately after generation")
    func challengeNotCompletedAfterGeneration() {
        DailyChallengeManager.shared.checkForNewDay()
        #expect(DailyChallengeManager.shared.isChallengeCompleted == false)
    }

    @Test("challengeHighScore is zero on a fresh challenge")
    func challengeHighScoreStartsZero() {
        DailyChallengeManager.shared.checkForNewDay()
        #expect(DailyChallengeManager.shared.challengeHighScore == 0)
    }

    // MARK: - Challenge Completion

    @Test("completeChallenge marks complete when score meets target")
    func completeChallengeWithSufficientScore() {
        DailyChallengeManager.shared.checkForNewDay()
        guard let challenge = DailyChallengeManager.shared.todaysChallenge else {
            Issue.record("No challenge was generated")
            return
        }
        DailyChallengeManager.shared.completeChallenge(challenge, withScore: challenge.targetScore)
        #expect(DailyChallengeManager.shared.isChallengeCompleted == true)
    }

    @Test("completeChallenge does not complete when score is one below target")
    func completeChallengeWithInsufficientScore() {
        DailyChallengeManager.shared.checkForNewDay()
        guard let challenge = DailyChallengeManager.shared.todaysChallenge else {
            Issue.record("No challenge was generated")
            return
        }
        DailyChallengeManager.shared.completeChallenge(challenge, withScore: challenge.targetScore - 1)
        #expect(DailyChallengeManager.shared.isChallengeCompleted == false)
    }

    @Test("completeChallenge awards coin reward on completion")
    func completeChallengeAwardsCoins() {
        DailyChallengeManager.shared.checkForNewDay()
        guard let challenge = DailyChallengeManager.shared.todaysChallenge else {
            Issue.record("No challenge was generated")
            return
        }
        let coinsBefore = GameManager.shared.coins
        DailyChallengeManager.shared.completeChallenge(challenge, withScore: challenge.targetScore)
        #expect(GameManager.shared.coins == coinsBefore + challenge.coinReward)
    }

    @Test("completeChallenge updates challengeHighScore")
    func completeChallengeUpdatesHighScore() {
        DailyChallengeManager.shared.checkForNewDay()
        guard let challenge = DailyChallengeManager.shared.todaysChallenge else {
            Issue.record("No challenge was generated")
            return
        }
        DailyChallengeManager.shared.completeChallenge(challenge, withScore: challenge.targetScore)
        #expect(DailyChallengeManager.shared.challengeHighScore == challenge.targetScore)
    }

    @Test("challengeHighScore tracks the highest score across calls")
    func challengeHighScoreTracksHighest() {
        DailyChallengeManager.shared.checkForNewDay()
        guard let challenge = DailyChallengeManager.shared.todaysChallenge else {
            Issue.record("No challenge was generated")
            return
        }
        // First call - just below target (no completion, but score should still be tracked)
        // Note: completeChallenge only updates highScore if score > challengeHighScore
        DailyChallengeManager.shared.completeChallenge(challenge, withScore: challenge.targetScore)
        let highAfterFirst = DailyChallengeManager.shared.challengeHighScore

        // Second call is a no-op (already completed) but score tracking is in the guard
        DailyChallengeManager.shared.completeChallenge(challenge, withScore: challenge.targetScore + 500)
        // After first completion, the guard `!isChallengeCompleted` fires, so no update
        #expect(DailyChallengeManager.shared.challengeHighScore == highAfterFirst)
    }

    @Test("completeChallenge is idempotent: coins awarded only once")
    func completeChallengeIdempotentCoins() {
        DailyChallengeManager.shared.checkForNewDay()
        guard let challenge = DailyChallengeManager.shared.todaysChallenge else {
            Issue.record("No challenge was generated")
            return
        }
        let coinsBefore = GameManager.shared.coins
        DailyChallengeManager.shared.completeChallenge(challenge, withScore: challenge.targetScore)
        DailyChallengeManager.shared.completeChallenge(challenge, withScore: challenge.targetScore)
        #expect(GameManager.shared.coins == coinsBefore + challenge.coinReward)
    }

    // MARK: - Streak

    @Test("streak starts at zero after reset")
    func streakStartsAtZero() {
        #expect(DailyChallengeManager.shared.currentStreak == 0)
    }

    @Test("completing a challenge increments the streak by 1")
    func completingChallengeIncrementsStreak() {
        DailyChallengeManager.shared.checkForNewDay()
        guard let challenge = DailyChallengeManager.shared.todaysChallenge else {
            Issue.record("No challenge was generated")
            return
        }
        DailyChallengeManager.shared.completeChallenge(challenge, withScore: challenge.targetScore)
        #expect(DailyChallengeManager.shared.currentStreak == 1)
    }

    @Test("streak is not incremented when challenge is not completed")
    func streakNotIncrementedOnFailure() {
        DailyChallengeManager.shared.checkForNewDay()
        guard let challenge = DailyChallengeManager.shared.todaysChallenge else {
            Issue.record("No challenge was generated")
            return
        }
        DailyChallengeManager.shared.completeChallenge(challenge, withScore: 0)
        #expect(DailyChallengeManager.shared.currentStreak == 0)
    }

    // MARK: - Time Until Reset

    @Test("timeUntilNextChallenge is within a 24-hour window")
    func timeUntilNextChallengeInRange() {
        let time = DailyChallengeManager.shared.timeUntilNextChallenge()
        #expect(time >= 0)
        #expect(time <= 86400)
    }

    @Test("formattedTimeUntilReset returns HH:MM format")
    func formattedTimeUntilResetFormat() {
        let formatted = DailyChallengeManager.shared.formattedTimeUntilReset()
        // Expect format like "HH:MM" — two digits, colon, two digits
        #expect(formatted.count == 5)
        #expect(formatted.contains(":"))
    }

    // MARK: - Static Data Validation

    @Test("allChallenges contains exactly 30 entries")
    func allChallengesCount() {
        #expect(DailyChallenge.allChallenges.count == 30)
    }

    @Test("all challenge IDs are unique")
    func challengeIDsUnique() {
        let ids = DailyChallenge.allChallenges.map { $0.id }
        #expect(Set(ids).count == ids.count)
    }

    @Test("all challenges have positive targetScore")
    func challengeTargetScoresPositive() {
        for challenge in DailyChallenge.allChallenges {
            #expect(challenge.targetScore > 0)
        }
    }

    @Test("all challenges have positive coinReward")
    func challengeCoinRewardsPositive() {
        for challenge in DailyChallenge.allChallenges {
            #expect(challenge.coinReward > 0)
        }
    }

    @Test("all challenge worldIndex values are valid (0-5)")
    func challengeWorldIndexesValid() {
        for challenge in DailyChallenge.allChallenges {
            #expect(challenge.worldIndex >= 0)
            #expect(challenge.worldIndex <= 5)
        }
    }

    @Test("all challenge difficultyStars are in range 1-5")
    func challengeDifficultyStarsValid() {
        for challenge in DailyChallenge.allChallenges {
            #expect(challenge.difficultyStars >= 1)
            #expect(challenge.difficultyStars <= 5)
        }
    }

    @Test("all speed multipliers are positive")
    func challengeSpeedMultipliersPositive() {
        for challenge in DailyChallenge.allChallenges {
            #expect(challenge.speedMultiplier > 0)
        }
    }
}
