import Foundation

/// Tile indices inside the 4x4 texture atlas.
enum Tile {
    static let grassTop = 0
    static let grassSide = 1
    static let dirt = 2
    static let stone = 3
    static let sand = 4
    static let logTop = 5
    static let logSide = 6
    static let leaves = 7
    static let planks = 8
    static let cobblestone = 9
    static let bedrock = 10
    static let water = 11
}

enum FaceKind { case top, bottom, side }

enum Block: UInt8 {
    case air = 0
    case grass, dirt, stone, sand, log, leaves, planks, cobblestone, bedrock, water

    var isSolid: Bool { self != .air && self != .water }
    var isLiquid: Bool { self == .water }

    var name: String {
        switch self {
        case .air: return "Air"
        case .grass: return "Grass Block"
        case .dirt: return "Dirt"
        case .stone: return "Stone"
        case .sand: return "Sand"
        case .log: return "Oak Log"
        case .leaves: return "Oak Leaves"
        case .planks: return "Oak Planks"
        case .cobblestone: return "Cobblestone"
        case .bedrock: return "Bedrock"
        case .water: return "Water"
        }
    }

    /// Relative hardness, same idea as Minecraft's block hardness values.
    var hardness: Double {
        switch self {
        case .air, .water: return 0
        case .grass: return 0.6
        case .dirt, .sand: return 0.5
        case .leaves: return 0.2
        case .log, .planks, .cobblestone: return 2.0
        case .stone: return 1.5
        case .bedrock: return .infinity
        }
    }

    /// Seconds to break by hand (no tools exist yet).
    var breakTime: Double { max(0.2, hardness * 0.6) }

    /// Temporary: every block except leaves gives 1 XP until ores and mobs exist.
    var xpReward: Int { self == .leaves ? 0 : 1 }

    func tile(_ face: FaceKind) -> Int {
        switch self {
        case .air: return Tile.stone
        case .grass:
            switch face {
            case .top: return Tile.grassTop
            case .bottom: return Tile.dirt
            case .side: return Tile.grassSide
            }
        case .dirt: return Tile.dirt
        case .stone: return Tile.stone
        case .sand: return Tile.sand
        case .log: return face == .side ? Tile.logSide : Tile.logTop
        case .leaves: return Tile.leaves
        case .planks: return Tile.planks
        case .cobblestone: return Tile.cobblestone
        case .bedrock: return Tile.bedrock
        case .water: return Tile.water
        }
    }
}
