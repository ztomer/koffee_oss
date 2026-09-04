import Foundation

struct Dose: Equatable {
    var time: Date?
    var amount: Double
    var compound: NootropicCompound = .caffeine
    var isPlanItem: Bool = false

    init(time: Date? = nil, amount: Double = 0, compound: NootropicCompound = .caffeine, isPlanItem: Bool = false) {
        self.time = time
        self.amount = amount
        self.compound = compound
        self.isPlanItem = isPlanItem
    }

    var timeString: String? {
        guard let time = time else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
}
