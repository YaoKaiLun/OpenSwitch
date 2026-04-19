import Foundation

enum AppRoute: Equatable {
    case editor
    case preset(UUID)
}

@MainActor
final class AssociationViewModel: ObservableObject {
    @Published var extensionsInput = ""
    @Published var presetNameInput = ""
    @Published var selectedAppBundleIdentifier = ""
    @Published private(set) var selectedExtensions: [String] = []
    @Published private(set) var apps: [AppInfo] = []
    @Published private(set) var presets: [FileAssociationPreset] = []
    @Published private(set) var results: [AssociationChangeResult] = []
    @Published private(set) var statusMessage = "准备就绪"
    @Published var route: AppRoute = .editor

    @Published var isPresentingApplyConfirmation = false
    @Published var isPresentingPresetSheet = false
    /// 刚刚保存成功的预设 id，用于在 UI 上做一次短暂的高亮反馈。
    @Published private(set) var recentlySavedPresetID: UUID?

    var selectedApp: AppInfo? {
        apps.first(where: { $0.bundleIdentifier == selectedAppBundleIdentifier })
    }

    func currentPreset() -> FileAssociationPreset? {
        if case .preset(let id) = route {
            return presets.first(where: { $0.id == id })
        }
        return nil
    }

    /// 编辑器视图离开时的状态快照，避免被预设视图编辑污染。
    private struct EditorSnapshot {
        var appBundleIdentifier: String
        var extensions: [String]
        var extensionsInput: String
    }

    private var editorSnapshot: EditorSnapshot?

    func selectRoute(_ newRoute: AppRoute) {
        guard newRoute != route else { return }

        // 离开编辑器：先把编辑器当前状态快照，避免预设视图把它改坏。
        if route == .editor {
            editorSnapshot = EditorSnapshot(
                appBundleIdentifier: selectedAppBundleIdentifier,
                extensions: selectedExtensions,
                extensionsInput: extensionsInput
            )
        }

        route = newRoute

        switch newRoute {
        case .editor:
            // 回到编辑器：还原之前的编辑器草稿（如果有）。
            if let snap = editorSnapshot {
                selectedAppBundleIdentifier = snap.appBundleIdentifier
                selectedExtensions = snap.extensions
                extensionsInput = snap.extensionsInput
                editorSnapshot = nil
            }
        case .preset(let id):
            // 进入预设：始终从持久化数据加载，未保存的预设编辑不跨切换保留。
            if let preset = presets.first(where: { $0.id == id }) {
                selectedAppBundleIdentifier = preset.bundleIdentifier
                selectedExtensions = preset.extensions
                extensionsInput = ""
            }
        }
    }

    /// 当前预设视图下，编辑结果与已存预设是否存在差异。
    var hasUnsavedPresetChanges: Bool {
        guard case .preset(let id) = route,
              let preset = presets.first(where: { $0.id == id }) else { return false }
        return preset.bundleIdentifier != selectedAppBundleIdentifier
            || preset.extensions != selectedExtensions
    }

    private let associationManager: FileAssociationManaging
    private let appProvider: AppProviding
    private let presetStore: PresetStoring

    private let recommendedDisplayLimit = 6

    init(
        associationManager: FileAssociationManaging,
        appProvider: AppProviding,
        presetStore: PresetStoring
    ) {
        self.associationManager = associationManager
        self.appProvider = appProvider
        self.presetStore = presetStore
        reloadData()
    }

    /// 用于触发计算与持久化的扩展名集合。沿用旧名以保持调用点稳定。
    var parsedExtensions: [String] {
        selectedExtensions
    }

    var selectedAppName: String {
        apps.first(where: { $0.bundleIdentifier == selectedAppBundleIdentifier })?.displayName ?? "未选择"
    }

    /// 当前目标应用真实声明可处理的扩展名（来自 Info.plist）。
    var recommendedExtensions: [String] {
        apps.first(where: { $0.bundleIdentifier == selectedAppBundleIdentifier })?.supportedExtensions ?? []
    }

    /// 用于 UI 卡片展示的简短推荐文案。
    var recommendedSummary: String {
        let exts = recommendedExtensions
        if exts.isEmpty { return "未声明可处理的文件类型" }
        let head = exts.prefix(recommendedDisplayLimit).map { ".\($0)" }.joined(separator: ", ")
        if exts.count > recommendedDisplayLimit {
            return "推荐用于 \(head) 等 \(exts.count) 种类型"
        }
        return "推荐用于 \(head)"
    }

    func reloadData() {
        apps = appProvider.fetchApps()
        presets = presetStore.loadPresets()
        if selectedAppBundleIdentifier.isEmpty, let first = apps.first {
            selectedAppBundleIdentifier = first.bundleIdentifier
        }
    }

    /// 把当前输入框中的内容解析、去重后追加进已选扩展名集合，并清空输入。
    func commitExtensionsInput() {
        let trimmed = extensionsInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let parsed = ExtensionParser.parse(extensionsInput)
        // 即便解析出 0 项或全是重复项，也清空输入框，避免脏输入残留误导用户。
        defer { extensionsInput = "" }
        guard !parsed.isEmpty else { return }
        var merged = selectedExtensions
        for ext in parsed where !merged.contains(ext) {
            merged.append(ext)
        }
        if merged != selectedExtensions {
            selectedExtensions = merged
        }
    }

