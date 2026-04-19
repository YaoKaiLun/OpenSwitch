import SwiftUI
import AppKit

struct MainView: View {
    @ObservedObject var viewModel: AssociationViewModel

    var body: some View {
        GeometryReader { proxy in
            let metrics = LayoutMetrics(containerWidth: proxy.size.width)
            HStack(spacing: 0) {
                sidebar
                    .frame(width: metrics.sidebarWidth)
                Divider()
                content(metrics: metrics)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(UITheme.pageBackground)
        }
        .alert(applyConfirmationTitle, isPresented: $viewModel.isPresentingApplyConfirmation) {
            Button("取消", role: .cancel) { }
            Button(applyConfirmationCTA, role: .destructive) {
                viewModel.confirmApplyCurrentSelection()
            }
        } message: {
            Text(applyConfirmationMessage)
        }
        .sheet(isPresented: $viewModel.isPresentingPresetSheet) {
            PresetNameSheet(viewModel: viewModel)
        }
    }

    // MARK: - Apply confirmation copy

    private var isOnPresetRoute: Bool {
        if case .preset = viewModel.route { return true }
        return false
    }

    private var applyConfirmationTitle: String {
        isOnPresetRoute ? "保存预设并应用到系统？" : "确认修改文件默认打开方式？"
    }

    private var applyConfirmationCTA: String {
        isOnPresetRoute ? "保存并应用" : "确认修改"
    }

    private var applyConfirmationMessage: String {
        let exts = viewModel.parsedExtensions.map { ".\($0)" }.joined(separator: ", ")
        let prefix = isOnPresetRoute ? "将把这条预设保存到本地，并立刻把以下扩展名的默认打开方式改为" : "将把以下扩展名的默认打开方式改为"
        return "\(prefix)「\(viewModel.selectedAppName)」，会对系统中所有此类文件全局生效：\n\n\(exts)"
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("OpenSwitch")
                .font(Typography.logo)
                .padding(.top, 12)

            sidebarItem(
                title: "编辑文件",
                icon: "gearshape.fill",
                isActive: viewModel.route == .editor
            ) {
                viewModel.selectRoute(.editor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 11, weight: .medium))
                    Text("自定义预设")
                        .font(Typography.sectionTag)
                    Spacer()
                    Text("\(viewModel.presets.count)")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 6)

                if viewModel.presets.isEmpty {
                    Text("暂无预设，点击下方「新建预设」保存当前组合")
                        .font(Typography.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 2) {
                        ForEach(viewModel.presets) { preset in
                            presetSidebarRow(preset)
                                // 用 preset 整体做 id，preset 任何字段变化都会强制重建该行，
                                // 避免 SwiftUI 仅按 UUID 复用导致 icon/名称视觉上"没更新"。
                                .id(preset)
                        }
                    }
                }
            }

            Spacer()

