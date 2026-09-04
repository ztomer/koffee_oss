import XCTest
@testable import LiquidContainer

@MainActor
final class LiquidLayerPositionTests: XCTestCase {

    func testSurfacePosition_When63PercentFill_ShouldBeAt37Percent() {
        let windowHeight: CGFloat = 600
        let caffeineAtBedtime: Double = 63
        let safeLimit: Double = 100
        let fillLevel = CGFloat(caffeineAtBedtime / safeLimit)

        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight

        print("=== 63% Fill Test ===")
        print("Fill level: \(fillLevel)")
        print("Liquid height: \(liquidHeight)")
        print("Surface Y: \(surfaceY)")
        print("Surface Y as % from top: \(surfaceY / windowHeight * 100)%")

        XCTAssertEqual(fillLevel, 0.63, accuracy: 0.001)
        XCTAssertEqual(liquidHeight, 378.0, accuracy: 0.1)
        XCTAssertEqual(surfaceY, 222.0, accuracy: 0.1)
        XCTAssertEqual(surfaceY / windowHeight * 100, 37.0, accuracy: 0.1)
    }

    func testSurfacePosition_WhenEmpty_ShouldBeAtWindowBottom() {
        let windowHeight: CGFloat = 600
        let fillLevel: CGFloat = 0.0
        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight

        XCTAssertEqual(liquidHeight, 0, "Liquid height should be 0 when empty")
        XCTAssertEqual(surfaceY, windowHeight, "Surface should be at window bottom when empty")
    }

    func testSurfacePosition_When50Percent_ShouldBeAtMidWindow() {
        let windowHeight: CGFloat = 600
        let fillLevel: CGFloat = 0.5
        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight

        XCTAssertEqual(liquidHeight, 300, "Liquid height should be 300 for 50% fill")
        XCTAssertEqual(surfaceY, 300, "Surface should be at 300 (mid window) for 50% fill")
    }

    func testSurfacePosition_When90Percent_ShouldBeNearTop() {
        let windowHeight: CGFloat = 600
        let fillLevel: CGFloat = 0.9
        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight

        XCTAssertEqual(surfaceY, 60.0, "Surface should be at 60 (10% from top) for 90% fill")
        XCTAssertLessThan(surfaceY, windowHeight * 0.2,
            "Surface should be in top 20% for 90% fill")
    }

    func testLayerBoundaries_When10PercentFill_ShouldBeNearBottom() {
        let layers = LiquidLayerConfiguration.espresso.layers

        let windowHeight: CGFloat = 600
        let fillLevel: CGFloat = 0.1
        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight

        var layerBoundaries: [CGFloat] = []
        for layer in layers {
            layerBoundaries.append(layer.boundaryHeight * liquidHeight)
        }

        print("=== 10% Fill Layer Test ===")
        print("Surface Y: \(surfaceY) (90% from top)")

        for (layerIndex, layer) in layers.enumerated() {
            let layerTopY: CGFloat
            let layerBottomY: CGFloat

            if layerIndex == 0 {
                layerTopY = surfaceY
                layerBottomY = surfaceY + layerBoundaries[0]
            } else {
                layerTopY = surfaceY + layerBoundaries[layerIndex - 1]
                layerBottomY = surfaceY + layerBoundaries[layerIndex]
            }

            let topPercent = layerTopY / windowHeight * 100
            let bottomPercent = layerBottomY / windowHeight * 100

            print("Layer \(layerIndex) (\(layer.name)): \(topPercent)% - \(bottomPercent)%")

            XCTAssertGreaterThan(topPercent, 85, "Top should be in bottom 15%")
        }
    }

