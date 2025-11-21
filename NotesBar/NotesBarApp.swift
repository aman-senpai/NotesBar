//
//  NoteBarApp.swift
//  NoteBar
//
//  Created by Aman Raj on 18/5/25.
//

import SwiftUI

@main
struct NotesBarApp: App {
    @StateObject private var vaultViewModel = VaultViewModel()
    @StateObject private var noteViewModel = NoteViewModel()
    @StateObject private var searchViewModel: SearchViewModel
    
    init() {
        let noteVM = NoteViewModel()
        _noteViewModel = StateObject(wrappedValue: noteVM)
        _searchViewModel = StateObject(wrappedValue: SearchViewModel(noteViewModel: noteVM))
        
        // Set activation policy before app launches
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(vaultViewModel)
                .environmentObject(noteViewModel)
                .environmentObject(searchViewModel)
        } label: {
            // Choose one of these icon options:
            
            // Option 1: Diamond/Gem icon (similar to Obsidian's crystal) - RECOMMENDED
            Image(systemName: "diamond.fill")
            
            // Option 2: Hexagon (geometric, modern)
            // Image(systemName: "hexagon.fill")
            
            // Option 3: Square with pen (note-taking)
            // Image(systemName: "square.and.pencil")
            
            // Option 4: Book closed
            // Image(systemName: "book.closed.fill")
            
            // Option 5: Note with text lines
            // Image(systemName: "note.text")
            
            // Option 6: Document with magnifying glass (original)
            // Image(systemName: "doc.text.magnifyingglass")
            
            // Option 7: Custom Obsidian Icon (if you add menubar-icon.png files)
            // Image("MenuBarIcon")
            //     .renderingMode(.template)
            
            // To use a custom icon:
            // 1. Download the Obsidian icon or create your own 18x18 PNG
            // 2. Add it to Assets.xcassets/MenuBarIcon.imageset/ as:
            //    - menubar-icon.png (18x18)
            //    - menubar-icon@2x.png (36x36)
            //    - menubar-icon@3x.png (54x54)
            // 3. Uncomment Option 7 above and comment out other options
        }
        .menuBarExtraStyle(.window)
    }
}
