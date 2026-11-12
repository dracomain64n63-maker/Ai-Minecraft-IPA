import SceneKit
import UIKit
import QuartzCore

struct PlayerState: Codable {
    var x: Double
    var y: Double
    var z: Double
    var yaw: Double
    var pitch: Double
    var slot: Int
}

/// Shared input state written by the SwiftUI controls and read by the game loop.
final class Controls: ObservableObject {
    var move = SIMD2<Double>(0, 0)
    var jumpHeld = false
    var breakHeld = false
    var placeTapped = false
    var lookDelta = SIMD2<Double>(0, 0)
    @Published var selectedSlot = 0
}

final class Game: NSObject, ObservableObject {
    static let hotbar: [Block] = [.grass, .dirt, .stone, .cobblestone, .planks, .log, .sand, .leaves]
    static let renderRadius = 5

    let controls = Controls()
    let scene = SCNScene()
    let cameraNode = SCNNode()

    private let chunkRoot = SCNNode()
    private let highlight = SCNNode()
    private let world: World
    private var player: Player
    private let spawn: SIMD3<Double>
    private var chunkNodes: [ChunkPos: SCNNode] = [:]
    private var pending: [ChunkPos] = []
    private var lastCenter: ChunkPos?
    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var breakCooldown = 0.0
    private var saveTimer = 0.0
    private var frame = 0
    private var savedSlot = 0

