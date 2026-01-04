import SwiftUI
import AppKit
import WebKit

struct MarkdownPreviewView: View {
    let file: NoteFile
    var onTap: (() -> Void)? = nil
    @State private var content: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with file name
            HStack {
                Text(file.name.replacingOccurrences(of: ".md", with: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }

            Divider()

            // Content area - WebKit preview
            MarkdownWebView(content: content, filePath: file.path)
                .frame(width: 450, height: 400)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            loadContent()
        }
    }

    private func loadContent() {
        let fileURL = URL(fileURLWithPath: file.path)
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
            content = content.replacingOccurrences(of: "\r\n", with: "\n")
        } catch {
            content = "Error loading content: \(error.localizedDescription)"
        }
    }
}

/// NSViewRepresentable wrapper for WKWebView to render markdown as HTML
struct MarkdownWebView: NSViewRepresentable {
    let content: String
    let filePath: String
    var onContentChanged: ((String) -> Void)?

    init(content: String, filePath: String, onContentChanged: ((String) -> Void)? = nil) {
        self.content = content
        self.filePath = filePath
        self.onContentChanged = onContentChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Add message handler for checkbox toggles
        config.userContentController.add(context.coordinator, name: "checkboxToggle")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        let html = MarkdownStyler.createStyledHTML(from: content)
        webView.loadHTMLString(html, baseURL: nil)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: MarkdownWebView

        init(_ parent: MarkdownWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "checkboxToggle",
                  let body = message.body as? [String: Any],
                  let lineNumber = body["line"] as? Int,
                  let isChecked = body["checked"] as? Bool else {
                return
            }

            // Toggle the checkbox in the file
            toggleCheckboxInFile(at: lineNumber, checked: isChecked)
        }

        private func toggleCheckboxInFile(at lineNumber: Int, checked: Bool) {
            let fileURL = URL(fileURLWithPath: parent.filePath)

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                return
            }

            var lines = content.components(separatedBy: "\n")

            guard lineNumber < lines.count else { return }

            let line = lines[lineNumber]

            // Replace checkbox state
            var newLine = line
            if checked {
                // Change [ ] to [x]
                newLine = line.replacingOccurrences(of: "[ ]", with: "[x]")
            } else {
                // Change [x] or [X] to [ ]
                newLine = line.replacingOccurrences(of: "[x]", with: "[ ]")
                newLine = newLine.replacingOccurrences(of: "[X]", with: "[ ]")
            }

            lines[lineNumber] = newLine
            let newContent = lines.joined(separator: "\n")

            // Save the file
            try? newContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // Notify parent of content change
            parent.onContentChanged?(newContent)
        }
    }
}

#Preview {
    MarkdownPreviewView(file: NoteFile(
        name: "test.md",
        path: "/path/to/test.md",
        relativePath: "test.md",
        isDirectory: false,
        children: nil
    ))
}
