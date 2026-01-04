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
    func openFloatingWindow(for file: NoteFile) {
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

        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = file.name.replacingOccurrences(of: ".md", with: "")
        window.center()
        window.setFrameAutosaveName("FloatingNote-\(file.path.hashValue)")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 300, height: 200)

        // Make window float above others but not always on top
        window.level = .floating
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
    let file: NoteFile
    let windowID: UUID
    let onClose: (UUID) -> Void

    @State private var content: String = ""
    @State private var saveError: String?
    @State private var lastSavedContent: String = ""
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var isEditing: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Edit/View toggle
                Picker("", selection: $isEditing) {
                    Image(systemName: "pencil").tag(true)
                    Image(systemName: "eye").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 70)

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
                } else {
                    Text("Saved")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { openInObsidian() }) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
                .help("Open in Obsidian")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

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
                MarkdownWebView(content: content, filePath: file.path) { newContent in
                    content = newContent
                    lastSavedContent = newContent
                }
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
    }

    private func loadContent() {
        let fileURL = URL(fileURLWithPath: file.path)
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
            content = content.replacingOccurrences(of: "\r\n", with: "\n")
            lastSavedContent = content
        } catch {
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
        let fileURL = URL(fileURLWithPath: file.path)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            lastSavedContent = content
            saveError = nil
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func openInObsidian() {
        let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") ?? ""
        let vaultName = (vaultPath as NSString).lastPathComponent
        let encodedPath = file.relativePath.encodedForObsidianURL()

        if let encodedVaultName = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let urlString = "obsidian://open?vault=\(encodedVaultName)&file=\(encodedPath)"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
