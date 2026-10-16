import Testing
@testable import CloneDash

@Suite("SkinManager", .serialized)
struct SkinManagerTests {

    init() {
        SkinManager.shared.resetSkins()
        GameManager.shared.resetAllData()
        GameManager.shared.loadGameData()
    }

    // MARK: - Initial State

    @Test("default skin is always unlocked after reset")
    func defaultSkinAlwaysUnlocked() {
        #expect(SkinManager.shared.isSkinUnlocked(.default) == true)
    }

    @Test("non-default skins start locked after reset")
    func nonDefaultSkinsStartLocked() {
        let lockedTypes: [RunnerSkin.SkinType] = [.ninja, .robot, .gold, .rainbow, .fire]
        for skinType in lockedTypes {
            #expect(SkinManager.shared.isSkinUnlocked(skinType) == false)
        }
    }

    @Test("only one skin is unlocked at start")
    func onlyDefaultUnlockedAtStart() {
        let unlockedCount = RunnerSkin.SkinType.allCases.filter {
            SkinManager.shared.isSkinUnlocked($0)
        }.count
        #expect(unlockedCount == 1)
    }

    // MARK: - Unlock With Coins

    @Test("unlockSkinWithCoins fails when player has no coins")
    func unlockSkinFailsWithNoCoins() {
        let result = SkinManager.shared.unlockSkinWithCoins(.ninja)
        #expect(result == false)
        #expect(SkinManager.shared.isSkinUnlocked(.ninja) == false)
    }

    @Test("unlockSkinWithCoins fails when coins are insufficient")
    func unlockSkinFailsInsufficientCoins() {
        let ninjaSkin = RunnerSkin.skin(for: .ninja)
        GameManager.shared.addCoins(ninjaSkin.coinPrice - 1)
        let result = SkinManager.shared.unlockSkinWithCoins(.ninja)
        #expect(result == false)
        #expect(SkinManager.shared.isSkinUnlocked(.ninja) == false)
    }

    @Test("unlockSkinWithCoins succeeds with exact coin balance")
    func unlockSkinSucceedsWithExactCoins() {
        let ninjaSkin = RunnerSkin.skin(for: .ninja)
        GameManager.shared.addCoins(ninjaSkin.coinPrice)
        let result = SkinManager.shared.unlockSkinWithCoins(.ninja)
        #expect(result == true)
        #expect(SkinManager.shared.isSkinUnlocked(.ninja) == true)
    }

    @Test("unlockSkinWithCoins deducts the correct coin amount")
    func unlockSkinDeductsCoins() {
        let ninjaSkin = RunnerSkin.skin(for: .ninja)
        GameManager.shared.addCoins(ninjaSkin.coinPrice + 50)
        let coinsBefore = GameManager.shared.coins
        _ = SkinManager.shared.unlockSkinWithCoins(.ninja)
        #expect(GameManager.shared.coins == coinsBefore - ninjaSkin.coinPrice)
    }

    @Test("unlockSkinWithCoins on an already-owned skin returns true and does not charge again")
    func unlockAlreadyOwnedSkinNoCost() {
        let ninjaSkin = RunnerSkin.skin(for: .ninja)
        GameManager.shared.addCoins(ninjaSkin.coinPrice + 200)
        _ = SkinManager.shared.unlockSkinWithCoins(.ninja)
        let coinsAfterFirstUnlock = GameManager.shared.coins

        let result = SkinManager.shared.unlockSkinWithCoins(.ninja)
        #expect(result == true)
        #expect(GameManager.shared.coins == coinsAfterFirstUnlock)  // no second charge
    }

    // MARK: - Unlock With Gems

    @Test("unlockSkinWithGems fails when player has no gems")
    func unlockSkinWithGemsFailsWithNoGems() {
        let result = SkinManager.shared.unlockSkinWithGems(.ninja)
        #expect(result == false)
        #expect(SkinManager.shared.isSkinUnlocked(.ninja) == false)
    }

    @Test("unlockSkinWithGems succeeds with sufficient gems")
    func unlockSkinWithGemsSuccess() {
        let ninjaSkin = RunnerSkin.skin(for: .ninja)
        GameManager.shared.addGems(ninjaSkin.gemPrice)
        let result = SkinManager.shared.unlockSkinWithGems(.ninja)
        #expect(result == true)
        #expect(SkinManager.shared.isSkinUnlocked(.ninja) == true)
    }

