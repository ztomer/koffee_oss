import Foundation
import SwiftUI

public struct LiquidConfig: Codable {
    public let version: String
    public let physics: PhysicsConfig
    public let bubble: BubbleConfig
    public let caustics: CausticsConfig
    public let foam: FoamConfig
    public let rendering: RenderingConfig
    public let animations: AnimationsConfig
    public let advancedEffects: AdvancedEffectsConfig
    public let presets: PresetsConfig

    public struct PhysicsConfig: Codable {
        public let ambientMotion: AmbientMotionConfig
        public let container: ContainerConfig
        public let wave: WaveConfig
        public let surface: SurfaceConfig

        public struct AmbientMotionConfig: Codable {
            public let enabled: Bool
            public let frequency1: Double
            public let frequency2: Double
            public let frequency3: Double
            public let amplitude1: Double
            public let amplitude2: Double
            public let amplitude3: Double
        }

        public struct ContainerConfig: Codable {
            public let accelerationDecay: Double
            public let tiltResponse: Double
            public let velocityDamping: Double
            public let angleDecay: Double
            public let springStrength: Double
            public let angleInertia: Double
            public let tiltAmplification: Double
            public let velocityDecay: Double
            public let displacementCoupling: Double
            public let displacementSpring: Double
        }

        public struct WaveConfig: Codable {
            public let excitationMultiplier: Double
            public let springMultiplier: Double
            public let reflectionBounce: Double
            public let frequencies: [Double]
            public let phaseOffsets: [Double]
            public let speedMultipliers: [Double]
            public let depthFactors: [Double]
            public let maxAmplitudes: [Double]
            public let coupling: [Double]
        }

        public struct SurfaceConfig: Codable {
            public let angleEffect: Double
            public let displacementEffect: Double
            public let waveDriftFactor: Double
            public let waveDriftFrequency: Double
            public let curvatureFactor: Double
            public let nonlinearityFactor: Double
            public let waveEffectFactor: Double
            public let rippleEffectFactor: Double
            public let rippleDampingFactor: Double
            public let maxWaveOffset: Double
        }
    }

    public struct BubbleConfig: Codable {
        public let minLiquidHeight: Double
        public let cycleSeconds: Double
        public let riseFraction: Double
        public let viscosityCoeff: Double
        public let wobbleBase: Double
        public let tiltFactor: Double
        public let maxAlpha: Double
    }

    public struct CausticsConfig: Codable {
        public let speed: Double
        public let scale: Double
        public let lightPenetration: Double
        public let depthFalloff: Double
        public let spotWidth: Double
        public let spotHeightMin: Double
        public let spotHeightMax: Double
        public let color: ColorConfig

        public struct ColorConfig: Codable {
            public let red: Double
            public let green: Double
            public let blue: Double
        }
    }

    public struct FoamConfig: Codable {
        public let thickness: Double
        public let clearOffset: Double
        public let clearOpacity: Double
        public let midOpacity: Double
        public let lightOpacity: Double
        public let creamOpacity: Double
    }

    public struct RenderingConfig: Codable {
        public let waveStep: Double
        public let causticStep: Double
        public let animationFramerate: Double
        public let gradientShiftFactor: Double
        public let gradientAngleFactor: Double
        public let gradientDisplacementFactor: Double
        public let gradientWaveFactor: Double
    }

    public struct AnimationsConfig: Codable {
        public let fillLevelDuration: Double
        public let fillLevelEasing: Double
        public let fillLevelSpring: Double
        public let fillLevelDamping: Double
        public let fillChangeSloshMultiplier: Double
        public let sloshImpulseStrength: Double
        public let sloshLayerMultiplier: [Double]
        public let sloshDampingExtra: Double
        public let pourWaveStrength: Double
        public let pourOscillationCount: Int
        public let settleWaveStrength: Double
    }

    public struct AdvancedEffectsConfig: Codable {
        public let viscosity: ViscosityConfig
        public let surfaceTension: SurfaceTensionConfig
        public let thermal: ThermalConfig
        public let coalescence: CoalescenceConfig

        public struct ViscosityConfig: Codable {
            public let base: Double
            public let waveDamping: Double
            public let surfaceTension: Double
            public let temperatureCoeff: Double
        }

        public struct SurfaceTensionConfig: Codable {
            public let strength: Double
            public let meniscusHeight: Double
            public let bubbleInteraction: Double
            public let viscosityCoupling: Double
        }

        public struct ThermalConfig: Codable {
            public let expansionCoeff: Double
            public let fillEffect: Double
            public let viscosity: Double
            public let bubbleGrowth: Double
        }

