import SwiftUI

public struct BubbleState: Sendable {
    public var x: CGFloat
    public var baseY: CGFloat
    public var size: CGFloat
    public var phase: Double
    public var wobblePhase: Double

    public init(x: CGFloat, baseY: CGFloat, size: CGFloat, phase: Double, wobblePhase: Double) {
        self.x = x
        self.baseY = baseY
        self.size = size
        self.phase = phase
        self.wobblePhase = wobblePhase
    }
}

public struct LiquidLayer: Sendable {
    public var name: String
    public var topColor: Color
    public var bottomColor: Color
    public var boundaryHeight: CGFloat
    public var waveDamping: CGFloat
    public var phaseDelay: CGFloat
    public var hasFoam: Bool
    public var foamColor: Color
    public var bubbleDensity: CGFloat

    public init(
        name: String,
        topColor: Color,
        bottomColor: Color,
        boundaryHeight: CGFloat,
        waveDamping: CGFloat,
        phaseDelay: CGFloat,
        hasFoam: Bool = false,
        foamColor: Color = .clear,
        bubbleDensity: CGFloat = 0
    ) {
        self.name = name
        self.topColor = topColor
        self.bottomColor = bottomColor
        self.boundaryHeight = boundaryHeight
        self.waveDamping = waveDamping
        self.phaseDelay = phaseDelay
        self.hasFoam = hasFoam
        self.foamColor = foamColor
        self.bubbleDensity = bubbleDensity
    }
}

public struct LiquidLayerConfiguration: Sendable {
    public var layers: [LiquidLayer]
    public var interLayerTransitionWidth: CGFloat
    public var waveCoupling: CGFloat
    public var waveReflectionRatio: CGFloat

    public init(
        layers: [LiquidLayer],
        interLayerTransitionWidth: CGFloat = 0.08,
        waveCoupling: CGFloat = 0.6,
        waveReflectionRatio: CGFloat = 0.6
    ) {
        self.layers = layers
        self.interLayerTransitionWidth = interLayerTransitionWidth
        self.waveCoupling = waveCoupling
        self.waveReflectionRatio = waveReflectionRatio
    }

    public static let espresso = LiquidLayerConfiguration(
        layers: [
            LiquidLayer(
                name: "crema",
                topColor: Color(red: 0.85, green: 0.70, blue: 0.50),
                bottomColor: Color(red: 0.65, green: 0.45, blue: 0.25),
                boundaryHeight: 0.12,
                waveDamping: 0.97,
                phaseDelay: 0.0,
                hasFoam: true,
                foamColor: Color(red: 0.90, green: 0.78, blue: 0.55),
                bubbleDensity: 0.8
            ),
            LiquidLayer(
                name: "liquid",
                topColor: Color(red: 0.40, green: 0.25, blue: 0.12),
                bottomColor: Color(red: 0.20, green: 0.10, blue: 0.05),
                boundaryHeight: 0.50,
                waveDamping: 0.88,
                phaseDelay: 0.15
            ),
            LiquidLayer(
                name: "dense",
                topColor: Color(red: 0.15, green: 0.07, blue: 0.03),
                bottomColor: Color(red: 0.08, green: 0.03, blue: 0.01),
                boundaryHeight: 1.0,
                waveDamping: 0.78,
                phaseDelay: 0.40
            )
        ]
    )

    public static let dripCoffee = LiquidLayerConfiguration(
        layers: [
            LiquidLayer(
                name: "crema",
                topColor: Color(red: 0.75, green: 0.60, blue: 0.45),
                bottomColor: Color(red: 0.55, green: 0.38, blue: 0.22),
                boundaryHeight: 0.08,
                waveDamping: 0.96,
                phaseDelay: 0.0,
                hasFoam: true,
                foamColor: Color(red: 0.82, green: 0.68, blue: 0.50),
                bubbleDensity: 0.5
            ),
            LiquidLayer(
                name: "liquid",
                topColor: Color(red: 0.35, green: 0.20, blue: 0.10),
                bottomColor: Color(red: 0.12, green: 0.06, blue: 0.03),
                boundaryHeight: 1.0,
                waveDamping: 0.85,
                phaseDelay: 0.20
            )
        ]
    )

