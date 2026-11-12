import Foundation

struct Player {
    static let halfWidth = 0.3
    static let height = 1.8
    static let eyeHeight = 1.62

    var pos: SIMD3<Double>
    var vel = SIMD3<Double>(0, 0, 0)
    var yaw = 0.0
    var pitch = 0.0
    var onGround = false

    init(pos: SIMD3<Double>) {
        self.pos = pos
    }

    /// input.x = strafe right, input.y = forward (both -1...1).
    mutating func update(dt: Double, input: SIMD2<Double>, jump: Bool, world: World) {
        let sy = sin(yaw), cy = cos(yaw)
        var dx = cy * input.x - sy * input.y
        var dz = -sy * input.x - cy * input.y
        let len = (dx * dx + dz * dz).squareRoot()
        if len > 1 {
            dx /= len
            dz /= len
        }
        let speed = 4.3
        vel.x = dx * speed
        vel.z = dz * speed

        let steps = max(1, Int((dt / 0.008).rounded(.up)))
        let h = dt / Double(steps)
        for _ in 0..<steps {
            vel.y = max(vel.y - 28.0 * h, -55.0)
            if jump && onGround {
                vel.y = 8.6
                onGround = false
            }
            moveAxis(0, vel.x * h, world)
            moveAxis(2, vel.z * h, world)
            moveAxis(1, vel.y * h, world)
        }
    }

    private mutating func moveAxis(_ axis: Int, _ delta: Double, _ world: World) {
        if axis == 1 { onGround = false }
        if delta == 0 { return }
        pos[axis] += delta
        guard collides(world) else { return }
        let hw = Player.halfWidth
        switch axis {
        case 0:
            if delta > 0 {
                pos.x = floor(pos.x + hw) - hw - 1e-6
            } else {
                pos.x = floor(pos.x - hw) + 1 + hw + 1e-6
            }
            vel.x = 0
        case 2:
            if delta > 0 {
                pos.z = floor(pos.z + hw) - hw - 1e-6
            } else {
                pos.z = floor(pos.z - hw) + 1 + hw + 1e-6
            }
            vel.z = 0
        default:
            if delta > 0 {
                pos.y = floor(pos.y + Player.height) - Player.height - 1e-6
            } else {
                pos.y = floor(pos.y) + 1 + 1e-6
                onGround = true
            }
            vel.y = 0
        }
    }

    private func collides(_ world: World) -> Bool {
        let hw = Player.halfWidth
        let x0 = Int(floor(pos.x - hw)), x1 = Int(floor(pos.x + hw - 1e-9))
        let y0 = Int(floor(pos.y)), y1 = Int(floor(pos.y + Player.height - 1e-9))
        let z0 = Int(floor(pos.z - hw)), z1 = Int(floor(pos.z + hw - 1e-9))
        for y in y0...y1 {
            for z in z0...z1 {
                for x in x0...x1 where world.block(x, y, z).isSolid {
                    return true
                }
            }
        }
        return false
    }

    func intersects(block b: SIMD3<Int>) -> Bool {
        let hw = Player.halfWidth
        let overlapX = pos.x + hw > Double(b.x) && pos.x - hw < Double(b.x + 1)
        let overlapY = pos.y + Player.height > Double(b.y) && pos.y < Double(b.y + 1)
        let overlapZ = pos.z + hw > Double(b.z) && pos.z - hw < Double(b.z + 1)
        return overlapX && overlapY && overlapZ
    }
}

struct RayHit {
    var block: SIMD3<Int>
    var previous: SIMD3<Int>?
}

/// Voxel traversal (Amanatides & Woo) to find the block the player is looking at.
enum Raycast {
    static func cast(origin o: SIMD3<Double>, dir d: SIMD3<Double>, maxDist: Double, world: World) -> RayHit? {
        var x = Int(floor(o.x)), y = Int(floor(o.y)), z = Int(floor(o.z))
        let sx = d.x > 0 ? 1 : -1
        let sy = d.y > 0 ? 1 : -1
        let sz = d.z > 0 ? 1 : -1
        let tdx = d.x == 0 ? Double.infinity : abs(1.0 / d.x)
        let tdy = d.y == 0 ? Double.infinity : abs(1.0 / d.y)
        let tdz = d.z == 0 ? Double.infinity : abs(1.0 / d.z)
        let fx = d.x > 0 ? Double(x + 1) - o.x : o.x - Double(x)
        let fy = d.y > 0 ? Double(y + 1) - o.y : o.y - Double(y)
        let fz = d.z > 0 ? Double(z + 1) - o.z : o.z - Double(z)
        var tmx = d.x == 0 ? Double.infinity : fx * tdx
        var tmy = d.y == 0 ? Double.infinity : fy * tdy
        var tmz = d.z == 0 ? Double.infinity : fz * tdz

        var prev: SIMD3<Int>? = nil
        var t = 0.0
        while t <= maxDist {
            if world.block(x, y, z).isSolid {
                return RayHit(block: SIMD3<Int>(x, y, z), previous: prev)
            }
            prev = SIMD3<Int>(x, y, z)
            if tmx < tmy && tmx < tmz {
                x += sx; t = tmx; tmx += tdx
            } else if tmy < tmz {
                y += sy; t = tmy; tmy += tdy
            } else {
                z += sz; t = tmz; tmz += tdz
            }
        }
        return nil
    }
}
