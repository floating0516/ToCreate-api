import Foundation

enum WidgetSnapshotStoreError: Error, Equatable {
    case encodingFailed
}

struct WidgetSnapshotStore {
    static let appGroupIdentifier = "group.chat.lihe.api.mac"
    static let snapshotKey = "widgetSnapshot"

    let defaults: UserDefaults

    init(defaults: UserDefaults = WidgetSnapshotStore.sharedDefaults()) {
        self.defaults = defaults
    }

    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    func save(_ snapshot: WidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: Self.snapshotKey)
    }

    func load() throws -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: Self.snapshotKey) else {
            return nil
        }
        return try JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
