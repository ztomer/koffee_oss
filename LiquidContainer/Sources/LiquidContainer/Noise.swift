import SwiftUI
import Foundation

public func simplexNoise2D(x: Double, y: Double) -> Double {
    let f2 = 0.5 * (sqrt(3.0) - 1.0)
    let g2 = (3.0 - sqrt(3.0)) / 6.0

    let s = (x + y) * f2
    let i = floor(x + s)
    let j = floor(y + s)

    let t = (i + j) * g2
    let x0i = i - t
    let y0i = j - t
    let x0 = x - x0i
    let y0 = y - y0i

    var i1: Double, j1: Double
    if x0 > y0 {
        i1 = 1
        j1 = 0
    } else {
        i1 = 0
        j1 = 1
    }

    let x1 = x0 - i1 + g2
    let y1 = y0 - j1 + g2
    let x2 = x0 - 1.0 + 2.0 * g2
    let y2 = y0 - 1.0 + 2.0 * g2

    var n0: Double = 0
    var n1: Double = 0
    var n2: Double = 0

    var t0 = 0.5 - x0 * x0 - y0 * y0
    if t0 >= 0 {
        t0 *= t0
        n0 = t0 * t0 * dotGradient(ix: Int(i), iy: Int(j), x: x0, y: y0)
    }

    var t1 = 0.5 - x1 * x1 - y1 * y1
    if t1 >= 0 {
        t1 *= t1
        n1 = t1 * t1 * dotGradient(ix: Int(i + i1), iy: Int(j + j1), x: x1, y: y1)
    }

    var t2 = 0.5 - x2 * x2 - y2 * y2
    if t2 >= 0 {
        t2 *= t2
        n2 = t2 * t2 * dotGradient(ix: Int(i + 1), iy: Int(j + 1), x: x2, y: y2)
    }

    return 70.0 * (n0 + n1 + n2)
}

private func dotGradient(ix: Int, iy: Int, x: Double, y: Double) -> Double {
    let hash = (ix &* 1619 &+ iy &* 31337) & 0x7FFFFFFF
    let grad = hash % 8
    let gx: Double
    let gy: Double
    switch grad {
    case 0: gx = 1; gy = 1
    case 1: gx = -1; gy = 1
    case 2: gx = 1; gy = -1
    case 3: gx = -1; gy = -1
    case 4: gx = 1; gy = 0
    case 5: gx = -1; gy = 0
    case 6: gx = 0; gy = 1
    default: gx = 0; gy = -1
    }
    return gx * x + gy * y
}

public func fbm(x: Double, y: Double, octaves: Int = 4) -> Double {
    var value: Double = 0
    var amplitude: Double = 0.5
    var frequency: Double = 1.0
    var maxValue: Double = 0

    for _ in 0..<octaves {
        value += amplitude * simplexNoise2D(x: x * frequency, y: y * frequency)
        maxValue += amplitude
        amplitude *= 0.5
        frequency *= 2.0
    }

    return value / maxValue
}
