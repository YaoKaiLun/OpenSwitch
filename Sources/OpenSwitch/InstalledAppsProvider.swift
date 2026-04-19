import Foundation
import UniformTypeIdentifiers

protocol AppProviding {
    func fetchApps() -> [AppInfo]
}

struct InstalledAppsProvider: AppProviding {
    func fetchApps() -> [AppInfo] {
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]

        var apps: [AppInfo] = []
        var seen = Set<String>()

        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            if let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                    guard
                        let bundle = Bundle(url: url),
                        let bundleIdentifier = bundle.bundleIdentifier,
                        !seen.contains(bundleIdentifier)
                    else {
                        continue
                    }

                    let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? url.deletingPathExtension().lastPathComponent

                    apps.append(
                        AppInfo(
                            id: bundleIdentifier,
                            bundleIdentifier: bundleIdentifier,
                            displayName: displayName,
                            supportedExtensions: Self.extractSupportedExtensions(from: bundle),
                            bundleURL: url
                        )
                    )
                    seen.insert(bundleIdentifier)
                }
            }
        }

        return apps.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    /// 从应用 Info.plist 中提取可处理的文件扩展名。
    /// 优先读取 CFBundleDocumentTypes.CFBundleTypeExtensions，
    /// 如未提供再回退到 LSItemContentTypes 经 UTType 转换的偏好扩展名。
    private static func extractSupportedExtensions(from bundle: Bundle) -> [String] {
        guard let docTypes = bundle.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]] else {
            return []
        }
        var collected: [String] = []
        var seen = Set<String>()

        func append(_ raw: String) {
            let normalized = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .lowercased()
            guard !normalized.isEmpty, normalized != "*", !seen.contains(normalized) else { return }
            seen.insert(normalized)
            collected.append(normalized)
        }

        for type in docTypes {
            if let exts = type["CFBundleTypeExtensions"] as? [String] {
                exts.forEach(append)
            }
            if let utis = type["LSItemContentTypes"] as? [String] {
                for uti in utis {
                    if let utType = UTType(uti),
                       let ext = utType.preferredFilenameExtension {
                        append(ext)
                    }
                }
            }
        }

        return collected
    }
}
