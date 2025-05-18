import Foundation
import Combine
import AppKit

class VaultViewModel: ObservableObject {
    @Published var currentVault: VaultSettings?
    @Published var isVaultSelected: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadVaultSettings()
    }
    
    func loadVaultSettings() {
        if let bookmarkData = UserDefaults.standard.data(forKey: "vaultBookmark") {
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
                
                currentVault = VaultSettings(path: url.path, name: url.lastPathComponent)
                isVaultSelected = true
                
                // Save the path to UserDefaults for backward compatibility
                UserDefaults.standard.set(url.path, forKey: "vaultPath")
                UserDefaults.standard.set(url.lastPathComponent, forKey: "vaultName")
            } catch {
                print("Debug: Failed to resolve bookmark: \(error.localizedDescription)")
            }
        } else if let vaultSettings = VaultSettings.loadFromDefaults() {
            currentVault = vaultSettings
            isVaultSelected = true
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
                // Stop accessing the previous vault if any
                if let currentVault = currentVault {
                    let currentURL = URL(fileURLWithPath: currentVault.path)
                    currentURL.stopAccessingSecurityScopedResource()
                }
                
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
                
                currentVault = vaultSettings
                isVaultSelected = true
                
                // Notify observers that vault has changed
                objectWillChange.send()
            } catch {
                print("Error creating bookmark: \(error.localizedDescription)")
            }
        }
    }
    
    func changeVault() {
        selectVault()
    }
} 