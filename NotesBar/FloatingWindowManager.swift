//
//  FloatingWindowManager.swift
//  NotesBar
//
//  Manages persistent floating windows for notes
//

import SwiftUI
import AppKit
import WebKit

/// Manages floating note windows that persist independently of the menu bar popover
class FloatingWindowManager: ObservableObject {
    static let shared = FloatingWindowManager()

    @Published private(set) var openWindows: [UUID: NSWindow] = [:]
    private var windowFilePaths: [UUID: String] = [:]

    private init() {}

    /// Opens a note in a new floating window
    func openFloatingWindow(for file: NoteFile, vaultViewModel: VaultViewModel) {
        // Check if window already exists for this file path
        if let existingID = windowFilePaths.first(where: { $0.value == file.path })?.key,
           let existingWindow = openWindows[existingID] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let windowID = UUID()

        let contentView = FloatingNoteView(file: file, windowID: windowID) { [weak self] id in
            self?.closeWindow(id: id)
        }
        .environmentObject(vaultViewModel)

        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = file.name
            .replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: ".canvas", with: "")
            .replacingOccurrences(of: ".excalidraw", with: "")
        window.center()
        window.setFrameAutosaveName("FloatingNote-\(file.path.hashValue)")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 300, height: 200)

        // Normal window level (not always on top)
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Set up close handler
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            if let closingWindow = notification.object as? NSWindow,
               let id = self?.openWindows.first(where: { $0.value === closingWindow })?.key {
                self?.openWindows.removeValue(forKey: id)
                self?.windowFilePaths.removeValue(forKey: id)
            }
        }

        openWindows[windowID] = window
        windowFilePaths[windowID] = file.path
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Opens the vault graph in a new floating window
    func openGraphWindow(viewModel: GraphViewModel) {
        let windowID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")! // Common ID for graph
        
        if let existingWindow = openWindows[windowID] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = GraphView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = "Vault Graph"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        
        // Normal window level
        window.level = .normal
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.openWindows.removeValue(forKey: windowID)
        }

        openWindows[windowID] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes a specific floating window
    func closeWindow(id: UUID) {
        if let window = openWindows[id] {
            window.close()
            openWindows.removeValue(forKey: id)
            windowFilePaths.removeValue(forKey: id)
        }
    }

    /// Closes all floating windows
    func closeAllWindows() {
        for window in openWindows.values {
            window.close()
        }
        openWindows.removeAll()
        windowFilePaths.removeAll()
    }
}

/// The SwiftUI view displayed in floating windows
struct FloatingNoteView: View {
    @State private var history: [NoteFile]
    let windowID: UUID
    let onClose: (UUID) -> Void

    @State private var content: String = ""
    @State private var saveError: String?
    @State private var lastSavedContent: String = ""
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var isEditing: Bool = true
    @AppStorage("editorTheme") private var selectedTheme: String = "system"
    @EnvironmentObject private var vaultViewModel: VaultViewModel
    
    // Navigation state for WebView
    @State private var isOnExternalPage = false
    @State private var webBackTrigger = 0
    @State private var renderMode: PreviewRenderMode = .markdown

    init(file: NoteFile, windowID: UUID, onClose: @escaping (UUID) -> Void) {
        self._history = State(initialValue: [file])
        self.windowID = windowID
        self.onClose = onClose
        
        let ext = file.path.lowercased()
        let isDiagram = ext.hasSuffix(".canvas") || ext.hasSuffix(".excalidraw")
        self._isEditing = State(initialValue: !isDiagram)
    }

