import SwiftUI

struct ActionButton: View {
    let icon: String
    let action: () -> Void
    let tooltip: String
    @State private var isHovered = false
    @State private var showTooltip = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .padding(6)
                .background(isHovered ? Color.white.opacity(0.2) : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(alignment: .bottom) {
            if showTooltip {
                Text(tooltip)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(4)
                    .offset(y: 28)
                    .fixedSize()
            }
        }
        .onHover { hovering in
            isHovered = hovering
            hoverTask?.cancel()

            if hovering {
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                    if !Task.isCancelled {
                        await MainActor.run { showTooltip = true }
                    }
                }
            } else {
                showTooltip = false
            }
        }
    }
}
