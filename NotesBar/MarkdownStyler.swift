//
//  MarkdownStyler.swift
//  NotesBar
//
//  Shared markdown styling utility
//

import AppKit
import Down

/// Utility for creating styled attributed strings from markdown content
enum MarkdownStyler {
    /// Creates a styled NSAttributedString from markdown content
    static func createStyledAttributedString(from content: String) -> NSAttributedString? {
        guard let attributedString = try? Down(markdownString: content).toAttributedString() else {
            return nil
        }

        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)

        // Apply base paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.paragraphSpacing = 8
        mutableString.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

        // Apply base font
        mutableString.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: fullRange)

        // Find and style headings
        let headingPatterns: [(String, NSFont)] = [
            ("^# (.+)$", NSFont.systemFont(ofSize: 24, weight: .bold)),
            ("^## (.+)$", NSFont.systemFont(ofSize: 20, weight: .bold)),
            ("^### (.+)$", NSFont.systemFont(ofSize: 18, weight: .semibold)),
            ("^#### (.+)$", NSFont.systemFont(ofSize: 16, weight: .semibold)),
            ("^##### (.+)$", NSFont.systemFont(ofSize: 14, weight: .semibold)),
            ("^###### (.+)$", NSFont.systemFont(ofSize: 14, weight: .semibold))
        ]

        for (pattern, font) in headingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))
                for match in matches {
                    guard match.numberOfRanges > 1 else { continue }
                    let range = match.range(at: 1)
                    guard range.location != NSNotFound && range.length > 0 else { continue }

                    // Ensure the range is within bounds
                    let safeRange = NSRange(
                        location: min(range.location, mutableString.length),
                        length: min(range.length, mutableString.length - range.location)
                    )

                    if safeRange.length > 0 {
                        mutableString.addAttribute(.font, value: font, range: safeRange)

                        let headingStyle = NSMutableParagraphStyle()
                        headingStyle.lineSpacing = 6
                        headingStyle.paragraphSpacing = 8
                        mutableString.addAttribute(.paragraphStyle, value: headingStyle, range: safeRange)
                    }
                }
            }
        }

        // Style code blocks
        if let codeRegex = try? NSRegularExpression(pattern: "```[\\s\\S]+?```", options: []) {
            let matches = codeRegex.matches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))
            for match in matches {
                let range = match.range
                guard range.location != NSNotFound && range.length > 0 else { continue }

                // Ensure the range is within bounds
                let safeRange = NSRange(
                    location: min(range.location, mutableString.length),
                    length: min(range.length, mutableString.length - range.location)
                )

                if safeRange.length > 0 {
                    mutableString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: safeRange)
                    mutableString.addAttribute(.backgroundColor, value: NSColor.textBackgroundColor.withAlphaComponent(0.1), range: safeRange)
                }
            }
        }

        return mutableString
    }
}
