//
//  ContentView.swift
//  ObsidianQuickNote
//
//  Created by Aman Raj on 18/5/25.
//

import SwiftUI
import Foundation
import AppKit

enum NoteSource: String, Codable {
    case obsidian
    case appleNotes
}

enum SortOption: String, CaseIterable, Codable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case dateDesc = "Date Modified (Newest)"
    case dateAsc = "Date Modified (Oldest)"
}

struct NoteFile: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let relativePath: String
    let isDirectory: Bool
    var children: [NoteFile]?
    var source: NoteSource = .obsidian
    var modificationDate: Date? = nil
    
    init(id: String = UUID().uuidString, name: String, path: String, relativePath: String, isDirectory: Bool, children: [NoteFile]? = nil, source: NoteSource = .obsidian, modificationDate: Date? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.children = children
        self.source = source
        self.modificationDate = modificationDate
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: NoteFile, rhs: NoteFile) -> Bool {
        lhs.id == rhs.id
    }
}

struct ContentView: View {
    @EnvironmentObject private var vaultViewModel: VaultViewModel

    @State private var vaultFiles: [NoteFile] = []
    @State private var searchText = ""
    @State private var expandedFolders: Set<String> = []
    @State private var showGraph = false
    @State private var isLoading = false
    @State private var activePopoverId: String? = nil
    @AppStorage("sortOption") private var sortOption: SortOption = .nameAsc

