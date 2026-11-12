import Foundation

let chunkSize = 16
let worldHeight = 64

@inline(__always) func floorDiv(_ a: Int, _ b: Int) -> Int {
    let q = a / b
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
}

@inline(__always) func floorMod(_ a: Int, _ b: Int) -> Int {
    let m = a % b
    return m < 0 ? m + b : m
}

struct ChunkPos: Hashable {
    var x: Int
    var z: Int
}

final class Chunk {
    let pos: ChunkPos
    var blocks: [UInt8]
    var topY = 0
    var modified = false

    init(pos: ChunkPos) {
        self.pos = pos
        blocks = [UInt8](repeating: 0, count: chunkSize * chunkSize * worldHeight)
    }

    @inline(__always) static func index(_ x: Int, _ y: Int, _ z: Int) -> Int {
        return (y * chunkSize + z) * chunkSize + x
    }

    @inline(__always) func get(_ x: Int, _ y: Int, _ z: Int) -> Block {
        return Block(rawValue: blocks[Chunk.index(x, y, z)]) ?? .air
    }

    func set(_ x: Int, _ y: Int, _ z: Int, _ b: Block) {
        blocks[Chunk.index(x, y, z)] = b.rawValue
        if b != .air && y > topY { topY = y }
    }

    func recomputeTopY() {
        topY = 0
        for y in stride(from: worldHeight - 1, through: 0, by: -1) {
            for z in 0..<chunkSize {
                for x in 0..<chunkSize where blocks[Chunk.index(x, y, z)] != 0 {
                    topY = y
                    return
                }
            }
        }
    }
}

final class World {
    static let defaultSeed: UInt32 = 20240607
    static let beachLevel = 24

    let noise: Noise
    let directory: URL
    private(set) var chunks: [ChunkPos: Chunk] = [:]
    private var dirty = Set<ChunkPos>()
    private var cachePos: ChunkPos?
    private var cacheChunk: Chunk?

