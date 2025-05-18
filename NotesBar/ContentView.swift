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
    
    private func openOrCreateTodayNote() {
        // Use Obsidian's daily note interface with the simple URI scheme
        if let url = URL(string: "obsidian://daily") {
            NSWorkspace.shared.open(url)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar with Vault Selector and Action Buttons
            HStack {
                Button(action: { vaultViewModel.selectVault() }) {
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
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: { openOrCreateTodayNote() }) {
                        Image(systemName: "calendar")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Today's Note")
                    
                    Button(action: { loadVaultContents() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Refresh Notes")
                    
                    Button(action: { showAbout = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("About")
                    
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Quit")
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
                            FolderView(folder: file)
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

struct FolderView: View {
    let folder: NoteFile
    @State private var isHovered = false
    @State private var showPopover = false
    @State private var searchText = ""
    @State private var isPopoverHovered = false
    @State private var hideWorkItem: DispatchWorkItem?
    @State private var isInteracting = false
    
    var body: some View {
        Button(action: {
            openFolder(folder)
        }) {
            HStack {
                Image(systemName: "folder.fill")
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
            .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
            
            // Cancel any pending hide work
            hideWorkItem?.cancel()
            
            if (hovering || isPopoverHovered || isInteracting) && (folder.children?.count ?? 0) > 0 {
                showPopover = true
            } else {
                // Create a new work item for hiding the popover
                let workItem = DispatchWorkItem {
                    if !isInteracting {
                        showPopover = false
                    }
                }
                hideWorkItem = workItem
                
                // Schedule the work item with a longer delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            FolderPopoverView(
                folder: folder,
                searchText: $searchText,
                isHovered: $isPopoverHovered,
                isInteracting: $isInteracting
            )
            .frame(width: 300, height: 400)
        }
        .contextMenu {
            FolderContextMenu(folder: folder)
        }
    }
    
    private func openFolder(_ folder: NoteFile) {
        let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") ?? ""
        let vaultName = (vaultPath as NSString).lastPathComponent
        
        // Get the relative path and ensure it starts with a forward slash
        var relativePath = folder.relativePath
        if !relativePath.hasPrefix("/") {
            relativePath = "/" + relativePath
        }
        
        // Remove leading slash for the URL
        if relativePath.hasPrefix("/") {
            relativePath = String(relativePath.dropFirst())
        }
        
        // Properly encode the path components
        let encodedPath = relativePath
            .components(separatedBy: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }
            .joined(separator: "%2F")
        
        // Create and open the Obsidian URL
        if let encodedVaultName = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let urlString = "obsidian://open?vault=\(encodedVaultName)&file=\(encodedPath)"
            if let url = URL(string: urlString) {
                print("Opening URL: \(urlString)") // Debug print
                NSWorkspace.shared.open(url)
                return
            }
        }
        
        // Fallback: Try to open the folder directly
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

struct FolderPopoverView: View {
    let folder: NoteFile
    @Binding var searchText: String
    @Binding var isHovered: Bool
    @Binding var isInteracting: Bool
    @EnvironmentObject private var noteViewModel: NoteViewModel
    @State private var shouldDismiss = false
    
    var filteredItems: [NoteFile] {
        guard let children = folder.children else { return [] }
        if searchText.isEmpty {
            return children.sorted { item1, item2 in
                if item1.isDirectory && !item2.isDirectory {
                    return true
                } else if !item1.isDirectory && item2.isDirectory {
                    return false
                } else {
                    return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                }
            }
        }
        
        return children.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText)
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search in \(folder.name)...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            // File list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredItems) { item in
                        if item.isDirectory {
                            FolderPopoverItemView(item: item)
                        } else {
                            Button(action: {
                                isInteracting = true
                                openItem(item)
                                shouldDismiss = true
                            }) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.gray)
                                    Text(item.name.replacingOccurrences(of: ".md", with: ""))
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider()
                        }
                    }
                }
            }
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                isInteracting = true
            }
        }
        .onTapGesture {
            isInteracting = true
        }
        .onChange(of: shouldDismiss) { oldValue, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let window = NSApp.windows.first(where: { $0.isKind(of: NSPopover.self) }) {
                        window.close()
                    }
                }
            }
        }
    }
    
    private func openItem(_ item: NoteFile) {
        let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") ?? ""
        let vaultName = (vaultPath as NSString).lastPathComponent
        noteViewModel.openNote(item, vaultName: vaultName)
    }
}

struct FolderPopoverItemView: View {
    let item: NoteFile
    @State private var isHovered = false
    @State private var showPopover = false
    @State private var searchText = ""
    @State private var isPopoverHovered = false
    @State private var hideWorkItem: DispatchWorkItem?
    @State private var isInteracting = false
    @State private var shouldDismiss = false
    @EnvironmentObject private var noteViewModel: NoteViewModel
    
    var body: some View {
        Button(action: {
            openFolder(item)
            shouldDismiss = true
        }) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.white)
                Text(item.name)
                    .foregroundColor(.white)
                Spacer()
                Text("\(item.children?.count ?? 0)")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.caption)
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
            
            if (hovering || isPopoverHovered || isInteracting) && (item.children?.count ?? 0) > 0 {
                showPopover = true
            } else {
                // Create a new work item for hiding the popover
                let workItem = DispatchWorkItem {
                    if !isInteracting {
                        showPopover = false
                    }
                }
                hideWorkItem = workItem
                
                // Schedule the work item with a longer delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            FolderPopoverView(
                folder: item,
                searchText: $searchText,
                isHovered: $isPopoverHovered,
                isInteracting: $isInteracting
            )
            .frame(width: 300, height: 400)
        }
        .onChange(of: shouldDismiss) { oldValue, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let window = NSApp.windows.first(where: { $0.isKind(of: NSPopover.self) }) {
                        window.close()
                    }
                }
            }
        }
        Divider()
    }
    
    private func openFolder(_ folder: NoteFile) {
        let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") ?? ""
        let vaultName = (vaultPath as NSString).lastPathComponent
        noteViewModel.openNote(folder, vaultName: vaultName)
    }
}

