import Foundation

extension String {
    func containsAll(_ substrings: [Substring]) -> Bool {
        substrings.allSatisfy { substring in
            self.contains(substring)
        }
    }

    /// Encodes a file path for use in Obsidian URLs
    func encodedForObsidianURL() -> String {
        var path = self
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        return path
            .components(separatedBy: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }
            .joined(separator: "%2F")
    }
}
