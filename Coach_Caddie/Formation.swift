import SwiftUI

// MARK: - Formation Enum with Corrected Player Counts
enum Formation: String, CaseIterable, Codable {
    case formation442 = "4-4-2"
    case formation433 = "4-3-3"
    case formation352 = "3-5-2"
    case formation451 = "4-5-1"
    case formation343 = "3-4-3"
    case formation4231 = "4-2-3-1"
    case formation532 = "5-3-2"
    case formation541 = "5-4-1"
    case formation41212 = "4-1-2-1-2"
    
    // 7v7 formations
    case formation7v7_312 = "3-1-2"
    case formation7v7_213 = "2-1-3"
    case formation7v7_321 = "3-2-1"
    case formation7v7_222 = "2-2-2"
    case formation7v7_231 = "2-3-1"  // NEW 7v7 formation
    
    // 9v9 formations
    case formation9v9_3212 = "3-2-1-2"
    case formation9v9_3131 = "3-1-3-1"
    case formation9v9_4121 = "4-1-2-1"
    case formation9v9_413 = "4-1-3"
    case formation9v9_323 = "3-2-3"
    case formation9v9_332 = "3-3-2"
    case formation9v9_233 = "2-3-3"
    
    // 5v5 formations (NO goalkeeper)
    case formation5v5_1211 = "1-2-1-1"
    case formation5v5_2111 = "2-1-1-1"
    case formation5v5_131 = "1-3-1"
    case formation5v5_221 = "2-2-1"
    case formation5v5_23 = "2-3"
    case formation5v5_32 = "3-2"

