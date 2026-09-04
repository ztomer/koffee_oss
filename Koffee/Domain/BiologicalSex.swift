import Foundation

enum BiologicalSex: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"

    var id: String { rawValue }

    var swiftDataValue: String { rawValue.lowercased() }

    init?(swiftDataValue: String) {
        self.init(rawValue: swiftDataValue.capitalized)
    }
}
