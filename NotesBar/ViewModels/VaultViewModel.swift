import Foundation
import Combine
import AppKit

class VaultViewModel: ObservableObject {
    @Published var currentVault: VaultSettings?
    @Published var savedVaults: [VaultSettings] = []
    @Published var isVaultSelected: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadVaultSettings()
    }
    
    func loadVaultSettings() {
        savedVaults = VaultSettings.loadFromDefaults()
        
        // Try to restore the last used vault
        if let lastVaultId = UserDefaults.standard.string(forKey: "lastUsedVaultId"),
           let uuid = UUID(uuidString: lastVaultId),
           let lastVault = savedVaults.first(where: { $0.id == uuid }) {
            switchToVault(lastVault)
        } else if let firstVault = savedVaults.first {
            switchToVault(firstVault)
        }
    }
    
    func switchToVault(_ vault: VaultSettings) {
        // Stop accessing the previous vault if any
        if let currentVault = currentVault {
            let currentURL = URL(fileURLWithPath: currentVault.path)
            currentURL.stopAccessingSecurityScopedResource()
        }
        
        // Start accessing the new vault
        let newURL = URL(fileURLWithPath: vault.path)
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
} 