# Clone Dash 🏃‍♂️

A unique top-down endless runner game for iOS where you control multiple clones simultaneously!

## 🎮 Game Concept

**The Twist:** Every 10 seconds, your runner CLONES! You must control all runners with the same swipe input. As clones multiply, the chaos and fun increases exponentially.

- **Start:** One runner, three lanes
- **10 seconds:** Two runners
- **20 seconds:** Three runners
- **And so on...**

You lose only when ALL clones die. This creates a unique "progressive multitasking" experience that's simple to learn but challenging to master.

## ✨ Features

### Core Gameplay
- **Lane-based movement** (3 lanes, swipe left/right)
- **Jump over obstacles** (swipe up)
- **Slide under barriers** (swipe down)
- **Clone mechanic** - runners duplicate every 10 seconds
- **Progressive difficulty** - speed increases over time

### Collectibles & Power-ups
- **Coins** - Currency for the shop
- **Gems** - Premium currency (rare)
- **Shield** - Protects from one hit
- **Slow Motion** - Slows everything down
- **Coin Magnet** - Attracts nearby coins
- **Clone Protect** - Saves one random clone

### Daily Challenges
Keep players coming back with rotating challenge modes:
- **Mirror Mode** - Controls are flipped!
- **Double Speed** - Everything is 2x faster
- **Clone Frenzy** - Clones every 5 seconds
- **Precision Mode** - Narrower lanes
- **Jump Master** - Only jumping allowed

### Customization
10 unlockable character skins:
- Classic (Free)
- Ninja
- Robot
- Astronaut
- Soccer Star
- Ghost
- Fire
- Ice
- Golden
- Rainbow

## 📱 Technical Details

### Requirements
- iOS 15.0+
- iPhone and iPad
- Xcode 15.0+
- Swift 5.0

### Architecture
Built with **SpriteKit** for optimal 2D game performance:

```
CloneDash/
├── Scenes/
│   ├── GameScene.swift      # Main gameplay
│   ├── MenuScene.swift      # Main menu
│   ├── GameOverScene.swift  # Results screen
│   └── ShopScene.swift      # Skin shop
├── Nodes/
│   ├── RunnerNode.swift     # Player character
│   ├── CollectibleNode.swift
│   ├── PowerUpNode.swift
│   ├── GameHUD.swift
│   ├── ForkNode.swift
│   └── ParticleEffects.swift
├── Managers/
│   ├── GameManager.swift    # Persistence & stats
│   ├── CloneManager.swift   # Clone spawning/control
│   ├── LaneSystem.swift     # Lane calculations
│   ├── ObstacleSpawner.swift
│   ├── SoundManager.swift
│   ├── SkinManager.swift
│   └── DailyChallengeManager.swift
└── Resources/
    ├── Assets.xcassets
    ├── Main.storyboard
    └── LaunchScreen.storyboard
```

### Key Classes

| Class | Purpose |
|-------|---------|
| `GameScene` | Main game loop, physics, collision handling |
| `CloneManager` | Spawns and controls multiple runners |
| `LaneSystem` | Manages lane positions and track layout |
| `ObstacleSpawner` | Procedural obstacle/collectible generation |
| `RunnerNode` | Player character with animations |
| `GameManager` | Save/load, stats, currency |

## 🚀 Getting Started

1. **Open in Xcode:**
   ```bash
   open CloneDash.xcodeproj
   ```

2. **Select your target device** (iPhone or iPad simulator)

3. **Build and Run** (⌘+R)

## 💰 Monetization (Ready to Implement)

The game is designed with these monetization options:

1. **Ad-Free Unlock** ($1.99) - Remove all ads
2. **Cosmetic Shop** - Skins purchased with in-game coins
3. **Optional IAPs:**
   - Extra lives/revives
   - Coin packs
   - Season pass (premium skins + daily bonuses)

## 🎨 Art Style

The game uses programmatic graphics (no external assets required):
- Flat 2D with shadows
- Vibrant neon colors on dark backgrounds
- Smooth animations via SKActions
- Particle effects for juice

To upgrade to custom assets:
1. Add sprites to Assets.xcassets
2. Update `RunnerNode` to use `SKSpriteNode` with textures
3. Add animation atlases for run cycles

## 🔊 Sound

Sound system is ready - just add your audio files:

1. Add .wav or .mp3 files to the project
2. Update `SoundManager.loadSounds()` with actual file names
3. Background music loops automatically

## 📊 Analytics Events (Suggested)

Track these events for optimization:
- `game_start`
- `game_over` (with score, distance, clones)
- `clone_spawned` (clone count)
- `item_collected` (type)
- `shop_viewed`
- `skin_purchased`
- `daily_challenge_completed`

## 🔧 Customization

### Adjust Difficulty
In `GameScene.swift`:
```swift
private var baseScrollSpeed: CGFloat = 300  // Starting speed
private var cloneInterval: TimeInterval = 10.0  // Clone timing
private var maxClones = 5  // Maximum runners
```

### Add New Skins
In `RunnerNode.swift`, add to `SkinType` enum and `RunnerSkin.all` array.

### Add New Power-ups
1. Add case to `PowerUpType` enum
2. Implement effect in `GameScene.handlePowerUpCollection()`
3. Add visual in `PowerUpNode.createIcon()`

## 📝 TODO / Future Enhancements

- [ ] Add actual sound effects
- [ ] Implement Game Center leaderboards
- [ ] Add more obstacle types
- [ ] Route fork mechanic (left/right path choice)
- [ ] Achievements system UI
- [ ] Tutorial for first-time players
- [ ] iCloud save sync
- [ ] Haptic feedback
- [ ] Watch complications for daily challenges

## 📄 License

This project is provided as a complete starter template. Use it for your own games!

---

**Happy Coding! 🎮**

*Built with ❤️ using SpriteKit and Swift*
