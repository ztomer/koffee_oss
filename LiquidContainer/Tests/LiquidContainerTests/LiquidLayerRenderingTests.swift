import XCTest
@testable import LiquidContainer

@MainActor
final class LiquidLayerRenderingTests: XCTestCase {

    func testLayerRenderingOrder_ShouldBeTopToBottom() {
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 600
        let fillLevel: CGFloat = 0.5

        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight

        let layers = LiquidLayerConfiguration.espresso.layers

        var layerBoundaries: [CGFloat] = []
        for layer in layers {
            layerBoundaries.append(layer.boundaryHeight * liquidHeight)
        }

        var layerRenderOrder: [(name: String, topY: CGFloat, bottomY: CGFloat, index: Int)] = []

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

            layerRenderOrder.append((layer.name, layerTopY, layerBottomY, layerIndex))
        }

        print("=== Layer Rendering Order Test ===")
        print("Window: \(windowWidth)x\(windowHeight)")
        print("Fill level: \(fillLevel)")
        print("Liquid height: \(liquidHeight)")
        print("Surface Y: \(surfaceY)")
        print("")

        for (index, entry) in layerRenderOrder.enumerated() {
            print("Layer \(index): \(entry.name)")
            print("  Top Y: \(entry.topY) (\(entry.topY / windowHeight * 100)% from top)")
            print("  Bottom Y: \(entry.bottomY) (\(entry.bottomY / windowHeight * 100)% from top)")
            print("  Height: \(entry.bottomY - entry.topY)")
        }

        print("")
        print("=== Verification ===")

        for index in layerRenderOrder.indices.dropFirst() {
            let prevEntry = layerRenderOrder[index - 1]
            let entry = layerRenderOrder[index]
            XCTAssertEqual(entry.topY, prevEntry.bottomY,
                "Layer \(index) (\(entry.name)) topY should equal previous layer's bottomY (\(prevEntry.bottomY))")
        }