        public struct CoalescenceConfig: Codable {
            public let enabled: Bool
            public let threshold: Double
            public let rate: Double
            public let viscosityFactor: Double
            public let surfaceTensionFactor: Double
            public let thermalFactor: Double
        }
    }

    public struct PresetsConfig: Codable {
        public let espresso: PresetLayers
        public let latte: PresetLayers
        public let water: PresetLayers

        public struct PresetLayers: Codable {
            public let layers: [Layer]
        }

        public struct Layer: Codable {
            public let name: String
            public let topColor: [Double]
            public let bottomColor: [Double]
            public let boundaryHeight: Double
            public let waveDamping: Double
            public let phaseDelay: Double
            public let hasFoam: Bool
            public let foamColor: [Double]?
            public let bubbleDensity: Double?
        }

        public func toLayerConfiguration(_ name: String) -> LiquidLayerConfiguration {
            let preset: PresetLayers
            switch name.lowercased() {
            case "espresso": preset = espresso
            case "latte": preset = latte
            case "water": preset = water
            default: preset = espresso
            }

            let layers = preset.layers.map { p in
                LiquidLayer(
                    name: p.name,
                    topColor: Color(red: p.topColor[0], green: p.topColor[1], blue: p.topColor[2]),
                    bottomColor: Color(red: p.bottomColor[0], green: p.bottomColor[1], blue: p.bottomColor[2]),
                    boundaryHeight: p.boundaryHeight,
                    waveDamping: p.waveDamping,
                    phaseDelay: p.phaseDelay,
                    hasFoam: p.hasFoam,
                    foamColor: p.foamColor.map { Color(red: $0[0], green: $0[1], blue: $0[2]) } ?? .clear,
                    bubbleDensity: p.bubbleDensity ?? 0
                )
            }

            return LiquidLayerConfiguration(layers: layers)
        }
    }

