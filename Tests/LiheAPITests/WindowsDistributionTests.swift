import XCTest

final class WindowsDistributionTests: XCTestCase {
    private static var projectRootPath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
    }

    private static func projectFile(_ relativePath: String) -> String {
        URL(fileURLWithPath: projectRootPath)
            .appendingPathComponent(relativePath)
            .path
    }

    func testWindowsClientProjectUsesWebView2ForEmbeddedSite() throws {
        let project = try String(contentsOfFile: Self.projectFile("windows/ToCreate.Windows/ToCreate.Windows.csproj"))
        let app = try String(contentsOfFile: Self.projectFile("windows/ToCreate.Windows/MainWindow.xaml.cs"))

        XCTAssertTrue(project.contains("Microsoft.Web.WebView2"))
        XCTAssertTrue(app.contains("https://api.lihe.chat"))
        XCTAssertTrue(app.contains("EnsureCoreWebView2Async"))
    }

    func testGitHubActionBuildsAndUploadsWindowsArtifact() throws {
        let workflow = try String(contentsOfFile: Self.projectFile(".github/workflows/windows.yml"))

        XCTAssertTrue(workflow.contains("windows-latest"))
        XCTAssertTrue(workflow.contains("dotnet restore"))
        XCTAssertTrue(workflow.contains("dotnet publish"))
        XCTAssertTrue(workflow.contains("actions/upload-artifact"))
        XCTAssertTrue(workflow.contains("ToCreate-Windows"))
    }

    func testSwiftPackageExcludesWindowsPrototypeFiles() throws {
        let package = try String(contentsOfFile: Self.projectFile("Package.swift"))

        XCTAssertTrue(package.contains("\"windows\""))
    }

    func testWindowsPublishScriptAvoidsSelfContainedOnlyCompressionFlag() throws {
        let script = try String(contentsOfFile: Self.projectFile("scripts/publish_windows.ps1"))

        XCTAssertTrue(script.contains("--self-contained false"))
        XCTAssertFalse(script.contains("EnableCompressionInSingleFile"))
    }
}
