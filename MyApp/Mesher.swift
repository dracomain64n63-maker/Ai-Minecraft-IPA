import SceneKit

/// Turns a chunk into one SCNGeometry, emitting only faces that touch air.
enum Mesher {
    /// If textures ever look upside-down on device, flip this to true.
    static let flipV = false

    private struct FaceDef {
        let dx: Int
        let dy: Int
        let dz: Int
        let corners: [SIMD3<Float>]   // counter-clockwise seen from outside
        let kind: FaceKind
    }

    private static let faces: [FaceDef] = [
        FaceDef(dx: 0, dy: 1, dz: 0, corners: [[0, 1, 0], [0, 1, 1], [1, 1, 1], [1, 1, 0]], kind: .top),
        FaceDef(dx: 0, dy: -1, dz: 0, corners: [[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1]], kind: .bottom),
        FaceDef(dx: 1, dy: 0, dz: 0, corners: [[1, 0, 1], [1, 0, 0], [1, 1, 0], [1, 1, 1]], kind: .side),
        FaceDef(dx: -1, dy: 0, dz: 0, corners: [[0, 0, 0], [0, 0, 1], [0, 1, 1], [0, 1, 0]], kind: .side),
        FaceDef(dx: 0, dy: 0, dz: 1, corners: [[0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]], kind: .side),
        FaceDef(dx: 0, dy: 0, dz: -1, corners: [[1, 0, 0], [0, 0, 0], [0, 1, 0], [1, 1, 0]], kind: .side)
    ]

    static func build(chunk: Chunk, world: World) -> SCNGeometry? {
        var verts: [SCNVector3] = []
        var norms: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [Int32] = []
        verts.reserveCapacity(8192)
        norms.reserveCapacity(8192)
        uvs.reserveCapacity(8192)
        indices.reserveCapacity(12288)

        let ox = chunk.pos.x * chunkSize
        let oz = chunk.pos.z * chunkSize
        let maxY = min(worldHeight - 1, chunk.topY)

        for y in 0...maxY {
            for z in 0..<chunkSize {
                for x in 0..<chunkSize {
                    let b = chunk.get(x, y, z)
                    if b == .air { continue }
                    for f in faces {
                        let nx = x + f.dx, ny = y + f.dy, nz = z + f.dz
                        let nb: Block
                        if nx >= 0 && nx < chunkSize && nz >= 0 && nz < chunkSize && ny >= 0 && ny < worldHeight {
                            nb = chunk.get(nx, ny, nz)
                        } else {
                            nb = world.block(ox + nx, ny, oz + nz)
                        }
                        if nb.isSolid { continue }

                        let rect = TextureAtlas.uvRect(tile: b.tile(f.kind))
                        let vTop = flipV ? rect.v1 : rect.v0
                        let vBottom = flipV ? rect.v0 : rect.v1
                        let normal = SCNVector3(Float(f.dx), Float(f.dy), Float(f.dz))
                        let base = Int32(verts.count)

                        for i in 0..<4 {
                            let c = f.corners[i]
                            verts.append(SCNVector3(c.x + Float(x), c.y + Float(y), c.z + Float(z)))
                            norms.append(normal)
                        }
                        uvs.append(CGPoint(x: rect.u0, y: vBottom))
                        uvs.append(CGPoint(x: rect.u1, y: vBottom))
                        uvs.append(CGPoint(x: rect.u1, y: vTop))
                        uvs.append(CGPoint(x: rect.u0, y: vTop))

                        indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
                    }
                }
            }
        }

        if verts.isEmpty { return nil }

        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: verts),
                SCNGeometrySource(normals: norms),
                SCNGeometrySource(textureCoordinates: uvs)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.materials = [TextureAtlas.material]
        return geometry
    }
}
