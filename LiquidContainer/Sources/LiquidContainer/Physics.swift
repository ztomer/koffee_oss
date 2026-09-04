import Foundation

@MainActor
public final class LiquidPhysicsEngine: Observable {
    public struct WaveState: Sendable {
        public var amplitude: CGFloat
        public var velocity: CGFloat

        public init(amplitude: CGFloat = 0, velocity: CGFloat = 0) {
            self.amplitude = amplitude
            self.velocity = velocity
        }
    }

    public struct LayerWaveState: Sendable {
        public var surfaceAngle: CGFloat
        public var angleVelocity: CGFloat
        public var displacement: CGFloat
        public var displacementVelocity: CGFloat
        public var waves: [WaveState]
        public var waveDamping: CGFloat
        public var phaseDelay: CGFloat

        public init(
            surfaceAngle: CGFloat = 0,
            angleVelocity: CGFloat = 0,
            displacement: CGFloat = 0,
            displacementVelocity: CGFloat = 0,
            waveDamping: CGFloat = 0.88,
            phaseDelay: CGFloat = 0
        ) {
            self.surfaceAngle = surfaceAngle
            self.angleVelocity = angleVelocity
            self.displacement = displacement
            self.displacementVelocity = displacementVelocity
            self.waveDamping = waveDamping
            self.phaseDelay = phaseDelay
            self.waves = (0..<3).map { _ in WaveState() }
        }
    }

    public var surfaceAngle: CGFloat = 0
    public var angleVelocity: CGFloat = 0

    public var liquidDisplacement: CGFloat = 0
    public var displacementVelocity: CGFloat = 0

    public private(set) var waves: [WaveState] = []

    public var containerAccelX: CGFloat = 0
    public var containerVelocityX: CGFloat = 0
    public var logFrame: Int = 0

    public var targetFillLevel: CGFloat = 0.5
    public var animatedFillLevel: CGFloat = 0.5
    public var fillLevelVelocity: CGFloat = 0

    public var pendingSlosh: CGFloat?
    public var sloshDirection: CGFloat = 1.0

    // Advanced physics state
    public var liquidTemperature: CGFloat = 0.5  // 0 = cold, 1 = hot (affects viscosity, expansion, bubble activity)
    public var viscosity: CGFloat = 0.15
    public var surfaceTension: CGFloat = 0.08
    public var foamStability: CGFloat = 1.0  // 1 = stable, 0 = collapsed
    public var rotationVelocity: CGFloat = 0  // centripetal rotation
    public var vortexIntensity: CGFloat = 0  // vortex shedding activity
    public var bubbleCoalescenceRate: CGFloat = 0.02

    // 8. Pressure Gradients
    public var pressureGradient: CGFloat = 0

    // 9. Density Stratification
    public var layerDensities: [CGFloat] = []

    // 10. Acoustic Resonance
    public var acousticPressure: CGFloat = 0
    public var acousticVelocity: CGFloat = 0

    // 11. Capillary Waves
    public var capillaryWaveAmplitude: CGFloat = 0

    // 12. Kelvin-Helmholtz Instability
    public var khInstability: CGFloat = 0

    // 13. Wetting Behavior
    public var wettingContactLine: CGFloat = 0.4

    // 14. Meniscus Curvature
    public var meniscusCurvature: CGFloat = 0.06

    // 15. Crema Dynamics
    public var cremaElasticEnergy: CGFloat = 0

    // 16. Extraction Effects
    public var extractionCO2: CGFloat = 0.08

    /// Internal simulation clock; exposed read-only via `internalTime`.
    var elapsedTime: Double = 0
    public private(set) var layerStates: [LayerWaveState] = []
    var layerCount: Int = 1
    private var layerDampingFactors: [CGFloat] = []
    private var layerPhaseDelays: [CGFloat] = []
    private var waveCoupling: CGFloat = 0.6
    private var reflectionRatio: CGFloat = 0.6

    public var internalTime: Double {
        elapsedTime
    }

    public var totalWaveAmplitude: CGFloat {
        waves.reduce(0) { $0 + abs($1.amplitude) }
    }

    public var totalLayerCount: Int {
        layerCount
    }

