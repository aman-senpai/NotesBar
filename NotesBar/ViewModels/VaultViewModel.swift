import Foundation
import Combine
import AppKit

class VaultViewModel: ObservableObject {
    @Published var currentVault: VaultSettings?
    @Published var savedVaults: [VaultSettings] = []
    @Published var isVaultSelected: Bool = false
    
    private var cachedNotes: [NoteFile] = []
    
    static let appleNotesVaultId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    var appleNotesVault: VaultSettings {
        VaultSettings(path: "apple-notes", name: "Apple Notes", type: .appleNotes)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadVaultSettings()
    }
    
    func loadVaultSettings() {
        savedVaults = VaultSettings.loadFromDefaults()
        
        // Try to restore the last used vault
        if let lastVaultId = UserDefaults.standard.string(forKey: "lastUsedVaultId"),
           let uuid = UUID(uuidString: lastVaultId) {
            if uuid == Self.appleNotesVaultId {
                switchToVault(appleNotesVault)
            } else if let lastVault = savedVaults.first(where: { $0.id == uuid }) {
                switchToVault(lastVault)
            }
        } else if let firstVault = savedVaults.first {
            switchToVault(firstVault)
        }
    }
    
    func switchToVault(_ vault: VaultSettings) {
        if vault.type == .appleNotes {
            currentVault = vault
            isVaultSelected = true
            UserDefaults.standard.set(Self.appleNotesVaultId.uuidString, forKey: "lastUsedVaultId")
            objectWillChange.send()
            AppleNotesManager.shared.preloadCache()
            NotificationCenter.default.post(name: NSNotification.Name("RefreshVaultFiles"), object: nil)
            return
        }
        
        // Stop accessing the previous vault if any
        if let currentVault = currentVault {
            let currentURL = URL(fileURLWithPath: currentVault.path)
            currentURL.stopAccessingSecurityScopedResource()
        }
        
        // Start accessing the new vault
        _ = URL(fileURLWithPath: vault.path)
        if let bookmarkData = vault.bookmarkData {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    print("Debug: Bookmark is stale, requesting new access")
                    return
                }
                
                guard url.startAccessingSecurityScopedResource() else {
                    print("Debug: Failed to access security-scoped resource from bookmark")
                    return
                }
                
                currentVault = vault
                isVaultSelected = true
                UserDefaults.standard.set(vault.id.uuidString, forKey: "lastUsedVaultId")
                
                // Notify observers that vault has changed
                objectWillChange.send()
                
                // Post notification to trigger file refresh
                NotificationCenter.default.post(name: NSNotification.Name("RefreshVaultFiles"), object: nil)
            } catch {
                print("Debug: Failed to resolve bookmark: \(error.localizedDescription)")
            }
        }
    }
    
    func selectVault() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select your Obsidian vault folder"
        openPanel.prompt = "Select"
        
        if openPanel.runModal() == .OK {
            guard let url = openPanel.url else { return }
            
            do {
                let bookmarkData = try url.bookmarkData(
                    options: [URL.BookmarkCreationOptions.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                guard url.startAccessingSecurityScopedResource() else {
                    print("Debug: Failed to access new vault")
                    return
                }
                
                var vaultSettings = VaultSettings(path: url.path, name: url.lastPathComponent)
                vaultSettings.bookmarkData = bookmarkData
                vaultSettings.saveToDefaults()
                
                savedVaults = VaultSettings.loadFromDefaults()
                switchToVault(vaultSettings)
            } catch {
                print("Error creating bookmark: \(error.localizedDescription)")
            }
        }
    }
    
    func removeVault(_ vault: VaultSettings) {
        if let index = savedVaults.firstIndex(where: { $0.id == vault.id }) {
            savedVaults.remove(at: index)
            
            // If we're removing the current vault, switch to another one if available
            if currentVault?.id == vault.id {
                if let nextVault = savedVaults.first {
                    switchToVault(nextVault)
                } else {
                    currentVault = nil
                    isVaultSelected = false
                }
            }
            
            // Save the updated vault list
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(savedVaults)
                UserDefaults.standard.set(data, forKey: "savedVaults")
            } catch {
                print("Error saving vaults: \(error)")
            }
        }
    }
    
    func fetchAllNotes(completion: @escaping ([NoteFile]) -> Void) {
        var allNotes: [NoteFile] = []
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.notesbar.search", attributes: .concurrent)
        
        let lock = NSLock()
        
        // 1. Fetch Obsidian notes
        for vault in savedVaults {
            if vault.type == .obsidian {
                group.enter()
                queue.async {
                    let files = self.loadObsidianVault(vault)
                    lock.lock()
                    allNotes.append(contentsOf: files)
                    lock.unlock()
                    group.leave()
                }
            }
        }
        
        // 2. Fetch Apple Notes
        group.enter()
        var hasLeftAppleNotes = false
        AppleNotesManager.shared.fetchNotes { notes in
            lock.lock()
            if !hasLeftAppleNotes {
                allNotes.append(contentsOf: notes)
                hasLeftAppleNotes = true
                group.leave()
            }
            lock.unlock()
        }
        
        group.notify(queue: .main) {
            // Flatten files and filter out directories
            var flatFiles: [NoteFile] = []
            func flatten(_ files: [NoteFile]) {
                for file in files {
                    if file.isDirectory {
                        if let children = file.children { flatten(children) }
                    } else {
                        flatFiles.append(file)
                    }
                }
            }
            flatten(allNotes)
            self.cachedNotes = flatFiles
            
            // Index notes for Spotlight
            SpotlightManager.shared.indexNotes(flatFiles)
            
            completion(flatFiles)
        }
    }
    
    func findNote(byId id: String, completion: @escaping (NoteFile?) -> Void) {
        // Try cache first for instant response
        if let cached = cachedNotes.first(where: { $0.id == id }) {
            completion(cached)
            return
        }
        
        fetchAllNotes { notes in
            let note = notes.first { $0.id == id }
            completion(note)
        }
    }
    
    func openNote(_ note: NoteFile) {
        if note.source == .appleNotes {
            AppleNotesManager.shared.openNoteInNotesApp(id: note.id)
        } else {
            FloatingWindowManager.shared.openFloatingWindow(for: note, vaultViewModel: self)
        }
    }
    
    private func loadObsidianVault(_ vault: VaultSettings) -> [NoteFile] {
        let fileManager = FileManager.default
        let vaultURL = URL(fileURLWithPath: vault.path)
        
        var isAccessing = false
        if let bookmarkData = vault.bookmarkData {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
                if !isStale && url.startAccessingSecurityScopedResource() {
                    isAccessing = true
                }
            } catch { }
        }
        
        defer {
            if isAccessing {
                let url = URL(fileURLWithPath: vault.path)
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        func loadDirectoryContents(at url: URL, relativePath: String = "") -> [NoteFile] {
            var files: [NoteFile] = []
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey])
                for itemURL in contents {
                    let isDirectory = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let modificationDate = (try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    
                    if itemURL.lastPathComponent.hasPrefix(".") { continue }
                    
                    let itemRelativePath = relativePath.isEmpty ? itemURL.lastPathComponent : (relativePath as NSString).appendingPathComponent(itemURL.lastPathComponent)
                    
                    if isDirectory {
                        let children = loadDirectoryContents(at: itemURL, relativePath: itemRelativePath)
                        let folder = NoteFile(name: itemURL.lastPathComponent, path: itemURL.path, relativePath: itemRelativePath, isDirectory: true, children: children, source: .obsidian, modificationDate: modificationDate)
                        files.append(folder)
                    } else {
                        let file = NoteFile(name: itemURL.lastPathComponent, path: itemURL.path, relativePath: itemRelativePath, isDirectory: false, children: nil, source: .obsidian, modificationDate: modificationDate)
                        files.append(file)
                    }
                }
            } catch { }
            return files
        }
        
        return loadDirectoryContents(at: vaultURL)
    }
} 
