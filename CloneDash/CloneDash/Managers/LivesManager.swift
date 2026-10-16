//
//  LivesManager.swift
//  CloneDash
//
//  Manages both the Continue system AND legacy Lives system
//

import Foundation

class LivesManager {
    
    static let shared = LivesManager()
    
    // MARK: - Constants
    
    private let livesKey = "playerLives"
    private let adsWatchedTodayKey = "adsWatchedToday"
    private let lastResetKey = "lastLivesReset"
    private let maxAdsPerDay = 10
    private let maxFreeLivesPerDay = 5
    
    // MARK: - Continue Tracking (per run)
    
    private(set) var continuesUsedThisRun: Int = 0
    let maxContinuesPerRun = 3
    
    // MARK: - Lives Properties (Legacy support for NoLivesPopup)
    
    private(set) var currentLives: Int {
        didSet {
            UserDefaults.standard.set(currentLives, forKey: livesKey)
            NotificationCenter.default.post(name: .livesChanged, object: nil, userInfo: ["lives": currentLives])
        }
    }
    
    var hasLives: Bool {
        return currentLives > 0
    }
    
    var livesDisplayText: String {
        return "\(currentLives)/\(maxFreeLivesPerDay)"
    }
    
    // Cost to buy a life with coins
    let coinCostPerLife = 100
    
    // MARK: - Ad Properties
    
    private(set) var adsWatchedToday: Int {
        didSet {
            UserDefaults.standard.set(adsWatchedToday, forKey: adsWatchedTodayKey)
        }
    }
    
    var canWatchAdForLife: Bool {
        return adsWatchedToday < maxAdsPerDay
    }
    
    // FIXED: Allow ads for ALL continues, not just the first one!
    var canWatchAdForContinue: Bool {
        return adsWatchedToday < maxAdsPerDay
    }
    
    var adsRemainingToday: Int {
        return max(0, maxAdsPerDay - adsWatchedToday)
    }
    
    // MARK: - Continue Properties
    
    var canContinue: Bool {
        return continuesUsedThisRun < maxContinuesPerRun
    }
    
    var currentContinueCost: Int {
        switch continuesUsedThisRun {
        case 0: return 50
        case 1: return 100
        case 2: return 200
        default: return 500
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        currentLives = UserDefaults.standard.integer(forKey: livesKey)
        adsWatchedToday = UserDefaults.standard.integer(forKey: adsWatchedTodayKey)
        
        // First launch - give max lives
        if currentLives == 0 && !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            currentLives = maxFreeLivesPerDay
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
        
        checkForDailyReset()
    }
    
    // MARK: - Daily Reset
    
    private func checkForDailyReset() {
        let lastReset = UserDefaults.standard.object(forKey: lastResetKey) as? Date ?? Date.distantPast
        
        if !Calendar.current.isDateInToday(lastReset) {
            performDailyReset()
        }
    }
    
    private func performDailyReset() {
        currentLives = maxFreeLivesPerDay
        adsWatchedToday = 0
        UserDefaults.standard.set(Date(), forKey: lastResetKey)
        #if DEBUG
        print("DEBUG: Daily reset - Lives restored to \(maxFreeLivesPerDay), Ad count reset")
        #endif
    }
    
    // MARK: - Continue System (New)
    
    /// Call when starting a new run
    func startNewRun() {
        continuesUsedThisRun = 0
        #if DEBUG
        print("DEBUG: New run started - continues reset")
        #endif
    }
    
    /// Use a continue (returns true if successful)
    func useContinue() -> Bool {
        guard canContinue else { return false }
        continuesUsedThisRun += 1
        #if DEBUG
        print("DEBUG: Continue used. Total this run: \(continuesUsedThisRun)")
        #endif
        return true
    }
    
    /// Use a continue via watching an ad
    func useContinueFromAd() -> Bool {
        guard canWatchAdForContinue && canContinue else { return false }
        adsWatchedToday += 1
        continuesUsedThisRun += 1
        #if DEBUG
        print("DEBUG: Ad continue used. Ads today: \(adsWatchedToday), Continues: \(continuesUsedThisRun)")
        #endif
        return true
    }
    
    /// Use a continue by spending coins
    func useContinueWithCoins() -> Bool {
        let cost = currentContinueCost
        guard GameManager.shared.coins >= cost && canContinue else { return false }
        
        _ = GameManager.shared.spendCoins(cost)
        continuesUsedThisRun += 1
        #if DEBUG
        print("DEBUG: Coin continue used. Cost: \(cost), Continues: \(continuesUsedThisRun)")
        #endif
        return true
    }
    
    var continuesRemainingText: String {
        let remaining = maxContinuesPerRun - continuesUsedThisRun
        return "\(remaining) continues left"
    }
    
    // MARK: - Legacy Lives System (for NoLivesPopup)
    
    /// Use a life when starting a run (legacy)
    func useLife() -> Bool {
        checkForDailyReset()
        
        guard currentLives > 0 else { return false }
        
        currentLives -= 1
        #if DEBUG
        print("DEBUG: Used 1 life. Remaining: \(currentLives)")
        #endif
        return true
    }
    
    /// Add lives (from purchase or reward)
    func addLives(_ amount: Int) {
        currentLives += amount
        #if DEBUG
        print("DEBUG: Added \(amount) lives. Total: \(currentLives)")
        #endif
    }
    
    /// Add a life from watching an ad
    func addLifeFromAd() -> Bool {
        guard canWatchAdForLife else {
            #if DEBUG
            print("DEBUG: Max ads reached for today")
            #endif
            return false
        }
        
        adsWatchedToday += 1
        currentLives += 1
        #if DEBUG
        print("DEBUG: Watched ad for life. Lives: \(currentLives), Ads today: \(adsWatchedToday)")
        #endif
        return true
    }
    
    /// Refund a life (e.g., if game crashes or error)
    func refundLife() {
        currentLives += 1
        #if DEBUG
        print("DEBUG: Refunded 1 life. Total: \(currentLives)")
        #endif
    }
    
    /// Purchase a life with coins (legacy)
    func purchaseLifeWithCoins() -> Bool {
        guard GameManager.shared.coins >= coinCostPerLife else { return false }
        
        _ = GameManager.shared.spendCoins(coinCostPerLife)
        addLives(1)
        return true
    }
    
}

// MARK: - Notification Names

extension Notification.Name {
    static let livesChanged = Notification.Name("livesChanged")
}
