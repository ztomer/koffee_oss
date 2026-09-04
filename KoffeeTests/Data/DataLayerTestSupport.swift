import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Test Helpers

@MainActor
final class TestAppState: ObservableObject {
    @Published var doses: [Dose] = []
    @Published var profile: UserProfileModel?
    @Published var dailyPlanItems: [DailyPlanItemModel] = []

    var dosesForDate: (Date) -> [Dose] = { _ in [] }
    var safeCaffeineLimit: Double { 400 }
    var todayCaffeineTotal: Double { 0 }
    var currentCaffeineLevel: Double { 0 }
    var toleranceAlert: ToleranceAlert? { nil }
}
