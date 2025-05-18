import SwiftUI
import AppKit
import Down

struct MarkdownPreviewView: View {
    let file: NoteFile
    @State private var content: String = ""
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with file name
            HStack {
                Text(file.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Content
            ScrollView {
                if let nsAttributedString = try? Down(markdownString: content).toAttributedString() {
                    Text(AttributedString(nsAttributedString))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                } else {
                    Text("Error rendering markdown")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .frame(width: 400, height: 300)
            .background(.ultraThinMaterial)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 5)
        .onAppear {
            loadContent()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func loadContent() {
        let fileURL = URL(fileURLWithPath: file.path)
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
            // Ensure proper line endings
            content = content.replacingOccurrences(of: "\r\n", with: "\n")
        } catch {
            content = "Error loading content: \(error.localizedDescription)"
        }
    }
}

#Preview {
    MarkdownPreviewView(file: NoteFile(
        name: "test.md",
        path: "/path/to/test.md",
        relativePath: "test.md",
        isDirectory: false,
        children: nil
    ))
} 