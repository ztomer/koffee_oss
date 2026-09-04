import Foundation

struct PKCurveParameters: Equatable {
    var baseHalfLife: Double = 5.0
    var jitterProbability: Double = 0.5
    var durationExtensionHours: Double = 0.0
    var cortisolImpact: Double = 1.0

    static let `default` = PKCurveParameters()
}
