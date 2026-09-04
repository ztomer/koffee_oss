import Foundation

struct UnifiedCurvePoint: Identifiable {
    let id = UUID()
    let time: Date
    let compoundLevels: [String: Double]
    let totalLevel: Double
}