            Button {
                viewModel.requestSavePreset()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("新建预设")
                        .font(Typography.body)
                }
                .frame(maxWidth: .infinity, minHeight: 34)
                .foregroundStyle(UITheme.brandBlue)
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftActionButtonStyle())
            .pointerCursor()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(UITheme.sidebarBackground)
    }

    private func sidebarItem(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(Typography.body)
                Spacer()
            }
            .foregroundStyle(isActive ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarRowButtonStyle(isActive: isActive))
        .pointerCursor()
    }

    private func presetSidebarRow(_ preset: FileAssociationPreset) -> some View {
        let isActive: Bool = {
            if case .preset(let id) = viewModel.route { return id == preset.id }
            return false
        }()
        let justSaved = viewModel.recentlySavedPresetID == preset.id
        return Button {
            viewModel.selectRoute(.preset(preset.id))
        } label: {
            HStack(spacing: 10) {
                AppIconView(bundleURL: bundleURL(for: preset.bundleIdentifier), size: 18)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(preset.name)
                            .font(Typography.body)
                            .lineLimit(1)
                        if justSaved {
                            Text("已更新")
                                .font(Typography.micro)
                                .foregroundStyle(UITheme.successGreen)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(UITheme.successGreen.opacity(0.15)))
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    Text("\(preset.appDisplayName) · \(preset.extensions.count) 项")
                        .font(Typography.micro)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarRowButtonStyle(isActive: isActive))
        .pointerCursor()
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(UITheme.successGreen, lineWidth: justSaved ? 1.5 : 0)
                .animation(.easeOut(duration: 0.25), value: justSaved)
        )
        .animation(.easeOut(duration: 0.2), value: justSaved)
        .contextMenu {
            Button("打开预设") { viewModel.selectRoute(.preset(preset.id)) }
            Divider()
            Button("删除预设", role: .destructive) { viewModel.deletePreset(preset) }
        }
    }

    private func bundleURL(for bundleIdentifier: String) -> URL? {
        viewModel.apps.first(where: { $0.bundleIdentifier == bundleIdentifier })?.bundleURL
    }

    // MARK: - Content router

    private func content(metrics: LayoutMetrics) -> some View {
        Group {
            switch viewModel.route {
            case .editor:
                editorContent(metrics: metrics)
            case .preset(let id):
                if let preset = viewModel.presets.first(where: { $0.id == id }) {
                    presetDetailContent(preset, metrics: metrics)
                } else {
                    editorContent(metrics: metrics)
                }
            }
        }
    }

    // MARK: - Editor (default)

    private func editorContent(metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("修改文件打开方式")
                    .font(Typography.pageTitle)
                Text("选择文件扩展名与目标应用，确认后将立即生效。")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 18)

            HStack(alignment: .top, spacing: 22) {
                extensionCard
                    .frame(width: metrics.leftCardWidth)
                targetAppCard
                    .frame(width: metrics.rightCardWidth)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack(spacing: 12) {
                Text(viewModel.statusMessage)
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Button("设为预设") { viewModel.requestSavePreset() }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .pointerCursor()
                Button("确认修改") { viewModel.requestApplyCurrentSelection() }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .pointerCursor()
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Extension card

    private var extensionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("文件扩展名", systemImage: "curlybraces")
                .font(Typography.cardTitle)

            HStack(spacing: 10) {
                TextField("输入扩展名，逗号分隔（例：.js,.ts,.json）",
                          text: $viewModel.extensionsInput)
                    .textFieldStyle(.plain)
                    .font(Typography.bodyRegular)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(UITheme.softBorder, lineWidth: 1)
                            )
                    )
                    .onSubmit { viewModel.commitExtensionsInput() }

                Button {
                    viewModel.commitExtensionsInput()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(IconActionButtonStyle(enabled: canCommitInput))
                .disabled(!canCommitInput)
                .pointerCursor(enabled: canCommitInput)
            }

            if viewModel.parsedExtensions.isEmpty {
                Text("尚未添加任何扩展名")
                    .font(Typography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.parsedExtensions, id: \.self) { ext in
                        extensionChip(ext)
                    }
                }
            }

            HStack(spacing: 8) {
                Text("已选择 \(viewModel.parsedExtensions.count) 项")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(UITheme.selectedRowFill))

                Text("回车或点击 + 添加")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .cardStyle()
    }

    private var canCommitInput: Bool {
        !ExtensionParser.parse(viewModel.extensionsInput).isEmpty
    }

    private func extensionChip(_ ext: String) -> some View {
        HStack(spacing: 2) {
            Text(".\(ext)")
                .font(Typography.secondaryStrong)
                .foregroundStyle(UITheme.brandBlue)
                .padding(.leading, 12)
                .padding(.vertical, 5)

            Button {
                viewModel.removeExtension(ext)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(UITheme.brandBlue.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .help("移除 .\(ext)")
        }
        .padding(.trailing, 2)
        .background(
            Capsule()
                .fill(UITheme.brandBlue.opacity(0.10))
                .overlay(
                    Capsule().stroke(UITheme.brandBlue.opacity(0.22), lineWidth: 1)
                )
        )
    }

    // MARK: - Target app card

    private var targetAppCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("目标应用", systemImage: "square.grid.2x2")
                .font(Typography.cardTitle)

            VStack(spacing: 10) {
                AppIconView(bundleURL: viewModel.selectedApp?.bundleURL, size: 56)
                Text(viewModel.selectedAppName)
                    .font(Typography.appName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(viewModel.recommendedSummary)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("更改应用程序")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("共 \(viewModel.apps.count) 个可选")
                        .font(Typography.micro)
                        .foregroundStyle(.tertiary)
                }
                AppPickerMenu(viewModel: viewModel)
            }
        }
        .cardStyle()
    }

    // MARK: - Preset detail

    private func presetDetailContent(_ preset: FileAssociationPreset, metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(preset.name)
                        .font(Typography.pageTitle)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if viewModel.hasUnsavedPresetChanges {
                        Text("有未保存修改")
                            .font(Typography.micro)
                            .foregroundStyle(UITheme.brandBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(UITheme.brandBlue.opacity(0.12)))
                    } else if viewModel.recentlySavedPresetID == preset.id {
                        Label("已更新", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(Typography.micro)
                            .foregroundStyle(UITheme.successGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(UITheme.successGreen.opacity(0.15)))
                            .transition(.opacity.combined(with: .scale))
                    }
                    Spacer()
                }
                .animation(.easeOut(duration: 0.2), value: viewModel.recentlySavedPresetID)
                .animation(.easeOut(duration: 0.2), value: viewModel.hasUnsavedPresetChanges)
                Text("修改后点击「保存修改」会同时写入预设并立即应用到系统。")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 18)

            HStack(alignment: .top, spacing: 22) {
                extensionCard
                    .frame(width: metrics.leftCardWidth)
                targetAppCard
                    .frame(width: metrics.rightCardWidth)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack(spacing: 12) {
                Text(viewModel.statusMessage)
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Button("删除预设") { viewModel.deletePreset(preset) }
                    .buttonStyle(DestructiveActionButtonStyle())
                    .pointerCursor()
                Button("保存修改") { viewModel.requestSaveCurrentPresetEdits() }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .pointerCursor(enabled: viewModel.hasUnsavedPresetChanges)
                    .disabled(!viewModel.hasUnsavedPresetChanges)
                    .opacity(viewModel.hasUnsavedPresetChanges ? 1 : 0.5)
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 36)
    }
}