    var positions: [Position] {
        switch self {
        // 11v11 formations (10 field players + 1 goalkeeper = 11 total)
        case .formation442:
            return [
                .goalkeeper,
                .leftBack, .centerBack, .centerBack, .rightBack,
                .leftMidfield, .centerMidfield, .centerMidfield, .rightMidfield,
                .striker, .striker
            ]
            
        case .formation433:
            return [
                .goalkeeper,
                .leftBack, .centerBack, .centerBack, .rightBack,
                .centerMidfield, .centerMidfield, .centerMidfield,
                .leftWing, .striker, .rightWing
            ]
            
        case .formation352:
            return [
                .goalkeeper,
                .centerBack, .centerBack, .centerBack,
                .leftMidfield, .centerMidfield, .centerMidfield, .centerMidfield, .rightMidfield,
                .striker, .striker
            ]
            
        case .formation451:
            return [
                .goalkeeper,
                .leftBack, .centerBack, .centerBack, .rightBack,
                .leftMidfield, .centerMidfield, .centerMidfield, .centerMidfield, .rightMidfield,
                .striker
            ]
            
        case .formation343:
            return [
                .goalkeeper,
                .centerBack, .centerBack, .centerBack,
                .leftMidfield, .centerMidfield, .centerMidfield, .rightMidfield,
                .leftWing, .striker, .rightWing
            ]
            
        case .formation4231:
            return [
                .goalkeeper,
                .leftBack, .centerBack, .centerBack, .rightBack,
                .defensiveMidfield, .defensiveMidfield,
                .leftMidfield, .attackingMidfield, .rightMidfield,
                .striker
            ]
            
        case .formation532:
            return [
                .goalkeeper,
                .centerBack, .centerBack, .centerBack, .centerBack, .centerBack,
                .leftMidfield, .centerMidfield, .rightMidfield,
                .striker, .striker
            ]
            
        case .formation541:
            return [
                .goalkeeper,
                .centerBack, .centerBack, .centerBack, .centerBack, .centerBack,
                .leftMidfield, .centerMidfield, .centerMidfield, .rightMidfield,
                .striker
            ]
            
        case .formation41212:
            return [
                .goalkeeper,
                .leftBack, .centerBack, .centerBack, .rightBack,
                .defensiveMidfield,
                .leftMidfield, .rightMidfield,
                .attackingMidfield,
                .striker, .striker
            ]
            
        // 7v7 formations (6 field players + 1 goalkeeper = 7 total)
        case .formation7v7_312:
            return [
                .goalkeeper,
                .centerBack, .centerBack, .centerBack,
                .centerMidfield,
                .striker, .striker
            ]
            
        case .formation7v7_213:
            return [
                .goalkeeper,
                .rightBack, .leftBack,
                .centerMidfield,
                .leftWing, .striker, .rightWing
            ]
            
        case .formation7v7_321:
            return [
                .goalkeeper,
                .centerBack, .centerBack, .centerBack,
                .centerMidfield, .centerMidfield,
                .striker
            ]
            
        case .formation7v7_222:
            return [
                .goalkeeper,
                .rightBack, .leftBack,
                .rightCenterMidfield, .leftCenterMidfield,
                .striker, .striker
            ]
            
        // NEW 7v7 formation: 2-3-1 (GK + RB, LB + LM, CM, RM + ST)
        case .formation7v7_231:
            return [
                .goalkeeper,
                .rightBack, .leftBack,
                .leftMidfield, .centerMidfield, .rightMidfield,
                .striker
            ]
            
        // 9v9 formations (8 field players + 1 goalkeeper = 9 total)
        case .formation9v9_3212:
            return [
                .goalkeeper,
                .centerBack, .centerBack, .centerBack,
                .centerMidfield, .centerMidfield,
                .attackingMidfield,
                .striker, .striker
            ]
            
        case .formation9v9_3131:
            return [
                .goalkeeper,
                .centerBack, .centerBack, .centerBack,
                .centerMidfield,
                .leftMidfield, .attackingMidfield, .rightMidfield,
                .striker
            ]
            
        case .formation9v9_4121:
            return [
                .goalkeeper,
                .leftBack, .centerBack, .centerBack, .rightBack,
                .centerMidfield,
                .leftMidfield, .rightMidfield,
                .striker
            ]
            
        case .formation9v9_413:
            return [
                .goalkeeper,
                .leftBack, .centerBack, .centerBack, .rightBack,
                .centerMidfield,
                .leftWing, .striker, .rightWing
            ]
            
        case .formation9v9_323:
            return [
                .goalkeeper,
                .defender, .defender, .defender,
                .midfielder, .midfielder,
                .forward, .forward, .forward
            ]
            
        case .formation9v9_332:
            return [
                .goalkeeper,
                .defender, .defender, .defender,
                .midfielder, .midfielder, .midfielder,
                .forward, .forward
            ]
            
        case .formation9v9_233:
            return [
                .goalkeeper,
                .defender, .defender,
                .midfielder, .midfielder, .midfielder,
                .forward, .forward, .forward
            ]
            
        // 5v5 formations (5 field players, NO goalkeeper)
        case .formation5v5_1211:
            return [
                .defender,
                .centerMidfield, .centerMidfield,
                .forward, .forward
            ]
            
        case .formation5v5_2111:
            return [
                .defender, .defender,
                .centerMidfield,
                .forward, .forward
            ]
            
        case .formation5v5_131:
            return [
                .defender,
                .centerMidfield, .centerMidfield, .centerMidfield,
                .forward
            ]
            
        case .formation5v5_221:
            return [
                .defender, .defender,
                .centerMidfield, .centerMidfield,
                .forward
            ]
            
        case .formation5v5_23:
            return [
                .defender, .defender,
                .forward, .forward, .forward
            ]
            
        case .formation5v5_32:
            return [
                .defender, .defender, .defender,
                .forward, .forward
            ]
        }
    }
    
