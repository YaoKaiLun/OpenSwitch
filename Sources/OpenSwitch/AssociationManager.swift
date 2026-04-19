import CoreServices
import Foundation
import UniformTypeIdentifiers

protocol FileAssociationManaging {
    func defaultAppBundleIdentifier(for fileExtension: String) -> String?
    func setDefaultApp(bundleIdentifier: String, for fileExtensions: [String]) -> [AssociationChangeResult]
}

struct LaunchServicesAssociationManager: FileAssociationManaging {
    func defaultAppBundleIdentifier(for fileExtension: String) -> String? {
        guard let type = Self.resolveUTI(for: fileExtension) else {
            return nil
        }
        let handler = LSCopyDefaultRoleHandlerForContentType(type.identifier as CFString, LSRolesMask.all)
        return handler?.takeRetainedValue() as String?
    }

    func setDefaultApp(bundleIdentifier: String, for fileExtensions: [String]) -> [AssociationChangeResult] {
        fileExtensions.map { item in
            guard let type = Self.resolveUTI(for: item) else {
                return AssociationChangeResult(
                    fileExtension: item,
                    success: false,
                    message: "无法识别的扩展名"
                )
            }

            let status = LSSetDefaultRoleHandlerForContentType(
                type.identifier as CFString,
                LSRolesMask.all,
                bundleIdentifier as CFString
            )

            if status == noErr {
                return AssociationChangeResult(
                    fileExtension: item,
                    success: true,
                    message: "已设置为 \(bundleIdentifier)（UTI: \(type.identifier)）"
                )
            }

            return AssociationChangeResult(
                fileExtension: item,
                success: false,
                message: "设置失败，状态码: \(status)（UTI: \(type.identifier)）"
            )
        }
    }

    /// 把扩展名归一化成无点小写字符串。
    static func normalize(_ fileExtension: String) -> String {
        fileExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }

    /// 把扩展名解析成最贴近"用户意图"的 UTI。
    ///
    /// 系统给某些扩展名的首选 UTI 并不是用户想要的，比如 `.ts` 系统首选是
    /// `public.mpeg-2-transport-stream`，而 OpenSwitch 的目标是为源码文件改默认编辑器。
    /// 解析顺序：
    ///   1. 列出该扩展名下所有候选 UTI（`UTType.types(tag:tagClass:conformingTo:)`）；
    ///   2. 优先选 **非动态、且 conforms 到 source-code 或 text** 的 UTI；
    ///   3. 退而求其次选 **任意非动态** UTI；
    ///   4. 再退到候选列表的第一个；
    ///   5. 最终回退到 `UTType(filenameExtension:)`（可能返回动态 UTI）。
    static func resolveUTI(for fileExtension: String) -> UTType? {
        let normalized = normalize(fileExtension)
        guard !normalized.isEmpty else { return nil }

        let candidates = UTType.types(
            tag: normalized,
            tagClass: .filenameExtension,
            conformingTo: nil
        )

        if let preferred = candidates.first(where: { uti in
            !uti.isDynamic && (uti.conforms(to: .sourceCode) || uti.conforms(to: .text))
        }) {
            return preferred
        }

        if let nonDynamic = candidates.first(where: { !$0.isDynamic }) {
            return nonDynamic
        }

        if let first = candidates.first {
            return first
        }

        return UTType(filenameExtension: normalized)
    }
}
