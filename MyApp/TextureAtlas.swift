import SceneKit
import UIKit

/// All block textures are drawn in code at launch (16x16 pixel art, original colors/patterns).
enum TextureAtlas {
    static let tileSize = 16
    static let columns = 4
    static let tileCount = 11

    static let image: UIImage = makeAtlas()

    static let material: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = image
        m.diffuse.magnificationFilter = .nearest
        m.diffuse.minificationFilter = .nearest
        m.diffuse.mipFilter = .none
        m.lightingModel = .lambert
        m.isDoubleSided = false
        return m
    }()

    /// UV rectangle for a tile. v0 is the TOP of the tile in image space.
    static func uvRect(tile: Int) -> (u0: CGFloat, v0: CGFloat, u1: CGFloat, v1: CGFloat) {
        let step = 1.0 / CGFloat(columns)
        let inset: CGFloat = 0.002
        let col = CGFloat(tile % columns), row = CGFloat(tile / columns)
        return (col * step + inset, row * step + inset, (col + 1) * step - inset, (row + 1) * step - inset)
    }

    private static var tileCache: [Int: UIImage] = [:]

    static func tileImage(_ t: Int) -> UIImage {
        if let c = tileCache[t] { return c }
        let rect = CGRect(x: (t % columns) * tileSize, y: (t / columns) * tileSize, width: tileSize, height: tileSize)
        let img: UIImage
        if let cg = image.cgImage?.cropping(to: rect) {
            img = UIImage(cgImage: cg)
        } else {
            img = UIImage()
        }
        tileCache[t] = img
        return img
    }

    // MARK: Drawing

    private static func makeAtlas() -> UIImage {
        let size = tileSize * columns
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: fmt)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(red: 1, green: 0, blue: 1, alpha: 1)
            cg.fill(CGRect(x: 0, y: 0, width: size, height: size))
            for t in 0..<tileCount {
                var rng = SeededRNG(seed: UInt64(t + 1) &* 7919)
                let ox = (t % columns) * tileSize, oy = (t / columns) * tileSize
                for y in 0..<tileSize {
                    for x in 0..<tileSize {
                        let c = pixel(tile: t, x: x, y: y, rng: &rng)
                        cg.setFillColor(red: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255, blue: CGFloat(c.2) / 255, alpha: 1)
                        cg.fill(CGRect(x: ox + x, y: oy + y, width: 1, height: 1))
                    }
                }
            }
        }
    }

    private static func clamp(_ v: Int) -> Int { return max(0, min(255, v)) }

    private static func shade(_ c: (Int, Int, Int), _ d: Int) -> (Int, Int, Int) {
        return (clamp(c.0 + d), clamp(c.1 + d), clamp(c.2 + d))
    }

    private static func jitter(_ base: (Int, Int, Int), _ amount: Int, _ rng: inout SeededRNG) -> (Int, Int, Int) {
        let d = Int.random(in: -amount...amount, using: &rng)
        return shade(base, d)
    }

    private static func grassPixel(_ rng: inout SeededRNG) -> (Int, Int, Int) {
        return jitter((98, 160, 54), 14, &rng)
    }

    private static func dirtPixel(_ rng: inout SeededRNG) -> (Int, Int, Int) {
        var c = jitter((134, 96, 67), 12, &rng)
        if Int.random(in: 0..<10, using: &rng) == 0 { c = shade(c, -26) }
        return c
    }

    private static func pixel(tile: Int, x: Int, y: Int, rng: inout SeededRNG) -> (Int, Int, Int) {
        switch tile {
        case Tile.grassTop:
            return grassPixel(&rng)

        case Tile.grassSide:
            let depth = 3 + (x * 5) % 3
            if y < depth { return grassPixel(&rng) }
            return dirtPixel(&rng)

        case Tile.dirt:
            return dirtPixel(&rng)

        case Tile.stone:
            var c = jitter((127, 127, 127), 10, &rng)
            if Int.random(in: 0..<14, using: &rng) == 0 { c = shade(c, -22) }
            return c

        case Tile.sand:
            return jitter((219, 207, 160), 8, &rng)

        case Tile.logTop:
            let dx = Double(x) - 7.5, dy = Double(y) - 7.5
            let r = (dx * dx + dy * dy).squareRoot()
            if max(abs(dx), abs(dy)) > 6.6 { return jitter((98, 76, 46), 8, &rng) }
            let ring = Int(r) % 2 == 0
            let base: (Int, Int, Int) = ring ? (172, 142, 90) : (142, 112, 68)
            return jitter(base, 6, &rng)

        case Tile.logSide:
            let streak = ((x * 37 + 11) % 5 - 2) * 5
            return jitter(shade((104, 82, 52), streak), 7, &rng)

        case Tile.leaves:
            var c = jitter((52, 120, 38), 22, &rng)
            if Int.random(in: 0..<6, using: &rng) == 0 { c = shade(c, -40) }
            return c

        case Tile.planks:
            let board = y / 4
            var c = shade((160, 130, 80), board % 2 == 0 ? 6 : -6)
            if y % 4 == 3 { c = shade(c, -34) }
            let seam = board % 2 == 0 ? 7 : 0
            if x == seam { c = shade(c, -28) }
            return jitter(c, 5, &rng)

        case Tile.cobblestone:
            let row = y / 4
            let xs = x + (row % 2) * 2
            let cell = xs / 4
            let h = (cell * 73 + row * 151) & 7
            var c = shade((118, 118, 118), (h - 3) * 8)
            if xs % 4 == 0 || y % 4 == 0 { c = shade(c, -28) }
            return jitter(c, 5, &rng)

        case Tile.bedrock:
            var c = jitter((74, 74, 74), 28, &rng)
            if Int.random(in: 0..<5, using: &rng) == 0 { c = shade(c, -30) }
            return c

        default:
            return (255, 0, 255)
        }
    }
}
