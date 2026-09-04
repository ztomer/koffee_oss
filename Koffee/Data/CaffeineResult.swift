import Foundation

struct CaffeineResult: Equatable {
    let dailyLimit: Double
    let firstDose: Dose
    let secondDose: Dose
    let thirdDose: Dose
    let warnings: [String]
    let latestSafeCaffeineTime: String?
}
