import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

class SpotlightManager {
    static let shared = SpotlightManager()
    
    private let isIndexingEnabledKey = "isSpotlightIndexingEnabled"
    private let isTabSearchEnabledKey = "isSpotlightTabSearchEnabled"
    
    private init() {}
    
    func indexNotes(_ notes: [NoteFile]) {
        let isIndexingEnabled = UserDefaults.standard.bool(forKey: isIndexingEnabledKey)
        
        if !isIndexingEnabled {
            clearIndex()
            return
        }
        
        // Run indexing on a background thread
        DispatchQueue.global(qos: .utility).async {
            let searchableItems = notes.compactMap { note -> CSSearchableItem? in
                guard !note.isDirectory else { return nil }
                
                let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
                let displayName = note.name
                    .replacingOccurrences(of: ".md", with: "")
                    .replacingOccurrences(of: ".canvas", with: "")
                    .replacingOccurrences(of: ".excalidraw", with: "")
                
                attributeSet.title = displayName
                attributeSet.contentDescription = "Note in \(note.source == .appleNotes ? "Apple Notes" : "Obsidian")"
                
                // Add keywords for better discoverability
                attributeSet.keywords = [displayName, "NotesBar", note.source.rawValue]
                
                return CSSearchableItem(
                    uniqueIdentifier: note.id,
                    domainIdentifier: "com.notesbar.notes",
                    attributeSet: attributeSet
                )
            }
            
            // First clear old items, then index new ones
            CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.notesbar.notes"]) { _ in
                CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
                    if let error = error {
                        print("Spotlight indexing error: \(error.localizedDescription)")
                    } else {
                        print("Spotlight indexed \(searchableItems.count) notes")
                    }
                }
            }
        }
    }
    
    func clearIndex() {
        CSSearchableIndex.default().deleteAllSearchableItems(completionHandler: nil)
    }
}
