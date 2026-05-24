# OpenSwitch 架构说明

## 1. 架构目标

- 将 UI、业务编排、系统 API 调用解耦
- 保证核心能力可以单独测试与替换
- 在不改动视图层的前提下扩展预设与回滚能力

## 2. 分层设计

### 2.1 View（SwiftUI）

- 文件：`MainView.swift`
- 职责：展示输入控件、预设列表、执行结果
- 约束：不直接调用 LaunchServices API

### 2.2 ViewModel（状态与用例编排）

- 文件：`AssociationViewModel.swift`
- 职责：
  - 管理页面状态
  - 解析扩展名输入
  - 调用服务执行设置
  - 读写预设
- 约束：通过协议依赖服务层，避免硬编码实现

### 2.3 Service（系统能力封装）

- 文件：`AssociationManager.swift`
- 协议：`FileAssociationManaging`
- 实现：`LaunchServicesAssociationManager`
- 职责：
  - 扩展名 -> 内容类型解析（UTType）
  - 调用 `LSSetDefaultRoleHandlerForContentType` 设置默认应用
  - 返回批量执行结果

### 2.4 Provider（应用发现）

- 文件：`InstalledAppsProvider.swift`
- 协议：`AppProviding`
- 实现：扫描 `/Applications` 与 `~/Applications`，读取 bundle 信息

### 2.5 Store（本地持久化）

- 文件：`PresetStore.swift`
- 协议：`PresetStoring`
- 实现：`LocalPresetStore`（JSON）
- 存储路径：`~/Library/Application Support/OpenSwitch/presets.json`

## 3. 当前数据流

1. 启动时 `AssociationViewModel` 载入已安装应用与预设。
2. 用户输入扩展名并选择应用。
3. ViewModel 调用 `FileAssociationManaging.setDefaultApp(...)`。
4. 服务层返回逐扩展名结果，ViewModel 汇总并更新状态。
5. 用户可将当前设置保存为预设，写入本地 JSON。

## 4. 后续扩展点

- 回滚机制：新增 `HistoryStore`，记录操作前映射
- 错误处理：补充 OSStatus 到可读文案的映射表
- 性能：批量设置时增加并发与进度反馈
- 测试：为 ViewModel、PresetStore 增加单元测试

## 5. 打包与分发

OpenSwitch 使用 Swift Package Manager 编译，通过 `Scripts/build.sh` 手动组装 `.app` bundle：

1. `swift build -c release` 生成可执行文件
2. `Scripts/create-icons-simple.py` 生成各尺寸 PNG
3. `iconutil` 将 PNG 编译为 `Contents/Resources/AppIcon.icns`
4. `Info.plist` 中 `CFBundleIconFile` 指向 `AppIcon`
5. `codesign` 对 bundle 做 ad-hoc 签名（含 hardened runtime 与 entitlements）

`Scripts/package.sh` 在此基础上生成 DMG，并附带 `Install OpenSwitch.command` 安装脚本，用于复制到 `/Applications` 并移除下载隔离属性（quarantine）。

> 未做 Apple 公证的 DMG 在首次打开时，macOS 可能提示「应用已损坏」。这是 Gatekeeper 对带 quarantine 标记的未公证应用的常见拦截，并非二进制损坏。执行 `xattr -cr /Applications/OpenSwitch.app` 或使用 DMG 内安装脚本即可。
