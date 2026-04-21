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
    static func createStyledHTML(from content: String, theme: String = "system") -> String {
        // Pre-process extensions
        var processedContent = preprocessGFMTables(content)
        processedContent = preprocessTaskLists(processedContent)
        // processedContent = preprocessMermaid(processedContent) // Moving to post-process
        processedContent = preprocessMath(processedContent)
        processedContent = preprocessWikilinks(processedContent)

        let down = Down(markdownString: processedContent)
        var html = (try? down.toHTML([.smart, .unsafe])) ?? ""
        
        // Post-process HTML for Mermaid and other enhancements
        html = postprocessHTML(html)

        return wrapInHTMLTemplate(html, theme: theme)
    }

    /// Converts [[Wikilinks]] or [[Wikilinks|Alias]] to HTML anchors
    private static func preprocessWikilinks(_ content: String) -> String {
        var result = content
        // Match [[Path/To/Note]] or [[Path/To/Note|Display Text]]
        // Pattern: [[ (any char except ] or |) (optionally | followed by display text) ]]
        let pattern = "\\[\\[([^\\]|]+)(?:\\|([^\\]]+))?\\]\\]"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        let nsString = content as NSString
        let matches = regex?.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches.reversed() {
            let path = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            let display: String
            if match.range(at: 2).location != NSNotFound {
                display = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
            } else {
                display = path
            }
            
            // Encode the path for use in a URL, but keep it identifiable for our resolver
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            let html = "<a href=\"wikilink:\(encodedPath)\">\(display)</a>"
            
            result = (result as NSString).replacingCharacters(in: match.range, with: html) as String
        }
        
        return result
    }

    /// Detects mermaid code blocks and wraps them in a div for mermaid.js
    private static func preprocessMermaid(_ content: String) -> String {
        var result = content
        let pattern = "```mermaid\\n([\\s\\S]*?)\\n```"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        let nsString = content as NSString
        let matches = regex?.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        // Reverse order to not mess up indices
        for match in matches.reversed() {
            let code = nsString.substring(with: match.range(at: 1))
            let html = "<div class=\"mermaid\">\(code)</div>"
            result = (result as NSString).replacingCharacters(in: match.range, with: html) as String
        }
        
        return result
    }

    /// Detects math blocks and wraps them for KaTeX
    private static func preprocessMath(_ content: String) -> String {
        var result = content
        
        // Block math: $$ ... $$
        let blockPattern = "\\$\\$([\\s\\S]*?)\\$\\$"
        let blockRegex = try? NSRegularExpression(pattern: blockPattern, options: [])
        let blockMatches = blockRegex?.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length)) ?? []
        
        for match in blockMatches.reversed() {
            let math = (result as NSString).substring(with: match.range(at: 1))
            let html = "<div class=\"math-block\">$$\(math)$$</div>"
            result = (result as NSString).replacingCharacters(in: match.range, with: html) as String
        }
        
        // Inline math: $ ... $
        // Be careful not to match literal dollar signs - usually requires whitespace before or after
        let inlinePattern = "(?<!\\\\)\\$([^$\\n]+?)\\$"
        let inlineRegex = try? NSRegularExpression(pattern: inlinePattern, options: [])
        let inlineMatches = inlineRegex?.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length)) ?? []
        
        for match in inlineMatches.reversed() {
            let math = (result as NSString).substring(with: match.range(at: 1))
            let html = "<span class=\"math-inline\">$\(math)$</span>"
            result = (result as NSString).replacingCharacters(in: match.range, with: html) as String
        }
        
        return result
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
        let lines = content.components(separatedBy: "\n")
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

    /// Post-processes the final HTML to handle Mermaid blocks and other dynamic elements
    private static func postprocessHTML(_ html: String) -> String {
        var result = html
        
        // Find Mermaid code blocks like <pre><code class="language-mermaid">...</code></pre>
        let pattern = "<pre><code class=\"language-mermaid\">([\\s\\S]*?)</code></pre>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        let nsString = result as NSString
        let matches = regex?.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches.reversed() {
            let escapedCode = nsString.substring(with: match.range(at: 1))
            
            // Unescape HTML entities so Mermaid gets the raw syntax
            let unescaped = escapedCode
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "–", with: "--") // Fix Down's smart dash replacement
            
            let mermaidDiv = "<pre class=\"mermaid\">\(unescaped)</pre>"
            result = (result as NSString).replacingCharacters(in: match.range, with: mermaidDiv) as String
        }
        
        return result
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
    static func wrapInHTMLTemplate(_ bodyContent: String, theme: String = "system") -> String {
        let themeClass = theme == "system" ? "" : "theme-\(theme)"
        
        return """
        <!DOCTYPE html>
        <html class="\(themeClass)">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="\(JSAssets.mermaidScript)"></script>
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css">
            <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.js"></script>
            <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/contrib/auto-render.min.js" onload="renderMathInElement(document.body);"></script>
            <style>
                :root {
                    --bg-color: transparent;
                    --header-bg: rgba(255, 255, 255, 0.05);
                }

                /* Default: System */
                @media (prefers-color-scheme: dark) {
                    :root {
                        --text-color: #e0e0e0;
                        --heading-color: #ffffff;
                        --link-color: #58a6ff;
                        --code-bg: rgba(255, 255, 255, 0.08);
                        --code-text: #f0f0f0;
                        --border-color: rgba(255, 255, 255, 0.15);
                        --quote-bg: rgba(255, 255, 255, 0.03);
                        --table-header-bg: rgba(255, 255, 255, 0.1);
                        --table-row-alt: rgba(255, 255, 255, 0.04);
                    }
                }

                @media (prefers-color-scheme: light) {
                    :root {
                        --text-color: #1d1d1f;
                        --heading-color: #000000;
                        --link-color: #0066cc;
                        --code-bg: rgba(0, 0, 0, 0.05);
                        --code-text: #1d1d1f;
                        --border-color: rgba(0, 0, 0, 0.1);
                        --quote-bg: rgba(0, 0, 0, 0.02);
                        --table-header-bg: rgba(0, 0, 0, 0.05);
                        --table-row-alt: rgba(0, 0, 0, 0.02);
                    }
                }

                /* Explicit Light Mode Override */
                html.theme-light {
                    --text-color: #1d1d1f;
                    --heading-color: #000000;
                    --link-color: #0066cc;
                    --code-bg: rgba(0, 0, 0, 0.05);
                    --code-text: #1d1d1f;
                    --border-color: rgba(0, 0, 0, 0.1);
                    --quote-bg: rgba(0, 0, 0, 0.02);
                    --table-header-bg: rgba(0, 0, 0, 0.05);
                    --table-row-alt: rgba(0, 0, 0, 0.02);
                }

                /* Explicit Dark Mode Override */
                html.theme-dark {
                    --text-color: #e0e0e0;
                    --heading-color: #ffffff;
                    --link-color: #58a6ff;
                    --code-bg: rgba(255, 255, 255, 0.08);
                    --code-text: #f0f0f0;
                    --border-color: rgba(255, 255, 255, 0.15);
                    --quote-bg: rgba(255, 255, 255, 0.03);
                    --table-header-bg: rgba(255, 255, 255, 0.1);
                    --table-row-alt: rgba(255, 255, 255, 0.04);
                }

                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif;
                    font-size: 15px;
                    line-height: 1.6;
                    color: var(--text-color);
                    background-color: var(--bg-color);
                    padding: 24px;
                    margin: 0;
                    -webkit-font-smoothing: antialiased;
                }

                h1, h2, h3, h4, h5, h6 {
                    color: var(--heading-color);
                    margin-top: 1.6em;
                    margin-bottom: 0.8em;
                    font-weight: 600;
                    letter-spacing: -0.01em;
                }

                h1 { font-size: 28px; border-bottom: 1px solid var(--border-color); padding-bottom: 0.3em; }
                h2 { font-size: 22px; border-bottom: 1px solid var(--border-color); padding-bottom: 0.3em; }
                h3 { font-size: 19px; }
                h4 { font-size: 17px; }

                h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }

                a {
                    color: var(--link-color);
                    text-decoration: none;
                    transition: color 0.15s ease;
                }

                a:hover { text-decoration: underline; }

                code {
                    font-family: "SF Mono", "Menlo", "Monaco", monospace;
                    font-size: 0.9em;
                    background-color: var(--code-bg);
                    color: var(--code-text);
                    padding: 0.2em 0.4em;
                    border-radius: 6px;
                }

                pre {
                    background-color: var(--code-bg);
                    padding: 16px;
                    border-radius: 12px;
                    overflow-x: auto;
                    margin: 1.2em 0;
                    border: 1px solid var(--border-color);
                }

                pre code {
                    background-color: transparent;
                    padding: 0;
                    border-radius: 0;
                    line-height: 1.5;
                }

                blockquote {
                    margin: 1.5em 0;
                    padding: 0.5em 1.2em;
                    border-left: 4px solid var(--link-color);
                    background-color: var(--quote-bg);
                    border-radius: 0 8px 8px 0;
                    color: var(--text-color);
                }

                table {
                    border-collapse: separate;
                    border-spacing: 0;
                    width: 100%;
                    margin: 1.5em 0;
                    border: 1px solid var(--border-color);
                    border-radius: 10px;
                    overflow: hidden;
                }

                th, td {
                    padding: 12px 16px;
                    text-align: left;
                    border-bottom: 1px solid var(--border-color);
                }

                th {
                    background-color: var(--table-header-bg);
                    font-weight: 600;
                    color: var(--heading-color);
                }

                tr:last-child td { border-bottom: none; }

                tr:nth-child(even) { background-color: var(--table-row-alt); }

                ul, ol { padding-left: 1.8em; margin: 1em 0; }
                li { margin: 0.4em 0; }

                hr {
                    border: none;
                    border-top: 1px solid var(--border-color);
                    margin: 2em 0;
                }

                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 1em 0;
                }

                /* Task list checkboxes */
                input[type="checkbox"] {
                    -webkit-appearance: none;
                    appearance: none;
                    width: 18px;
                    height: 18px;
                    border: 1.5px solid var(--border-color);
                    border-radius: 5px;
                    margin-right: 10px;
                    vertical-align: middle;
                    position: relative;
                    top: -1px;
                    cursor: pointer;
                    background-color: transparent;
                    transition: all 0.2s ease;
                }

                input[type="checkbox"]:checked {
                    background-color: var(--link-color);
                    border-color: var(--link-color);
                }

                input[type="checkbox"]:checked::after {
                    content: '✓';
                    color: white;
                    font-size: 13px;
                    font-weight: bold;
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                }

                input[type="checkbox"]:hover { border-color: var(--link-color); }

                li:has(input[type="checkbox"]) {
                    list-style: none;
                    margin-left: -1.5em;
                }

                /* Mermaid styling */
                .mermaid {
                    background: var(--code-bg);
                    padding: 16px;
                    border-radius: 12px;
                    display: flex;
                    justify-content: center;
                    margin: 1.5em 0;
                    border: 1px solid var(--border-color);
                }
                
                /* Math styling */
                .math-block {
                    margin: 1.5em 0;
                    text-align: center;
                    overflow-x: auto;
                }

                /* Apple Notes specific styles */
                .Apple-dash-list {
                    list-style-type: none;
                    padding-left: 1.8em;
                }
                .Apple-dash-list li::before {
                    content: "–";
                    position: absolute;
                    margin-left: -1.2em;
                    color: var(--text-color);
                    opacity: 0.6;
                }
                
                /* Ensure Apple Notes h1 matches our theme */
                body > div > h1:first-child {
                    font-size: 28px;
                    margin-top: 0;
                    border-bottom: 1px solid var(--border-color);
                    padding-bottom: 0.3em;
                    color: var(--heading-color);
                }
                
                /* Override Apple Notes hardcoded inline styles */
                .apple-notes-content * {
                    color: var(--text-color) !important;
                    background-color: transparent !important;
                }
                .apple-notes-content a, .apple-notes-content a * {
                    color: var(--link-color) !important;
                }
                
                /* Invert handwriting and images in Apple Notes for dark mode */
                html.theme-dark .apple-notes-content img,
                html.theme-dark .apple-notes-content object,
                html.theme-dark .apple-notes-content svg {
                    filter: invert(1) hue-rotate(180deg);
                    mix-blend-mode: screen;
                    border-radius: 8px;
                }
            </style>
            <script>
                function toggleCheckbox(checkbox, lineNumber) {
                    const isChecked = checkbox.checked;
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.checkboxToggle) {
                        window.webkit.messageHandlers.checkboxToggle.postMessage({
                            line: lineNumber,
                            checked: isChecked
                        });
                    }
                }

                document.addEventListener('DOMContentLoaded', function() {
                    if (typeof mermaid !== 'undefined') {
                        mermaid.initialize({ 
                            startOnLoad: false, 
                            theme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default',
                            securityLevel: 'loose',
                            fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif'
                        });
                        mermaid.run();
                    }
                });
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
