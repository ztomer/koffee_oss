import Foundation

// MARK: - Advanced Physics Effects

// MARK: - Advanced physics: temperature, vortex, foam, stratification, acoustic,
// capillary, Kelvin-Helmholtz, wetting, meniscus, crema, extraction.
@MainActor
extension LiquidPhysicsEngine {

    func updateAdvancedPhysicsEffects(accel: CGFloat, deltaTime: Double) {
        let baseViscosity = LiquidPhysics.viscosityBase
        let viscosityTempEffect = (1.0 - liquidTemperature) * LiquidPhysics.viscosityTemperatureCoeff
        viscosity = baseViscosity + viscosityTempEffect

        surfaceTension = LiquidPhysics.surfaceTensionStrength * (1.0 + viscosity * LiquidPhysics.surfaceTensionViscosityCoupling)

        let accelMagnitude = abs(accel)
        if accelMagnitude > LiquidPhysics.vortexVelocityThreshold && LiquidPhysics.vortexEnabled {
            let vortexForce = (accelMagnitude - LiquidPhysics.vortexVelocityThreshold) * LiquidPhysics.vortexStrength
            vortexIntensity = min(vortexIntensity + vortexForce, 1.0)
            vortexIntensity *= (1.0 - LiquidPhysics.vortexViscosityDamping * viscosity)
        } else {
            vortexIntensity *= 0.98
        }

        if LiquidPhysics.centripetalEnabled {
            rotationVelocity += accel * LiquidPhysics.centripetalStrength * deltaTime
            rotationVelocity *= LiquidPhysics.centripetalDecay
            rotationVelocity *= (1.0 - LiquidPhysics.centripetalViscosityDrag * viscosity)
        }

        let vortexCentripetalCoupling = vortexIntensity * LiquidPhysics.centripetalVortexCoupling
        rotationVelocity += vortexCentripetalCoupling * 0.1

        if LiquidPhysics.coalescenceEnabled {
            let tempCoalescence = liquidTemperature * LiquidPhysics.coalescenceThermalFactor
            let visCoalescence = (1.0 - viscosity * LiquidPhysics.coalescenceViscosityFactor)
            let stCoalescence = surfaceTension * LiquidPhysics.coalescenceSurfaceTensionFactor
            bubbleCoalescenceRate = LiquidPhysics.coalescenceRate * (1.0 + tempCoalescence + stCoalescence) * visCoalescence
        }

        if LiquidPhysics.foamCollapseEnabled {
            let visCollapse = 1.0 - viscosity * LiquidPhysics.foamCollapseViscosity
            let stCollapse = surfaceTension * LiquidPhysics.foamCollapseSurfaceTension
            let thermalCollapse = (1.0 - liquidTemperature) * LiquidPhysics.foamCollapseThermal
            let vortexDisturb = vortexIntensity * LiquidPhysics.foamCollapseVortexDisturb
            let collapseRate = LiquidPhysics.foamCollapseRate * (visCollapse + stCollapse + thermalCollapse + vortexDisturb)
            foamStability = max(0, min(1.0, foamStability - collapseRate))
        }

        // 8. Pressure Gradients
        if LiquidPhysics.pressureGradientEnabled {
            let basePressure = abs(surfaceAngle) * LiquidPhysics.pressureGradientStrength
            let densityFactor = layerCount > 0 ? CGFloat(layerCount) / 3.0 : 0.5
            pressureGradient = basePressure * densityFactor * (1.0 + viscosity * 0.1)
        }

        // 9. Density Stratification
        if LiquidPhysics.densityStratificationEnabled {
            if layerDensities.isEmpty {
                layerDensities = (0..<max(layerCount, 1)).map { i in
                    switch i {
                    case 0: return LiquidPhysics.densityCrema
                    case 1: return LiquidPhysics.densityLiquid
                    default: return LiquidPhysics.densityDense
                    }
                }
            }
            let densityWaveEffect = layerDensities.reduce(0, +) / CGFloat(max(layerDensities.count, 1))
            pressureGradient += densityWaveEffect * LiquidPhysics.densityPressureFactor * abs(surfaceAngle) * 0.1
        }

        // 10. Acoustic Resonance
        if LiquidPhysics.acousticEnabled {
            let acousticAccel = accel * LiquidPhysics.acousticVelocityCoupling
            acousticVelocity += acousticAccel
            acousticVelocity += liquidDisplacement * LiquidPhysics.acousticDisplacementCoupling * 0.01
            acousticVelocity *= LiquidPhysics.acousticDamping
            acousticPressure = sin(internalTime * LiquidPhysics.acousticFrequency) * acousticVelocity * CGFloat(LiquidPhysics.acousticWaveSpeed)
        }

        // 11. Capillary Waves
        if LiquidPhysics.capillaryEnabled {
            let capSTFactor = surfaceTension * LiquidPhysics.capillarySurfaceTensionFactor
            let capViscosityDamp = 1.0 - viscosity * LiquidPhysics.capillaryViscosityDamping
            capillaryWaveAmplitude = LiquidPhysics.capillaryAmplitude * capSTFactor * capViscosityDamp
                * (1.0 + sin(internalTime * LiquidPhysics.capillarySpeed) * 0.3)
        }

        // 12. Kelvin-Helmholtz Instability
        if LiquidPhysics.khInstabilityEnabled {
            var totalShear: CGFloat = 0
            for i in 0..<max(layerStates.count - 1, 0) {
                let layer1Vel = layerStates[i].surfaceAngle
                let layer2Vel = layerStates[i + 1].surfaceAngle
                totalShear += abs(layer1Vel - layer2Vel)
            }
            if totalShear > LiquidPhysics.khShearThreshold {
                let khGrowth = (totalShear - LiquidPhysics.khShearThreshold) * LiquidPhysics.khGrowthRate
                let khDensity = LiquidPhysics.densityStratificationEnabled ? LiquidPhysics.khDensityContrastFactor : 0.1
                let khViscosityStab = 1.0 - viscosity * LiquidPhysics.khViscosityStabilization
                khInstability += khGrowth * khDensity * khViscosityStab
            }
            khInstability *= LiquidPhysics.khDamping
            khInstability = min(khInstability, 1.0)
        }

        // 13. Wetting Behavior
        if LiquidPhysics.wettingEnabled {
            let baseContact = LiquidPhysics.wettingContactAngle
            let tempEffect = (liquidTemperature - 0.5) * 0.1
            wettingContactLine = baseContact + tempEffect
        }

        // 14. Meniscus Curvature
        if LiquidPhysics.meniscusEnabled {
            let stEffect = surfaceTension * LiquidPhysics.meniscusSurfaceTensionEffect
            let visEffect = viscosity * LiquidPhysics.meniscusViscosityEffect
            let presEffect = abs(surfaceAngle) * LiquidPhysics.meniscusPressureEffect
            meniscusCurvature = LiquidPhysics.meniscusCurvatureStrength * 0.3 * (1.0 + stEffect + visEffect + presEffect)
        }

        // 15. Crema Dynamics
        if LiquidPhysics.cremaDynamicsEnabled && layerStates.count > 0 {
            let creElastic = surfaceAngle * LiquidPhysics.cremaElasticity
            let creDamp = 1.0 - viscosity * LiquidPhysics.cremaDamping
            cremaElasticEnergy += creElastic * creDamp
            cremaElasticEnergy *= (1.0 - LiquidPhysics.cremaDamping * 0.1)
        }

        // 16. Extraction Effects (CO2 release)
        if LiquidPhysics.extractionEnabled {
            let tempEffect = liquidTemperature * LiquidPhysics.extractionTemperatureEffect
            extractionCO2 *= (1.0 - LiquidPhysics.extractionDecayRate)
            extractionCO2 += tempEffect * LiquidPhysics.extractionCO2Release * 0.1
            extractionCO2 = min(extractionCO2, LiquidPhysics.extractionCO2Release)
        }
    }
}
