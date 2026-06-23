import Foundation

enum NavigationDestination: Equatable {
    case embedded
    case external
}

enum URLPolicy {
    private static let allowedHost = "api.lihe.chat"

    static func destination(for url: URL) -> NavigationDestination {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              host == allowedHost || host.hasSuffix(".\(allowedHost)") else {
            return .external
        }

        return .embedded
    }
}