    public init(waveCount: Int = 3, layerCount: Int = 1) {
        waves = (0..<waveCount).map { _ in WaveState() }
        self.layerCount = layerCount
        initializeLayers()
    }

    public func configureLayers(
        count: Int,
        dampingFactors: [CGFloat],
        phaseDelays: [CGFloat],
        coupling: CGFloat = 0.6,
        reflection: CGFloat = 0.6
    ) {
        layerCount = count
        layerDampingFactors = dampingFactors
        layerPhaseDelays = phaseDelays
        waveCoupling = coupling
        reflectionRatio = reflection
        initializeLayers()
    }

    private func initializeLayers() {
        layerStates = (0..<layerCount).map { i in
            let damping = i < layerDampingFactors.count ? layerDampingFactors[i] : 0.85
            let phase = i < layerPhaseDelays.count ? layerPhaseDelays[i] : CGFloat(i) * 0.15
            return LayerWaveState(waveDamping: damping, phaseDelay: phase)
        }
    }

    public func step(deltaTime: Double) {
        elapsedTime += deltaTime

        let fillDiff = targetFillLevel - animatedFillLevel
        if abs(fillDiff) > 0.001 {
            let springForce = fillDiff * LiquidPhysics.fillLevelSpring
            fillLevelVelocity += springForce
            fillLevelVelocity *= LiquidPhysics.fillLevelDamping

            if abs(fillDiff) < 0.02 && abs(fillLevelVelocity) < 0.1 {
                fillLevelVelocity = 0
                animatedFillLevel = targetFillLevel
            } else {
                animatedFillLevel += fillLevelVelocity
            }

            if let pendingDir = pendingSlosh {
                sloshDirection = pendingDir > 0 ? 1.0 : -1.0
                pendingSlosh = nil
                let impulseStrength = abs(fillDiff) * LiquidPhysics.fillChangeSloshMultiplier
                containerAccelX += sloshDirection * impulseStrength
                angleVelocity += sloshDirection * impulseStrength * 0.5
            }
        }

        // Gradual slosh application over time
        if pendingSloshRemaining > 0 {
            let sloshDirection = pendingSlosh ?? 1.0
            let fraction = pendingSloshRemaining / pendingSloshDuration
            let currentStrength = pendingSloshStrength * fraction * CGFloat(deltaTime)

            containerAccelX += sloshDirection * currentStrength
            angleVelocity += sloshDirection * currentStrength * 0.6
            displacementVelocity += sloshDirection * currentStrength * 0.4

            for (index, layerMultiplier) in LiquidPhysics.sloshLayerMultiplier.enumerated() where index < layerStates.count {
                layerStates[index].angleVelocity += sloshDirection * currentStrength * layerMultiplier * 0.4
                layerStates[index].displacementVelocity += sloshDirection * currentStrength * layerMultiplier * 0.3
                if index < layerStates[index].waves.count {
                    layerStates[index].waves[0].velocity += sloshDirection * currentStrength * layerMultiplier * 0.5
                    layerStates[index].waves[1].velocity += sloshDirection * currentStrength * layerMultiplier * 0.3
                }
            }

            pendingSloshRemaining -= deltaTime
            if pendingSloshRemaining <= 0 {
                pendingSlosh = nil
                pendingSloshRemaining = 0
            }
        }

        var accel = containerAccelX

        if LiquidPhysics.ambientMotionEnabled {
            let ambientAccel = sin(elapsedTime * LiquidPhysics.ambientFrequency1) * LiquidPhysics.ambientAmplitude1
                            + sin(elapsedTime * LiquidPhysics.ambientFrequency2) * LiquidPhysics.ambientAmplitude2
                            + sin(elapsedTime * LiquidPhysics.ambientFrequency3) * LiquidPhysics.ambientAmplitude3
            accel += ambientAccel
        }

        containerAccelX *= LiquidPhysics.accelerationDecay

        containerVelocityX += accel * 0.5
        containerVelocityX *= LiquidPhysics.containerVelocityDecay

        angleVelocity += accel * LiquidPhysics.tiltResponse * LiquidPhysics.waveExcitationMultiplier
        angleVelocity -= surfaceAngle * LiquidPhysics.springStrength * LiquidPhysics.waveSpringMultiplier
        angleVelocity *= LiquidPhysics.velocityDamping
        surfaceAngle += angleVelocity * LiquidPhysics.angleInertia
        surfaceAngle *= LiquidPhysics.angleDecay

        displacementVelocity += containerVelocityX * LiquidPhysics.displacementCoupling
        displacementVelocity -= liquidDisplacement * LiquidPhysics.springStrength * LiquidPhysics.displacementSpring
        displacementVelocity *= LiquidPhysics.velocityDamping
        liquidDisplacement += displacementVelocity * LiquidPhysics.angleInertia
        liquidDisplacement *= LiquidPhysics.angleDecay

        for i in 0..<waves.count {
            let coupling = i < LiquidPhysics.waveCoupling.count ? LiquidPhysics.waveCoupling[i] : 0.1

            waves[i].velocity += accel * LiquidPhysics.tiltResponse * coupling
            waves[i].velocity -= waves[i].amplitude * LiquidPhysics.springStrength
            waves[i].velocity *= LiquidPhysics.velocityDamping
            waves[i].amplitude += waves[i].velocity * LiquidPhysics.angleInertia
            waves[i].amplitude *= LiquidPhysics.angleDecay

            let maxAmp = i < LiquidPhysics.waveMaxAmplitudes.count ? LiquidPhysics.waveMaxAmplitudes[i] : CGFloat(15 - i * 3)
            if abs(waves[i].amplitude) > maxAmp {
                waves[i].amplitude = maxAmp * (waves[i].amplitude > 0 ? 1 : -1)
                waves[i].velocity *= LiquidPhysics.waveReflectionBounce
            }
        }

        for layerIndex in 0..<layerStates.count {
            let layerDamping = layerStates[layerIndex].waveDamping

            // Bidirectional angle coupling
            var angleCoupling: CGFloat = 0
            if layerIndex > 0 {
                angleCoupling += layerStates[layerIndex - 1].surfaceAngle * 0.15
            }
            if layerIndex < layerStates.count - 1 {
                angleCoupling -= layerStates[layerIndex + 1].surfaceAngle * 0.08
            }

            layerStates[layerIndex].angleVelocity += accel * LiquidPhysics.tiltResponse * LiquidPhysics.waveExcitationMultiplier * layerDamping
            layerStates[layerIndex].angleVelocity += angleCoupling * 0.1
            layerStates[layerIndex].angleVelocity -= layerStates[layerIndex].surfaceAngle * LiquidPhysics.springStrength * LiquidPhysics.waveSpringMultiplier
            layerStates[layerIndex].angleVelocity *= LiquidPhysics.velocityDamping * layerDamping
            layerStates[layerIndex].surfaceAngle += layerStates[layerIndex].angleVelocity * LiquidPhysics.angleInertia
            layerStates[layerIndex].surfaceAngle *= LiquidPhysics.angleDecay * layerDamping

            // Bidirectional displacement coupling
            var dispCoupling: CGFloat = 0
            if layerIndex > 0 {
                dispCoupling += layerStates[layerIndex - 1].displacement * 0.12
            }
            if layerIndex < layerStates.count - 1 {
                dispCoupling -= layerStates[layerIndex + 1].displacement * 0.06
            }

            layerStates[layerIndex].displacementVelocity += containerVelocityX * LiquidPhysics.displacementCoupling * layerDamping
            layerStates[layerIndex].displacementVelocity += dispCoupling * 0.05
            layerStates[layerIndex].displacementVelocity -= layerStates[layerIndex].displacement
                * LiquidPhysics.springStrength * LiquidPhysics.displacementSpring
            layerStates[layerIndex].displacementVelocity *= LiquidPhysics.velocityDamping * layerDamping
            layerStates[layerIndex].displacement += layerStates[layerIndex].displacementVelocity * LiquidPhysics.angleInertia
            layerStates[layerIndex].displacement *= LiquidPhysics.angleDecay * layerDamping

            for i in 0..<layerStates[layerIndex].waves.count {
                let coupling = i < LiquidPhysics.waveCoupling.count ? LiquidPhysics.waveCoupling[i] : 0.1

                var waveAccel = accel

                // Bidirectional layer coupling - waves propagate both upward and downward
                if layerIndex > 0 {
                    // Downward coupling from layer above
                    waveAccel += layerStates[layerIndex - 1].surfaceAngle * waveCoupling * reflectionRatio * (1.0 - CGFloat(layerIndex) * 0.2)
                }
                if layerIndex < layerStates.count - 1 {
                    // Upward coupling from layer below
                    waveAccel -= layerStates[layerIndex + 1].surfaceAngle * waveCoupling * reflectionRatio * 0.3
                }

                // Cross-layer displacement influence
                if layerIndex > 0 {
                    waveAccel += layerStates[layerIndex - 1].displacement * waveCoupling * 0.1
                }
                if layerIndex < layerStates.count - 1 {
                    waveAccel -= layerStates[layerIndex + 1].displacement * waveCoupling * 0.08
                }

                layerStates[layerIndex].waves[i].velocity += waveAccel * LiquidPhysics.tiltResponse * coupling * layerDamping
                layerStates[layerIndex].waves[i].velocity -= layerStates[layerIndex].waves[i].amplitude * LiquidPhysics.springStrength
                layerStates[layerIndex].waves[i].velocity *= LiquidPhysics.velocityDamping * layerDamping
                layerStates[layerIndex].waves[i].amplitude += layerStates[layerIndex].waves[i].velocity * LiquidPhysics.angleInertia
                layerStates[layerIndex].waves[i].amplitude *= LiquidPhysics.angleDecay * layerDamping

                let maxAmp = i < LiquidPhysics.waveMaxAmplitudes.count ? LiquidPhysics.waveMaxAmplitudes[i] : CGFloat(15 - i * 3)
                if abs(layerStates[layerIndex].waves[i].amplitude) > maxAmp {
                    layerStates[layerIndex].waves[i].amplitude = maxAmp * (layerStates[layerIndex].waves[i].amplitude > 0 ? 1 : -1)
                    layerStates[layerIndex].waves[i].velocity *= LiquidPhysics.waveReflectionBounce
                }
            }
        }

        updateAdvancedPhysicsEffects(accel: accel, deltaTime: deltaTime)

        logFrame += 1
    }