    func testLayerBoundaries_When20PercentFill_ShouldBeAt80Percent() {
        let windowHeight: CGFloat = 600
        let fillLevel: CGFloat = 0.2
        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight

        let layers = LiquidLayerConfiguration.espresso.layers

        var layerBoundaries: [CGFloat] = []
        for layer in layers {
            layerBoundaries.append(layer.boundaryHeight * liquidHeight)
        }

        print("=== 20% Fill Layer Test ===")
        print("Surface Y: \(surfaceY) (80% from top)")
        print("Liquid height: \(liquidHeight)")

        XCTAssertEqual(surfaceY, 480.0, accuracy: 0.1, "Surface should be at 80% for 20% fill")

        for (layerIndex, layer) in layers.enumerated() {
            let layerTopY: CGFloat
            let layerBottomY: CGFloat

            if layerIndex == 0 {
                layerTopY = surfaceY
                layerBottomY = surfaceY + layerBoundaries[0]
            } else {
                layerTopY = surfaceY + layerBoundaries[layerIndex - 1]
                layerBottomY = surfaceY + layerBoundaries[layerIndex]
            }

            let topPercent = layerTopY / windowHeight * 100
            let bottomPercent = layerBottomY / windowHeight * 100

            print("Layer \(layerIndex) (\(layer.name)): top=\(topPercent)%, bottom=\(bottomPercent)%")

            XCTAssertGreaterThan(topPercent, 75, "Top should be in bottom 25%")
            XCTAssertGreaterThan(bottomPercent, topPercent, "Bottom should be below top")
        }

        let cremaTop = surfaceY
        let cremaBottom = surfaceY + layerBoundaries[0]
        let liquidBottom = surfaceY + layerBoundaries[1]

        print("Crema: \(cremaTop) -> \(cremaBottom)")
        print("Liquid: \(cremaBottom) -> \(liquidBottom)")

        XCTAssertEqual(cremaTop, 480.0, accuracy: 0.1)
        XCTAssertEqual(cremaBottom, 494.4, accuracy: 0.1, "Crema bottom should be surface + 12% of liquid")
        XCTAssertEqual(liquidBottom, 540.0, accuracy: 0.1, "Liquid bottom should be surface + 50% of liquid")
    }

    func testBoundaryValues_AreCumulativeHeights() {
        let fillLevel: CGFloat = 0.2
        let liquidHeight: CGFloat = 120.0

        let layers = LiquidLayerConfiguration.espresso.layers

        var layerBoundaries: [CGFloat] = []
        for layer in layers {
            layerBoundaries.append(layer.boundaryHeight * liquidHeight)
        }

        XCTAssertEqual(layerBoundaries[0], 14.4, accuracy: 0.1, "Crema boundary (12% of 120)")
        XCTAssertEqual(layerBoundaries[1], 60.0, accuracy: 0.1, "Liquid boundary (50% of 120)")
        XCTAssertEqual(layerBoundaries[2], 120.0, accuracy: 0.1, "Dense boundary (100% of 120)")
    }

    func testBottomWave_ShouldNotExceedTopOfLiquid() {
        let windowHeight: CGFloat = 600
        let fillLevel: CGFloat = 0.3
        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight

        let maxWaveAmplitude: CGFloat = 15.0

        let topOfLiquidWithWave = surfaceY - maxWaveAmplitude

        print("=== Bottom Wave Position Test ===")
        print("Surface Y: \(surfaceY) (\(surfaceY / windowHeight * 100)% from top)")
        print("Max wave amplitude: \(maxWaveAmplitude)")
        print("Top of liquid with wave: \(topOfLiquidWithWave) (\(topOfLiquidWithWave / windowHeight * 100)% from top)")

        XCTAssertGreaterThan(surfaceY, windowHeight * 0.5, "Surface should be in lower half for 30% fill")
        XCTAssertLessThan(topOfLiquidWithWave, windowHeight * 0.75, "Top with wave should be above 75% from top")
    }

    func testWaveAtBottomLayer_ShouldBeAtLiquidBottom() {
        let windowHeight: CGFloat = 600
        let fillLevel: CGFloat = 0.5
        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight

        let layers = LiquidLayerConfiguration.espresso.layers
        var layerBoundaries: [CGFloat] = []
        for layer in layers {
            layerBoundaries.append(layer.boundaryHeight * liquidHeight)
        }

        let bottomLayerTop = surfaceY + layerBoundaries[1]
        let bottomLayerBottom = surfaceY + layerBoundaries[2]

        let maxWaveOffset: CGFloat = 15.0

        let bottomOfWave = bottomLayerBottom + maxWaveOffset

        print("=== Bottom Layer Wave Test ===")
        print("Surface Y: \(surfaceY)")
        print("Bottom layer (dense): top=\(bottomLayerTop), bottom=\(bottomLayerBottom)")
        print("Bottom of wave: \(bottomOfWave)")

        XCTAssertLessThan(bottomOfWave, windowHeight + 20, "Bottom of wave should be within liquid area")
    }
}
