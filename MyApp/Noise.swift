import Foundation

/// Small deterministic RNG used for texture generation.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// 2D value noise with fractal layering. All outputs are in 0...1.
struct Noise {
    let seed: UInt32

    func hash(_ x: Int, _ y: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: x) &* 374761393
        h = h &+ UInt32(truncatingIfNeeded: y) &* 668265263
        h = h &+ seed &* 2246822519
        h = (h ^ (h >> 13)) &* 1274126177
        h ^= h >> 16
        return Double(h) / 4294967295.0
    }

    func value(_ x: Double, _ y: Double) -> Double {
        let x0 = Int(floor(x)), y0 = Int(floor(y))
        let fx = x - Double(x0), fy = y - Double(y0)
        let u = fx * fx * (3 - 2 * fx)
        let v = fy * fy * (3 - 2 * fy)
        let a = hash(x0, y0)
        let b = hash(x0 + 1, y0)
        let c = hash(x0, y0 + 1)
        let d = hash(x0 + 1, y0 + 1)
        return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
    }

    func fbm(_ x: Double, _ y: Double, octaves: Int = 4) -> Double {
        var amp = 1.0, freq = 1.0, sum = 0.0, norm = 0.0
        for _ in 0..<octaves {
            sum += value(x * freq, y * freq) * amp
            norm += amp
            amp *= 0.5
            freq *= 2
        }
        return sum / norm
    }
}
