//
//  MarkdownStyler.swift
//  NotesBar
//
//  Shared markdown styling utility
//

import AppKit
import Down

/// Utility for creating styled HTML from markdown content
enum MarkdownStyler {
    /// Creates HTML string from markdown content with styling for dark/light mode
    static func createStyledHTML(from content: String) -> String {
        // Pre-process GFM extensions since cmark doesn't support them
        var processedContent = preprocessGFMTables(content)
        processedContent = preprocessTaskLists(processedContent)

        let down = Down(markdownString: processedContent)
        let html = (try? down.toHTML([.smart, .unsafe])) ?? ""

        return wrapInHTMLTemplate(html)
    }

    /// Converts GFM-style task lists to HTML checkboxes
    private static func preprocessTaskLists(_ content: String) -> String {
        // Handle multiline - process line by line
        let lines = content.components(separatedBy: "\n")
        var lineIndex = 0
        let processedLines = lines.map { line -> String in
            var processedLine = line
            defer { lineIndex += 1 }

            // Unchecked: - [ ] or * [ ]
            if let range = processedLine.range(of: #"^(\s*[-*])\s+\[ \]"#, options: .regularExpression) {
                let match = processedLine[range]
                let indent = String(match.prefix(while: { $0.isWhitespace }))
                let bullet = match.contains("-") ? "-" : "*"
                processedLine = processedLine.replacingCharacters(
                    in: range,
                    with: "\(indent)\(bullet) <input type=\"checkbox\" data-line=\"\(lineIndex)\" onclick=\"toggleCheckbox(this, \(lineIndex))\">"
                )
            }

            // Checked: - [x] or * [x] or - [X] or * [X]
            if let range = processedLine.range(of: #"^(\s*[-*])\s+\[[xX]\]"#, options: .regularExpression) {
                let match = processedLine[range]
                let indent = String(match.prefix(while: { $0.isWhitespace }))
                let bullet = match.contains("-") ? "-" : "*"
                processedLine = processedLine.replacingCharacters(
                    in: range,
                    with: "\(indent)\(bullet) <input type=\"checkbox\" checked data-line=\"\(lineIndex)\" onclick=\"toggleCheckbox(this, \(lineIndex))\">"
                )
            }

            return processedLine
        }

        return processedLines.joined(separator: "\n")
    }

    /// Converts GFM-style markdown tables to HTML tables
    private static func preprocessGFMTables(_ content: String) -> String {
        var lines = content.components(separatedBy: "\n")
        var result: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Check if this line looks like a table row (starts with | or has | separators)
            if isTableRow(line) && i + 1 < lines.count && isTableSeparator(lines[i + 1]) {
                // Found a table - parse it
                var tableLines: [String] = [line]
                var j = i + 1

                // Collect all table lines
                while j < lines.count && (isTableRow(lines[j]) || isTableSeparator(lines[j])) {
                    tableLines.append(lines[j])
                    j += 1
                }

                // Convert to HTML
                let tableHTML = convertTableToHTML(tableLines)
                result.append(tableHTML)
                i = j
            } else {
                result.append(line)
                i += 1
            }
        }

