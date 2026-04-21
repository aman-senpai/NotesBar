import Cocoa
import CoreSpotlight

class AppDelegate: NSObject, NSApplicationDelegate {
    var vaultViewModel: VaultViewModel?
    
    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        if userActivity.activityType == CSSearchableItemActionType {
            if let noteId = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                print("Spotlight activity received for note: \(noteId)")
                
                // Ensure we have a view model
                guard let vaultViewModel = vaultViewModel else {
                    print("Error: vaultViewModel not set in AppDelegate")
                    return false
                }
                
                GlobalSearchManager.shared.hideWindow()
                
                vaultViewModel.findNote(byId: noteId) { note in
                    if let note = note {
                        DispatchQueue.main.async {
                            vaultViewModel.openNote(note)
                        }
                    } else {
                        print("Error: Could not find note with ID \(noteId)")
                    }
                }
                return true
            }
        }
        return false
    }
}