    init(directory: URL, seed: UInt32 = World.defaultSeed) {
        self.directory = directory
        self.noise = Noise(seed: seed)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: Access

    func chunk(at p: ChunkPos) -> Chunk {
        if let c = cacheChunk, cachePos == p { return c }
        let c: Chunk
        if let existing = chunks[p] {
            c = existing
        } else {
            c = load(p) ?? generate(p)
            chunks[p] = c
        }
        cachePos = p
        cacheChunk = c
        return c
    }

    /// Unloaded space below the world counts as solid, above as air.
    func block(_ x: Int, _ y: Int, _ z: Int) -> Block {
        if y < 0 { return .stone }
        if y >= worldHeight { return .air }
        let c = chunk(at: ChunkPos(x: floorDiv(x, chunkSize), z: floorDiv(z, chunkSize)))
        return c.get(floorMod(x, chunkSize), y, floorMod(z, chunkSize))
    }

    func setBlock(_ x: Int, _ y: Int, _ z: Int, _ b: Block) {
        guard y >= 0 && y < worldHeight else { return }
        let cp = ChunkPos(x: floorDiv(x, chunkSize), z: floorDiv(z, chunkSize))
        let lx = floorMod(x, chunkSize), lz = floorMod(z, chunkSize)
        let c = chunk(at: cp)
        c.set(lx, y, lz, b)
        c.modified = true
        dirty.insert(cp)
        if lx == 0 { dirty.insert(ChunkPos(x: cp.x - 1, z: cp.z)) }
        if lx == chunkSize - 1 { dirty.insert(ChunkPos(x: cp.x + 1, z: cp.z)) }
        if lz == 0 { dirty.insert(ChunkPos(x: cp.x, z: cp.z - 1)) }
        if lz == chunkSize - 1 { dirty.insert(ChunkPos(x: cp.x, z: cp.z + 1)) }
    }

    func takeDirty() -> Set<ChunkPos> {
        let d = dirty
        dirty.removeAll()
        return d
    }

    func surfaceHeight(_ x: Int, _ z: Int) -> Int {
        for y in stride(from: worldHeight - 1, through: 0, by: -1) where block(x, y, z) != .air {
            return y
        }
        return 0
    }

    // MARK: Persistence

    private func url(for p: ChunkPos) -> URL {
        return directory.appendingPathComponent("c.\(p.x).\(p.z).bin")
    }

    private func load(_ p: ChunkPos) -> Chunk? {
        guard let data = try? Data(contentsOf: url(for: p)),
              data.count == chunkSize * chunkSize * worldHeight else { return nil }
        let c = Chunk(pos: p)
        c.blocks = [UInt8](data)
        c.recomputeTopY()
        return c
    }

    private func write(_ c: Chunk) {
        try? Data(c.blocks).write(to: url(for: c.pos), options: .atomic)
        c.modified = false
    }

    func saveModified() {
        for c in chunks.values where c.modified { write(c) }
    }

    func unloadChunks(center: ChunkPos, radius: Int) {
        for (p, c) in chunks {
            let dx = p.x - center.x, dz = p.z - center.z
            if dx * dx + dz * dz > radius * radius {
                if c.modified { write(c) }
                chunks[p] = nil
            }
        }
        cachePos = nil
        cacheChunk = nil
    }

    // MARK: Generation

    func terrainHeight(_ x: Int, _ z: Int) -> Int {
        let fx = Double(x), fz = Double(z)
        let base = noise.fbm(fx / 90.0, fz / 90.0, octaves: 4)
        let hills = noise.fbm(fx / 28.0 + 100.0, fz / 28.0 + 100.0, octaves: 3)
        let h = 28.0 + (base - 0.5) * 40.0 + (hills - 0.5) * 12.0
        return max(3, min(worldHeight - 14, Int(h)))
    }

    private func generate(_ p: ChunkPos) -> Chunk {
        let c = Chunk(pos: p)
        let ox = p.x * chunkSize, oz = p.z * chunkSize
        var heights = [Int](repeating: 0, count: chunkSize * chunkSize)

        for lz in 0..<chunkSize {
            for lx in 0..<chunkSize {
                let h = terrainHeight(ox + lx, oz + lz)
                heights[lz * chunkSize + lx] = h
                let sandy = h <= World.beachLevel
                for y in 0...h {
                    let b: Block
                    if y == 0 {
                        b = .bedrock
                    } else if y < h - 3 {
                        b = .stone
                    } else if y < h {
                        b = sandy ? .sand : .dirt
                    } else {
                        b = sandy ? .sand : .grass
                    }
                    c.set(lx, y, lz, b)
                }
            }
        }

        // Trees stay at least 2 blocks from the chunk edge so they never cross chunks.
        for lz in 2..<(chunkSize - 2) {
            for lx in 2..<(chunkSize - 2) {
                let h = heights[lz * chunkSize + lx]
                if h <= World.beachLevel { continue }
                let r = noise.hash((ox + lx) * 31 + 7, (oz + lz) * 17 + 3)
                if r > 0.993 {
                    placeTree(c, lx, h + 1, lz, trunk: 4 + Int(r * 1000) % 3)
                }
            }
        }
        return c
    }

    private func placeTree(_ c: Chunk, _ x: Int, _ y: Int, _ z: Int, trunk: Int) {
        for i in 0..<trunk where y + i < worldHeight {
            c.set(x, y + i, z, .log)
        }
        let top = y + trunk
        for dy in -2...1 {
            let radius = dy < 0 ? 2 : 1
            let yy = top + dy
            if yy >= worldHeight { continue }
            for dz in -radius...radius {
                for dx in -radius...radius {
                    if abs(dx) == radius && abs(dz) == radius && dy >= 0 { continue }
                    if c.get(x + dx, yy, z + dz) == .air {
                        c.set(x + dx, yy, z + dz, .leaves)
                    }
                }
            }
        }
    }
}