    func fieldPositions(for size: CGSize) -> [CGPoint] {
        let width = size.width
        let height = size.height
        
        // Calculate dynamic spacing to prevent overlap with safe boundaries
        let minSpacing: CGFloat = 45.0  // Minimum spacing between players
        let playerCount = positions.count
        
        // Safe zone boundaries to prevent cutoff
        let safeMarginX: CGFloat = 0.08  // 8% margin on sides
        let safeMarginY: CGFloat = 0.05  // 5% margin top/bottom
        
        // Helper closure to ensure points stay within safe boundaries
        let safePoint: (CGFloat, CGFloat) -> CGPoint = { x, y in
            let safeX = max(safeMarginX, min(1.0 - safeMarginX, x))
            let safeY = max(safeMarginY, min(1.0 - safeMarginY, y))
            return CGPoint(x: width * safeX, y: height * safeY)
        }
        
        switch self {
        // 11v11 formations - Enhanced spacing to prevent overlap with safe boundaries
        case .formation442:
            return [
                // Goalkeeper
                safePoint(0.03, 0.5),
                // Defense - moved higher from GK to prevent overlap
                safePoint(0.26, 0.08),  // LB (moved from 0.22 to 0.26)
                safePoint(0.26, 0.32),  // CB
                safePoint(0.26, 0.68),  // CB
                safePoint(0.26, 0.92),  // RB
                // Midfield - staggered to prevent overlap
                safePoint(0.5, 0.12),   // LM
                safePoint(0.5, 0.35),   // CM
                safePoint(0.5, 0.65),   // CM
                safePoint(0.5, 0.88),   // RM
                // Attack - wider spread
                safePoint(0.88, 0.28),  // ST
                safePoint(0.88, 0.72)   // ST
            ]
            
        case .formation433:
            return [
                // Goalkeeper
                safePoint(0.03, 0.5),
                // Defense - moved higher from GK
                safePoint(0.26, 0.08),  // LB (moved from 0.22 to 0.26)
                safePoint(0.26, 0.32),  // CB
                safePoint(0.26, 0.68),  // CB
                safePoint(0.26, 0.92),  // RB
                // Midfield - triangular formation
                safePoint(0.5, 0.2),    // CM
                safePoint(0.5, 0.5),    // CM
                safePoint(0.5, 0.8),    // CM
                // Attack - wings positioned lower than ST, wider spread
                safePoint(0.85, 0.12),  // LW (lower than ST)
                safePoint(0.92, 0.5),   // ST (highest)
                safePoint(0.85, 0.88)   // RW (lower than ST)
            ]
            
        case .formation352:
            return [
                // Goalkeeper
                safePoint(0.03, 0.5),
                // Defense - moved higher from GK
                safePoint(0.26, 0.25),  // LCB (moved from 0.22 to 0.26)
                safePoint(0.26, 0.5),   // CB
                safePoint(0.26, 0.75),  // RCB
                // Midfield - 5 players with better spacing
                safePoint(0.55, 0.1),   // LM
                safePoint(0.55, 0.32),  // LCM
                safePoint(0.55, 0.5),   // CM
                safePoint(0.55, 0.68),  // RCM
                safePoint(0.55, 0.9),   // RM
                // Attack
                safePoint(0.88, 0.35),  // ST
                safePoint(0.88, 0.65)   // ST
            ]
            
        case .formation451:
            return [
                // Goalkeeper
                safePoint(0.05, 0.5),
                // Defense - moved higher from GK
                safePoint(0.26, 0.1),   // LB (moved from 0.22 to 0.26)
                safePoint(0.26, 0.32),  // LCB
                safePoint(0.26, 0.68),  // RCB
                safePoint(0.26, 0.9),   // RB
                // Midfield - 5 players with safe spacing
                safePoint(0.5, 0.08),   // LM
                safePoint(0.5, 0.32),   // LCM
                safePoint(0.5, 0.5),    // CM
                safePoint(0.5, 0.68),   // RCM
                safePoint(0.5, 0.92),   // RM
                // Attack
                safePoint(0.88, 0.5)    // ST
            ]
            
        case .formation343:
            return [
                // Goalkeeper
                safePoint(0.03, 0.5),
                // Defense - moved higher from GK
                safePoint(0.26, 0.15),  // CB (moved from 0.22 to 0.26)
                safePoint(0.26, 0.5),   // CB
                safePoint(0.26, 0.85),  // CB
                // Midfield
                safePoint(0.5, 0.08),   // LM
                safePoint(0.5, 0.35),   // CM
                safePoint(0.5, 0.65),   // CM
                safePoint(0.5, 0.92),   // RM
                // Attack - wings positioned lower than ST
                safePoint(0.85, 0.12),  // LW (lower than ST)
                safePoint(0.92, 0.5),   // ST (highest)
                safePoint(0.85, 0.88)   // RW (lower than ST)
            ]
            
        case .formation4231:
            return [
                // Goalkeeper
                safePoint(0.03, 0.5),
                // Defense - moved higher from GK
                safePoint(0.26, 0.08),  // LB (moved from 0.22 to 0.26)
                safePoint(0.26, 0.32),  // CB
                safePoint(0.26, 0.68),  // CB
                safePoint(0.26, 0.92),  // RB
                // Defensive Midfield
                safePoint(0.4, 0.32),   // CDM
                safePoint(0.4, 0.68),   // CDM
                // Attacking Midfield - CAM higher than wide mids
                safePoint(0.62, 0.12),  // LM (lower)
                safePoint(0.68, 0.5),   // CAM (higher than LM/RM)
                safePoint(0.62, 0.88),  // RM (lower)
                // Attack
                safePoint(0.88, 0.5)    // ST
            ]
            
        case .formation532:
            return [
                // Goalkeeper
                safePoint(0.05, 0.5),
                // Defense - 5 CBs moved higher from GK
                safePoint(0.26, 0.1),   // LCB (moved from 0.22 to 0.26)
                safePoint(0.26, 0.3),   // LCB
                safePoint(0.26, 0.5),   // CB
                safePoint(0.26, 0.7),   // RCB
                safePoint(0.26, 0.9),   // RCB
                // Midfield - safe spacing
                safePoint(0.5, 0.25),   // LM
                safePoint(0.5, 0.5),    // CM
                safePoint(0.5, 0.75),   // RM
                // Attack
                safePoint(0.88, 0.35),  // ST
                safePoint(0.88, 0.65)   // ST
            ]
            
        case .formation541:
            return [
                // Goalkeeper
                safePoint(0.05, 0.5),
                // Defense - 5 CBs moved higher from GK
                safePoint(0.26, 0.1),   // LCB (moved from 0.22 to 0.26)
                safePoint(0.26, 0.3),   // LCB
                safePoint(0.26, 0.5),   // CB
                safePoint(0.26, 0.7),   // RCB
                safePoint(0.26, 0.9),   // RCB
                // Midfield - 4 players with safe spacing
                safePoint(0.5, 0.18),   // LM
                safePoint(0.5, 0.42),   // LCM
                safePoint(0.5, 0.58),   // RCM
                safePoint(0.5, 0.82),   // RM
                // Attack
                safePoint(0.88, 0.5)    // ST
            ]
            
        case .formation41212:
            return [
                // Goalkeeper
                safePoint(0.03, 0.5),
                // Defense - moved higher from GK
                safePoint(0.26, 0.08),  // LB (moved from 0.22 to 0.26)
                safePoint(0.26, 0.32),  // CB
                safePoint(0.26, 0.68),  // CB
                safePoint(0.26, 0.92),  // RB
                // Defensive Midfield
                safePoint(0.4, 0.5),    // CDM
                // Wide Midfield
                safePoint(0.55, 0.15),  // LM
                safePoint(0.55, 0.85),  // RM
                // Attacking Midfield
                safePoint(0.7, 0.5),    // CAM
                // Attack
                safePoint(0.88, 0.28),  // ST
                safePoint(0.88, 0.72)   // ST
            ]
            
        // 7v7 formations - Enhanced spacing
        case .formation7v7_312:
            return [
                // Goalkeeper
                safePoint(0.08, 0.5),
                // Defense
                safePoint(0.3, 0.15),   // CB
                safePoint(0.3, 0.5),    // CB
                safePoint(0.3, 0.85),   // CB
                // Midfield
                safePoint(0.6, 0.5),    // CM
                // Attack
                safePoint(0.9, 0.25),   // ST
                safePoint(0.9, 0.75)    // ST
            ]
            
        case .formation7v7_213:
            return [
                safePoint(0.08, 0.5),   // GK
                safePoint(0.32, 0.25),   // LB (FIXED: was at 0.8, now correctly at top)
                safePoint(0.32, 0.75),   // RB (FIXED: was at 0.2, now correctly at bottom)
                safePoint(0.56, 0.5),   // CM
                safePoint(0.82, 0.15),  // LW (lower than ST)
                safePoint(0.88, 0.5),   // ST (highest)
                safePoint(0.82, 0.85)   // RW (lower than ST)
            ]
            
        case .formation7v7_321:
            return [
                safePoint(0.08, 0.5),   // GK
                safePoint(0.32, 0.15),  // CB
                safePoint(0.32, 0.5),   // CB
                safePoint(0.32, 0.85),  // CB
                safePoint(0.64, 0.32),  // CM
                safePoint(0.64, 0.68),  // CM
                safePoint(0.88, 0.5)    // ST
            ]
            
        case .formation7v7_222:
            return [
                safePoint(0.08, 0.5),   // GK
                safePoint(0.32, 0.25),  // LB (FIXED: was at 0.75, now correctly at top)
                safePoint(0.32, 0.75),  // RB (FIXED: was at 0.25, now correctly at bottom)
                safePoint(0.6, 0.25),   // LCM (FIXED: now matches LB side)
                safePoint(0.6, 0.75),   // RCM (FIXED: now matches RB side)
                safePoint(0.88, 0.25),  // ST
                safePoint(0.88, 0.75)   // ST
            ]
            
        case .formation7v7_231:
            return [
                safePoint(0.08, 0.5),   // GK
                safePoint(0.32, 0.25),  // LB (FIXED: was at 0.75, now correctly at top)
                safePoint(0.32, 0.75),  // RB (FIXED: was at 0.25, now correctly at bottom)
                safePoint(0.6, 0.12),   // LM (FIXED: was at 0.88, now correctly left side)
                safePoint(0.6, 0.5),    // CM
                safePoint(0.6, 0.88),   // RM (FIXED: was at 0.12, now correctly right side)
                safePoint(0.88, 0.5)    // ST
            ]
            
        // 9v9 formations - Enhanced spacing
        case .formation9v9_3212:
            return [
                // Goalkeeper
                safePoint(0.08, 0.5),
                // Defense
                safePoint(0.28, 0.15),  // CB
                safePoint(0.28, 0.5),   // CB
                safePoint(0.28, 0.85),  // CB
                // Midfield
                safePoint(0.48, 0.28),  // CM
                safePoint(0.48, 0.72),  // CM
                // Attacking Midfield
                safePoint(0.68, 0.5),   // CAM
                // Attack
                safePoint(0.92, 0.28),  // ST
                safePoint(0.92, 0.72)   // ST
            ]
            
        case .formation9v9_3131:
            return [
                // Goalkeeper
                safePoint(0.08, 0.5),
                // Defense
                safePoint(0.28, 0.15),  // CB
                safePoint(0.28, 0.5),   // CB
                safePoint(0.28, 0.85),  // CB
                // Midfield
                safePoint(0.48, 0.5),   // CM
                // Attacking Midfield
                safePoint(0.68, 0.12),  // LM
                safePoint(0.68, 0.5),   // CAM
                safePoint(0.68, 0.88),  // RM
                // Attack
                safePoint(0.92, 0.5)    // ST
            ]
            
        case .formation9v9_4121:
            return [
                // Goalkeeper
                safePoint(0.08, 0.5),
                // Defense
                safePoint(0.28, 0.12),  // LB
                safePoint(0.28, 0.35),  // CB
                safePoint(0.28, 0.65),  // CB
                safePoint(0.28, 0.88),  // RB
                // Midfield
                safePoint(0.52, 0.5),   // CM
                // Wide Midfield
                safePoint(0.72, 0.15),  // LM
                safePoint(0.72, 0.85),  // RM
                // Attack
                safePoint(0.92, 0.5)    // ST
            ]
            
        case .formation9v9_413:
            return [
                // Goalkeeper
                safePoint(0.08, 0.5),
                // Defense
                safePoint(0.28, 0.12),  // LB
                safePoint(0.28, 0.35),  // CB
                safePoint(0.28, 0.65),  // CB
                safePoint(0.28, 0.88),  // RB
                // Midfield
                safePoint(0.52, 0.5),   // CM
                // Attack - wings positioned lower than ST
                safePoint(0.78, 0.12),  // LW (lower than ST)
                safePoint(0.88, 0.5),   // ST (highest)
                safePoint(0.78, 0.88)   // RW (lower than ST)
            ]
            
        case .formation9v9_323:
            return [
                safePoint(0.08, 0.5),   // GK
                safePoint(0.28, 0.15),  // DEF
                safePoint(0.28, 0.5),   // DEF
                safePoint(0.28, 0.85),  // DEF
                safePoint(0.52, 0.28),  // MID
                safePoint(0.52, 0.72),  // MID
                safePoint(0.84, 0.12),  // FWD
                safePoint(0.84, 0.5),   // FWD
                safePoint(0.84, 0.88)   // FWD
            ]
            
        case .formation9v9_332:
            return [
                safePoint(0.08, 0.5),   // GK
                safePoint(0.28, 0.15),  // DEF
                safePoint(0.28, 0.5),   // DEF
                safePoint(0.28, 0.85),  // DEF
                safePoint(0.52, 0.12),  // MID
                safePoint(0.52, 0.5),   // MID
                safePoint(0.52, 0.88),  // MID
                safePoint(0.84, 0.28),  // FWD
                safePoint(0.84, 0.72)   // FWD
            ]
            
        case .formation9v9_233:
            return [
                safePoint(0.08, 0.5),   // GK
                safePoint(0.28, 0.25),  // DEF
                safePoint(0.28, 0.75),  // DEF
                safePoint(0.52, 0.12),  // MID
                safePoint(0.52, 0.5),   // MID
                safePoint(0.52, 0.88),  // MID
                safePoint(0.84, 0.12),  // FWD
                safePoint(0.84, 0.5),   // FWD
                safePoint(0.84, 0.88)   // FWD
            ]
            
        // 5v5 formations - Enhanced spacing (no goalkeeper)
        case .formation5v5_1211:
            return [
                // Defense
                safePoint(0.15, 0.5),   // DEF
                // Midfield
                safePoint(0.45, 0.25),  // MID
                safePoint(0.45, 0.75),  // MID
                // Attack
                safePoint(0.85, 0.25),  // FWD
                safePoint(0.85, 0.75)   // FWD
            ]
            
        case .formation5v5_2111:
            return [
                // Defense
                safePoint(0.15, 0.25),  // DEF
                safePoint(0.15, 0.75),  // DEF
                // Midfield
                safePoint(0.45, 0.5),   // MID
                // Attack
                safePoint(0.85, 0.25),  // FWD
                safePoint(0.85, 0.75)   // FWD
            ]
            
        case .formation5v5_131:
            return [
                // Defense
                safePoint(0.15, 0.5),   // DEF
                // Midfield - 3 players with good spacing
                safePoint(0.45, 0.15),  // MID
                safePoint(0.45, 0.5),   // MID
                safePoint(0.45, 0.85),  // MID
                // Attack
                safePoint(0.85, 0.5)    // FWD
            ]
            
        case .formation5v5_221:
            return [
                // Defense
                safePoint(0.15, 0.25),  // DEF
                safePoint(0.15, 0.75),  // DEF
                // Midfield
                safePoint(0.45, 0.25),  // MID
                safePoint(0.45, 0.75),  // MID
                // Attack
                safePoint(0.85, 0.5)    // FWD
            ]
            
        case .formation5v5_23:
            return [
                // Defense
                safePoint(0.15, 0.25),  // DEF
                safePoint(0.15, 0.75),  // DEF
                // Attack - 3 forwards with good spacing
                safePoint(0.7, 0.12),   // FWD
                safePoint(0.7, 0.5),    // FWD
                safePoint(0.7, 0.88)    // FWD
            ]
            
        case .formation5v5_32:
            return [
                // Defense - 3 defenders with good spacing
                safePoint(0.15, 0.12),  // DEF
                safePoint(0.15, 0.5),   // DEF
                safePoint(0.15, 0.88),  // DEF
                // Attack
                safePoint(0.7, 0.32),   // FWD
                safePoint(0.7, 0.68)    // FWD
            ]
            
        default:
            // Default positioning with enhanced spacing
            return positions.enumerated().map { index, _ in
                let rows = ceil(sqrt(Double(positions.count)))
                let cols = ceil(Double(positions.count) / rows)
                let row = Double(index) / cols
                let col = Double(index).truncatingRemainder(dividingBy: cols)
                
                // Enhanced spacing calculation
                let xSpacing = (width * 0.8) / max(cols, 1)
                let ySpacing = (height * 0.8) / max(rows, 1)
                
                // Ensure minimum spacing
                let finalXSpacing = max(xSpacing, minSpacing)
                let finalYSpacing = max(ySpacing, minSpacing)
                
                return CGPoint(
                    x: width * 0.1 + finalXSpacing * (col + 0.5),
                    y: height * 0.1 + finalYSpacing * (row + 0.5)
                )
            }
        }
    }
}

