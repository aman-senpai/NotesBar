import SwiftUI

struct SettingsView: View {
    @AppStorage("isGlobalSearchEnabled") private var isGlobalSearchEnabled: Bool = true
    @AppStorage("isSpotlightIndexingEnabled") private var isSpotlightIndexingEnabled: Bool = true
    @AppStorage("isSpotlightTabSearchEnabled") private var isSpotlightTabSearchEnabled: Bool = true

    var body: some View {
        TabView {
            GeneralSettingsView(
                isGlobalSearchEnabled: $isGlobalSearchEnabled
            )
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .tag("general")
            
            SpotlightSettingsView(
                isSpotlightIndexingEnabled: $isSpotlightIndexingEnabled,
                isSpotlightTabSearchEnabled: $isSpotlightTabSearchEnabled
            )
            .tabItem {
                Label("Spotlight", systemImage: "magnifyingglass")
            }
            .tag("spotlight")
        }
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsView: View {
    @Binding var isGlobalSearchEnabled: Bool
    
    var body: some View {
        Form {
            Section(header: Text("Keyboard Shortcuts")) {
                Toggle("Enable Global Search Shortcut", isOn: $isGlobalSearchEnabled)
                Text("Use Ctrl + N to open the spotlight-style search from anywhere.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct SpotlightSettingsView: View {
    @Binding var isSpotlightIndexingEnabled: Bool
    @Binding var isSpotlightTabSearchEnabled: Bool
    
    var body: some View {
        Form {
            Section(header: Text("System Integration")) {
                Toggle("Show Notes in System Spotlight", isOn: $isSpotlightIndexingEnabled)
                Toggle("Enable Spotlight 'Tab to Search'", isOn: $isSpotlightTabSearchEnabled)
                
                Text("Indexing your notes allows you to find them via Cmd+Space. 'Tab to Search' lets you type 'NotesBar', press Tab, and search only your notes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?
    
    private init() {}
    
    func showSettings() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 250),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.title = "NotesBar Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.isReleasedWhenClosed = false
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
