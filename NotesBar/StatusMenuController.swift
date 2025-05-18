//
//  StatusMenuController.swift
//  ObsidianQuickNote
//
//  Created by Aman Raj on 18/5/25.
//

import AppKit
import Combine

final class StatusMenuController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var cancellables = Set<AnyCancellable>()
    private var submenuTimer: Timer?
    private var currentFolder: NoteFile?
    private var activeSubmenu: NSMenu?
    private var isMenuOpen = false
    private var lastHighlightedItem: NSMenuItem?
    private var menuTrackingView: NSView?
    private var activePopover: NSPopover?
    
    private let vaultViewModel: VaultViewModel
    private let noteViewModel: NoteViewModel
    private let searchViewModel: SearchViewModel
    
    // MARK: - Search Field Subclass
    private class NoteSearchField: NSSearchField {
        var folder: NoteFile?
    }
    
    init(vaultViewModel: VaultViewModel, noteViewModel: NoteViewModel, searchViewModel: SearchViewModel) {
        self.vaultViewModel = vaultViewModel
        self.noteViewModel = noteViewModel
        self.searchViewModel = searchViewModel
        super.init()
        setupMenu()
        setupBindings()
    }
    
    private func setupBindings() {
        vaultViewModel.$currentVault
            .sink { [weak self] vault in
                if let vault = vault {
                    self?.noteViewModel.loadNotes(from: vault.path)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupMenu() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "NotesBar")
            button.imagePosition = .imageLeft
            button.image?.size = NSSize(width: 18, height: 18)
            
            // Get vault name from UserDefaults
            if let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") {
                let vaultName = (vaultPath as NSString).lastPathComponent
                button.title = vaultName
            } else {
                button.title = "NotesBar"
            }
            
            button.font = NSFont.systemFont(ofSize: 13)
            statusItem.length = 180 // Increased to accommodate vault name
        }
        updateMenu()
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        // Create tracking view if needed
        if menuTrackingView == nil {
            menuTrackingView = NSView(frame: .zero)
            menuTrackingView?.wantsLayer = true
            menuTrackingView?.layer?.backgroundColor = .clear
        }
        
        // Add tracking area to monitor mouse movement
        if let trackingView = menuTrackingView {
            // Remove existing tracking areas
            trackingView.trackingAreas.forEach { trackingView.removeTrackingArea($0) }
            
            // Add new tracking area
            let trackingArea = NSTrackingArea(
                rect: trackingView.bounds,
                options: [.mouseEnteredAndExited, .activeAlways],
                owner: trackingView,
                userInfo: nil
            )
            trackingView.addTrackingArea(trackingArea)
            
            // Set up tracking view delegate
            trackingView.window?.delegate = self
        }
        
        // Header with app icon
        let headerItem = NSMenuItem(title: "NotesBar", action: #selector(openGitHubProfile), keyEquivalent: "")
        headerItem.isEnabled = true
        headerItem.image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "NotesBar")
        headerItem.image?.size = NSSize(width: 16, height: 16)
        headerItem.target = self
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        
        // Vault Selection
        if !vaultViewModel.isVaultSelected {
            let selectVaultItem = NSMenuItem(
                title: "Select Vault",
                action: #selector(showVaultSelector),
                keyEquivalent: ""
            )
            selectVaultItem.target = self
            selectVaultItem.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "Select Vault")
            selectVaultItem.image?.size = NSSize(width: 16, height: 16)
            menu.addItem(selectVaultItem)
        } else {
            // Master Search Bar
            let searchItem = NSMenuItem()
            let searchView = createMasterSearchView()
            searchItem.view = searchView
            menu.addItem(searchItem)
            menu.addItem(NSMenuItem.separator())
            
            // Refresh Item
            let refreshItem = NSMenuItem(
                title: "Refresh Notes",
                action: #selector(refreshNotes),
                keyEquivalent: "r"
            )
            refreshItem.target = self
            refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
            refreshItem.image?.size = NSSize(width: 16, height: 16)
            menu.addItem(refreshItem)
            menu.addItem(NSMenuItem.separator())
            
            // Notes List
            if noteViewModel.rootFiles.isEmpty {
                let item = NSMenuItem(
                    title: "No notes found",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                menu.addItem(item)
            } else {
                // Add folders and files
                for file in noteViewModel.rootFiles {
                    // Skip files and directories that start with a dot
                    if file.name.hasPrefix(".") {
                        continue
                    }
                    let item = file.isDirectory ? createFolderMenuItem(for: file) : createFileMenuItem(for: file)
                    menu.addItem(item)
                }
            }
            
            menu.addItem(NSMenuItem.separator())
            
            // Change Vault
            let changeVaultItem = NSMenuItem(
                title: "Change Vault",
                action: #selector(showVaultSelector),
                keyEquivalent: ""
            )
            changeVaultItem.target = self
            changeVaultItem.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: "Change Vault")
            changeVaultItem.image?.size = NSSize(width: 16, height: 16)
            menu.addItem(changeVaultItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // About Item
        let aboutItem = NSMenuItem(
            title: "About",
            action: #selector(openGitHubProfile),
            keyEquivalent: ""
        )
        aboutItem.target = self
        aboutItem.image = NSImage(systemSymbolName: "person.circle", accessibilityDescription: "About")
        aboutItem.image?.size = NSSize(width: 16, height: 16)
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit Item
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApp.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
        quitItem.image?.size = NSSize(width: 16, height: 16)
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func createMasterSearchView() -> NSView {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 30))
        
        let searchField = NSSearchField(frame: NSRect(x: 8, y: 4, width: 284, height: 22))
        searchField.placeholderString = "Search all notes..."
        searchField.focusRingType = .none
        searchField.bezelStyle = .roundedBezel
        searchField.font = NSFont.systemFont(ofSize: 13)
        searchField.target = self
        searchField.action = #selector(masterSearchFieldChanged(_:))
        containerView.addSubview(searchField)
        
        return containerView
    }
    
    @objc private func masterSearchFieldChanged(_ sender: NSSearchField) {
        searchViewModel.searchText = sender.stringValue
    }
    
    @objc private func showVaultSelector() {
        vaultViewModel.selectVault()
    }
    
    @objc private func refreshNotes() {
        if let vault = vaultViewModel.currentVault {
            noteViewModel.loadNotes(from: vault.path)
        }
    }
    
    private func createFolderMenuItem(for folder: NoteFile) -> NSMenuItem {
        let item = NSMenuItem(
            title: folder.name,
            action: #selector(showFolderPopover(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = folder
        item.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
        item.image?.size = NSSize(width: 16, height: 16)
        
        if let count = folder.children?.count {
            item.title = "\(folder.name) (\(count))"
        }
        
        return item
    }
    
    private func createFileMenuItem(for file: NoteFile) -> NSMenuItem {
        let item = NSMenuItem(
            title: file.name,
            action: #selector(openFile(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = file
        item.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: nil)
        item.image?.size = NSSize(width: 16, height: 16)
        return item
    }
    
    @objc private func showFolderPopover(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? NoteFile else { return }
        
        // Close any existing popover
        activePopover?.close()
        
        // Create popover
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 400)
        
        // Create content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
        
        // Add search field
        let searchField = NSSearchField(frame: NSRect(x: 8, y: 370, width: 284, height: 22))
        searchField.placeholderString = "Search in \(folder.name)..."
        searchField.focusRingType = .none
        searchField.bezelStyle = .roundedBezel
        searchField.font = NSFont.systemFont(ofSize: 13)
        searchField.target = self
        searchField.action = #selector(folderSearchFieldChanged(_:))
        searchField.isEditable = true
        searchField.isSelectable = true
        searchField.isEnabled = true
        
        // Store the folder reference in the search field's cell
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.representedObject = folder
        }
        
        contentView.addSubview(searchField)
        
        // Add scroll view for content
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 340))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.spacing = 4
        contentStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        // Add children to stack view
        if let children = folder.children {
            for child in children {
                // Skip files and directories that start with a dot
                if child.name.hasPrefix(".") {
                    continue
                }
                let childView = createItemView(for: child)
                contentStack.addArrangedSubview(childView)
            }
        }
        
        scrollView.documentView = contentStack
        contentView.addSubview(scrollView)
        
        // Set content view
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = contentView
        
        // Show popover
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxX)
        }
        
        activePopover = popover
    }
    
    private func createItemView(for item: NoteFile) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 284, height: 24))
        
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 284, height: 24))
        button.bezelStyle = .texturedRounded
        button.title = item.name
        button.image = NSImage(systemSymbolName: item.isDirectory ? "folder.fill" : "doc.text.fill", accessibilityDescription: nil)
        button.imagePosition = .imageLeft
        button.alignment = .left
        button.target = self
        button.action = item.isDirectory ? #selector(showFolderPopover(_:)) : #selector(openFile(_:))
        
        // Store the item reference using the safer method
        button.setAssociatedObject(item, forKey: "item")
        
        container.addSubview(button)
        return container
    }
    
    @objc private func folderSearchFieldChanged(_ sender: NSSearchField) {
        guard let cell = sender.cell as? NSSearchFieldCell,
              let folder = cell.representedObject as? NoteFile,
              let scrollView = sender.superview?.subviews.first as? NSScrollView,
              let contentStack = scrollView.documentView as? NSStackView else { return }
        
        // Remove all existing items
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let searchText = sender.stringValue.lowercased()
        
        if searchText.isEmpty {
            // If search is empty, show all items
            if let children = folder.children {
                for child in children {
                    let childView = createItemView(for: child)
                    contentStack.addArrangedSubview(childView)
                }
            }
        } else {
            // Filter items based on search text
            if let children = folder.children {
                for child in children {
                    // Skip files and directories that start with a dot
                    if child.name.hasPrefix(".") {
                        continue
                    }
                    if child.name.lowercased().contains(searchText) {
                        let childView = createItemView(for: child)
                        contentStack.addArrangedSubview(childView)
                    }
                }
            }
        }
    }
    
    @objc private func openFile(_ sender: NSButton) {
        guard let item = sender.getAssociatedObject(forKey: "item") as? NoteFile,
              let vault = vaultViewModel.currentVault else { return }
        noteViewModel.openNote(item, vaultName: vault.name)
    }
    
    @objc private func openGitHubProfile() {
        if let url = URL(string: "https://github.com/aman-senpai") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func closeAllMenus() {
        if let activeSubmenu = activeSubmenu {
            activeSubmenu.cancelTracking()
            self.activeSubmenu = nil
        }
        
        submenuTimer?.invalidate()
        submenuTimer = nil
        
        isMenuOpen = false
        currentFolder = nil
        lastHighlightedItem = nil
    }
}