// MARK: - Position Enum with All Positions
enum Position: String, CaseIterable, Codable {
    case goalkeeper = "Goalkeeper"
    case centerBack = "Center Back"
    case leftBack = "Left Back"
    case rightBack = "Right Back"
    case defender = "Defender"
    case defensiveMidfield = "Defensive Midfielder"
    case centerMidfield = "Center Midfielder"
    case leftMidfield = "Left Midfielder"
    case rightMidfield = "Right Midfielder"
    case attackingMidfield = "Attacking Midfielder"
    case midfielder = "Midfielder"
    case leftWing = "Left Wing"
    case rightWing = "Right Wing"
    case striker = "Striker"
    case forward = "Forward"
    case rightCenterMidfield = "Right Center Midfielder"
    case leftCenterMidfield = "Left Center Midfielder"
    
    var abbreviation: String {
        switch self {
        case .goalkeeper: return "GK"
        case .centerBack: return "CB"
        case .leftBack: return "LB"
        case .rightBack: return "RB"
        case .defender: return "DEF"
        case .defensiveMidfield: return "CDM"
        case .centerMidfield: return "CM"
        case .leftMidfield: return "LM"
        case .rightMidfield: return "RM"
        case .attackingMidfield: return "CAM"
        case .midfielder: return "MID"
        case .leftWing: return "LW"
        case .rightWing: return "RW"
        case .striker: return "ST"
        case .forward: return "FW"
        case .rightCenterMidfield: return "RCM"
        case .leftCenterMidfield: return "LCM"
        }
    }
    
