import XCTest
@testable import OpenSwitch

final class AssociationViewModelTests: XCTestCase {
    private static let cursor = AppInfo(
        id: "com.todesktop.cursor",
        bundleIdentifier: "com.todesktop.cursor",
        displayName: "Cursor",
        supportedExtensions: ["ts", "tsx", "js", "jsx"],
        bundleURL: URL(fileURLWithPath: "/Applications/Cursor.app")
    )
    private static let antigravity = AppInfo(
        id: "com.google.antigravity",
        bundleIdentifier: "com.google.antigravity",
        displayName: "Antigravity",
        supportedExtensions: ["ts", "tsx"],
        bundleURL: URL(fileURLWithPath: "/Applications/Antigravity.app")
    )

    /// 把测试 SUT（system under test）的搭建集中在一处，每个 case 各自隔离，避免共享状态。
    @MainActor
    private func makeSUT() throws -> SUT {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenSwitchVMTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tempDir)
        }
        let manager = SpyAssociationManager()
        let appProvider = StubAppProvider(apps: [Self.antigravity, Self.cursor])
        let store = LocalPresetStore(fileURL: tempDir.appendingPathComponent("presets.json"))
        let viewModel = AssociationViewModel(
            associationManager: manager,
            appProvider: appProvider,
            presetStore: store
        )
        return SUT(viewModel: viewModel, manager: manager, store: store)
    }

    private struct SUT {
        let viewModel: AssociationViewModel
        let manager: SpyAssociationManager
        let store: LocalPresetStore
    }

    // MARK: - commitExtensionsInput

    @MainActor
    func testCommitExtensionsInputAddsAndDeduplicates() throws {
        let sut = try makeSUT()
        sut.viewModel.extensionsInput = ".ts, .tsx, ts"
        sut.viewModel.commitExtensionsInput()
        XCTAssertEqual(sut.viewModel.parsedExtensions, ["ts", "tsx"])
        XCTAssertEqual(sut.viewModel.extensionsInput, "", "提交后输入框应被清空")
    }

    @MainActor
    func testCommitExtensionsInputClearsInputEvenWhenAllDuplicates() throws {
        let sut = try makeSUT()
        sut.viewModel.extensionsInput = ".ts"
        sut.viewModel.commitExtensionsInput()
        sut.viewModel.extensionsInput = "ts, .ts"
        sut.viewModel.commitExtensionsInput()
        XCTAssertEqual(sut.viewModel.parsedExtensions, ["ts"])
        XCTAssertEqual(sut.viewModel.extensionsInput, "", "全是重复项也要清空，避免视觉上像被吞没")
    }

    @MainActor
    func testRemoveExtensionDropsItemAndKeepsOrder() throws {
        let sut = try makeSUT()
        sut.viewModel.extensionsInput = "ts, tsx, js"
        sut.viewModel.commitExtensionsInput()
        sut.viewModel.removeExtension("tsx")
        XCTAssertEqual(sut.viewModel.parsedExtensions, ["ts", "js"])
    }

    // MARK: - editor 应用流程

    @MainActor
    func testConfirmApplyCurrentSelectionCallsManagerWithSelectedAppAndExtensions() throws {
        let sut = try makeSUT()
        sut.viewModel.selectedAppBundleIdentifier = Self.cursor.bundleIdentifier
        sut.viewModel.extensionsInput = ".ts,.tsx"
        sut.viewModel.requestApplyCurrentSelection()
        XCTAssertTrue(sut.viewModel.isPresentingApplyConfirmation, "校验通过后应弹出二次确认")

        sut.viewModel.confirmApplyCurrentSelection()

        XCTAssertEqual(sut.manager.calls.count, 1)
        XCTAssertEqual(sut.manager.calls.first?.bundleIdentifier, Self.cursor.bundleIdentifier)
        XCTAssertEqual(sut.manager.calls.first?.fileExtensions, ["ts", "tsx"])
    }

    @MainActor
    func testRequestApplyShortCircuitsWhenAppOrExtensionsMissing() throws {
        let sut = try makeSUT()
        sut.viewModel.selectedAppBundleIdentifier = ""
        sut.viewModel.requestApplyCurrentSelection()
        XCTAssertFalse(sut.viewModel.isPresentingApplyConfirmation)

        sut.viewModel.selectedAppBundleIdentifier = Self.cursor.bundleIdentifier
        sut.viewModel.extensionsInput = ""
        sut.viewModel.requestApplyCurrentSelection()
        XCTAssertFalse(sut.viewModel.isPresentingApplyConfirmation)
    }

    // MARK: - 预设 保存即应用 流程

    @MainActor
    func testRequestSaveCurrentPresetEditsRequiresPresetRoute() throws {
        let sut = try makeSUT()
        // 编辑器路由下不应触发预设保存确认。
        sut.viewModel.selectedAppBundleIdentifier = Self.cursor.bundleIdentifier
        sut.viewModel.extensionsInput = ".ts"
        sut.viewModel.requestSaveCurrentPresetEdits()
        XCTAssertFalse(sut.viewModel.isPresentingApplyConfirmation)
    }

    @MainActor
    func testConfirmApplyOnPresetRouteWritesSystemAndPersistsPreset() throws {
        let sut = try makeSUT()
        // 准备：先在编辑器里造一个预设。
        sut.viewModel.selectedAppBundleIdentifier = Self.antigravity.bundleIdentifier
        sut.viewModel.extensionsInput = ".ts,.tsx"
        sut.viewModel.requestSavePreset()
        sut.viewModel.presetNameInput = "前端"
        sut.viewModel.confirmSavePreset()

        guard case .preset(let presetID) = sut.viewModel.route else {
            return XCTFail("保存后应自动跳转到该预设路由")
        }

        // 在预设页里改 App 与扩展名
        sut.viewModel.selectedAppBundleIdentifier = Self.cursor.bundleIdentifier
        sut.viewModel.extensionsInput = ".jsx"
        sut.viewModel.requestSaveCurrentPresetEdits()
        XCTAssertTrue(sut.viewModel.isPresentingApplyConfirmation)

        sut.manager.reset()
        sut.viewModel.confirmApplyCurrentSelection()

        // 1) 系统层面被调用
        XCTAssertEqual(sut.manager.calls.count, 1)
        XCTAssertEqual(sut.manager.calls.first?.bundleIdentifier, Self.cursor.bundleIdentifier)
        XCTAssertEqual(sut.manager.calls.first?.fileExtensions, ["ts", "tsx", "jsx"])

        // 2) 预设 JSON 被同步更新（重新 load 验证）
        let reloaded = sut.store.loadPresets()
        XCTAssertEqual(reloaded.count, 1)
        let saved = try XCTUnwrap(reloaded.first(where: { $0.id == presetID }))
        XCTAssertEqual(saved.bundleIdentifier, Self.cursor.bundleIdentifier)
        XCTAssertEqual(saved.extensions, ["ts", "tsx", "jsx"])
        XCTAssertEqual(saved.appDisplayName, "Cursor")

        // 3) 视图态与磁盘对齐
        XCTAssertFalse(sut.viewModel.hasUnsavedPresetChanges)
        XCTAssertEqual(sut.viewModel.recentlySavedPresetID, presetID)
    }

    // MARK: - 编辑器快照（防止预设视图污染编辑器）

    @MainActor
    func testEditorStateRestoredAfterVisitingPreset() throws {
        let sut = try makeSUT()
        // 让 store 里预先存在一个预设，避免使用 confirmSavePreset 把编辑器状态污染掉。
        let preset = FileAssociationPreset(
            name: "前端",
            extensions: ["tsx"],
            bundleIdentifier: Self.antigravity.bundleIdentifier,
            appDisplayName: "Antigravity"
        )
        try sut.store.save(preset: preset)
        sut.viewModel.reloadData()

        // 用户在编辑器里写自己的草稿
        sut.viewModel.selectedAppBundleIdentifier = Self.cursor.bundleIdentifier
        sut.viewModel.extensionsInput = ".md, .json"
        sut.viewModel.commitExtensionsInput()

        // 进入预设页
        sut.viewModel.selectRoute(.preset(preset.id))
        XCTAssertEqual(sut.viewModel.parsedExtensions, ["tsx"], "进入预设页应加载预设的内容，覆盖编辑器草稿")
        XCTAssertEqual(sut.viewModel.selectedAppBundleIdentifier, Self.antigravity.bundleIdentifier)

        // 切回编辑器：必须还原到 cursor + [md, json]
        sut.viewModel.selectRoute(.editor)
        XCTAssertEqual(sut.viewModel.selectedAppBundleIdentifier, Self.cursor.bundleIdentifier, "编辑器草稿不应被预设污染")
        XCTAssertEqual(sut.viewModel.parsedExtensions, ["md", "json"])
    }

    // MARK: - hasUnsavedPresetChanges

    @MainActor
    func testHasUnsavedPresetChangesReflectsBothAppAndExtensions() throws {
        let sut = try makeSUT()
        sut.viewModel.selectedAppBundleIdentifier = Self.antigravity.bundleIdentifier
        sut.viewModel.extensionsInput = ".ts"
        sut.viewModel.requestSavePreset()
        sut.viewModel.presetNameInput = "A"
        sut.viewModel.confirmSavePreset()

        XCTAssertFalse(sut.viewModel.hasUnsavedPresetChanges, "刚保存完，编辑态与磁盘一致")

        sut.viewModel.selectedAppBundleIdentifier = Self.cursor.bundleIdentifier
        XCTAssertTrue(sut.viewModel.hasUnsavedPresetChanges, "改 App 应产生未保存差异")

        sut.viewModel.selectedAppBundleIdentifier = Self.antigravity.bundleIdentifier
        XCTAssertFalse(sut.viewModel.hasUnsavedPresetChanges)

        sut.viewModel.extensionsInput = ".tsx"
        sut.viewModel.commitExtensionsInput()
        XCTAssertTrue(sut.viewModel.hasUnsavedPresetChanges, "加扩展名应产生未保存差异")
    }
}

// MARK: - test doubles

private final class SpyAssociationManager: FileAssociationManaging, @unchecked Sendable {
    struct Call {
        let bundleIdentifier: String
        let fileExtensions: [String]
    }

    var calls: [Call] = []

    func reset() { calls.removeAll() }

    func defaultAppBundleIdentifier(for fileExtension: String) -> String? { nil }

    func setDefaultApp(bundleIdentifier: String, for fileExtensions: [String]) -> [AssociationChangeResult] {
        calls.append(Call(bundleIdentifier: bundleIdentifier, fileExtensions: fileExtensions))
        return fileExtensions.map {
            AssociationChangeResult(fileExtension: $0, success: true, message: "ok")
        }
    }
}

private struct StubAppProvider: AppProviding {
    let apps: [AppInfo]
    func fetchApps() -> [AppInfo] { apps }
}
