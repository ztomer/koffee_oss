import Foundation
import GRDB

@MainActor
class BeverageManager: ObservableObject {
    static let shared = BeverageManager()

    @Published var beverages: [Beverage] = []

    private init() {
        loadBeverages()
    }

    private func loadBeverages() {
        guard let url = Bundle.main.url(forResource: "beverages", withExtension: "json") else {
            loadDefaultBeverages()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let beverageData = try JSONDecoder().decode(BeverageData.self, from: data)

            // Remove any existing beverages from DB before loading fresh
            // This prevents duplicates on app restart
            Task {
                _ = try? await DatabaseManager.shared.queue().write { db in
                    try BeverageModel.deleteAll(db)
                }

                // Save fresh beverages
                let beverageModels = beverageData.beverages.map { b in
                    BeverageModel(
                        id: b.id.uuidString,
                        name: b.name,
                        caffeineMg: b.caffeineMg,
                        category: b.category,
                        icon: b.icon,
                        sortOrder: beverageData.beverages.firstIndex(where: { $0.id == b.id }) ?? 0
                    )
                }

                try? await DatabaseManager.shared.queue().write { db in
                    for model in beverageModels {
                        try model.insert(db)
                    }
                }

                self.beverages = beverageData.beverages
            }

            self.beverages = beverageData.beverages
        } catch {
            debugLog("Failed to load beverages: \(error)")
            loadDefaultBeverages()
        }
    }

    private func loadDefaultBeverages() {
        beverages = [
            Beverage(name: "Espresso (1 shot, 30ml)", caffeineMg: 63, category: "Coffee", icon: "Coffee"),
            Beverage(name: "Brewed Coffee (240ml)", caffeineMg: 95, category: "Coffee", icon: "Coffee"),
            Beverage(name: "Instant Coffee (240ml)", caffeineMg: 62, category: "Coffee", icon: "Coffee"),
            Beverage(name: "Cold Brew (240ml)", caffeineMg: 200, category: "Coffee", icon: "Coffee"),
            Beverage(name: "Cafe Latte (240ml)", caffeineMg: 75, category: "Coffee", icon: "Coffee"),
            Beverage(name: "Black Tea (240ml)", caffeineMg: 47, category: "Tea", icon: "Tea"),
            Beverage(name: "Green Tea (240ml)", caffeineMg: 28, category: "Tea", icon: "Tea"),
            Beverage(name: "Cola (355ml)", caffeineMg: 40, category: "Energy", icon: "Soft drink"),
            Beverage(name: "Red Bull (240ml)", caffeineMg: 80, category: "Energy", icon: "Energy"),
            Beverage(name: "Energy Drink (240ml)", caffeineMg: 80, category: "Energy", icon: "Energy")
        ]
    }

    func findBestBeverageIndex(for amount: Double) -> Int {
        var bestIndex = 0
        var bestDiff = Double.infinity

        for (index, beverage) in beverages.enumerated() {
            let count = amount / Double(beverage.caffeineMg)
            let diff = abs(count - 1.0)
            if diff < bestDiff {
                bestDiff = diff
                bestIndex = index
            }
        }

        return bestIndex
    }
}
