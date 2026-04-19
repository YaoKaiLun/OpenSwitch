import Foundation

enum ExtensionParser {
    static func parse(_ raw: String) -> [String] {
        raw
            .split(separator: ",")
            .map { item in
                item
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    .lowercased()
            }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, value in
                if !result.contains(value) {
                    result.append(value)
                }
            }
    }
}
