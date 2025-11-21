//
//  ContentView.swift
//  ObsidianQuickNote
//
//  Created by Aman Raj on 18/5/25.
//

import SwiftUI
import Foundation
import AppKit

struct NoteFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let relativePath: String
    let isDirectory: Bool
    var children: [NoteFile]?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: NoteFile, rhs: NoteFile) -> Bool {
        lhs.id == rhs.id
    }
}

struct ContentView: View {
    @EnvironmentObject private var vaultViewModel: VaultViewModel
    @State private var showVaultPicker = false
    @State private var vaultFiles: [NoteFile] = []
    @State private var searchText = ""
    @State private var showAbout = false
    @State private var expandedFolders: Set<String> = []
    
    private func openOrCreateTodayNote() {
        // Use Obsidian's daily note interface with the simple URI scheme
        if let url = URL(string: "obsidian://daily") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func createNewNote() {
        // Create a new note in Obsidian
        if let vault = vaultViewModel.currentVault,
           let encodedVaultName = vault.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let urlString = "obsidian://new?vault=\(encodedVaultName)"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
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
                                Text(vault.name)
                                if vault.id == vaultViewModel.currentVault?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { vaultViewModel.selectVault() }) {
                        Label("Add Vault", systemImage: "plus")
                    }
                    
                    if !vaultViewModel.savedVaults.isEmpty {
                        Divider()
                        
                        ForEach(vaultViewModel.savedVaults) { vault in
                            Button(action: { vaultViewModel.removeVault(vault) }) {
                                Label("Remove \(vault.name)", systemImage: "minus")
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.white)
                        Text(vaultViewModel.currentVault?.name ?? "Select Vault")
                            .lineLimit(1)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    ActionButton(
                        icon: "plus.circle",
                        action: { createNewNote() },
                        tooltip: "New Note"
                    )
                    
                    ActionButton(
                        icon: "calendar",
                        action: { openOrCreateTodayNote() },
                        tooltip: "Today's Note"
                    )
                    
                    ActionButton(
                        icon: "arrow.clockwise",
                        action: { loadVaultContents() },
                        tooltip: "Refresh Notes"
                    )
                    
                    ActionButton(
                        icon: "info.circle",
                        action: { showAbout = true },
                        tooltip: "About"
                    )
                    
                    ActionButton(
                        icon: "xmark.circle",
                        action: { NSApplication.shared.terminate(nil) },
                        tooltip: "Quit"
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                TextField("Search notes...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 2)
            .padding(.bottom, 4)
            
            // File List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredFiles) { file in
                        if file.isDirectory {
                            CollapsibleFolderView(
                                folder: file,
                                expandedFolders: $expandedFolders,
                                level: 0
                            )
                        } else {
                            FileRow(file: file)
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
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }
    
    private var filteredFiles: [NoteFile] {
        if searchText.isEmpty {
            return vaultFiles.sorted { item1, item2 in
                if item1.isDirectory && !item2.isDirectory {
                    return true
                } else if !item1.isDirectory && item2.isDirectory {
                    return false
                } else {
                    return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                }
            }
        }
        
        let searchTerms = searchText.lowercased().split(separator: " ")
        return vaultFiles.filter { file in
            file.name.lowercased().containsAll(searchTerms)
        }.sorted { item1, item2 in
            if item1.isDirectory && !item2.isDirectory {
                return true
            } else if !item1.isDirectory && item2.isDirectory {
                return false
            } else {
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        }
    }
    
    private func loadVaultContents() {
        guard let vault = vaultViewModel.currentVault else { return }
        
        let fileManager = FileManager.default
        let vaultURL = URL(fileURLWithPath: vault.path)
        
        func loadDirectoryContents(at url: URL, relativePath: String = "") -> [NoteFile]? {
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                return contents.compactMap { url -> NoteFile? in
                    let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    
                    // Skip directories starting with a dot
                    if isDirectory && url.lastPathComponent.hasPrefix(".") {
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
                            children: children
                        )
                    } else {
                        return NoteFile(
                            name: url.lastPathComponent,
                            path: url.path,
                            relativePath: itemRelativePath,
                            isDirectory: false,
                            children: nil
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
        }
    }
}

struct CollapsibleFolderView: View {
    let folder: NoteFile
    @Binding var expandedFolders: Set<String>
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
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 12)
                    
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .foregroundColor(.white)
                    
                    Text(folder.name)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(folder.children?.count ?? 0)")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .padding(.leading, indentation)
                .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
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
                ForEach(children.sorted { item1, item2 in
                    if item1.isDirectory && !item2.isDirectory {
                        return true
                    } else if !item1.isDirectory && item2.isDirectory {
                        return false
                    } else {
                        return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                    }
                }) { child in
                    if child.isDirectory {
                        CollapsibleFolderView(
                            folder: child,
                            expandedFolders: $expandedFolders,
                            level: level + 1
                        )
                    } else {
                        FileRow(file: child)
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
        
        var relativePath = folder.relativePath
        if !relativePath.hasPrefix("/") {
            relativePath = "/" + relativePath
        }
        
        if relativePath.hasPrefix("/") {
            relativePath = String(relativePath.dropFirst())
        }
        
        let encodedPath = relativePath
            .components(separatedBy: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }
            .joined(separator: "%2F")
        
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
    let file: NoteFile
    @State private var isHovered = false
    @State private var showPreview = false
    @State private var isPreviewHovered = false
    @State private var hideWorkItem: DispatchWorkItem?
    @State private var mouseExitTime: Date?
    @EnvironmentObject private var noteViewModel: NoteViewModel
    
    var body: some View {
        Button(action: {
            openNote(file)
        }) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.white)
                Text(file.name.replacingOccurrences(of: ".md", with: ""))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
            
            // Cancel any pending hide work
            hideWorkItem?.cancel()
            hideWorkItem = nil
            
            if hovering {
                mouseExitTime = nil
                showPreview = true
            } else {
                let currentExitTime = Date()
                mouseExitTime = currentExitTime
                // Create a new work item for hiding the preview
                let workItem = DispatchWorkItem {
                    if !self.isHovered && !self.isPreviewHovered {
                        if let exitTime = self.mouseExitTime, exitTime == currentExitTime {
                            self.showPreview = false
                        }
                    }
                }
                hideWorkItem = workItem
                
                // Schedule the work item with a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
            }
        }
        .popover(isPresented: $showPreview, arrowEdge: .trailing) {
            MarkdownPreviewView(file: file)
                .onHover { hovering in
                    isPreviewHovered = hovering
                    if !hovering && !isHovered {
                        // Add slight delay before hiding
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            if !self.isHovered && !self.isPreviewHovered {
                                self.showPreview = false
                            }
                        }
                    }
                }
        }
    }
    
    private func openNote(_ note: NoteFile) {
        let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") ?? ""
        let vaultName = (vaultPath as NSString).lastPathComponent
        noteViewModel.openNote(note, vaultName: vaultName)
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
            
            Text("Version 1.0")
                .foregroundColor(.secondary)
            
            Text("A quick way to access your Obsidian notes")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
        .frame(width: 300, height: 300)
    }
}

// MARK: - String Extension
extension String {
    func containsAll(_ substrings: [Substring]) -> Bool {
        substrings.allSatisfy { substring in
            self.contains(substring)
        }
    }
}

// MARK: - Action Button Component
struct ActionButton: View {
    let icon: String
    let action: () -> Void
    let tooltip: String
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .padding(6)
                .background(isHovered ? Color.white.opacity(0.2) : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    ContentView()
}
