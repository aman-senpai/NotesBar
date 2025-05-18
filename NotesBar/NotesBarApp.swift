//
//  NoteBarApp.swift
//  NoteBar
//
//  Created by Aman Raj on 18/5/25.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct ObsidianQuickNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vaultViewModel = VaultViewModel()
    @StateObject private var noteViewModel = NoteViewModel()
    @StateObject private var searchViewModel: SearchViewModel
    
    init() {
        let noteVM = NoteViewModel()
        _noteViewModel = StateObject(wrappedValue: noteVM)
        _searchViewModel = StateObject(wrappedValue: SearchViewModel(noteViewModel: noteVM))
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