        return result.joined(separator: "\n")
    }

    /// Checks if a line looks like a table row
    private static func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("|") && !isTableSeparator(line)
    }

    /// Checks if a line is a table separator (e.g., |---|---|)
    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Must contain | and - and optionally :
        let separatorPattern = #"^\|?[\s\-:\|]+\|?$"#
        return trimmed.range(of: separatorPattern, options: .regularExpression) != nil &&
               trimmed.contains("-") && trimmed.contains("|")
    }

    /// Converts table lines to HTML
    private static func convertTableToHTML(_ lines: [String]) -> String {
        guard lines.count >= 2 else { return lines.joined(separator: "\n") }

        var html = "<table>\n"
        var isHeader = true

        for line in lines {
            // Skip separator lines
            if isTableSeparator(line) {
                isHeader = false
                continue
            }

            let cells = parseTableRow(line)

            if isHeader {
                html += "<thead>\n<tr>\n"
                for cell in cells {
                    html += "<th>\(escapeHTML(cell))</th>\n"
                }
                html += "</tr>\n</thead>\n<tbody>\n"
            } else {
                html += "<tr>\n"
                for cell in cells {
                    html += "<td>\(escapeHTML(cell))</td>\n"
                }
                html += "</tr>\n"
            }
        }

        html += "</tbody>\n</table>\n"
        return html
    }

    /// Parses a table row into cells
    private static func parseTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)

        // Remove leading and trailing pipes
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }

        // Split by | and trim each cell
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Escapes HTML special characters
    private static func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        return result
    }

    /// Wraps HTML content in a full HTML document with styling
    private static func wrapInHTMLTemplate(_ bodyContent: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                :root {
                    color-scheme: light dark;
                }

                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    color: var(--text-color);
                    background-color: transparent;
                    padding: 16px 20px;
                    margin: 0;
                }

                @media (prefers-color-scheme: dark) {
                    :root {
                        --text-color: #f0f0f0;
                        --heading-color: #ffffff;
                        --link-color: #6cb6ff;
                        --code-bg: rgba(255, 255, 255, 0.1);
                        --border-color: rgba(255, 255, 255, 0.2);
                        --table-header-bg: rgba(255, 255, 255, 0.1);
                        --table-row-alt: rgba(255, 255, 255, 0.05);
                    }
                }

                @media (prefers-color-scheme: light) {
                    :root {
                        --text-color: #1d1d1f;
                        --heading-color: #000000;
                        --link-color: #0066cc;
                        --code-bg: rgba(0, 0, 0, 0.05);
                        --border-color: rgba(0, 0, 0, 0.15);
                        --table-header-bg: rgba(0, 0, 0, 0.05);
                        --table-row-alt: rgba(0, 0, 0, 0.02);
                    }
                }

                h1, h2, h3, h4, h5, h6 {
                    color: var(--heading-color);
                    margin-top: 1.2em;
                    margin-bottom: 0.6em;
                }

                h1 { font-size: 24px; font-weight: bold; }
                h2 { font-size: 20px; font-weight: bold; }
                h3 { font-size: 18px; font-weight: 600; }
                h4 { font-size: 16px; font-weight: 600; }
                h5, h6 { font-size: 14px; font-weight: 600; }

                h1:first-child, h2:first-child, h3:first-child {
                    margin-top: 0;
                }

                a {
                    color: var(--link-color);
                    text-decoration: none;
                }

                a:hover {
                    text-decoration: underline;
                }

                code {
                    font-family: "SF Mono", Menlo, Monaco, monospace;
                    font-size: 13px;
                    background-color: var(--code-bg);
                    padding: 2px 6px;
                    border-radius: 4px;
                }

                pre {
                    background-color: var(--code-bg);
                    padding: 12px;
                    border-radius: 6px;
                    overflow-x: auto;
                }

                pre code {
                    background-color: transparent;
                    padding: 0;
                }

                blockquote {
                    margin: 1em 0;
                    padding-left: 1em;
                    border-left: 3px solid var(--border-color);
                    color: var(--text-color);
                    opacity: 0.8;
                }

                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 1em 0;
                    font-size: 13px;
                }

                th, td {
                    border: 1px solid var(--border-color);
                    padding: 8px 12px;
                    text-align: left;
                }

                th {
                    background-color: var(--table-header-bg);
                    font-weight: 600;
                }

                tr:nth-child(even) {
                    background-color: var(--table-row-alt);
                }

                ul, ol {
                    padding-left: 2em;
                    margin: 0.5em 0;
                }

                li {
                    margin: 0.3em 0;
                }

                hr {
                    border: none;
                    border-top: 1px solid var(--border-color);
                    margin: 1.5em 0;
                }

                img {
                    max-width: 100%;
                    height: auto;
                }

                p {
                    margin: 0.8em 0;
                }

                p:first-child {
                    margin-top: 0;
                }

                /* Task list checkboxes */
                input[type="checkbox"] {
                    -webkit-appearance: none;
                    appearance: none;
                    width: 16px;
                    height: 16px;
                    border: 2px solid var(--border-color);
                    border-radius: 3px;
                    margin-right: 8px;
                    vertical-align: middle;
                    position: relative;
                    top: -1px;
                    cursor: pointer;
                    background-color: transparent;
                }

                input[type="checkbox"]:checked {
                    background-color: var(--link-color);
                    border-color: var(--link-color);
                }

                input[type="checkbox"]:checked::after {
                    content: '✓';
                    color: white;
                    font-size: 12px;
                    font-weight: bold;
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                }

                input[type="checkbox"]:hover {
                    border-color: var(--link-color);
                }

                /* Style list items with checkboxes */
                li:has(input[type="checkbox"]) {
                    list-style: none;
                    margin-left: -1.5em;
                }
            </style>
            <script>
                function toggleCheckbox(checkbox, lineNumber) {
                    const isChecked = checkbox.checked;
                    // Send message to Swift via webkit message handler
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.checkboxToggle) {
                        window.webkit.messageHandlers.checkboxToggle.postMessage({
                            line: lineNumber,
                            checked: isChecked
                        });
                    }
                }
            </script>
        </head>
        <body>
            \(bodyContent)
        </body>
        </html>
        """
    }

    /// Creates a styled NSAttributedString from markdown content (legacy support)
    static func createStyledAttributedString(from content: String) -> NSAttributedString? {
        // Configure fonts
        let fonts = StaticFontCollection(
            heading1: NSFont.systemFont(ofSize: 24, weight: .bold),
            heading2: NSFont.systemFont(ofSize: 20, weight: .bold),
            heading3: NSFont.systemFont(ofSize: 18, weight: .semibold),
            heading4: NSFont.systemFont(ofSize: 16, weight: .semibold),
            heading5: NSFont.systemFont(ofSize: 14, weight: .semibold),
            heading6: NSFont.systemFont(ofSize: 14, weight: .semibold),
            body: NSFont.systemFont(ofSize: 14),
            code: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            listItemPrefix: NSFont.systemFont(ofSize: 14)
        )

        // Configure paragraph styles
        var paragraphStyles = StaticParagraphStyleCollection()
        let defaultStyle = NSMutableParagraphStyle()
        defaultStyle.lineSpacing = 6
        defaultStyle.paragraphSpacing = 8
        paragraphStyles.heading1 = defaultStyle
        paragraphStyles.heading2 = defaultStyle
        paragraphStyles.heading3 = defaultStyle
        paragraphStyles.heading4 = defaultStyle
        paragraphStyles.heading5 = defaultStyle
        paragraphStyles.heading6 = defaultStyle
        paragraphStyles.body = defaultStyle
        paragraphStyles.code = defaultStyle

        // Configure colors for dark mode support
        let colors = StaticColorCollection(
            heading1: .labelColor,
            heading2: .labelColor,
            heading3: .labelColor,
            heading4: .labelColor,
            heading5: .labelColor,
            heading6: .labelColor,
            body: .labelColor,
            code: .labelColor,
            link: .linkColor,
            quote: .secondaryLabelColor,
            quoteStripe: .tertiaryLabelColor,
            thematicBreak: .separatorColor,
            listItemPrefix: .secondaryLabelColor,
            codeBlockBackground: NSColor.textBackgroundColor.withAlphaComponent(0.3)
        )

        let config = DownStylerConfiguration(fonts: fonts, colors: colors, paragraphStyles: paragraphStyles)
        let styler = DownStyler(configuration: config)

        let down = Down(markdownString: content)
        guard let attributedString = try? down.toAttributedString(styler: styler) else {
            return nil
        }

        return attributedString
    }
}
