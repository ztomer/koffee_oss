import Foundation

// MARK: - Surface Geometry
@MainActor
extension LiquidPhysicsEngine {

    public func surfaceHeight(x: CGFloat, width: CGFloat) -> CGFloat {
        baseSurfaceHeight(x: x, width: width, layerIndex: 0)
    }

    public func layerSurfaceHeight(x: CGFloat, width: CGFloat, layerIndex: Int) -> CGFloat {
        guard layerIndex < layerStates.count else {
            return baseSurfaceHeight(x: x, width: width, layerIndex: 0)
        }
        return baseSurfaceHeight(x: x, width: width, layerIndex: layerIndex)
    }

    private func baseSurfaceHeight(x: CGFloat, width: CGFloat, layerIndex: Int) -> CGFloat {
        let normalizedX = x / width

        var layerAngle: CGFloat
        var layerDisp: CGFloat
        var localWaves: [WaveState]
        var layerDamping: CGFloat
        var phaseDelay: CGFloat

        if layerIndex > 0 && layerIndex < layerStates.count {
            layerAngle = layerStates[layerIndex].surfaceAngle
            layerDisp = layerStates[layerIndex].displacement
            localWaves = layerStates[layerIndex].waves
            layerDamping = layerStates[layerIndex].waveDamping
            phaseDelay = layerStates[layerIndex].phaseDelay
        } else {
            layerAngle = surfaceAngle
            layerDisp = liquidDisplacement
            localWaves = waves
            layerDamping = 1.0
            phaseDelay = 0.0
        }

        let t = internalTime - Double(phaseDelay)

        let visWaveDamping = 1.0 - viscosity * LiquidPhysics.viscosityWaveDamping
        let effectiveLayerDamping = layerDamping * visWaveDamping

        let angleEffect = -layerAngle * (normalizedX - 0.5) * LiquidPhysics.surfaceAngleEffect
        let displacementEffect = layerDisp * (normalizedX - 0.5) * LiquidPhysics.surfaceDisplacementEffect

        let waveDrift = layerDisp * LiquidPhysics.surfaceWaveDriftFactor * cos(t * LiquidPhysics.surfaceWaveDriftFrequency) * effectiveLayerDamping

        let waveAmplitude = localWaves.reduce(CGFloat(0)) { $0 + $1.amplitude }
        let curvature = waveAmplitude * LiquidPhysics.surfaceCurvatureFactor * effectiveLayerDamping

        let stWaveEffect = surfaceTension * LiquidPhysics.surfaceTensionBubbleInteraction
        let curvatureEffect = (curvature + stWaveEffect * waveAmplitude * 0.1) * sin(normalizedX * .pi * 2.0 + t * 2.0)
        let nonlinearity = waveAmplitude * LiquidPhysics.surfaceNonlinearityFactor * effectiveLayerDamping * sin(normalizedX * .pi * 3.0 + t * 1.5)

        var waveEffect: CGFloat = 0

        for i in 0..<min(localWaves.count, 3) {
            let freq = i < LiquidPhysics.waveFrequencies.count ? LiquidPhysics.waveFrequencies[i] : CGFloat(0.015 + Double(i) * 0.01)
            let phaseOffset = i < LiquidPhysics.wavePhaseOffsets.count ? LiquidPhysics.wavePhaseOffsets[i] : Double(i) * 2.0
            let speedMult = i < LiquidPhysics.waveSpeedMultipliers.count ? LiquidPhysics.waveSpeedMultipliers[i] : 0.8 + Double(i) * 0.3
            let depthFactor = i < LiquidPhysics.waveDepthFactors.count ? LiquidPhysics.waveDepthFactors[i] : 1.0 - CGFloat(i) * 0.15

            let wave = sin(x * freq + t * speedMult + phaseOffset) * localWaves[i].amplitude
                * LiquidPhysics.surfaceWaveEffectFactor * depthFactor * effectiveLayerDamping
            waveEffect += wave
        }

        let rippleDamping = effectiveLayerDamping * LiquidPhysics.surfaceRippleDampingFactor
        let ripple1 = sin(x * LiquidPhysics.waveFrequency1 + t * LiquidPhysics.waveSpeed1) * LiquidPhysics.waveAmplitude1
            * LiquidPhysics.surfaceRippleEffectFactor * rippleDamping
        let ripple2 = sin(x * LiquidPhysics.waveFrequency2 - t * LiquidPhysics.waveSpeed2) * LiquidPhysics.waveAmplitude2
            * LiquidPhysics.surfaceRippleEffectFactor * rippleDamping

        var vortexEffect: CGFloat = 0
        if LiquidPhysics.vortexEnabled && vortexIntensity > 0.01 {
            let vortexFreq = LiquidPhysics.vortexSheddingFrequency
            let vortexPhase = internalTime * vortexFreq
            vortexEffect = sin(normalizedX * .pi * 4.0 + vortexPhase) * vortexIntensity * LiquidPhysics.vortexStrength
                * (1.0 - surfaceTension * LiquidPhysics.vortexSurfaceTensionStabilization)
        }

        var centripetalEffect: CGFloat = 0
        if LiquidPhysics.centripetalEnabled && abs(rotationVelocity) > 0.01 {
            let rotPhase = normalizedX * .pi * 2.0 + internalTime * 3.0
            centripetalEffect = sin(rotPhase) * rotationVelocity * LiquidPhysics.centripetalStrength
                * (1.0 - viscosity * LiquidPhysics.centripetalViscosityDrag)
        }

        let foamEffect = (1.0 - foamStability) * LiquidPhysics.surfaceTensionMeniscusHeight * sin(normalizedX * .pi * 2.0) * 0.5

        let total = angleEffect + displacementEffect + waveDrift + curvatureEffect + nonlinearity + waveEffect
            + ripple1 + ripple2 + vortexEffect + centripetalEffect + foamEffect

        return total
    }

    public func bottomWaveOffset(x: CGFloat, width: CGFloat) -> CGFloat {
        let normalizedX = x / width
        let t = internalTime

        let bottomPhaseLag: Double = 0.4
        let bottomDepthFactor: CGFloat = 0.35
        let bottomDamping: CGFloat = 0.4

        let baseAngle = surfaceAngle * bottomDepthFactor
        let baseDisplacement = liquidDisplacement * bottomDepthFactor * 0.5

        let angleEffect = -baseAngle * (normalizedX - 0.5) * 1.5
        let displacementEffect = baseDisplacement * (normalizedX - 0.5) * 3.0

        let waveAmplitude = waves[0].amplitude + waves[1].amplitude + waves[2].amplitude
        let bottomWave = waveAmplitude * bottomDamping * sin(normalizedX * .pi * 2.0 + t * 1.5 - bottomPhaseLag)

        let rippleBottom = sin(x * LiquidPhysics.waveFrequency1 + t * LiquidPhysics.waveSpeed1) * LiquidPhysics.waveAmplitude1 * 0.15

        return angleEffect + displacementEffect + bottomWave + rippleBottom
    }
}
