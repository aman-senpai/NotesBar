import SwiftUI
import AppKit

struct MarkdownPreviewView: View {
    let file: NoteFile
    var onTap: (() -> Void)? = nil
    @State private var content: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with file name
            HStack {
                Text(file.name.replacingOccurrences(of: ".md", with: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }

            Divider()

            // Content area - preview only
            ScrollView {
                if let nsAttributedString = MarkdownStyler.createStyledAttributedString(from: content) {
                    Text(AttributedString(nsAttributedString))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .frame(width: 450, height: 400)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            loadContent()
        }
    }

    private func loadContent() {
        let fileURL = URL(fileURLWithPath: file.path)
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
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