    private func openOrCreateTodayNote() {
        // Use Obsidian's daily note interface with the simple URI scheme
        if let url = URL(string: "obsidian://daily") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func createNewNote() {
        if let vault = vaultViewModel.currentVault {
            if vault.type == .appleNotes {
                AppleNotesManager.shared.createNewNote()
            } else if let encodedVaultName = vault.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                let urlString = "obsidian://new?vault=\(encodedVaultName)"
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar with Vault Selector and Action Buttons
            HStack {
                Menu {
                    ForEach(vaultViewModel.savedVaults) { vault in
                        Button(action: { vaultViewModel.switchToVault(vault) }) {
                            HStack {
                                Label(vault.name, systemImage: "folder")
                                if vault.id == vaultViewModel.currentVault?.id && vaultViewModel.currentVault?.type == .obsidian {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { vaultViewModel.switchToVault(vaultViewModel.appleNotesVault) }) {
                        HStack {
                            Label("Apple Notes", systemImage: "apple.logo")
                            if vaultViewModel.currentVault?.type == .appleNotes {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { vaultViewModel.selectVault() }) {
                        Label("Add Vault", systemImage: "plus")
                    }
                    
                    if !vaultViewModel.savedVaults.isEmpty {
                        Divider()
                        
                        Menu {
                            ForEach(vaultViewModel.savedVaults) { vault in
                                Button(role: .destructive, action: { vaultViewModel.removeVault(vault) }) {
                                    Label("Remove \(vault.name)", systemImage: "trash")
                                }
                            }
                        } label: {
                            Label("Remove Vault...", systemImage: "trash")
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { SettingsWindowManager.shared.showSettings() }) {
                        Label("Settings...", systemImage: "gear")
                    }
                } label: {
                    HStack {
                        Image(systemName: vaultViewModel.currentVault?.type == .appleNotes ? "apple.logo" : "folder")
                            .foregroundColor(.primary)
                        Text(vaultViewModel.currentVault?.name ?? "Select Vault")
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                                .padding(.leading, 4)
                            Spacer()
                        } else {
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.primary.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(8)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    Menu {
                        Picker("Sort By", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .menuIndicator(.hidden)
                    .help("Sort Notes")

                    ActionButton(
                        icon: "plus",
                        action: { createNewNote() },
                        tooltip: "New Note"
                    )
                    
                    if vaultViewModel.currentVault?.type != .appleNotes {
                        ActionButton(
                            icon: "calendar",
                            action: { openOrCreateTodayNote() },
                            tooltip: "Today's Note"
                        )
                    }
                    
                    ActionButton(
                        icon: "power",
                        action: { NSApplication.shared.terminate(nil) },
                        tooltip: "Quit"
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.primary.opacity(0.5))
                    .font(.system(size: 13, weight: .medium))
                TextField("Search notes...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.primary)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.primary.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
            
            // File List
            if isLoading {
                Spacer()
                ProgressView()
                    .controlSize(.regular)
                    .scaleEffect(1.2)
                Text("Loading Apple Notes...")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.6))
                    .padding(.top, 12)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredFiles) { file in
                            if file.isDirectory {
                                CollapsibleFolderView(
                                    folder: file,
                                    expandedFolders: $expandedFolders,
                                    activePopoverId: $activePopoverId,
                                    level: 0
                                )
                            } else {
                                FileRow(file: file, activePopoverId: $activePopoverId)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 400, height: 600)
        .onAppear {
            loadVaultContents()
            
            // Add observer for vault refresh notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RefreshVaultFiles"),
                object: nil,
                queue: .main
            ) { _ in
                loadVaultContents()
            }
        }
    }
    
    private var filteredFiles: [NoteFile] {
        let filesToSort: [NoteFile]
        
        if searchText.isEmpty {
            filesToSort = vaultFiles
        } else {
            // Flatten all files recursively for search
            func flattenFiles(_ files: [NoteFile]) -> [NoteFile] {
                var result: [NoteFile] = []
                for file in files {
                    if file.isDirectory {
                        if let children = file.children {
                            result.append(contentsOf: flattenFiles(children))
                        }
                    } else {
                        result.append(file)
                    }
                }
                return result
            }

            let allFiles = flattenFiles(vaultFiles)
            let searchTerms = searchText.lowercased().split(separator: " ")

            filesToSort = allFiles.filter { file in
                file.name.lowercased().containsAll(searchTerms)
            }
        }
        
        return sortFiles(filesToSort)
    }
    
    private func sortFiles(_ files: [NoteFile]) -> [NoteFile] {
        let sorted = files.sorted { item1, item2 in
            // Always keep directories above files
            if item1.isDirectory && !item2.isDirectory { return true }
            if !item1.isDirectory && item2.isDirectory { return false }
            
            switch sortOption {
            case .nameAsc:
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            case .nameDesc:
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedDescending
            case .dateDesc:
                let d1 = item1.modificationDate ?? Date.distantPast
                let d2 = item2.modificationDate ?? Date.distantPast
                return d1 > d2
            case .dateAsc:
                let d1 = item1.modificationDate ?? Date.distantPast
                let d2 = item2.modificationDate ?? Date.distantPast
                return d1 < d2
            }
        }
        
        // Recursively sort children
        return sorted.map { file in
            var newFile = file
            if let children = file.children {
                newFile.children = sortFiles(children)
            }
            return newFile
        }
    }
    
    private func loadVaultContents() {
        guard let vault = vaultViewModel.currentVault else { return }
        
        // Clear old files before loading new ones
        vaultFiles = []
        
        if vault.type == .appleNotes {
            isLoading = true
            AppleNotesManager.shared.fetchNotes { notes in
                // Ensure we haven't switched away from Apple Notes before the fetch completes
                guard self.vaultViewModel.currentVault?.id == vault.id else { return }
                self.vaultFiles = notes
                self.isLoading = false
            }
            return
        }
        
        let fileManager = FileManager.default
        let vaultURL = URL(fileURLWithPath: vault.path)
        
        func loadDirectoryContents(at url: URL, relativePath: String = "") -> [NoteFile]? {
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey])
                return contents.compactMap { url -> NoteFile? in
                    let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let modificationDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    
                    // Skip any file or directory starting with a dot
                    if url.lastPathComponent.hasPrefix(".") {
                        return nil
                    }
                    
                    // Construct proper relative path
                    let itemRelativePath = relativePath.isEmpty ? url.lastPathComponent : (relativePath as NSString).appendingPathComponent(url.lastPathComponent)
                    
                    if isDirectory {
                        // Recursively load children for directories
                        let children = loadDirectoryContents(at: url, relativePath: itemRelativePath)
                        return NoteFile(
                            name: url.lastPathComponent,
                            path: url.path,
                            relativePath: itemRelativePath,
                            isDirectory: true,
                            children: children,
                            modificationDate: modificationDate
                        )
                    } else {
                        // Also skip common non-markdown hidden files if needed, 
                        // but sticking to prefix check as requested.
                        return NoteFile(
                            name: url.lastPathComponent,
                            path: url.path,
                            relativePath: itemRelativePath,
                            isDirectory: false,
                            children: nil,
                            modificationDate: modificationDate
                        )
                    }
                }
            } catch {
                print("Error loading directory contents: \(error.localizedDescription)")
                return nil
            }
        }
        
        if let files = loadDirectoryContents(at: vaultURL) {
            vaultFiles = files
            isLoading = false
        } else {
            isLoading = false
        }
    }
}

struct CollapsibleFolderView: View {
    let folder: NoteFile
    @Binding var expandedFolders: Set<String>
    @Binding var activePopoverId: String?
    let level: Int
    @State private var isHovered = false
    @EnvironmentObject private var vaultViewModel: VaultViewModel
    
    private var isExpanded: Bool {
        expandedFolders.contains(folder.path)
    }
    
    private var indentation: CGFloat {
        CGFloat(level) * 16
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Folder header
            Button(action: {
                toggleExpanded()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.primary.opacity(0.6))
                        .frame(width: 12)
                    
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .foregroundColor(.primary)
                    
                    Text(folder.name)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(folder.children?.count ?? 0)")
                        .foregroundColor(.primary.opacity(0.6))
                        .font(.caption)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .padding(.leading, indentation)
                .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isHovered = hovering
            }
            .contextMenu {
                Button("Open in Obsidian") {
                    openFolder(folder)
                }
            }
            
            // Folder contents (when expanded)
            if isExpanded, let children = folder.children {
                ForEach(children) { child in
                    if child.isDirectory {
                        CollapsibleFolderView(
                            folder: child,
                            expandedFolders: $expandedFolders,
                            activePopoverId: $activePopoverId,
                            level: level + 1
                        )
                    } else {
                        FileRow(file: child, activePopoverId: $activePopoverId)
                            .padding(.leading, indentation + 16)
                    }
                }
            }
        }
    }
    
    private func toggleExpanded() {
        if isExpanded {
            expandedFolders.remove(folder.path)
        } else {
            expandedFolders.insert(folder.path)
        }
    }
    
    private func openFolder(_ folder: NoteFile) {
        let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") ?? ""
        let vaultName = (vaultPath as NSString).lastPathComponent
        let encodedPath = folder.relativePath.encodedForObsidianURL()

        if let encodedVaultName = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let urlString = "obsidian://open?vault=\(encodedVaultName)&file=\(encodedPath)"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                return
            }
        }

        let folderURL = URL(fileURLWithPath: folder.path)
        let obsidianURL = URL(fileURLWithPath: "/Applications/Obsidian.app")
        let config = NSWorkspace.OpenConfiguration()
        
        NSWorkspace.shared.open([folderURL], withApplicationAt: obsidianURL, configuration: config) { _, error in
            if let error = error {
                print("Error opening folder: \(error.localizedDescription)")
            }
        }
    }
}

struct FileRow: View {
    @EnvironmentObject private var vaultViewModel: VaultViewModel
    let file: NoteFile
    @Binding var activePopoverId: String?
    @State private var isHovered = false
    @State private var isPreviewHovered = false
    @State private var showWorkItem: DispatchWorkItem?
    @State private var hideWorkItem: DispatchWorkItem?

    var body: some View {
        HStack(spacing: 8) {
            let ext = (file.name as NSString).pathExtension.lowercased()
            let icon: String = {
                if file.source == .appleNotes { return "apple.logo" }
                switch ext {
                case "canvas": return "square.grid.2x2"
                case "excalidraw": return "scribble.variable"
                default: return "doc.text"
                }
            }()
            
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.primary.opacity(0.7))
                
            let displayName = file.name
                .replacingOccurrences(of: ".md", with: "")
                .replacingOccurrences(of: ".canvas", with: "")
                .replacingOccurrences(of: ".excalidraw", with: "")
                
            Text(displayName)
                .font(.system(size: 13))
                .foregroundColor(.primary.opacity(0.9))
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(isHovered ? Color.primary.opacity(0.12) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            // Cancel any pending work and close preview
            showWorkItem?.cancel()
            showWorkItem = nil
            hideWorkItem?.cancel()
            hideWorkItem = nil
            activePopoverId = nil
            
            if file.source == .appleNotes {
                AppleNotesManager.shared.openNoteInNotesApp(id: file.id)
            } else {
                FloatingWindowManager.shared.openFloatingWindow(for: file, vaultViewModel: vaultViewModel)
            }
        }
        .onHover { hovering in
            isHovered = hovering

            // Cancel both pending show and hide on every state change
            showWorkItem?.cancel()
            showWorkItem = nil
            hideWorkItem?.cancel()
            hideWorkItem = nil

            if hovering {
                // Debounce show: only open popover after cursor rests for 400ms
                let work = DispatchWorkItem {
                    if self.isHovered {
                        self.activePopoverId = self.file.id
                    }
                }
                showWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
            } else {
                // Debounce hide: allow brief gap when moving to popover
                let work = DispatchWorkItem {
                    if !self.isHovered && !self.isPreviewHovered {
                        if self.activePopoverId == self.file.id {
                            self.activePopoverId = nil
                        }
                    }
                }
                hideWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
            }
        }
        .popover(isPresented: Binding(
            get: { activePopoverId == file.id },
            set: { newValue in
                if !newValue && activePopoverId == file.id {
                    activePopoverId = nil
                }
            }
        ), arrowEdge: .trailing) {
            MarkdownPreviewView(file: file) {
                activePopoverId = nil
                if file.source == .appleNotes {
                    AppleNotesManager.shared.openNoteInNotesApp(id: file.id)
                } else {
                    FloatingWindowManager.shared.openFloatingWindow(for: file, vaultViewModel: vaultViewModel)
                }
            }
            .onHover { hovering in
                isPreviewHovered = hovering
                if !hovering && !isHovered {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !self.isHovered && !self.isPreviewHovered {
                            if self.activePopoverId == self.file.id {
                                self.activePopoverId = nil
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func openNote(_ note: NoteFile) {
        // Placeholder for noteViewModel which seems to be missing in FileRow
        // noteViewModel.openNote(note, vaultName: vaultName)
        print("Opening note: \(note.name)")
        // let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") ?? ""
        // let vaultName = (vaultPath as NSString).lastPathComponent
        // noteViewModel.openNote(note, vaultName: vaultName)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Obsidian Quick Note")
                .font(.title)
            
            Text("Version 0.3")
                .foregroundColor(.secondary)
            
            Text("A quick way to access your Obsidian notes")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Close") {
                dismiss()
            }
        }
    }

}





#Preview {
    ContentView()
}