// MARK: - Preset name sheet

private struct PresetNameSheet: View {
    @ObservedObject var viewModel: AssociationViewModel
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("保存预设")
                    .font(Typography.dialogTitle)
                Text("将当前应用与扩展名组合保存，便于一键切换。")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(UITheme.cardBackground)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("预设名称")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    TextField("例如：前端开发、Markdown 写作", text: $viewModel.presetNameInput)
                        .textFieldStyle(.plain)
                        .font(Typography.bodyRegular)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(UITheme.softBorder, lineWidth: 1)
                                )
                        )
                        .focused($nameFocused)
                        .onSubmit { viewModel.confirmSavePreset() }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        AppIconView(bundleURL: viewModel.selectedApp?.bundleURL, size: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(viewModel.selectedAppName)
                                .font(Typography.body)
                            Text("目标应用")
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("扩展名（\(viewModel.parsedExtensions.count) 项）")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(viewModel.parsedExtensions, id: \.self) { ext in
                                Text(".\(ext)")
                                    .font(Typography.caption)
                                    .foregroundStyle(UITheme.brandBlue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(UITheme.brandBlue.opacity(0.10))
                                    )
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(UITheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(UITheme.softBorder, lineWidth: 1)
                        )
                )
            }
            .padding(20)

            Divider()

            HStack(spacing: 10) {
                Spacer()
                Button("取消") { viewModel.cancelSavePreset() }
                    .buttonStyle(SecondaryActionButtonStyle(minWidth: 76, height: 30))
                    .pointerCursor()
                    .keyboardShortcut(.cancelAction)
                Button("保存") { viewModel.confirmSavePreset() }
                    .buttonStyle(PrimaryActionButtonStyle(minWidth: 76, height: 30))
                    .pointerCursor()
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(UITheme.cardBackground)
        }
        .frame(width: 420)
        .background(UITheme.pageBackground)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                nameFocused = true
            }
        }
    }
}

// MARK: - App picker menu

