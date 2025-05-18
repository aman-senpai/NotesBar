import Foundation
import Combine
import AppKit

class NoteViewModel: ObservableObject {
    @Published var rootFiles: [NoteFile] = []
    @Published var searchResults: [NoteFile] = []
    @Published var isSearching: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let fileManager = FileManager.default
    
    func loadNotes(from vaultPath: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let files = self.scanDirectory(at: vaultPath, relativePath: "")
            
            DispatchQueue.main.async {
                self.rootFiles = files
            }
        }
    }
    
    func searchNotes(query: String, in vaultPath: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let results = self.performSearch(query: query.lowercased(), in: vaultPath)
            
            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
    
    func openNote(_ note: NoteFile, vaultName: String) {
        // Debug logging
        print("Opening note:")
        print("Vault Name: \(vaultName)")
        print("Relative Path: \(note.relativePath)")
        
        // Get the relative path and ensure it starts with a forward slash
        var relativePath = note.relativePath
        if !relativePath.hasPrefix("/") {
            relativePath = "/" + relativePath
        }
        
        // Remove .md extension and leading slash for the URL
        relativePath = relativePath.replacingOccurrences(of: ".md", with: "")
        if relativePath.hasPrefix("/") {
            relativePath = String(relativePath.dropFirst())
        }
        
        // Properly encode the path components
        let encodedPath = relativePath
            .components(separatedBy: "/")
            .map { component in
                // First decode any existing encoding to avoid double encoding
                let decoded = component.removingPercentEncoding ?? component
                // Then encode the decoded component
                return decoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? component
            }
            .joined(separator: "%2F")
        
        print("Encoded Path: \(encodedPath)")
        
        // Create and open the Obsidian URL
        if let encodedVaultName = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let urlString = "obsidian://open?vault=\(encodedVaultName)&file=\(encodedPath)"
            print("URL String: \(urlString)")
            
            if let url = URL(string: urlString) {
                print("Opening URL: \(url)")
                NSWorkspace.shared.open(url)
                
                // Activate Obsidian
                let obsidianURL = URL(fileURLWithPath: "/Applications/Obsidian.app")
                if FileManager.default.fileExists(atPath: obsidianURL.path) {
                    do {
                        try NSWorkspace.shared.launchApplication(at: obsidianURL, options: .default, configuration: [:])
                    } catch {
                        print("Error launching Obsidian: \(error.localizedDescription)")
                    }
                }
                return
            } else {
                print("Failed to create URL from string: \(urlString)")
            }
        } else {
            print("Failed to encode vault name")
        }
        
        // Fallback: Try to open the file directly
        print("Attempting fallback: Opening file directly")
        let fileURL = URL(fileURLWithPath: note.path)
        let obsidianURL = URL(fileURLWithPath: "/Applications/Obsidian.app")
        
        if FileManager.default.fileExists(atPath: obsidianURL.path) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            NSWorkspace.shared.open([fileURL], withApplicationAt: obsidianURL, configuration: config) { _, error in
                if let error = error {
                    print("Error opening file: \(error.localizedDescription)")
                } else {
                    print("Successfully opened file directly")
                }
            }
        } else {
            print("Obsidian app not found at expected location")
        }
    }
    
    private func scanDirectory(at path: String, relativePath: String) -> [NoteFile] {
        var files: [NoteFile] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            
            for item in contents {
                // Skip files and directories that start with a dot (like .gitignore, .git, etc.)
                if item.hasPrefix(".") {
                    continue
                }
                
                let fullPath = (path as NSString).appendingPathComponent(item)
                let itemRelativePath = relativePath.isEmpty ? item : (relativePath as NSString).appendingPathComponent(item)
                
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory)
                
                let noteFile = NoteFile(
                    name: item,
                    path: fullPath,
                    relativePath: itemRelativePath,
                    isDirectory: isDirectory.boolValue,
                    children: isDirectory.boolValue ? scanDirectory(at: fullPath, relativePath: itemRelativePath) : nil
                )
                
                files.append(noteFile)
            }
        } catch {
            print("Error scanning directory: \(error.localizedDescription)")
        }
        
        return files.sorted { item1, item2 in
            if item1.isDirectory && !item2.isDirectory {
                return true
            } else if !item1.isDirectory && item2.isDirectory {
                return false
            } else {
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        }
    }
    
    private func performSearch(query: String, in vaultPath: String) -> [NoteFile] {
        var results: [NoteFile] = []
        
        func searchInDirectory(_ path: String, relativePath: String) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                
                for item in contents {
                    // Skip files and directories that start with a dot (like .gitignore, .git, etc.)
                    if item.hasPrefix(".") {
                        continue
                    }
                    
                    let fullPath = (path as NSString).appendingPathComponent(item)
                    let itemRelativePath = relativePath.isEmpty ? item : (relativePath as NSString).appendingPathComponent(item)
                    
                    var isDirectory: ObjCBool = false
                    fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory)
                    
                    if !isDirectory.boolValue {
                        // Check if filename matches
                        let filenameMatches = item.lowercased().contains(query)
                        
                        // Check if content matches
                        var contentMatches = false
                        if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                            contentMatches = content.lowercased().contains(query)
                        }
                        
                        if filenameMatches || contentMatches {
                            let noteFile = NoteFile(
                                name: item,
                                path: fullPath,
                                relativePath: itemRelativePath,
                                isDirectory: false,
                                children: nil
                            )
                            results.append(noteFile)
                        }
                    } else if isDirectory.boolValue {
                        searchInDirectory(fullPath, relativePath: itemRelativePath)
                    }
                }
            } catch {
                print("Error searching directory: \(error.localizedDescription)")
            }
        }
        
        searchInDirectory(vaultPath, relativePath: "")
        return results
    }
} 