struct FolderContextMenu: NSViewRepresentable {
    let folder: NoteFile
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        let menu = NSMenu()
        
        // Add search field
        let searchItem = NSMenuItem()
        let searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        searchField.placeholderString = "Search in \(folder.name)..."
        searchField.target = context.coordinator
        searchField.action = #selector(Coordinator.searchChanged(_:))
        searchField.cell?.focusRingType = .none
        searchField.isEditable = false
        searchItem.view = searchField
        menu.addItem(searchItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add folder contents
        if let children = folder.children {
            let sortedItems = children.sorted { item1, item2 in
                if item1.isDirectory && !item2.isDirectory {
                    return true
                } else if !item1.isDirectory && item2.isDirectory {
                    return false
                } else {
                    return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                }
            }
            
            for item in sortedItems {
                let menuItem = NSMenuItem(
                    title: item.isDirectory ? item.name : item.name.replacingOccurrences(of: ".md", with: ""),
                    action: #selector(Coordinator.openItem(_:)),
                    keyEquivalent: ""
                )
                
                menuItem.target = context.coordinator
                menuItem.representedObject = item
                
                // Set appropriate icon and add count for folders
                if item.isDirectory {
                    menuItem.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
                    if let count = item.children?.count {
                        menuItem.title = "\(item.name) (\(count))"
                    }
                } else {
                    menuItem.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: nil)
                }
                
                menu.addItem(menuItem)
            }
        }
        
        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: nsView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(folder: folder)
    }
    
    class Coordinator: NSObject {
        let folder: NoteFile
        
        init(folder: NoteFile) {
            self.folder = folder
        }
        
        @objc func searchChanged(_ sender: NSSearchField) {
            // Implement search functionality if needed
        }
        
        @objc func openItem(_ sender: NSMenuItem) {
            guard let item = sender.representedObject as? NoteFile else { return }
            
            if item.isDirectory {
                if let url = URL(string: "obsidian://open?vault=\(item.name)") {
                    NSWorkspace.shared.open(url)
                }
            } else {
                if let url = URL(string: "obsidian://open?vault=\(folder.name)&file=\(item.relativePath)") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

struct FileRow: View {
    let file: NoteFile
    @State private var isHovered = false
    @State private var showPreview = false
    @State private var isPreviewHovered = false
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
            if hovering {
                showPreview = true
            } else if !isPreviewHovered {
                // Only hide if not hovering over preview
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if !isHovered && !isPreviewHovered {
                        showPreview = false
                    }
                }
            }
        }
        .popover(isPresented: $showPreview, arrowEdge: .trailing) {
            MarkdownPreviewView(file: file)
                .onHover { hovering in
                    isPreviewHovered = hovering
                    if !hovering && !isHovered {
                        showPreview = false
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

#Preview {
    ContentView()
}
