import Cocoa
import SwiftUI
import Carbon

class GlobalSearchManager: NSObject {
    static let shared = GlobalSearchManager()
    
    private var window: NSPanel?
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    
    @AppStorage("isGlobalSearchEnabled") private var isGlobalSearchEnabled: Bool = true
    
    private var vaultViewModel: VaultViewModel?
    
    private override init() {
        super.init()
        UserDefaults.standard.addObserver(self, forKeyPath: "isGlobalSearchEnabled", options: .new, context: nil)
    }
    
    func setup(vaultViewModel: VaultViewModel) {
        self.vaultViewModel = vaultViewModel
        setupWindow()
        if isGlobalSearchEnabled {
            registerHotKey()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "isGlobalSearchEnabled" {
            if isGlobalSearchEnabled {
                registerHotKey()
            } else {
                unregisterHotKey()
            }
        }
    }
    
    private func setupWindow() {
        guard let vaultViewModel = vaultViewModel else { return }
        
        class KeyPanel: NSPanel {
            override var canBecomeKey: Bool { return true }
            override var canBecomeMain: Bool { return true }
        }
        
        let panel = KeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.center()
        
        let rootView = GlobalSearchView(onClose: { [weak self] in
            self?.hideWindow()
        })
        .environmentObject(vaultViewModel)
        
        panel.contentView = NSHostingView(rootView: rootView)
        self.window = panel
    }
    
    func toggleWindow() {
        guard let window = window else { return }
        if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
    
    func showWindow() {
        guard let window = window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: NSNotification.Name("GlobalSearchOpened"), object: nil)
    }
    
    func hideWindow() {
        window?.orderOut(nil)
    }
    
    private func registerHotKey() {
        guard hotKeyRef == nil else { return }
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("NBGK".utf8.reduce(0) { $0 << 8 + $1 })
        hotKeyID.id = 1
        
        let keyCode = UInt32(kVK_ANSI_N)
        let modifiers = UInt32(controlKey)
        
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            DispatchQueue.main.async {
                GlobalSearchManager.shared.toggleWindow()
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)
    }
    
    private func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: "isGlobalSearchEnabled")
        unregisterHotKey()
    }
}
