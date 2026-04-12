import SwiftUI
import AppKit
import WebKit

// MARK: - Render Mode

enum PreviewRenderMode {
    case markdown
    case canvas
    case excalidraw
}

// MARK: - MarkdownPreviewView

struct MarkdownPreviewView: View {
    @State private var history: [NoteFile]
    var onTap: (() -> Void)? = nil
    @State private var content: String = ""
    @State private var renderMode: PreviewRenderMode = .markdown
    @EnvironmentObject private var vaultViewModel: VaultViewModel
    @Environment(\.colorScheme) var colorScheme
    
    // Navigation state
    @State private var isOnExternalPage = false
    @State private var webBackTrigger = 0
    
    init(file: NoteFile, onTap: (() -> Void)? = nil) {
        self._history = State(initialValue: [file])
        self.onTap = onTap
    }

    private var currentFile: NoteFile {
        history.last!
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                if history.count > 1 || isOnExternalPage {
                    Button(action: {
                        if isOnExternalPage {
                            webBackTrigger += 1
                        } else {
                            withAnimation(.spring(response: 0.3)) {
                                history.removeLast()
                                loadContent()
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(6)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                let displayName = currentFile.name
                    .replacingOccurrences(of: ".md", with: "")
                    .replacingOccurrences(of: ".canvas", with: "")
                    .replacingOccurrences(of: ".excalidraw", with: "")
                
                Text(displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if renderMode == .canvas {
                    Label("Canvas", systemImage: "square.grid.2x2")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                } else if renderMode == .excalidraw {
                    Label("Excalidraw", systemImage: "scribble.variable")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            Divider()

            MarkdownWebView(
                content: content,
                filePath: currentFile.path,
                theme: colorScheme == .dark ? "dark" : "light",
                renderMode: renderMode,
                isOnExternalPage: $isOnExternalPage,
                webBackTrigger: $webBackTrigger,
                onLinkClick: { url in handleLinkClick(url) }
            )
            .frame(width: 450, height: 400)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .onAppear { loadContent() }
        .onChange(of: history) { loadContent() }
    }

    private func loadContent() {
        let fileURL = URL(fileURLWithPath: currentFile.path)
        let ext = fileURL.pathExtension.lowercased()
        do {
            let fileData = try Data(contentsOf: fileURL)
            let rawString = String(data: fileData, encoding: .utf8) ?? ""
            
            if ext == "canvas" {
                renderMode = .canvas
                content = rawString
            } else if ext == "excalidraw" || (ext == "md" && rawString.contains("excalidraw-plugin:")) {
                renderMode = .excalidraw
                if let compressed = extractCompressedExcalidrawBase64(from: rawString) {
                    let textElements = extractExcalidrawTextElements(from: rawString)
                    content = "EXCALIDRAW_MD\u{0}\(compressed)\u{0}" + textElements.joined(separator: "\n")
                } else {
                    // Fallback for pure JSON .excalidraw files
                    content = rawString
                }
            } else {
                renderMode = .markdown
                content = rawString.replacingOccurrences(of: "\r\n", with: "\n")
            }
        } catch {
            renderMode = .markdown
            content = "Error loading content: \(error.localizedDescription)"
        }
    }

    private func extractCompressedExcalidrawBase64(from raw: String) -> String? {
        let patterns = [
            "```compressed-json\n([\\s\\S]*?)\n```",
            "%%[\\s\\S]*?(EXCALIDRAW_[A-Za-z0-9+/=\\s\\n]+)[\\s\\S]*?%%",
            "EXCALIDRAW_([A-Za-z0-9+/=\\s\\n]+)"
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { continue }
            let nsRange = NSRange(raw.startIndex..., in: raw)
            if let match = regex.firstMatch(in: raw, range: nsRange),
               let range = Range(match.range(at: 1), in: raw) {
                let found = String(raw[range])
                // Clean: remove prefix if second or third pattern matched and included it (third pattern excludes it in group 1)
                let base64Part = found.hasPrefix("EXCALIDRAW_") ? String(found.dropFirst(11)) : found
                // Remove all whitespace/newlines for LZString
                return base64Part.components(separatedBy: .whitespacesAndNewlines).joined()
            }
        }
        return nil
    }

    private func extractExcalidrawTextElements(from raw: String) -> [String] {
        guard let sectionStart = raw.range(of: "## Text Elements\n") else { return [] }
        let afterSection = raw[sectionStart.upperBound...]
        let sectionContent: String
        if let nextSection = afterSection.range(of: "\n## ") {
            sectionContent = String(afterSection[..<nextSection.lowerBound])
        } else if let drawingSection = afterSection.range(of: "\n%%") {
            sectionContent = String(afterSection[..<drawingSection.lowerBound])
        } else {
            sectionContent = String(afterSection)
        }
        let idPattern = try? NSRegularExpression(pattern: "\\s+\\^[A-Za-z0-9]+$", options: .anchorsMatchLines)
        return sectionContent
            .components(separatedBy: "\n")
            .map { line -> String in
                let ns = line as NSString
                guard let regex = idPattern,
                      let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else {
                    return line.trimmingCharacters(in: .whitespaces)
                }
                return ns.substring(to: match.range.location).trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }

    private func handleLinkClick(_ url: URL) {
        if url.scheme == "wikilink" {
            let noteName = url.absoluteString
                .replacingOccurrences(of: "wikilink:", with: "")
                .removingPercentEncoding ?? ""
            resolveAndNavigate(to: noteName)
            return
        }
        if url.isFileURL {
            let newFile = NoteFile(name: url.lastPathComponent, path: url.path, relativePath: "", isDirectory: false, children: nil)
            navigateTo(newFile)
        }
    }

    private func resolveAndNavigate(to noteName: String) {
        guard let vault = vaultViewModel.currentVault else { return }
        let fileManager = FileManager.default
        let nameWithExt = noteName.lowercased().hasSuffix(".md") ? noteName : "\(noteName).md"
        let vaultURL = URL(fileURLWithPath: vault.path)
        let enumerator = fileManager.enumerator(at: vaultURL, includingPropertiesForKeys: [.nameKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent.localizedCaseInsensitiveCompare(nameWithExt) == .orderedSame ||
               fileURL.lastPathComponent.localizedCaseInsensitiveCompare(noteName) == .orderedSame {
                let newFile = NoteFile(name: fileURL.lastPathComponent, path: fileURL.path, relativePath: fileURL.path.replacingOccurrences(of: vault.path + "/", with: ""), isDirectory: false, children: nil)
                navigateTo(newFile)
                return
            }
        }
    }

    private func navigateTo(_ file: NoteFile) {
        withAnimation(.spring(response: 0.3)) {
            history.append(file)
        }
    }
}

// MARK: - MarkdownWebView

struct MarkdownWebView: NSViewRepresentable {
    let content: String
    let filePath: String
    let theme: String
    let renderMode: PreviewRenderMode
    @Binding var isOnExternalPage: Bool
    @Binding var webBackTrigger: Int
    var onContentChanged: ((String) -> Void)? = nil
    var onLinkClick: ((URL) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "checkboxToggle")
        config.userContentController.add(context.coordinator, name: "wikilinkClick")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        
        let themeChanged = context.coordinator.lastTheme != theme
        if themeChanged {
            context.coordinator.lastTheme = theme
        }

        if context.coordinator.lastWebBackTrigger != webBackTrigger {
            context.coordinator.lastWebBackTrigger = webBackTrigger
            if webView.canGoBack {
                webView.goBack()
            } else {
                reload(webView: webView)
                DispatchQueue.main.async { self.isOnExternalPage = false }
            }
            return
        }

        if context.coordinator.lastContent != content || context.coordinator.lastFilePath != filePath || themeChanged {
            context.coordinator.lastContent = content
            context.coordinator.lastFilePath = filePath
            reload(webView: webView)
            DispatchQueue.main.async { self.isOnExternalPage = false }
        }
    }

    private func reload(webView: WKWebView) {
        let baseURL = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        let html: String
        switch renderMode {
        case .canvas:
            html = MarkdownHTMLGenerator.generateCanvasHTML(jsonString: content, theme: theme)
        case .excalidraw:
            if content.hasPrefix("EXCALIDRAW_MD\u{0}") {
                let parts = content.components(separatedBy: "\u{0}")
                let compressed = parts.count > 1 ? parts[1] : ""
                let texts = parts.count > 2 ? parts[2] : ""
                html = MarkdownHTMLGenerator.generateExcalidrawMDHTML(compressedBase64: compressed, textElements: texts, theme: theme)
            } else {
                html = MarkdownHTMLGenerator.generateExcalidrawHTML(jsonString: content, theme: theme)
            }
        case .markdown:
            html = MarkdownStyler.createStyledHTML(from: content, theme: theme)
        }
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: MarkdownWebView
        var lastWebBackTrigger: Int = 0
        var lastContent: String = ""
        var lastFilePath: String = ""
        var lastTheme: String = ""

        init(_ parent: MarkdownWebView) {
            self.parent = parent
            self.lastTheme = parent.theme
            super.init()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "checkboxToggle", let newContent = message.body as? String {
                parent.onContentChanged?(newContent)
            } else if message.name == "wikilinkClick", let noteName = message.body as? String {
                if let url = URL(string: "wikilink:\(noteName)") {
                    parent.onLinkClick?(url)
                }
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, navigationAction.navigationType == .linkActivated {
                if url.scheme == "wikilink" || url.isFileURL {
                    parent.onLinkClick?(url)
                    decisionHandler(.cancel)
                    return
                }
                DispatchQueue.main.async { self.parent.isOnExternalPage = true }
            }
            decisionHandler(.allow)
        }
    }
}