private struct AppPickerMenu: View {
    @ObservedObject var viewModel: AssociationViewModel
    @State private var isHovering = false

    var body: some View {
        Menu {
            ForEach(viewModel.apps) { app in
                Button {
                    viewModel.selectedAppBundleIdentifier = app.bundleIdentifier
                } label: {
                    HStack {
                        Text(app.displayName)
                        if app.bundleIdentifier == viewModel.selectedAppBundleIdentifier {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: 10) {
                    AppIconView(bundleURL: viewModel.selectedApp?.bundleURL, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(viewModel.selectedAppName)
                            .font(Typography.bodyStrong)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("当前应用")
                            .font(Typography.micro)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                }
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .padding(.vertical, 7)

                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isHovering ? UITheme.brandBlue : UITheme.brandBlue.opacity(0.12))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isHovering ? Color.white : UITheme.brandBlue)
                }
                .frame(width: 32, height: 28)
                .padding(.trailing, 6)
                .animation(.easeOut(duration: 0.12), value: isHovering)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isHovering ? UITheme.brandBlue.opacity(0.55) : UITheme.softBorder,
                                    lineWidth: 1)
                    )
                    .shadow(color: UITheme.brandBlue.opacity(isHovering ? 0.12 : 0),
                            radius: isHovering ? 6 : 0, x: 0, y: 2)
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: isHovering)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { isHovering = $0 }
        .pointerCursor()
    }
}

// MARK: - App icon

private struct AppIconView: View {
    let bundleURL: URL?
    let size: CGFloat

