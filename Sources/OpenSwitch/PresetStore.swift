import Foundation

protocol PresetStoring {
    func loadPresets() -> [FileAssociationPreset]
    func save(preset: FileAssociationPreset) throws
    func delete(presetID: UUID) throws
}

struct LocalPresetStore: PresetStoring {
    /// 持久化文件路径，注入便于测试。
    let fileURL: URL

    init(fileURL: URL = LocalPresetStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func loadPresets() -> [FileAssociationPreset] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            let presets = try JSONDecoder.preset.decode([FileAssociationPreset].self, from: data)
            return presets.sorted { $0.createdAt < $1.createdAt }
        } catch {
            assertionFailure("解析预设文件失败: \(error)")
            return []
        }
    }

    func save(preset: FileAssociationPreset) throws {
        var presets = loadPresets()
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        try persist(presets)
    }

    func delete(presetID: UUID) throws {
        var presets = loadPresets()
        presets.removeAll { $0.id == presetID }
        try persist(presets)
    }

    private func persist(_ presets: [FileAssociationPreset]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.preset.encode(presets)
        try data.write(to: fileURL, options: .atomic)
    }

    static func defaultFileURL() -> URL {
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupportDirectory
            .appendingPathComponent("OpenSwitch", isDirectory: true)
            .appendingPathComponent("presets.json", isDirectory: false)
    }
}

private extension JSONEncoder {
    /// 用于预设序列化的编码器：与 JSONDecoder.preset 成对使用，保证日期格式一致。
    static var preset: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var preset: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
