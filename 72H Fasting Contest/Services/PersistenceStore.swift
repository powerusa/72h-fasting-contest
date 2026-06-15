import Foundation

actor PersistenceStore {
    private let key = "fastingContest.snapshot.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSnapshot {
        guard let data = defaults.data(forKey: key) else {
            return AppSnapshot()
        }

        do {
            return try JSONDecoder().decode(AppSnapshot.self, from: data)
        } catch {
            return AppSnapshot()
        }
    }

    func save(_ snapshot: AppSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: key)
        } catch {
            assertionFailure("Unable to save app snapshot: \(error)")
        }
    }
}