    public static let latte = LiquidLayerConfiguration(
        layers: [
            LiquidLayer(
                name: "foam",
                topColor: Color(red: 0.95, green: 0.92, blue: 0.88),
                bottomColor: Color(red: 0.85, green: 0.80, blue: 0.75),
                boundaryHeight: 0.25,
                waveDamping: 0.98,
                phaseDelay: 0.0,
                hasFoam: true,
                foamColor: Color(red: 0.95, green: 0.92, blue: 0.88),
                bubbleDensity: 1.0
            ),
            LiquidLayer(
                name: "milkCoffee",
                topColor: Color(red: 0.60, green: 0.45, blue: 0.30),
                bottomColor: Color(red: 0.40, green: 0.28, blue: 0.18),
                boundaryHeight: 0.60,
                waveDamping: 0.90,
                phaseDelay: 0.12
            ),
            LiquidLayer(
                name: "espresso",
                topColor: Color(red: 0.25, green: 0.12, blue: 0.06),
                bottomColor: Color(red: 0.10, green: 0.05, blue: 0.02),
                boundaryHeight: 1.0,
                waveDamping: 0.80,
                phaseDelay: 0.35
            )
        ]
    )

    public static let coldBrew = LiquidLayerConfiguration(
        layers: [
            LiquidLayer(
                name: "foam",
                topColor: Color(red: 0.70, green: 0.60, blue: 0.50),
                bottomColor: Color(red: 0.55, green: 0.45, blue: 0.35),
                boundaryHeight: 0.05,
                waveDamping: 0.95,
                phaseDelay: 0.0,
                hasFoam: true,
                foamColor: Color(red: 0.75, green: 0.65, blue: 0.55),
                bubbleDensity: 0.3
            ),
            LiquidLayer(
                name: "liquid",
                topColor: Color(red: 0.30, green: 0.18, blue: 0.10),
                bottomColor: Color(red: 0.12, green: 0.06, blue: 0.03),
                boundaryHeight: 1.0,
                waveDamping: 0.85,
                phaseDelay: 0.18
            )
        ]
    )

    public static let americano = LiquidLayerConfiguration(
        layers: [
            LiquidLayer(
                name: "crema",
                topColor: Color(red: 0.80, green: 0.65, blue: 0.48),
                bottomColor: Color(red: 0.60, green: 0.42, blue: 0.28),
                boundaryHeight: 0.10,
                waveDamping: 0.96,
                phaseDelay: 0.0,
                hasFoam: true,
                foamColor: Color(red: 0.85, green: 0.72, blue: 0.55),
                bubbleDensity: 0.4
            ),
            LiquidLayer(
                name: "liquid",
                topColor: Color(red: 0.32, green: 0.18, blue: 0.10),
                bottomColor: Color(red: 0.10, green: 0.05, blue: 0.02),
                boundaryHeight: 1.0,
                waveDamping: 0.86,
                phaseDelay: 0.18
            )
        ]
    )
}

public struct LiquidContainerConfiguration: Sendable {
    public var liquidColor: Color
    public var liquidColorDark: Color
    public var liquidColorMid: Color
    public var liquidColorLight: Color
    public var foamColor: Color
    public var foamCremaColor: Color
    public var minFillRatio: CGFloat
    public var maxFillRatio: CGFloat
    public var layerConfiguration: LiquidLayerConfiguration

    /// Whether the container animates.
    ///
    /// `LiquidContainerView` drives itself from `TimelineView(.animation)` and steps the physics on
    /// every frame, so two renders of one view differ in the liquid. A render harness draws one
    /// instant and turns this off.
    public var animates: Bool = true

    public static let coffee = LiquidContainerConfiguration(
        liquidColor: Color(red: 0.85, green: 0.70, blue: 0.50),
        liquidColorDark: Color(red: 0.12, green: 0.05, blue: 0.02),
        liquidColorMid: Color(red: 0.30, green: 0.15, blue: 0.06),
        liquidColorLight: Color(red: 0.55, green: 0.32, blue: 0.15),
        foamColor: Color(red: 0.85, green: 0.75, blue: 0.65),
        foamCremaColor: Color(red: 0.88, green: 0.78, blue: 0.65),
        minFillRatio: 0.05,
        maxFillRatio: 1.3,
        layerConfiguration: .espresso
    )

    public static let water = LiquidContainerConfiguration(
        liquidColor: Color(red: 0.3, green: 0.5, blue: 0.8),
        liquidColorDark: Color(red: 0.05, green: 0.15, blue: 0.3),
        liquidColorMid: Color(red: 0.1, green: 0.25, blue: 0.5),
        liquidColorLight: Color(red: 0.4, green: 0.6, blue: 0.9),
        foamColor: Color.white.opacity(0.3),
        foamCremaColor: Color.white.opacity(0.5),
        minFillRatio: 0.05,
        maxFillRatio: 1.3,
        layerConfiguration: LiquidLayerConfiguration(
            layers: [
                LiquidLayer(
                    name: "surface",
                    topColor: Color(red: 0.5, green: 0.65, blue: 0.85),
                    bottomColor: Color(red: 0.35, green: 0.50, blue: 0.70),
                    boundaryHeight: 0.08,
                    waveDamping: 0.95,
                    phaseDelay: 0.0,
                    hasFoam: false
                ),
                LiquidLayer(
                    name: "liquid",
                    topColor: Color(red: 0.25, green: 0.40, blue: 0.60),
                    bottomColor: Color(red: 0.08, green: 0.18, blue: 0.35),
                    boundaryHeight: 1.0,
                    waveDamping: 0.85,
                    phaseDelay: 0.15
                )
            ]
        )
    )

