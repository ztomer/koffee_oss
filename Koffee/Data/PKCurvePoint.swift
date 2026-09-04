import Foundation

struct PKCurvePoint: Identifiable {
    let id = UUID()
    let time: Date
    let expected: Double
    let upper: Double
    let lower: Double
}
