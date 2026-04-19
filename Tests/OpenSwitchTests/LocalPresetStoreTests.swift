import XCTest
@testable import OpenSwitch

final class LocalPresetStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: LocalPresetStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenSwitchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = LocalPresetStore(fileURL: tempDir.appendingPathComponent("presets.json"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        store = nil
        tempDir = nil
        try super.tearDownWithError()
    }

    func testLoadFromMissingFileReturnsEmpty() {
        XCTAssertTrue(store.loadPresets().isEmpty)
    }

    func testSaveThenLoadRoundTrip() throws {
        let preset = makePreset(name: "前端", extensions: ["js", "ts", "tsx"])
        try store.save(preset: preset)

        let loaded = store.loadPresets()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first, preset, "Preset 应当原样还原（含 id、扩展名、bundleID）")
    }

    func testSaveSameIdReplacesInsteadOfAppending() throws {
        let id = UUID()
        let original = makePreset(id: id, name: "前端", extensions: ["ts"])
        let updated = makePreset(id: id, name: "前端", extensions: ["ts", "tsx"], bundleIdentifier: "com.different.app")

        try store.save(preset: original)
        try store.save(preset: updated)

        let loaded = store.loadPresets()
        XCTAssertEqual(loaded.count, 1, "相同 id 应覆盖而非追加")
        XCTAssertEqual(loaded.first?.extensions, ["ts", "tsx"])
        XCTAssertEqual(loaded.first?.bundleIdentifier, "com.different.app")
    }

    func testDeleteRemovesOnlyMatchingPreset() throws {
        let a = makePreset(name: "A", extensions: ["a"])
        let b = makePreset(name: "B", extensions: ["b"])
        try store.save(preset: a)
        try store.save(preset: b)

        try store.delete(presetID: a.id)

        let loaded = store.loadPresets()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, b.id)
    }

    func testLoadSortsByCreatedAtAscending() throws {
        let older = makePreset(name: "older", extensions: ["a"], createdAt: Date(timeIntervalSince1970: 1000))
        let newer = makePreset(name: "newer", extensions: ["b"], createdAt: Date(timeIntervalSince1970: 9000))

        try store.save(preset: newer)
        try store.save(preset: older)

        let loaded = store.loadPresets()
        XCTAssertEqual(loaded.map(\.name), ["older", "newer"])
    }

    func testSaveCreatesParentDirectoryIfNeeded() throws {
        let nested = tempDir.appendingPathComponent("a/b/c/presets.json")
        let nestedStore = LocalPresetStore(fileURL: nested)
        try nestedStore.save(preset: makePreset(name: "x", extensions: ["x"]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }

    // MARK: - helpers

    private func makePreset(
        id: UUID = UUID(),
        name: String,
        extensions: [String],
        bundleIdentifier: String = "com.example.app",
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> FileAssociationPreset {
        FileAssociationPreset(
            id: id,
            name: name,
            extensions: extensions,
            bundleIdentifier: bundleIdentifier,
            appDisplayName: "Example",
            createdAt: createdAt
        )
    }
}
