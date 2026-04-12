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
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(isHovered ? 1.0 : 0.8))
                .padding(8)
                .frame(width: 32, height: 32)
                .background(isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
