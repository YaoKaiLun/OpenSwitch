import Foundation

struct AppInfo: Identifiable, Equatable {
    let id: String
    let bundleIdentifier: String
    let displayName: String
    let supportedExtensions: [String]
    let bundleURL: URL
}

struct AssociationChangeResult: Identifiable, Equatable {
    let id = UUID()
    let fileExtension: String
    let success: Bool
    let message: String
}

struct FileAssociationPreset: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var extensions: [String]
    var bundleIdentifier: String
    var appDisplayName: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        extensions: [String],
        bundleIdentifier: String,
        appDisplayName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.extensions = extensions
        self.bundleIdentifier = bundleIdentifier
        self.appDisplayName = appDisplayName
        self.createdAt = createdAt
    }
}