    private var currentFile: NoteFile {
        history.last!
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Back button (only in View mode)
                if !isEditing && history.count > 1 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            history.removeLast()
                            loadContent()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.borderless)
                    .help("Back")
                }

                // Edit/View toggle (disabled for diagrams)
                Picker("", selection: $isEditing) {
                    Image(systemName: "pencil").tag(true)
                    Image(systemName: "eye").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 70)
                .disabled(renderMode != .markdown)
                .help(renderMode != .markdown ? "Editing disabled for diagrams" : "")

                // Theme toggle button
                Button(action: {
                    if selectedTheme == "dark" {
                        selectedTheme = "light"
                    } else if selectedTheme == "light" {
                        selectedTheme = "dark"
                    } else {
                        // If system, toggle to the opposite of current system theme
                        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        selectedTheme = isDark ? "light" : "dark"
                    }
                }) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedTheme == "dark" ? .orange : (selectedTheme == "light" ? .blue : .primary))
                }
                .buttonStyle(.borderless)
                .help("Toggle Theme")
                .frame(width: 30)

                Spacer()

                if content != lastSavedContent {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                        Text("Saving...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: { copyToClipboard() }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy to Clipboard")

                Button(action: { openInObsidian() }) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
                .help("Open in Obsidian")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Divider()

            // Content area
            if isEditing {
                TextEditor(text: Binding(
                    get: { content },
                    set: { newValue in
                        content = newValue
                        scheduleAutoSave()
                    }
                ))
                .font(.system(size: 14, design: .monospaced))
                .padding(12)
            } else {
                MarkdownWebView(
                    content: content,
                    filePath: currentFile.path,
                    theme: selectedTheme,
                    renderMode: renderMode,
                    isOnExternalPage: $isOnExternalPage,
                    webBackTrigger: $webBackTrigger,
                    onContentChanged: { newContent in
                        content = newContent
                        lastSavedContent = newContent
                    },
                    onLinkClick: { url in
                        handleLinkClick(url)
                    }
                )
            }

            if let error = saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            loadContent()
        }
        .onDisappear {
            autoSaveTask?.cancel()
        }
        .preferredColorScheme(selectedTheme == "system" ? nil : (selectedTheme == "dark" ? .dark : .light))
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
                isEditing = false
            } else if ext == "excalidraw" {
                renderMode = .excalidraw
                content = rawString
                isEditing = false
            } else if ext == "md" && rawString.contains("excalidraw-plugin:") {
                renderMode = .excalidraw
                isEditing = false
                // Extract compressed-json base64 block
                let compressedBase64: String
                let compressedPattern = "```compressed-json\n([\\s\\S]*?)\n```"
                if let regex = try? NSRegularExpression(pattern: compressedPattern),
                   let match = regex.firstMatch(in: rawString, range: NSRange(rawString.startIndex..., in: rawString)),
                   let range = Range(match.range(at: 1), in: rawString) {
                    compressedBase64 = String(rawString[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    compressedBase64 = ""
                }
                // Extract ## Text Elements section
                var textElements = ""
                if let sectionStart = rawString.range(of: "## Text Elements\n") {
                    let after = rawString[sectionStart.upperBound...]
                    let sectionContent: String
                    if let nextSection = after.range(of: "\n## ") {
                        sectionContent = String(after[..<nextSection.lowerBound])
                    } else if let pct = after.range(of: "\n%%") {
                        sectionContent = String(after[..<pct.lowerBound])
                    } else {
                        sectionContent = String(after)
                    }
                    let idPattern = try? NSRegularExpression(pattern: "\\s+\\^[A-Za-z0-9]+$", options: .anchorsMatchLines)
                    let cleaned = sectionContent.components(separatedBy: "\n").map { line -> String in
                        let ns = line as NSString
                        if let rx = idPattern,
                           let m = rx.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) {
                            return ns.substring(to: m.range.location).trimmingCharacters(in: .whitespaces)
                        }
                        return line.trimmingCharacters(in: .whitespaces)
                    }.filter { !$0.isEmpty }
                    textElements = cleaned.joined(separator: "\n")
                }
                content = "EXCALIDRAW_MD\u{0}\(compressedBase64)\u{0}\(textElements)"
            } else {
                renderMode = .markdown
                content = rawString.replacingOccurrences(of: "\r\n", with: "\n")
            }
            lastSavedContent = content
        } catch {
            renderMode = .markdown
            content = "Error loading content: \(error.localizedDescription)"
        }
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()

        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                saveContent()
            }
        }
    }

    private func saveContent() {
        let fileURL = URL(fileURLWithPath: currentFile.path)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            lastSavedContent = content
            saveError = nil
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func handleLinkClick(_ url: URL) {
        if url.scheme == "wikilink" {
            let noteName = url.absoluteString.replacingOccurrences(of: "wikilink:", with: "").removingPercentEncoding ?? ""
            resolveAndNavigate(to: noteName)
            return
        }
        
        if url.isFileURL {
            let path = url.path
            let newFile = NoteFile(
                name: url.lastPathComponent,
                path: path,
                relativePath: "",
                isDirectory: false,
                children: nil
            )
            navigateTo(newFile)
        }
    }

    private func resolveAndNavigate(to noteName: String) {
        guard let vault = vaultViewModel.currentVault else { return }
        
        let fileManager = FileManager.default
        let nameWithExt = noteName.lowercased().hasSuffix(".md") ? noteName : "\(noteName).md"
        let vaultURL = URL(fileURLWithPath: vault.path)
        
        let enumerator = fileManager.enumerator(at: vaultURL, includingPropertiesForKeys: [.nameKey], options: [.skipsHiddenFiles])
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent.localizedCaseInsensitiveCompare(nameWithExt) == .orderedSame ||
               fileURL.lastPathComponent.localizedCaseInsensitiveCompare(noteName) == .orderedSame {
                
                let newFile = NoteFile(
                    name: fileURL.lastPathComponent,
                    path: fileURL.path,
                    relativePath: fileURL.path.replacingOccurrences(of: vault.path + "/", with: ""),
                    isDirectory: false,
                    children: nil
                )
                navigateTo(newFile)
                return
            }
        }
    }

    private func navigateTo(_ file: NoteFile) {
        withAnimation(.spring(response: 0.3)) {
            history.append(file)
            loadContent()
        }
    }

    private func openInObsidian() {
        let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") ?? ""
        let vaultName = (vaultPath as NSString).lastPathComponent
        let encodedPath = currentFile.relativePath.encodedForObsidianURL()

        if let encodedVaultName = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let urlString = "obsidian://open?vault=\(encodedVaultName)&file=\(encodedPath)"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }
}
