import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var hoveredItemId: UUID?
    @State private var selectedItem: ClipboardItem?
    
    private var recentItems: [ClipboardItem] {
        Array(manager.history.prefix(10))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed, outside scroll)
            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .font(.system(size: 15, weight: .semibold))
                Text("Clipboard History")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(manager.history.count) items")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            
            Divider().opacity(0.2)
            
            // Scrollable content area (list + preview inside a single scroll)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(recentItems) { item in
                            MenuBarItemRow(
                                item: item,
                                isHovered: hoveredItemId == item.id,
                                isSelected: selectedItem?.id == item.id,
                                onCopy: {
                                    manager.writeToPasteboard(item: item)
                                },
                                onSelect: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        if selectedItem?.id == item.id {
                                            selectedItem = nil
                                        } else {
                                            selectedItem = item
                                        }
                                    }
                                }
                            )
                            .onHover { hovering in
                                hoveredItemId = hovering ? item.id : nil
                            }
                            .onDrag {
                                if item.type == .text, let text = item.textData {
                                    return NSItemProvider(object: text as NSString)
                                } else if item.type == .image, let image = item.imageData {
                                    return NSItemProvider(object: image)
                                }
                                return NSItemProvider()
                            }
                            
                            // Inline preview — directly below the selected row
                            if selectedItem?.id == item.id {
                                MenuBarPreviewPanel(item: item) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedItem = nil
                                    }
                                }
                                .transition(.opacity)
                                .padding(.horizontal, 2)
                                .padding(.bottom, 4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
            }
            
            Divider().opacity(0.2)
            
            // Footer (fixed, outside scroll)
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
        .frame(width: 340, height: 460)
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
    let isSelected: Bool
    let onCopy: () -> Void
    let onSelect: () -> Void
    
    @State private var justCopied = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Clickable content area
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    // Type icon with background
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(item.type == .text
                                  ? Color.blue.opacity(0.12)
                                  : Color.purple.opacity(0.12))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: item.type == .text ? "doc.plaintext.fill" : "photo.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(item.type == .text ? .blue : .purple)
                    }
                    
                    // Content preview
                    if item.type == .text {
                        Text(item.textData ?? "")
                            .font(.system(size: 13))
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if item.type == .image, let img = item.imageData {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .cornerRadius(6)
                            .clipped()
                        Text("Image")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Right side: timestamp or copy button
            if isHovered || justCopied {
                Button(action: handleCopy) {
                    Image(systemName: justCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(justCopied ? .green : .blue)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                Text(item.dateCopied, style: .time)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isSelected
                    ? Color.blue.opacity(0.18)
                    : (isHovered ? Color(nsColor: .windowBackgroundColor).opacity(0.6) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
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

// MARK: - Menu Bar Preview Panel

struct MenuBarPreviewPanel: View {
    let item: ClipboardItem
    let onDismiss: () -> Void
    
    @State private var justCopied = false
    @ObservedObject private var manager = ClipboardManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Preview header
            HStack {
                Image(systemName: item.type == .text ? "doc.plaintext.fill" : "photo.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Preview")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Copy button
                Button(action: handleCopy) {
                    HStack(spacing: 4) {
                        Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                        Text(justCopied ? "Copied!" : "Copy")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(justCopied ? .green : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(justCopied ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // Preview content
            if item.type == .text, let text = item.textData {
                ScrollView {
                    Text(text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.2))
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else if item.type == .image, let img = item.imageData {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .cornerRadius(8)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .background(
            Color(nsColor: .windowBackgroundColor).opacity(0.3)
        )
    }
    
    private func handleCopy() {
        manager.writeToPasteboard(item: item)
        withAnimation {
            justCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                justCopied = false
            }
        }
    }
}
