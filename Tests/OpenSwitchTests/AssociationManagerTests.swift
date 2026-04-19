import XCTest
import UniformTypeIdentifiers
@testable import OpenSwitch

/// 这些测试只覆盖纯逻辑（扩展名 → UTI 的解析），不调用 LaunchServices，
/// 避免在 CI 与本地环境里产生不可预期的全局副作用。
final class AssociationManagerUTIResolutionTests: XCTestCase {
    func testNormalizeStripsDotAndLowercases() {
        XCTAssertEqual(LaunchServicesAssociationManager.normalize("  .TSX "), "tsx")
        XCTAssertEqual(LaunchServicesAssociationManager.normalize(".JSON"), "json")
        XCTAssertEqual(LaunchServicesAssociationManager.normalize("..ts."), "ts")
        XCTAssertEqual(LaunchServicesAssociationManager.normalize(""), "")
    }

    func testResolvesTsxToTypescriptUTI() {
        // 现实场景：用户截图里的 ToolbarButton.tsx
        // 系统的 com.microsoft.typescript 既包含 tsx 也是 source-code，必须被选中。
        let uti = LaunchServicesAssociationManager.resolveUTI(for: ".tsx")
        XCTAssertNotNil(uti)
        XCTAssertEqual(uti?.identifier, "com.microsoft.typescript")
        XCTAssertFalse(uti?.isDynamic ?? true, "tsx 不应回退到 dyn.* UTI")
    }

    func testResolvesTsToTypescriptInsteadOfMpegTransportStream() {
        // .ts 系统首选是 public.mpeg-2-transport-stream（视频），
        // 但 OpenSwitch 永远应该按"源码"语义解释，必须挑 com.microsoft.typescript。
        let uti = LaunchServicesAssociationManager.resolveUTI(for: ".ts")
        XCTAssertNotNil(uti)
        XCTAssertEqual(
            uti?.identifier,
            "com.microsoft.typescript",
            "如果回到 public.mpeg-2-transport-stream，相当于改了视频流的默认 App"
        )
    }

    func testResolvesJsonToPublicJSON() {
        let uti = LaunchServicesAssociationManager.resolveUTI(for: "json")
        XCTAssertEqual(uti?.identifier, "public.json")
    }

    func testResolvesPlainTextExtensions() {
        XCTAssertEqual(LaunchServicesAssociationManager.resolveUTI(for: "txt")?.identifier, "public.plain-text")
        XCTAssertEqual(LaunchServicesAssociationManager.resolveUTI(for: ".swift")?.identifier, "public.swift-source")
        XCTAssertEqual(LaunchServicesAssociationManager.resolveUTI(for: ".js")?.identifier, "com.netscape.javascript-source")
    }

    func testReturnsNilForEmptyInput() {
        XCTAssertNil(LaunchServicesAssociationManager.resolveUTI(for: ""))
        XCTAssertNil(LaunchServicesAssociationManager.resolveUTI(for: "   "))
    }

    func testJsxFallsBackGracefully() {
        // jsx 在系统里只有动态 UTI，能给出值就行（不应崩、不应 nil）。
        let uti = LaunchServicesAssociationManager.resolveUTI(for: "jsx")
        XCTAssertNotNil(uti)
        XCTAssertTrue(uti?.preferredFilenameExtension == "jsx" || uti?.identifier.contains("jsx") == true)
    }
}
