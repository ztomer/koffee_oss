import Foundation

struct Beverage: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String
    let caffeineMg: Int
    let category: String
    let icon: String

    enum CodingKeys: String, CodingKey {
        case name
        case caffeineMg = "caffeine_mg"
        case category
        case icon
    }
}