    var body: some View {
        Group {
            if let url = bundleURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(size * 0.15)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Layout

private struct LayoutMetrics {
    let sidebarWidth: CGFloat
    let leftCardWidth: CGFloat
    let rightCardWidth: CGFloat

    init(containerWidth: CGFloat) {
        sidebarWidth = 232
        let available = max(containerWidth - sidebarWidth - 60, 740)
        let rawLeft = available * 0.58
        let rawRight = available * 0.36
        leftCardWidth = min(max(rawLeft, 360), 480)
        rightCardWidth = min(max(rawRight, 300), 380)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth - spacing)
        return CGSize(width: min(maxRowWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Style helpers

private extension View {
    func cardStyle() -> some View {
        self
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(UITheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(UITheme.softBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 2)
            )
    }

    func pointerCursor(enabled: Bool = true) -> some View {
        self.modifier(PointerCursorModifier(enabled: enabled))
    }
}

private struct PointerCursorModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering, enabled {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Typography

/// 全局字号体系。所有 UI 字体应通过此处常量获取，禁止散落硬编码字号。
enum Typography {
    /// 侧栏顶部品牌名
    static let logo: Font = .system(size: 20, weight: .bold)
    /// 主内容区一级标题
    static let pageTitle: Font = .system(size: 24, weight: .bold)
    /// 弹窗标题
    static let dialogTitle: Font = .system(size: 16, weight: .semibold)
    /// 卡片标题（如「文件扩展名」「目标应用」）
    static let cardTitle: Font = .system(size: 14, weight: .semibold)
    /// 大号应用名（卡片中心展示）
    static let appName: Font = .system(size: 18, weight: .semibold)
    /// 主体加粗（如选择器中的当前应用名）
    static let bodyStrong: Font = .system(size: 13, weight: .semibold)
    /// 主体（按钮文字、菜单项、可点击标题）
    static let body: Font = .system(size: 13, weight: .medium)
    /// 主体常规（输入框文字、正文段落）
    static let bodyRegular: Font = .system(size: 13)
    /// 次要正文（提示、状态、辅助说明）
    static let secondary: Font = .system(size: 12)
    /// 次要正文加粗（chip 标签等需略微强调的小尺寸文字）
    static let secondaryStrong: Font = .system(size: 12, weight: .medium)
    /// 分组小标题（侧栏分组名）
    static let sectionTag: Font = .system(size: 11, weight: .semibold)
    /// 标注（统计、单位、表单字段标签）
    static let caption: Font = .system(size: 11)
    /// 极小辅助（页脚、附属说明、计数）
    static let micro: Font = .system(size: 10)
}

private enum UITheme {
    static let pageBackground = Color(nsColor: NSColor(calibratedRed: 0.965, green: 0.969, blue: 0.977, alpha: 1))
    static let sidebarBackground = Color(nsColor: NSColor(calibratedRed: 0.949, green: 0.953, blue: 0.960, alpha: 1))
    static let cardBackground = Color(nsColor: NSColor(calibratedRed: 0.973, green: 0.976, blue: 0.982, alpha: 1))
    static let selectedRowFill = Color(nsColor: NSColor(calibratedRed: 0.871, green: 0.918, blue: 0.996, alpha: 1))
    static let softBorder = Color(nsColor: NSColor(calibratedRed: 0.882, green: 0.902, blue: 0.933, alpha: 1))
    static let brandBlue = Color(nsColor: NSColor(calibratedRed: 0.090, green: 0.506, blue: 0.992, alpha: 1))
    static let danger = Color(nsColor: NSColor(calibratedRed: 0.890, green: 0.302, blue: 0.318, alpha: 1))
    static let successGreen = Color(nsColor: NSColor(calibratedRed: 0.196, green: 0.667, blue: 0.380, alpha: 1))
}

// MARK: - Button styles

private struct PrimaryActionButtonStyle: ButtonStyle {
    var minWidth: CGFloat = 96
    var height: CGFloat = 34
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let baseColor = UITheme.brandBlue
        let bg: Color = configuration.isPressed
            ? baseColor.opacity(0.85)
            : (isHovering ? baseColor.opacity(0.92) : baseColor)
        return configuration.label
            .font(Typography.body)
            .foregroundStyle(.white)
            .frame(minWidth: minWidth, minHeight: height)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(bg)
                    .shadow(color: baseColor.opacity(isHovering ? 0.22 : 0.0),
                            radius: isHovering ? 6 : 0, x: 0, y: 2)
            )
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    var minWidth: CGFloat = 84
    var height: CGFloat = 34
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let bg: Color = configuration.isPressed
            ? Color.white.opacity(0.7)
            : (isHovering ? UITheme.selectedRowFill.opacity(0.55) : Color.white)
        return configuration.label
            .font(Typography.body)
            .foregroundStyle(Color.primary)
            .frame(minWidth: minWidth, minHeight: height)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(isHovering ? UITheme.brandBlue.opacity(0.45) : UITheme.softBorder,
                                    lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct DestructiveActionButtonStyle: ButtonStyle {
    var minWidth: CGFloat = 84
    var height: CGFloat = 34
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let danger = UITheme.danger
        let isActive = isHovering || configuration.isPressed
        return configuration.label
            .font(Typography.body)
            .foregroundStyle(isActive ? Color.white : danger)
            .frame(minWidth: minWidth, minHeight: height)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isActive ? danger.opacity(configuration.isPressed ? 0.85 : 0.95) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(danger.opacity(0.45), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct SoftActionButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let base = UITheme.brandBlue
        let fill: Color = configuration.isPressed
            ? base.opacity(0.18)
            : (isHovering ? base.opacity(0.16) : base.opacity(0.10))
        return configuration.label
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(base.opacity(isHovering ? 0.32 : 0.18), lineWidth: 1)
                    )
            )
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct IconActionButtonStyle: ButtonStyle {
    let enabled: Bool
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let base = UITheme.brandBlue
        let fill: Color = !enabled
            ? base.opacity(0.30)
            : (configuration.isPressed ? base.opacity(0.85)
                : (isHovering ? base.opacity(0.92) : base))
        return configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill)
            )
            .onHover { if enabled { isHovering = $0 } }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct SidebarRowButtonStyle: ButtonStyle {
    let isActive: Bool
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color
        if isActive {
            fill = UITheme.selectedRowFill
        } else if configuration.isPressed {
            fill = UITheme.selectedRowFill.opacity(0.55)
        } else if isHovering {
            fill = Color.black.opacity(0.045)
        } else {
            fill = .clear
        }
        return configuration.label
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(fill)
            )
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.10), value: isHovering)
    }
}
