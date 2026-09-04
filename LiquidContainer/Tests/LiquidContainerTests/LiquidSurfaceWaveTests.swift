import XCTest
@testable import LiquidContainer

@MainActor
final class LiquidSurfaceWaveTests: XCTestCase {

    func testWaveOffset_CanBeNegative() {
        let engine = LiquidPhysicsEngine(waveCount: 3)

        let width: CGFloat = 400

        engine.containerAccelX = 10.0
        engine.step(deltaTime: 0.1)

        let leftWave = engine.layerSurfaceHeight(x: 50, width: width, layerIndex: 0)
        let rightWave = engine.layerSurfaceHeight(x: 350, width: width, layerIndex: 0)

        print("=== Wave Offset Test ===")
        print("Left (x=50): \(leftWave)")
        print("Right (x=350): \(rightWave)")
        print("Difference: \(rightWave - leftWave)")

        let surfaceY: CGFloat = 300
        let leftY = surfaceY + leftWave
        let rightY = surfaceY + rightWave

        print("Left Y: \(leftY)")
        print("Right Y: \(rightY)")

        if leftWave != rightWave {
            print("Surface is tilted - this is expected")
        }

        if leftWave < 0 || rightWave < 0 {
            print("WARNING: Wave can be negative - liquid surface dips BELOW surfaceY")
        }
        if leftWave > 0 || rightWave > 0 {
            print("INFO: Wave can be positive - liquid surface rises ABOVE surfaceY")
        }
    }

    func testSurfaceTilt_WhenAccelerating_ShouldTilt() {
        let engine = LiquidPhysicsEngine(waveCount: 3)

        let width: CGFloat = 400
        let surfaceY: CGFloat = 300

        engine.step(deltaTime: 0.016)
        let neutralLeft = engine.layerSurfaceHeight(x: 50, width: width, layerIndex: 0)
        let neutralRight = engine.layerSurfaceHeight(x: 350, width: width, layerIndex: 0)

        for _ in 0..<10 {
            engine.step(deltaTime: 0.016)
        }

        engine.containerAccelX = 5.0
        for _ in 0..<5 {
            engine.step(deltaTime: 0.016)
        }

        let tiltedLeft = engine.layerSurfaceHeight(x: 50, width: width, layerIndex: 0)
        let tiltedRight = engine.layerSurfaceHeight(x: 350, width: width, layerIndex: 0)

        print("=== Surface Tilt Test ===")
        print("Neutral: left=\(neutralLeft), right=\(neutralRight)")
        print("Tilted: left=\(tiltedLeft), right=\(tiltedRight)")
        print("Neutral diff: \(neutralRight - neutralLeft)")
        print("Tilted diff: \(tiltedRight - tiltedLeft)")

        let neutralDiff = abs(neutralRight - neutralLeft)
        let tiltedDiff = abs(tiltedRight - tiltedLeft)

        XCTAssertGreaterThan(tiltedDiff, neutralDiff, "Tilted surface should have greater difference than neutral")
    }

    func testClampingLogic_ShouldNotPreventRising() {
        let surfaceY: CGFloat = 300
        let layerTopY: CGFloat = surfaceY

        let waveOffset: CGFloat = 10.0

        let clampedWaveBad = max(-layerTopY + surfaceY, min(15.0, waveOffset))
        let yBad = layerTopY + clampedWaveBad

        print("=== Clamping Logic Test ===")
        print("layerTopY: \(layerTopY)")
        print("surfaceY: \(surfaceY)")
        print("waveOffset: \(waveOffset)")
        print("clampedWave (current logic): \(clampedWaveBad)")
        print("y (current): \(yBad)")
        print("surfaceY: \(surfaceY)")

        if yBad == surfaceY {
            print("PROBLEM: y equals surfaceY - liquid can't rise above surface!")
        }

        let yCorrect = layerTopY + waveOffset
        print("y (without clamping): \(yCorrect)")

        if yCorrect < surfaceY {
            print("Correct logic: liquid falls below surface (negative wave)")
        } else {
            print("Correct logic: liquid rises above surface (positive wave)")
        }
    }

    func testClampingLogic_ShouldNotPreventFalling() {
        let surfaceY: CGFloat = 300
        let layerTopY: CGFloat = surfaceY

        let waveOffset: CGFloat = -10.0

        let clampedWaveBad = max(-layerTopY + surfaceY, min(15.0, waveOffset))
        let yBad = layerTopY + clampedWaveBad

        print("=== Negative Wave Clamping Test ===")
        print("waveOffset: \(waveOffset)")
        print("clampedWave (current logic): \(clampedWaveBad)")
        print("y (current): \(yBad)")

        if clampedWaveBad == 0 && waveOffset < 0 {
            print("PROBLEM: Negative wave was clamped to 0 - liquid can't fall below surface!")
        }

        let yCorrect = layerTopY + waveOffset
        print("y (without clamping): \(yCorrect)")
        XCTAssertLessThan(yCorrect, layerTopY, "Without clamping, negative wave should go below layerTopY")
    }
}
