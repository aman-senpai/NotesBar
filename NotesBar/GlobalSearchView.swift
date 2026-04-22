import SwiftUI
import AppKit

struct GlobalSearchView: View {
    @EnvironmentObject private var vaultViewModel: VaultViewModel
    let onClose: () -> Void
    
    @State private var searchText = ""
    @State private var allNotes: [NoteFile] = []
    @State private var isLoading = true
    @State private var selectedNoteId: String?
    @State private var eventMonitor: Any?
    
    var filteredNotes: [NoteFile] {
        if searchText.isEmpty {
            return allNotes
        }
        let terms = searchText.lowercased().split(separator: " ")
        return allNotes.filter { note in
            let nameMatch = note.name.lowercased()
            return terms.allSatisfy { term in nameMatch.contains(term) }
        }
    }
    
    var selectedNote: NoteFile? {
        guard let id = selectedNoteId else { return nil }
        return allNotes.first { $0.id == id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar Area
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.secondary)
                
                TextField("Search all notes...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 24, weight: .light))
                    .onChange(of: searchText) { _ in
                        if let first = filteredNotes.first {
                            selectedNoteId = first.id
                        } else {
                            selectedNoteId = nil
                        }
                    }
                
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            
            Divider()
            
            // Content Area
            if filteredNotes.isEmpty && !isLoading {
                VStack {
                    Spacer()
                    Text("No notes found")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Left List Pane
                        ScrollViewReader { proxy in
                            List(selection: $selectedNoteId) {
                                ForEach(filteredNotes) { note in
                                    GlobalSearchRow(note: note)
                                        .tag(note.id)
                                        .id(note.id)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                }
                            }
                            .listStyle(SidebarListStyle())
                            .clipped()
                            .onChange(of: selectedNoteId) { id in
                                if let id = id {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        proxy.scrollTo(id, anchor: .center)
                                    }
                                }
                            }
                        }
                        .frame(width: geo.size.width * 0.4)
                        
                        Divider()
                        
                        // Right Preview Pane
                        ZStack {
                            Color(NSColor.textBackgroundColor).opacity(0.5)
                            
                            if let note = selectedNote {
                                MarkdownPreviewView(file: note) {
                                    openSelectedNote(note)
                                }
                                .id(note.id)
                                .padding(8)
                            } else {
                                VStack {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("Select a note to preview")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                }
                            }
                        }
                        .frame(width: geo.size.width * 0.6)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
        .onAppear {
            loadNotes()
            setupEventMonitor()
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        // Handle global Enter to open note
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GlobalSearchOpened"))) { _ in
            searchText = ""
            loadNotes()
        }
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only process if this window is key
            guard NSApp.keyWindow?.contentView?.window == event.window else { return event }
            
            if event.keyCode == 125 { // Down arrow
                moveSelection(up: false)
                return nil
            } else if event.keyCode == 126 { // Up arrow
                moveSelection(up: true)
                return nil
            } else if event.keyCode == 36 { // Enter
                if let note = selectedNote {
                    openSelectedNote(note)
                    return nil
                }
            } else if event.keyCode == 53 { // Escape
                onClose()
                return nil
            }
            return event
        }
    }
    
    private func moveSelection(up: Bool) {
        let notes = filteredNotes
        guard !notes.isEmpty else { return }
        
        if let currentId = selectedNoteId, let currentIndex = notes.firstIndex(where: { $0.id == currentId }) {
            let newIndex = up ? max(0, currentIndex - 1) : min(notes.count - 1, currentIndex + 1)
            selectedNoteId = notes[newIndex].id
        } else {
            selectedNoteId = notes.first?.id
        }
    }
    
    private func loadNotes() {
        isLoading = true
        vaultViewModel.fetchAllNotes { notes in
            self.allNotes = notes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.isLoading = false
            if self.selectedNoteId == nil, let first = self.allNotes.first {
                self.selectedNoteId = first.id
            }
        }
    }
    
    private func openSelectedNote(_ note: NoteFile) {
        onClose()
        vaultViewModel.openNote(note)
    }
}

struct GlobalSearchRow: View {
    let note: NoteFile
    
    var body: some View {
        HStack(spacing: 8) {
            let ext = (note.name as NSString).pathExtension.lowercased()
            let icon: String = {
                if note.source == .appleNotes { return "apple.logo" }
                switch ext {
                case "canvas": return "square.grid.2x2"
                case "excalidraw": return "scribble.variable"
                default: return "doc.text"
                }
            }()
            
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 16)
                
            let displayName = note.name
                .replacingOccurrences(of: ".md", with: "")
                .replacingOccurrences(of: ".canvas", with: "")
                .replacingOccurrences(of: ".excalidraw", with: "")
                
            Text(displayName)
                .font(.system(size: 13))
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// Helper to use NSVisualEffectView in SwiftUI
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