    override init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("world1", isDirectory: true)
        let w = World(directory: dir)
        world = w
        let surface = w.surfaceHeight(0, 0)
        let sp = SIMD3<Double>(0.5, Double(surface + 1), 0.5)
        spawn = sp
        var p = Player(pos: sp)
        var slot = 0
        if let data = try? Data(contentsOf: dir.appendingPathComponent("player.json")),
           let st = try? JSONDecoder().decode(PlayerState.self, from: data) {
            p.pos = SIMD3<Double>(st.x, st.y, st.z)
            p.yaw = st.yaw
            p.pitch = st.pitch
            slot = max(0, min(Game.hotbar.count - 1, st.slot))
        }
        player = p
        savedSlot = slot
        super.init()
        controls.selectedSlot = savedSlot
        setupScene()
    }

    // MARK: Scene

    private func setupScene() {
        let sky = UIColor(red: 0.53, green: 0.78, blue: 0.95, alpha: 1)
        scene.background.contents = sky
        scene.fogColor = sky
        scene.fogStartDistance = CGFloat(Game.renderRadius * chunkSize - 30)
        scene.fogEndDistance = CGFloat(Game.renderRadius * chunkSize - 4)
        scene.fogDensityExponent = 1

        let cam = SCNCamera()
        cam.zNear = 0.05
        cam.zFar = 200
        cam.fieldOfView = 70
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(chunkRoot)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 700
        scene.rootNode.addChildNode(sun)
        sun.look(at: SCNVector3(-0.337, -0.842, -0.421))

        // Wireframe cube: 8 corners, 12 edges (a plain .lines fill mode would show face diagonals).
        let s: Float = 0.502
        let corners: [SCNVector3] = [
            SCNVector3(-s, -s, -s), SCNVector3(s, -s, -s), SCNVector3(s, -s, s), SCNVector3(-s, -s, s),
            SCNVector3(-s, s, -s), SCNVector3(s, s, -s), SCNVector3(s, s, s), SCNVector3(-s, s, s)
        ]
        let edges: [Int32] = [0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7]
        let wire = SCNGeometry(sources: [SCNGeometrySource(vertices: corners)],
                               elements: [SCNGeometryElement(indices: edges, primitiveType: .line)])
        let m = SCNMaterial()
        m.diffuse.contents = UIColor.black
        m.lightingModel = .constant
        wire.materials = [m]
        highlight.geometry = wire
        highlight.isHidden = true
        highlight.renderingOrder = 10
        scene.rootNode.addChildNode(highlight)
    }

    // MARK: Loop

    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
        NotificationCenter.default.addObserver(self, selector: #selector(save),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        var dt = lastTime == 0 ? 1.0 / 60.0 : now - lastTime
        lastTime = now
        dt = min(dt, 0.05)
        frame += 1

        // Look
        let ld = controls.lookDelta
        controls.lookDelta = SIMD2<Double>(0, 0)
        player.yaw -= ld.x * 0.006
        player.pitch = max(-1.5, min(1.5, player.pitch - ld.y * 0.006))

        // Move
        player.update(dt: dt, input: controls.move, jump: controls.jumpHeld, world: world)
        if player.pos.y < -30 {
            player.pos = spawn
            player.vel = SIMD3<Double>(0, 0, 0)
        }

        cameraNode.position = SCNVector3(Float(player.pos.x),
                                         Float(player.pos.y + Player.eyeHeight),
                                         Float(player.pos.z))
        cameraNode.eulerAngles = SCNVector3(Float(player.pitch), Float(player.yaw), 0)

        interact(dt: dt)

        let center = ChunkPos(x: floorDiv(Int(floor(player.pos.x)), chunkSize),
                              z: floorDiv(Int(floor(player.pos.z)), chunkSize))
        updateStreaming(center: center)

        saveTimer += dt
        if saveTimer > 15 {
            saveTimer = 0
            save()
        }
    }

    // MARK: Interaction

    private func interact(dt: Double) {
        breakCooldown -= dt
        let eye = SIMD3<Double>(player.pos.x, player.pos.y + Player.eyeHeight, player.pos.z)
        let cp = cos(player.pitch)
        let dir = SIMD3<Double>(-sin(player.yaw) * cp, sin(player.pitch), -cos(player.yaw) * cp)
        let hit = Raycast.cast(origin: eye, dir: dir, maxDist: 5, world: world)

        if let h = hit {
            highlight.position = SCNVector3(Float(h.block.x) + 0.5, Float(h.block.y) + 0.5, Float(h.block.z) + 0.5)
            highlight.isHidden = false
        } else {
            highlight.isHidden = true
        }

        if controls.breakHeld, breakCooldown <= 0, let h = hit {
            let b = world.block(h.block.x, h.block.y, h.block.z)
            if b != .bedrock {
                world.setBlock(h.block.x, h.block.y, h.block.z, .air)
                breakCooldown = 0.25
            }
        }

        if controls.placeTapped {
            controls.placeTapped = false
            if let h = hit, let pr = h.previous,
               world.block(pr.x, pr.y, pr.z) == .air,
               !player.intersects(block: pr) {
                world.setBlock(pr.x, pr.y, pr.z, Game.hotbar[controls.selectedSlot])
            }
        }

        for p in world.takeDirty() where chunkNodes[p] != nil {
            rebuild(p)
        }
    }

    // MARK: Chunk streaming

    private func rebuild(_ p: ChunkPos) {
        let chunk = world.chunk(at: p)
        if let geo = Mesher.build(chunk: chunk, world: world) {
            let node: SCNNode
            if let existing = chunkNodes[p] {
                node = existing
            } else {
                node = SCNNode()
                node.position = SCNVector3(Float(p.x * chunkSize), 0, Float(p.z * chunkSize))
                chunkRoot.addChildNode(node)
                chunkNodes[p] = node
            }
            node.geometry = geo
        } else if let node = chunkNodes[p] {
            node.removeFromParentNode()
            chunkNodes[p] = nil
        }
    }

    private func updateStreaming(center: ChunkPos) {
        let r = Game.renderRadius
        if center != lastCenter {
            lastCenter = center
            var list: [(ChunkPos, Int)] = []
            for dz in -r...r {
                for dx in -r...r {
                    let d = dx * dx + dz * dz
                    if d <= r * r {
                        let p = ChunkPos(x: center.x + dx, z: center.z + dz)
                        if chunkNodes[p] == nil { list.append((p, d)) }
                    }
                }
            }
            list.sort { $0.1 < $1.1 }
            // Nearest chunk goes last so removeLast() takes it first.
            pending = Array(list.map { $0.0 }.reversed())

            for (p, node) in chunkNodes {
                let dx = p.x - center.x, dz = p.z - center.z
                if dx * dx + dz * dz > (r + 1) * (r + 1) {
                    node.removeFromParentNode()
                    chunkNodes[p] = nil
                }
            }
            world.unloadChunks(center: center, radius: r + 3)
        }

        let budget = frame < 10 ? 0.06 : 0.006
        let start = CACurrentMediaTime()
        while let p = pending.last, CACurrentMediaTime() - start < budget {
            pending.removeLast()
            rebuild(p)
        }
    }

    // MARK: Saving

    @objc func save() {
        world.saveModified()
        let st = PlayerState(x: player.pos.x, y: player.pos.y, z: player.pos.z,
                             yaw: player.yaw, pitch: player.pitch, slot: controls.selectedSlot)
        if let d = try? JSONEncoder().encode(st) {
            try? d.write(to: world.directory.appendingPathComponent("player.json"), options: .atomic)
        }
    }
}