    func removeExtension(_ ext: String) {
        selectedExtensions.removeAll { $0 == ext }
    }

    /// 用户点击「确认修改」时调用：先做前置校验再弹出二次确认。
    func requestApplyCurrentSelection() {
        commitExtensionsInput()
        guard !selectedAppBundleIdentifier.isEmpty else {
            statusMessage = "请先选择目标应用"
            return
        }
        guard !parsedExtensions.isEmpty else {
            statusMessage = "请至少添加一个扩展名"
            return
        }
        isPresentingApplyConfirmation = true
    }

    /// 二次确认通过后真正执行 LaunchServices 写入。
    /// - 在编辑器路由：仅写系统。
    /// - 在预设路由：先把编辑结果写回预设 JSON，再写系统，并触发 UI 高亮。
    func confirmApplyCurrentSelection() {
        guard !selectedAppBundleIdentifier.isEmpty, !parsedExtensions.isEmpty else { return }
        results = associationManager.setDefaultApp(
            bundleIdentifier: selectedAppBundleIdentifier,
            for: parsedExtensions
        )
        let successCount = results.filter(\.success).count
        let summary = "\(successCount)/\(results.count) 个扩展名设置成功"

        if case .preset(let id) = route,
           let original = presets.first(where: { $0.id == id }) {
            let updated = FileAssociationPreset(
                id: original.id,
                name: original.name,
                extensions: parsedExtensions,
                bundleIdentifier: selectedAppBundleIdentifier,
                appDisplayName: selectedAppName,
                createdAt: original.createdAt
            )
            do {
                try presetStore.save(preset: updated)
                presets = presetStore.loadPresets()
                if let saved = presets.first(where: { $0.id == updated.id }) {
                    selectedAppBundleIdentifier = saved.bundleIdentifier
                    selectedExtensions = saved.extensions
                    extensionsInput = ""
                }
                statusMessage = "✓ 已更新预设「\(updated.name)」并应用：\(summary)"
                flashRecentlySaved(presetID: updated.id)
            } catch {
                statusMessage = "已写入系统但保存预设失败：\(error.localizedDescription)"
            }
        } else {
            statusMessage = "完成：\(summary)"
        }
    }

    /// 用户点击「设为预设」时调用：校验后弹出命名表单。
    func requestSavePreset() {
        commitExtensionsInput()
        guard !selectedAppBundleIdentifier.isEmpty else {
            statusMessage = "请先选择目标应用"
            return
        }
        guard !parsedExtensions.isEmpty else {
            statusMessage = "请至少添加一个扩展名"
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        presetNameInput = "\(selectedAppName) \(formatter.string(from: Date()))"
        isPresentingPresetSheet = true
    }

    /// 在命名表单中点击保存。
    func confirmSavePreset() {
        let trimmed = presetNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "预设名称不能为空"
            return
        }
        guard !selectedAppBundleIdentifier.isEmpty, !parsedExtensions.isEmpty else {
            statusMessage = "请先选择应用并添加扩展名"
            return
        }
        let preset = FileAssociationPreset(
            name: trimmed,
            extensions: parsedExtensions,
            bundleIdentifier: selectedAppBundleIdentifier,
            appDisplayName: selectedAppName
        )
        do {
            try presetStore.save(preset: preset)
            presets = presetStore.loadPresets()
            statusMessage = "已保存预设「\(preset.name)」"
            presetNameInput = ""
            isPresentingPresetSheet = false
            // 走 selectRoute 以触发编辑器快照保护，回到编辑器时仍能看到原草稿。
            selectRoute(.preset(preset.id))
        } catch {
            statusMessage = "保存预设失败：\(error.localizedDescription)"
        }
    }

    func cancelSavePreset() {
        isPresentingPresetSheet = false
        presetNameInput = ""
    }

    /// 用户在预设详情页点击「保存修改」：和编辑器的「确认修改」共用同一条二次确认链路。
    /// 因为修改预设的语义就是"我希望这套关联立刻生效"，只写 JSON 不写系统会让用户觉得没生效。
    func requestSaveCurrentPresetEdits() {
        commitExtensionsInput()
        guard case .preset = route else { return }
        guard !selectedAppBundleIdentifier.isEmpty else {
            statusMessage = "请先选择目标应用"
            return
        }
        guard !parsedExtensions.isEmpty else {
            statusMessage = "请至少保留一个扩展名"
            return
        }
        isPresentingApplyConfirmation = true
    }

    /// 给指定预设亮一次"刚保存"的高亮，几秒后自动熄灭。
    private func flashRecentlySaved(presetID: UUID) {
        recentlySavedPresetID = presetID
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self else { return }
            if self.recentlySavedPresetID == presetID {
                self.recentlySavedPresetID = nil
            }
        }
    }

    func deletePreset(_ preset: FileAssociationPreset) {
        do {
            try presetStore.delete(presetID: preset.id)
            presets = presetStore.loadPresets()
            statusMessage = "已删除预设「\(preset.name)」"
            // 删除的是当前正在查看的预设：跳回编辑器并还原原编辑草稿。
            if case .preset(let id) = route, id == preset.id {
                selectRoute(.editor)
            }
        } catch {
            statusMessage = "删除预设失败：\(error.localizedDescription)"
        }
    }
}
