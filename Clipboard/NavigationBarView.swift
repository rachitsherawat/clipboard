import SwiftUI

struct NavigationBarView: View {
    @Binding var selectedTab: NavigationTab
    @Namespace private var tabNamespace
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: App icon trigger
            AppIconButton()
            
            Spacer()
            
            // Center: Navigation items
            HStack(spacing: 2) {
                ForEach(NavigationTab.allCases) { tab in
                    NavTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: tabNamespace
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(3)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            
            Spacer()
            
            // Right: Quick action badge
            QuickActionBadge()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            NavBarBackground()
        )
        // Keyboard shortcuts
        .background(
            Group {
                ForEach(NavigationTab.allCases) { tab in
                    Button("") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    }
                    .keyboardShortcut(tab.shortcutKey, modifiers: .command)
                    .hidden()
                }
            }
        )
    }
}

// MARK: - App Icon Button (Left)

private struct AppIconButton: View {
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            // Trigger action — e.g. toggle sidebar or show app menu
        }) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovered ? 0.1 : 0.05))
                )
                .scaleEffect(isHovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help("Clipboard")
    }
}

// MARK: - Nav Tab Button

private struct NavTabButton: View {
    let tab: NavigationTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : (isHovered ? .primary.opacity(0.85) : .secondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.7),
                                        Color.blue.opacity(0.5)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.blue.opacity(0.3), radius: 6, y: 2)
                            .matchedGeometryEffect(id: "activeTab", in: namespace)
                    } else if isHovered {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    }
                }
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Quick Action Badge (Right)

private struct QuickActionBadge: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "square.stack.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text("\(manager.history.count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.1 : 0.05))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help("\(manager.history.count) items in clipboard")
    }
}

// MARK: - Navbar Background

private struct NavBarBackground: View {
    var body: some View {
        ZStack {
            // Glass material
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            
            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 8)
    }
}

#Preview {
    NavigationBarView(selectedTab: .constant(.history))
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
}