// Add NSWindowDelegate conformance
extension StatusMenuController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        closeAllMenus()
    }
}

// Add custom tracking view
class MenuTrackingView: NSView {
    weak var menuController: StatusMenuController?
    
    override func mouseEntered(with event: NSEvent) {
        // Mouse entered the tracking area
    }
    
    override func mouseExited(with event: NSEvent) {
        // Close all menus when mouse exits the tracking area
        menuController?.closeAllMenus()
    }
}

extension StatusMenuController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        updateMenu()
    }
    
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        // If the highlighted item is the same as the last one, do nothing
        if item === lastHighlightedItem {
            return
        }
        
        // Update the last highlighted item
        lastHighlightedItem = item
        
        // Cancel any existing timer and close any active submenu
        submenuTimer?.invalidate()
        submenuTimer = nil
        
        // Always close any active submenu when highlighting a new item
        if let activeSubmenu = activeSubmenu {
            activeSubmenu.cancelTracking()
            self.activeSubmenu = nil
        }
        
        if let item = item, let submenu = item.submenu {
            // Create a timer to show submenu after a short delay
            submenuTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                guard let self = self,
                      self.isMenuOpen,
                      item === self.lastHighlightedItem else { return }
                
                // Get the status item's button frame
                guard let button = self.statusItem.button,
                      let buttonWindow = button.window else { return }
                
                // Convert button frame to screen coordinates
                let buttonFrame = buttonWindow.convertPoint(toScreen: button.frame.origin)
                
                // Calculate the position for the submenu
                let itemIndex = menu.index(of: item)
                let itemHeight = item.view?.frame.height ?? 22 // Default menu item height
                let yOffset = CGFloat(menu.numberOfItems - itemIndex - 1) * itemHeight
                
                // Position the submenu to the right of the main menu, aligned with the item
                let submenuPoint = NSPoint(
                    x: buttonFrame.x + button.frame.width,
                    y: buttonFrame.y - yOffset - itemHeight
                )
                
                // Store the active submenu
                self.activeSubmenu = submenu
                
                // Show the submenu
                DispatchQueue.main.async {
                    submenu.popUp(positioning: nil, at: submenuPoint, in: nil)
                }
            }
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        // Clean up timer and active submenu when menu closes
        closeAllMenus()
        
        // Remove tracking view
        menuTrackingView?.removeFromSuperview()
        menuTrackingView = nil
    }
    
    func menu(_ menu: NSMenu, willOpen item: NSMenuItem) {
        // Ensure any existing submenu is closed when opening a new one
        if let activeSubmenu = activeSubmenu, activeSubmenu != item.submenu {
            activeSubmenu.cancelTracking()
            self.activeSubmenu = nil
        }
    }
    
    func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool {
        // If the menu should be cancelled, clean up
        if shouldCancel {
            submenuTimer?.invalidate()
            submenuTimer = nil
            
            if let activeSubmenu = activeSubmenu {
                activeSubmenu.cancelTracking()
                self.activeSubmenu = nil
            }
            
            isMenuOpen = false
            currentFolder = nil
            lastHighlightedItem = nil
        }
        return true
    }
}

