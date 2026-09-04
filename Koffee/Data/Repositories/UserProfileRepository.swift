import Foundation
import GRDB
import Combine

final class UserProfileRepository: UserProfileRepositoryProtocol {
    private let db: DatabaseQueue
    @Published private(set) var profile: UserProfileModel?
    private var cancellables = Set<AnyCancellable>()

    init(db: DatabaseQueue) {
        self.db = db
        self.profile = try? db.read { db in try UserProfileModel.fetchOne(db) }
        startObserving()
    }

    private func startObserving() {
        ValueObservation
            .tracking(UserProfileModel.fetchAll)
            .publisher(in: db, scheduling: .immediate)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] profiles in
                    self?.profile = profiles.first
                }
            )
            .store(in: &cancellables)
    }

    /// Re-run the observed query so published state reflects this write NOW.
    /// GRDB 7's `.immediate` scheduler delivers only the INITIAL value
    /// synchronously; subsequent observations arrive via DispatchQueue.main.async,
    /// so callers cannot rely on the observer for read-after-write consistency.
    private func reload() {
        profile = (try? db.read { db in try UserProfileModel.fetchOne(db) }) ?? profile
    }

    func save(_ profile: UserProfileModel) throws {
        try db.write { db in
            try profile.save(db)
        }
        reload()
    }

    /// Checks the DATABASE, not the published cache - the cache can lag the
    /// latest write by one main-queue hop, which would create duplicate rows.
    func getOrCreate() throws -> UserProfileModel {
        if let existing = try db.read({ db in try UserProfileModel.fetchOne(db) }) {
            debugLog("ProfileRepository.getOrCreate: returning existing, wakeTime=\(existing.wakeTime), sleepTime=\(existing.sleepTime)")
            return existing
        }

        let now = Date()
        let wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
        let sleepTime = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: now) ?? now

        debugLog("ProfileRepository.getOrCreate: creating new, wakeTime=\(wakeTime), sleepTime=\(sleepTime)")

        let newProfile = UserProfileModel(
            wakeTime: wakeTime,
            sleepTime: sleepTime
        )
        try save(newProfile)
        return newProfile
    }
}