    var color: Color {
        switch self {
        case .goalkeeper:
            return Color.yellow
        case .centerBack, .leftBack, .rightBack, .defender:
            return Color.blue
        case .defensiveMidfield, .centerMidfield, .leftMidfield, .rightMidfield, .attackingMidfield, .midfielder, .rightCenterMidfield, .leftCenterMidfield:
            return Color.green
        case .leftWing, .rightWing, .striker, .forward:
            return Color.red
        }
    }
}

// MARK: - Team Format with Available Formations - NO DUPLICATES
enum GameFormat: String, CaseIterable, Codable {
    case fiveVFive = "5v5"
    case sevenVSeven = "7v7"
    case nineVNine = "9v9"
    case elevenVEleven = "11v11"
    
    var playerCount: Int {
        switch self {
        case .fiveVFive: return 5      // 5 field players, NO goalkeeper
        case .sevenVSeven: return 7    // 6 field players + 1 goalkeeper
        case .nineVNine: return 9      // 8 field players + 1 goalkeeper
        case .elevenVEleven: return 11 // 10 field players + 1 goalkeeper
        }
    }
    
    var hasGoalkeeper: Bool {
        switch self {
        case .fiveVFive: return false
        case .sevenVSeven, .nineVNine, .elevenVEleven: return true
        }
    }
    
    var availableFormations: [Formation] {
        switch self {
        case .fiveVFive:
            return [.formation5v5_1211, .formation5v5_2111, .formation5v5_131, .formation5v5_221, .formation5v5_23, .formation5v5_32]
        case .sevenVSeven:
            return [.formation7v7_312, .formation7v7_213, .formation7v7_321, .formation7v7_222, .formation7v7_231]
        case .nineVNine:
            return [.formation9v9_3212, .formation9v9_3131, .formation9v9_4121, .formation9v9_413, .formation9v9_323, .formation9v9_332, .formation9v9_233]
        case .elevenVEleven:
            return [.formation442, .formation433, .formation352, .formation451, .formation343, .formation4231, .formation532, .formation541, .formation41212]
        }
    }
    
    var defaultFormation: Formation {
        switch self {
        case .fiveVFive: return .formation5v5_1211
        case .sevenVSeven: return .formation7v7_312
        case .nineVNine: return .formation9v9_3212
        case .elevenVEleven: return .formation442
        }
    }
}

// MARK: - Extension for Team to get default formation
extension Team {
    var teamDefaultFormation: Formation {
        return format.defaultFormation
    }
}
