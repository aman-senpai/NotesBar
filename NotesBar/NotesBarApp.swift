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

    init() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(vaultViewModel)
        } label: {
            Image(systemName: "diamond.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