    public static let wine = LiquidContainerConfiguration(
        liquidColor: Color(red: 0.5, green: 0.1, blue: 0.2),
        liquidColorDark: Color(red: 0.2, green: 0.02, blue: 0.05),
        liquidColorMid: Color(red: 0.35, green: 0.05, blue: 0.1),
        liquidColorLight: Color(red: 0.6, green: 0.2, blue: 0.3),
        foamColor: Color(red: 0.7, green: 0.5, blue: 0.55),
        foamCremaColor: Color(red: 0.75, green: 0.6, blue: 0.65),
        minFillRatio: 0.05,
        maxFillRatio: 1.3,
        layerConfiguration: LiquidLayerConfiguration(
            layers: [
                LiquidLayer(
                    name: "surface",
                    topColor: Color(red: 0.60, green: 0.15, blue: 0.25),
                    bottomColor: Color(red: 0.45, green: 0.08, blue: 0.15),
                    boundaryHeight: 0.10,
                    waveDamping: 0.96,
                    phaseDelay: 0.0
                ),
                LiquidLayer(
                    name: "liquid",
                    topColor: Color(red: 0.35, green: 0.05, blue: 0.12),
                    bottomColor: Color(red: 0.15, green: 0.02, blue: 0.05),
                    boundaryHeight: 1.0,
                    waveDamping: 0.82,
                    phaseDelay: 0.25
                )
            ]
        )
    )

    public init(
        liquidColor: Color,
        liquidColorDark: Color,
        liquidColorMid: Color,
        liquidColorLight: Color,
        foamColor: Color,
        foamCremaColor: Color = .clear,
        minFillRatio: CGFloat,
        maxFillRatio: CGFloat,
        layerConfiguration: LiquidLayerConfiguration
    ) {
        self.liquidColor = liquidColor
        self.liquidColorDark = liquidColorDark
        self.liquidColorMid = liquidColorMid
        self.liquidColorLight = liquidColorLight
        self.foamColor = foamColor
        self.foamCremaColor = foamCremaColor == .clear ? foamColor : foamCremaColor
        self.minFillRatio = minFillRatio
        self.maxFillRatio = maxFillRatio
        self.layerConfiguration = layerConfiguration
    }
}

public struct BubbleGenerator {
    public static func generate(count: Int, width: CGFloat, height: CGFloat) -> [BubbleState] {
        var random = SystemRandomNumberGenerator()
        return generate(count: count, width: width, height: height, using: &random)
    }

    /// Lays the bubbles out from `generator` rather than from the system's entropy, so a caller that
    /// needs the same picture twice — the render harness's fixture — can reproduce it. The layout was
    /// the one unseeded source in a dashboard render; everything else derives from the fixture.
    public static func generate<G: RandomNumberGenerator>(
        count: Int,
        width: CGFloat,
        height: CGFloat,
        using generator: inout G
    ) -> [BubbleState] {
        (0..<count).map { i in
            let seed = Int.random(in: 0...10000, using: &generator)
            return BubbleState(
                x: CGFloat(seed % Int(width - 40)) + 20,
                baseY: CGFloat((seed / 100) % Int(height * 0.8)) + 20,
                size: CGFloat(4 + (seed % 7)),
                phase: Double(i) * (LiquidPhysics.bubbleCycleSeconds / Double(count)),
                wobblePhase: Double(i) * 0.7
            )
        }
    }

    public static func generateForLayer(count: Int, width: CGFloat, heightFraction: CGFloat, density: CGFloat) -> [BubbleState] {
        let actualCount = Int(CGFloat(count) * density)
        return (0..<actualCount).map { i in
            let seed = Int.random(in: 0...10000)
            return BubbleState(
                x: CGFloat(seed % Int(width - 20)) + 10,
                baseY: CGFloat((seed / 100) % Int(heightFraction * 650 * 0.15)) + 5,
                size: CGFloat(3 + (seed % 6)),
                phase: Double(i) * (LiquidPhysics.bubbleCycleSeconds / Double(max(1, actualCount))),
                wobblePhase: Double(i) * 0.7
            )
        }
    }
}