    public static func load() -> LiquidConfig? {
        guard let url = Bundle.module.url(forResource: "liquid_config", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return try? JSONDecoder().decode(LiquidConfig.self, from: data)
    }

    public static var `default`: LiquidConfig {
        LiquidConfig(
            version: "1.0",
            physics: PhysicsConfig(
                ambientMotion: PhysicsConfig.AmbientMotionConfig(
                    enabled: true, frequency1: 1.7, frequency2: 2.3, frequency3: 3.1,
                    amplitude1: 0.02, amplitude2: 0.015, amplitude3: 0.01
                ),
                container: PhysicsConfig.ContainerConfig(
                    accelerationDecay: 0.88, tiltResponse: 0.15, velocityDamping: 0.985,
                    angleDecay: 0.985, springStrength: 0.03, angleInertia: 0.95,
                    tiltAmplification: 4.5, velocityDecay: 0.98, displacementCoupling: 0.003,
                    displacementSpring: 0.3
                ),
                wave: PhysicsConfig.WaveConfig(
                    excitationMultiplier: 2.0, springMultiplier: 0.8, reflectionBounce: -0.3,
                    frequencies: [0.015, 0.025, 0.035], phaseOffsets: [0.0, 2.0, 4.0],
                    speedMultipliers: [0.8, 1.1, 1.4], depthFactors: [1.0, 0.85, 0.7],
                    maxAmplitudes: [8.0, 6.0, 4.0], coupling: [0.5, 0.2, 0.1]
                ),
                surface: PhysicsConfig.SurfaceConfig(
                    angleEffect: 1.0, displacementEffect: 2.0, waveDriftFactor: 0.5,
                    waveDriftFrequency: 0.5, curvatureFactor: 0.15, nonlinearityFactor: 0.08,
                    waveEffectFactor: 0.15, rippleEffectFactor: 0.1, rippleDampingFactor: 0.4,
                    maxWaveOffset: 40.0
                )
            ),
            bubble: BubbleConfig(
                minLiquidHeight: 30, cycleSeconds: 8.0, riseFraction: 0.8,
                viscosityCoeff: 2.5, wobbleBase: 3.0, tiltFactor: 30.0, maxAlpha: 0.3
            ),
            caustics: CausticsConfig(
                speed: 0.3, scale: 0.02, lightPenetration: 0.08, depthFalloff: 0.7,
                spotWidth: 6.0, spotHeightMin: 12.0, spotHeightMax: 32.0,
                color: CausticsConfig.ColorConfig(red: 0.92, green: 0.88, blue: 0.80)
            ),
            foam: FoamConfig(
                thickness: 20.0, clearOffset: 12.0, clearOpacity: 0.2,
                midOpacity: 0.5, lightOpacity: 0.7, creamOpacity: 0.8
            ),
            rendering: RenderingConfig(
                waveStep: 2.0, causticStep: 2.0, animationFramerate: 30.0,
                gradientShiftFactor: 10.0, gradientAngleFactor: 0.8,
                gradientDisplacementFactor: 0.05, gradientWaveFactor: 0.02
            ),
            animations: AnimationsConfig(
                fillLevelDuration: 0.8, fillLevelEasing: 0.3, fillLevelSpring: 0.075,
                fillLevelDamping: 0.75, fillChangeSloshMultiplier: 10.0,
                sloshImpulseStrength: 15.0, sloshLayerMultiplier: [1.0, 0.7, 0.4],
                sloshDampingExtra: 0.1, pourWaveStrength: 25.0, pourOscillationCount: 3,
                settleWaveStrength: 8.0
            ),
            advancedEffects: AdvancedEffectsConfig(
                viscosity: AdvancedEffectsConfig.ViscosityConfig(
                    base: 0.15, waveDamping: 0.3, surfaceTension: 0.2, temperatureCoeff: 0.02
                ),
                surfaceTension: AdvancedEffectsConfig.SurfaceTensionConfig(
                    strength: 0.08, meniscusHeight: 3.0, bubbleInteraction: 0.15, viscosityCoupling: 0.12
                ),
                thermal: AdvancedEffectsConfig.ThermalConfig(
                    expansionCoeff: 0.0003, fillEffect: 0.02, viscosity: 0.08, bubbleGrowth: 0.05
                ),
                coalescence: AdvancedEffectsConfig.CoalescenceConfig(
                    enabled: true, threshold: 8.0, rate: 0.02,
                    viscosityFactor: 0.3, surfaceTensionFactor: 0.25, thermalFactor: 0.15
                )
            ),
            presets: PresetsConfig(
                espresso: PresetsConfig.PresetLayers(
                    layers: [
                        PresetsConfig.Layer(
                            name: "crema", topColor: [0.85, 0.70, 0.50], bottomColor: [0.65, 0.45, 0.25],
                            boundaryHeight: 0.12, waveDamping: 0.97, phaseDelay: 0.0,
                            hasFoam: true, foamColor: [0.90, 0.78, 0.55], bubbleDensity: 0.8
                        ),
                        PresetsConfig.Layer(
                            name: "liquid", topColor: [0.40, 0.25, 0.12], bottomColor: [0.20, 0.10, 0.05],
                            boundaryHeight: 0.50, waveDamping: 0.88, phaseDelay: 0.15,
                            hasFoam: false, foamColor: nil, bubbleDensity: nil
                        ),
                        PresetsConfig.Layer(
                            name: "dense", topColor: [0.15, 0.07, 0.03], bottomColor: [0.08, 0.03, 0.01],
                            boundaryHeight: 1.0, waveDamping: 0.78, phaseDelay: 0.40,
                            hasFoam: false, foamColor: nil, bubbleDensity: nil
                        )
                    ]
                ),
                latte: PresetsConfig.PresetLayers(
                    layers: [
                        PresetsConfig.Layer(
                            name: "foam", topColor: [0.95, 0.92, 0.88], bottomColor: [0.85, 0.80, 0.75],
                            boundaryHeight: 0.25, waveDamping: 0.98, phaseDelay: 0.0,
                            hasFoam: true, foamColor: [0.95, 0.92, 0.88], bubbleDensity: 1.0
                        ),
                        PresetsConfig.Layer(
                            name: "milkCoffee", topColor: [0.60, 0.45, 0.30], bottomColor: [0.40, 0.28, 0.18],
                            boundaryHeight: 0.60, waveDamping: 0.90, phaseDelay: 0.12,
                            hasFoam: false, foamColor: nil, bubbleDensity: nil
                        ),
                        PresetsConfig.Layer(
                            name: "espresso", topColor: [0.25, 0.12, 0.06], bottomColor: [0.10, 0.05, 0.02],
                            boundaryHeight: 1.0, waveDamping: 0.80, phaseDelay: 0.35,
                            hasFoam: false, foamColor: nil, bubbleDensity: nil
                        )
                    ]
                ),
                water: PresetsConfig.PresetLayers(
                    layers: [
                        PresetsConfig.Layer(
                            name: "surface", topColor: [0.50, 0.65, 0.85], bottomColor: [0.35, 0.50, 0.70],
                            boundaryHeight: 0.08, waveDamping: 0.95, phaseDelay: 0.0,
                            hasFoam: false, foamColor: nil, bubbleDensity: nil
                        ),
                        PresetsConfig.Layer(
                            name: "liquid", topColor: [0.25, 0.40, 0.60], bottomColor: [0.08, 0.18, 0.35],
                            boundaryHeight: 1.0, waveDamping: 0.85, phaseDelay: 0.15,
                            hasFoam: false, foamColor: nil, bubbleDensity: nil
                        )
                    ]
                )
            )
        )
    }
}
