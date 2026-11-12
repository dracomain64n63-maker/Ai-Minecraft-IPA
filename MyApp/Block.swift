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
}

enum FaceKind { case top, bottom, side }

enum Block: UInt8 {
    case air = 0
    case grass, dirt, stone, sand, log, leaves, planks, cobblestone, bedrock

    var isSolid: Bool { self != .air }

    var name: String {
        switch self {
        case .air: return "Air"
        case .grass: return "Grass"
        case .dirt: return "Dirt"
        case .stone: return "Stone"
        case .sand: return "Sand"
        case .log: return "Log"
        case .leaves: return "Leaves"
        case .planks: return "Planks"
        case .cobblestone: return "Cobblestone"
        case .bedrock: return "Bedrock"
        }
    }

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
        }
    }
}
