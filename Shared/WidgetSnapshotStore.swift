import Foundation

enum WidgetSnapshotStoreError: Error, Equatable {
    case encodingFailed
}

struct WidgetSnapshotStore {
    static let appGroupIdentifier = "group.chat.lihe.api.mac"
    static let snapshotKey = "widgetSnapshot"
    static let snapshotFileName = "WidgetSnapshot.json"

    let defaults: UserDefaults
    let fileURL: URL?

    init(
        defaults: UserDefaults = WidgetSnapshotStore.sharedDefaults(),
        fileURL: URL? = WidgetSnapshotStore.sharedFileURL()
    ) {
        self.defaults = defaults
        self.fileURL = fileURL
    }

    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func sharedFileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(snapshotFileName)
    }

    func save(_ snapshot: WidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: Self.snapshotKey)
        defaults.synchronize()

        if let fileURL {
            try data.write(to: fileURL, options: [.atomic])
        }
    }

    func load() throws -> WidgetSnapshot? {
        if let fileURL,
           FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        }

        guard let data = defaults.data(forKey: Self.snapshotKey) else {
            return nil
        }
        return try JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
