import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var hoveredItemId: UUID?
    
    private var recentItems: [ClipboardItem] {
        Array(manager.history.prefix(10))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
                Text("Clipboard History")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(manager.history.count) items")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            
            Divider().opacity(0.3)
            
            // Items list
            if recentItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No items yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Copy something to see it here")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(recentItems) { item in
                            MenuBarItemRow(
                                item: item,
                                isHovered: hoveredItemId == item.id,
                                onCopy: {
                                    manager.writeToPasteboard(item: item)
                                }
                            )
                            .onHover { hovering in
                                hoveredItemId = hovering ? item.id : nil
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .frame(maxHeight: 320)
            }
            
            Divider().opacity(0.3)
            
            // Footer
            HStack {
                Button(action: openMainWindow) {
                    HStack(spacing: 6) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 12))
                        Text("Open Clipboard")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                
                Spacer()
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 320)
    }
    
    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.title != "" || $0.contentView?.subviews.isEmpty == false }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Menu Bar Item Row

struct MenuBarItemRow: View {
    let item: ClipboardItem
    let isHovered: Bool
    let onCopy: () -> Void
    
    @State private var justCopied = false
    
    var body: some View {
        Button(action: handleCopy) {
            HStack(spacing: 10) {
                // Type icon
                Image(systemName: item.type == .text ? "doc.plaintext" : "photo")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                
                // Content preview
                if item.type == .text {
                    Text(item.textData ?? "")
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.primary)
                } else if item.type == .image, let img = item.imageData {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .cornerRadius(4)
                        .clipped()
                    Text("Image")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Timestamp or copied indicator
                if justCopied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Text(item.dateCopied, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.blue.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func handleCopy() {
        onCopy()
        withAnimation {
            justCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                justCopied = false
            }
        }
    }
}
