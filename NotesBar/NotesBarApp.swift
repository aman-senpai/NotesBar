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
        
        // Ensure the app doesn't appear in the dock
        NSApp.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(vaultViewModel)
                .environmentObject(noteViewModel)
                .environmentObject(searchViewModel)
        } label: {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                if let vault = vaultViewModel.currentVault {
                    Text(vault.name)
                } else {
                    Text("NotesBar")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
