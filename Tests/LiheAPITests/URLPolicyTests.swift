import XCTest
@testable import LiheAPI

final class URLPolicyTests: XCTestCase {
    func testMainSiteUsesEmbeddedBrowser() {
        XCTAssertEqual(URLPolicy.destination(for: URL(string: "https://api.lihe.chat/dashboard")!), .embedded)
    }

    func testSubdomainsUseEmbeddedBrowser() {
        XCTAssertEqual(URLPolicy.destination(for: URL(string: "https://docs.api.lihe.chat/guide")!), .embedded)
    }

    func testExternalHTTPSLinksUseSystemBrowser() {
        XCTAssertEqual(URLPolicy.destination(for: URL(string: "https://example.com/help")!), .external)
    }

    func testNonHTTPSLinksUseSystemBrowser() {
        XCTAssertEqual(URLPolicy.destination(for: URL(string: "mailto:support@lihe.chat")!), .external)
    }
}