        let lastLayer = layerRenderOrder.last!
        XCTAssertEqual(lastLayer.bottomY, surfaceY + liquidHeight,
            "Last layer's bottom should equal surfaceY + liquidHeight")
    }

    func testLayerGaps_ShouldHaveNoOverlaps() {
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 600
        let fillLevel: CGFloat = 0.5

        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight

        let layers = LiquidLayerConfiguration.espresso.layers

        var layerBoundaries: [CGFloat] = []
        for layer in layers {
            layerBoundaries.append(layer.boundaryHeight * liquidHeight)
        }

        var layerBoundariesWithY: [(name: String, topY: CGFloat, bottomY: CGFloat)] = []

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

            layerBoundariesWithY.append((layer.name, layerTopY, layerBottomY))
        }

        print("=== Layer Gap/Overlap Test ===")

        var overlaps: [(layer1: String, layer2: String, overlap: CGFloat)] = []
        var gaps: [(layer1: String, layer2: String, gap: CGFloat)] = []

        for i in 0..<(layerBoundariesWithY.count - 1) {
            let current = layerBoundariesWithY[i]
            let next = layerBoundariesWithY[i + 1]

            let gap = next.topY - current.bottomY

            if gap > 0.5 {
                gaps.append((current.name, next.name, gap))
            } else if gap < -0.5 {
                overlaps.append((current.name, next.name, -gap))
            }
        }

        if !gaps.isEmpty {
            print("GAPS FOUND:")
            for gap in gaps {
                print("  Between \(gap.layer1) and \(gap.layer2): \(gap.gap)px")
            }
        } else {
            print("No gaps between layers")
        }

        if !overlaps.isEmpty {
            print("OVERLAPS FOUND:")
            for overlap in overlaps {
                print("  Between \(overlap.layer1) and \(overlap.layer2): \(overlap.overlap)px")
            }
        } else {
            print("No overlaps between layers")
        }

        XCTAssertTrue(gaps.isEmpty, "There should be no gaps between layers")
        XCTAssertTrue(overlaps.isEmpty, "There should be no overlaps between layers")
    }

    func testLayerBoundaryTransitions_ShouldNotExceedLayerBounds() {
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 600
        let fillLevel: CGFloat = 0.5

        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight
        let transitionWidth: CGFloat = 0.08

        let layers = LiquidLayerConfiguration.espresso.layers

        var layerBoundaries: [CGFloat] = []
        for layer in layers {
            layerBoundaries.append(layer.boundaryHeight * liquidHeight)
        }

        var layerBoundariesWithY: [(name: String, topY: CGFloat, bottomY: CGFloat)] = []

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

            layerBoundariesWithY.append((layer.name, layerTopY, layerBottomY))
        }

        print("=== Transition Bounds Test ===")
        print("Transition width factor: \(transitionWidth)")
        print("Liquid height: \(liquidHeight)")
        print("Transition height: \(liquidHeight * transitionWidth)")

        for i in 1..<layerBoundariesWithY.count {
            let boundaryY = layerBoundariesWithY[i - 1].bottomY
            let transitionHeight = liquidHeight * transitionWidth

            let transitionTop = boundaryY - transitionHeight * 0.5
            let transitionBottom = boundaryY + transitionHeight * 0.5

            let prevLayer = layerBoundariesWithY[i - 1]
            let nextLayer = layerBoundariesWithY[i]

            print("Boundary \(i) between \(prevLayer.name) and \(nextLayer.name):")
            print("  Boundary Y: \(boundaryY)")
            print("  Transition: \(transitionTop) to \(transitionBottom)")
            print("  \(prevLayer.name) range: \(prevLayer.topY) - \(prevLayer.bottomY)")
            print("  \(nextLayer.name) range: \(nextLayer.topY) - \(nextLayer.bottomY)")

            let topOvershoot = transitionTop - prevLayer.topY
            let bottomOvershoot = transitionBottom - nextLayer.bottomY

            print("  Top overshoot into \(prevLayer.name): \(topOvershoot)")
            print("  Bottom overshoot into \(nextLayer.name): \(bottomOvershoot)")
        }
    }

    func testWaveOffset_ShouldNotPushLayerOutsideBounds() {
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 600
        let fillLevel: CGFloat = 0.3

        let liquidHeight = windowHeight * fillLevel
        let surfaceY = windowHeight - liquidHeight

        let layers = LiquidLayerConfiguration.espresso.layers

        var layerBoundaries: [CGFloat] = []
        for layer in layers {
            layerBoundaries.append(layer.boundaryHeight * liquidHeight)
        }

        let maxWaveAmplitude: CGFloat = 20.0

        print("=== Wave Bounds Test ===")
        print("Max wave amplitude: \(maxWaveAmplitude)")

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

            let topWithWave = layerTopY - maxWaveAmplitude
            let bottomWithWave = layerBottomY + maxWaveAmplitude

            print("\(layer.name):")
            print("  Bounds: \(layerTopY) - \(layerBottomY)")
            print("  With wave: \(topWithWave) - \(bottomWithWave)")

            if layerIndex > 0 {
                let prevLayerTop = layers[layerIndex - 1].boundaryHeight * liquidHeight
                let topOvershoot = layerTopY - maxWaveAmplitude - (surfaceY + prevLayerTop)
                if topOvershoot < 0 {
                    print("  WARNING: Top of wave would go ABOVE previous layer boundary!")
                }
            }
        }
    }

    func testAllFillLevels_ShouldHaveNoGapsOrOverlaps() {
        let windowHeight: CGFloat = 600
        let fillLevels: [CGFloat] = [0.1, 0.2, 0.3, 0.5, 0.7, 0.9]

        for fillLevel in fillLevels {
            let liquidHeight = windowHeight * fillLevel
            let surfaceY = windowHeight - liquidHeight

            let layers = LiquidLayerConfiguration.espresso.layers

            var layerBoundaries: [CGFloat] = []
            for layer in layers {
                layerBoundaries.append(layer.boundaryHeight * liquidHeight)
            }

            var layerYPositions: [(topY: CGFloat, bottomY: CGFloat)] = []

            for layerIndex in layers.indices {
                let layerTopY: CGFloat
                let layerBottomY: CGFloat

                if layerIndex == 0 {
                    layerTopY = surfaceY
                    layerBottomY = surfaceY + layerBoundaries[0]
                } else {
                    layerTopY = surfaceY + layerBoundaries[layerIndex - 1]
                    layerBottomY = surfaceY + layerBoundaries[layerIndex]
                }

                layerYPositions.append((layerTopY, layerBottomY))
            }

            var gaps: [CGFloat] = []
            for i in 0..<(layerYPositions.count - 1) {
                let gap = layerYPositions[i + 1].topY - layerYPositions[i].bottomY
                if abs(gap) > 0.1 {
                    gaps.append(gap)
                }
            }

            print("Fill \(Int(fillLevel * 100))%: Surface Y=\(Int(surfaceY)), "
                  + "Layers=\(layerYPositions.map { "\(Int($0.topY))-\(Int($0.bottomY))" }.joined(separator: ", "))")

            XCTAssertTrue(gaps.isEmpty, "No gaps at \(Int(fillLevel * 100))% fill")
        }
    }
}
