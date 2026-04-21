//
//  NoteBarApp.swift
//  NoteBar
//
//  Created by Aman Raj on 18/5/25.
//

import SwiftUI
import CoreSpotlight

@main
struct NotesBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
                .onAppear {
                    appDelegate.vaultViewModel = vaultViewModel
                    GlobalSearchManager.shared.setup(vaultViewModel: vaultViewModel)
                    // Initial indexing
                    vaultViewModel.fetchAllNotes { _ in }
                }
        } label: {
            Image(systemName: "diamond.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