    public func addSloshImpulse(direction: CGFloat = 1.0) {
        addSloshImpulseGradual(direction: direction, duration: 0.5)
    }

    public func addSloshImpulseGradual(direction: CGFloat = 1.0, duration: Double = 0.5) {
        pendingSlosh = direction
        pendingSloshDuration = duration
        pendingSloshRemaining = duration

        let strength = direction > 0 ? LiquidPhysics.pourWaveStrength : LiquidPhysics.settleWaveStrength
        pendingSloshStrength = direction * strength
    }

    private var pendingSloshDuration: Double = 0
    private var pendingSloshRemaining: Double = 0
    private var pendingSloshStrength: CGFloat = 0

    public func reset() {
        surfaceAngle = 0
        angleVelocity = 0
        liquidDisplacement = 0
        displacementVelocity = 0
        containerAccelX = 0
        containerVelocityX = 0
        elapsedTime = 0
        liquidTemperature = 0.5
        viscosity = LiquidPhysics.viscosityBase
        surfaceTension = LiquidPhysics.surfaceTensionStrength
        foamStability = 1.0
        rotationVelocity = 0
        vortexIntensity = 0
        bubbleCoalescenceRate = LiquidPhysics.coalescenceRate
        pendingSlosh = nil
        pendingSloshDuration = 0
        pendingSloshRemaining = 0
        pendingSloshStrength = 0
        pressureGradient = 0
        layerDensities = []
        acousticPressure = 0
        acousticVelocity = 0
        capillaryWaveAmplitude = 0
        khInstability = 0
        wettingContactLine = LiquidPhysics.wettingContactAngle
        meniscusCurvature = LiquidPhysics.meniscusCurvatureStrength
        cremaElasticEnergy = 0
        extractionCO2 = LiquidPhysics.extractionCO2Release
        for i in 0..<waves.count {
            waves[i] = WaveState()
        }
        for i in 0..<layerStates.count {
            layerStates[i] = LayerWaveState(waveDamping: layerDampingFactors[safe: i] ?? 0.85, phaseDelay: layerPhaseDelays[safe: i] ?? 0)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