    @Test("unlockSkinWithGems deducts the correct gem amount")
    func unlockSkinWithGemsDeductsGems() {
        let ninjaSkin = RunnerSkin.skin(for: .ninja)
        GameManager.shared.addGems(ninjaSkin.gemPrice + 10)
        let gemsBefore = GameManager.shared.gems
        _ = SkinManager.shared.unlockSkinWithGems(.ninja)
        #expect(GameManager.shared.gems == gemsBefore - ninjaSkin.gemPrice)
    }

    // MARK: - Force Unlock

    @Test("forceUnlockSkin unlocks without spending coins")
    func forceUnlockSkinNoCoinCost() {
        #expect(GameManager.shared.coins == 0)
        SkinManager.shared.forceUnlockSkin(.robot)
        #expect(SkinManager.shared.isSkinUnlocked(.robot) == true)
        #expect(GameManager.shared.coins == 0)  // no coins spent
    }

    @Test("forceUnlockSkin is idempotent")
    func forceUnlockSkinIdempotent() {
        SkinManager.shared.forceUnlockSkin(.robot)
        SkinManager.shared.forceUnlockSkin(.robot)
        let robotCount = RunnerSkin.SkinType.allCases.filter {
            $0 == .robot && SkinManager.shared.isSkinUnlocked($0)
        }.count
        #expect(robotCount == 1)
    }

    // MARK: - Select Skin

    @Test("selectSkin ignores locked skins")
    func selectSkinIgnoresLocked() {
        SkinManager.shared.selectSkin(.ninja)  // ninja is locked
        let selected = SkinManager.shared.allSkins().first { $0.isSelected }?.type
        #expect(selected == .default)  // still on default
    }

    @Test("selectSkin switches to an unlocked skin")
    func selectSkinSwitchesToUnlocked() {
        let ninjaSkin = RunnerSkin.skin(for: .ninja)
        GameManager.shared.addCoins(ninjaSkin.coinPrice)
        _ = SkinManager.shared.unlockSkinWithCoins(.ninja)

        SkinManager.shared.selectSkin(.ninja)
        let selected = SkinManager.shared.allSkins().first { $0.isSelected }?.type
        #expect(selected == .ninja)
    }

    @Test("currentSkin reflects the selected skin type")
    func currentSkinMatchesSelection() {
        let ninjaSkin = RunnerSkin.skin(for: .ninja)
        GameManager.shared.addCoins(ninjaSkin.coinPrice)
        _ = SkinManager.shared.unlockSkinWithCoins(.ninja)
        SkinManager.shared.selectSkin(.ninja)
        #expect(SkinManager.shared.currentSkin.type == .ninja)
    }

    // MARK: - Reset

    @Test("resetSkins leaves only the default skin unlocked")
    func resetSkinsLeavesDefault() {
        SkinManager.shared.forceUnlockSkin(.ninja)
        SkinManager.shared.forceUnlockSkin(.robot)
        SkinManager.shared.forceUnlockSkin(.fire)
        SkinManager.shared.resetSkins()

        #expect(SkinManager.shared.isSkinUnlocked(.default) == true)
        #expect(SkinManager.shared.isSkinUnlocked(.ninja) == false)
        #expect(SkinManager.shared.isSkinUnlocked(.robot) == false)
        #expect(SkinManager.shared.isSkinUnlocked(.fire) == false)
    }

    @Test("resetSkins resets selection back to default")
    func resetSkinsResetsSelection() {
        let ninjaSkin = RunnerSkin.skin(for: .ninja)
        GameManager.shared.addCoins(ninjaSkin.coinPrice)
        _ = SkinManager.shared.unlockSkinWithCoins(.ninja)
        SkinManager.shared.selectSkin(.ninja)

        SkinManager.shared.resetSkins()

        let selected = SkinManager.shared.allSkins().first { $0.isSelected }?.type
        #expect(selected == .default)
    }

    // MARK: - All Skins

    @Test("allSkins returns one entry per SkinType")
    func allSkinsCountMatchesSkinTypes() {
        let allSkins = SkinManager.shared.allSkins()
        #expect(allSkins.count == RunnerSkin.SkinType.allCases.count)
    }

    @Test("allSkins marks exactly one skin as selected")
    func allSkinsExactlyOneSelected() {
        let selectedCount = SkinManager.shared.allSkins().filter { $0.isSelected }.count
        #expect(selectedCount == 1)
    }

    @Test("allSkins correctly reflects unlock status")
    func allSkinsReflectsUnlockStatus() {
        SkinManager.shared.forceUnlockSkin(.ninja)
        let ninjInfo = SkinManager.shared.allSkins().first { $0.type == .ninja }
        #expect(ninjInfo?.isUnlocked == true)
    }
}
