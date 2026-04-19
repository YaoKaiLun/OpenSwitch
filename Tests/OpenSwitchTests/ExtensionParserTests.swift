import XCTest
@testable import OpenSwitch

final class ExtensionParserTests: XCTestCase {
    func testParsesCommaSeparatedExtensions() {
        XCTAssertEqual(ExtensionParser.parse(".js,.ts,.tsx"), ["js", "ts", "tsx"])
    }

    func testStripsLeadingDotsAndWhitespace() {
        XCTAssertEqual(ExtensionParser.parse("  .JS , ts , .TSX "), ["js", "ts", "tsx"])
    }

    func testLowercasesAndDeduplicates() {
        XCTAssertEqual(ExtensionParser.parse("JSX, jsx, .JsX, tsx"), ["jsx", "tsx"])
    }

    func testFiltersOutEmptyTokens() {
        XCTAssertEqual(ExtensionParser.parse(",, .,, ts, ,,"), ["ts"])
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertTrue(ExtensionParser.parse("").isEmpty)
        XCTAssertTrue(ExtensionParser.parse("   ,, ").isEmpty)
    }

    func testPreservesFirstSeenOrder() {
        // 先出现的保留位置，重复项被丢弃，避免抖动用户视图。
        XCTAssertEqual(ExtensionParser.parse("ts, js, ts, tsx, js"), ["ts", "js", "tsx"])
    }
}