// Add mouseDownHandler to NSView
extension NSView {
    private static var mouseDownHandlerKey = "mouseDownHandler"
    
    var mouseDownHandler: (() -> Void)? {
        get {
            return objc_getAssociatedObject(self, &NSView.mouseDownHandlerKey) as? () -> Void
        }
        set {
            if let newValue = newValue {
                objc_setAssociatedObject(self, &NSView.mouseDownHandlerKey, newValue, .OBJC_ASSOCIATION_RETAIN)
            } else {
                objc_setAssociatedObject(self, &NSView.mouseDownHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN)
            }
        }
    }
    
    override open func mouseDown(with event: NSEvent) {
        mouseDownHandler?()
        super.mouseDown(with: event)
    }
}

// Add a safer way to store associated objects
extension NSView {
    private static var associatedObjectsKey = "associatedObjects"
    
    private var associatedObjects: [String: Any] {
        get {
            if let objects = objc_getAssociatedObject(self, &NSView.associatedObjectsKey) as? [String: Any] {
                return objects
            }
            return [:]
        }
        set {
            objc_setAssociatedObject(self, &NSView.associatedObjectsKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    func setAssociatedObject(_ value: Any?, forKey key: String) {
        var objects = associatedObjects
        objects[key] = value
        associatedObjects = objects
    }
    
    func getAssociatedObject(forKey key: String) -> Any? {
        return associatedObjects[key]
    }
} 
