import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Menu Bar Filter Type

enum MenuBarFilterType: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case image = "Image"
    case code = "Code"
    case link = "Link"
    
    var icon: String {
        switch self {
        case .all: return "square.stack.fill"
        case .text: return "doc.plaintext.fill"
        case .image: return "photo.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .link: return "link"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .all: return .blue
        case .text: return .cyan
        case .image: return .purple
        case .code: return .green
        case .link: return .orange
        }
    }
}

// MARK: - Window Pin Manager

/// Manages the "Keep Open" state — delegates to MenuBarController for actual window behavior.
class MenuBarPinManager: ObservableObject {
    static let shared = MenuBarPinManager()
    
    @Published var keepOpen: Bool = false {
        didSet {
            MenuBarController.shared.onPinStateChanged(keepOpen: keepOpen)
        }
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @ObservedObject private var pinManager = MenuBarPinManager.shared
    @State private var hoveredItemId: UUID?
    @State private var selectedItem: ClipboardItem?
    @State private var activeFilter: MenuBarFilterType = .all
    @State private var isDropTargeted = false
    @State private var dropFlashCount = 0
    @Namespace private var filterNamespace
    
    private var recentItems: [ClipboardItem] {
        switch activeFilter {
        case .all:
            return Array(manager.history.prefix(15))
        case .text:
            return Array(manager.history.filter { $0.type == .text && !$0.looksLikeCode && !$0.looksLikeLink }.prefix(15))
        case .image:
            return Array(manager.history.filter { $0.type == .image }.prefix(15))
        case .code:
            return Array(manager.history.filter { $0.looksLikeCode }.prefix(15))
        case .link:
            return Array(manager.history.filter { $0.looksLikeLink }.prefix(15))
        }
    }
    
    private func itemCountFor(_ filter: MenuBarFilterType) -> Int {
        switch filter {
        case .all: return min(manager.history.count, 15)
        case .text: return min(manager.history.filter { $0.type == .text && !$0.looksLikeCode && !$0.looksLikeLink }.count, 15)
        case .image: return min(manager.history.filter { $0.type == .image }.count, 15)
        case .code: return min(manager.history.filter { $0.looksLikeCode }.count, 15)
        case .link: return min(manager.history.filter { $0.looksLikeLink }.count, 15)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ─── Header ───
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .font(.system(size: 14, weight: .semibold))
                Text("Clipboard")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                // Keep Open toggle
                KeepOpenToggle(isOn: $pinManager.keepOpen)
                
                Text("\(manager.history.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // ─── Navbar Filter ───
            MenuBarNavbar(
                activeFilter: $activeFilter,
                namespace: filterNamespace,
                itemCountFor: itemCountFor
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            
            Divider().opacity(0.15)
            
            // ─── Drop Zone (always visible when dragging, or when Keep Open is on) ───
            if isDropTargeted {
                MenuBarDropZone(isTargeted: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // ─── Content ───
            if recentItems.isEmpty && !isDropTargeted {
                emptyStateView
            } else {
                ScrollView {
                    // Subtle drop hint at top when not actively dragging
                    if !isDropTargeted {
                        DropHintBanner()
                            .padding(.horizontal, 6)
                            .padding(.top, 4)
                    }
                    
                    LazyVStack(spacing: 2) {
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
                            
                            // Inline preview
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
            
            Divider().opacity(0.15)
            
            // ─── Footer ───
            HStack {
                Button(action: openMainWindow) {
                    HStack(spacing: 5) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 11))
                        Text("Open Clipboard")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                
                Spacer()
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 340, height: 480)
        .animation(.easeInOut(duration: 0.2), value: activeFilter)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDropTargeted)
        // Global drop target for the entire menu bar view
        .onDrop(of: [.plainText, .utf8PlainText, .image, .png, .tiff, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: activeFilter == .all ? "doc.on.clipboard" : activeFilter.icon)
                .font(.system(size: 30))
                .foregroundColor(.secondary.opacity(0.4))
            Text(activeFilter == .all ? "No items yet" : "No \(activeFilter.rawValue.lowercased()) items")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            if activeFilter == .all {
                Text("Drag items here or copy something")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Drop Handling
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        
        for provider in providers {
            // Try plain text
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                    if let textData = data as? Data, let text = String(data: textData, encoding: .utf8) {
                        let item = ClipboardItem(id: UUID(), type: .text, textData: text, imageData: nil, dateCopied: Date())
                        DispatchQueue.main.async {
                            manager.addItem(item)
                            flashDropSuccess()
                        }
                    } else if let text = data as? String {
                        let item = ClipboardItem(id: UUID(), type: .text, textData: text, imageData: nil, dateCopied: Date())
                        DispatchQueue.main.async {
                            manager.addItem(item)
                            flashDropSuccess()
                        }
                    }
                }
                handled = true
            }
            // Try image types
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { data, _ in
                    if let imageData = data as? Data, let image = NSImage(data: imageData) {
                        let item = ClipboardItem(id: UUID(), type: .image, textData: nil, imageData: image, dateCopied: Date())
                        DispatchQueue.main.async {
                            manager.addItem(item)
                            flashDropSuccess()
                        }
                    }
                }
                handled = true
            }
            // Try file URL (images or text files)
            else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    if let urlData = data as? Data,
                       let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                        // Try loading as image
                        if let image = NSImage(contentsOf: url) {
                            let item = ClipboardItem(id: UUID(), type: .image, textData: nil, imageData: image, dateCopied: Date())
                            DispatchQueue.main.async {
                                manager.addItem(item)
                                flashDropSuccess()
                            }
                        }
                        // Try loading as text file
                        else if let text = try? String(contentsOf: url, encoding: .utf8) {
                            let item = ClipboardItem(id: UUID(), type: .text, textData: text, imageData: nil, dateCopied: Date())
                            DispatchQueue.main.async {
                                manager.addItem(item)
                                flashDropSuccess()
                            }
                        }
                    }
                }
                handled = true
            }
        }
        
        return handled
    }
    
    private func flashDropSuccess() {
        dropFlashCount += 1
    }
    
    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.title != "" || $0.contentView?.subviews.isEmpty == false }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Keep Open Toggle

private struct KeepOpenToggle: View {
    @Binding var isOn: Bool
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: isOn ? "pin.fill" : "pin")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(isOn ? 0 : 45))
            }
            .foregroundColor(isOn ? .orange : .secondary)
            .frame(width: 26, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? Color.orange.opacity(0.15) : Color.white.opacity(isHovered ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isOn ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(isOn ? "Unpin — allow auto-close" : "Pin — keep menu bar open")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Drop Zone (shown when dragging over)

private struct MenuBarDropZone: View {
    let isTargeted: Bool
    
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.blue)
                .scaleEffect(pulseScale)
            Text("Drop here to add")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.blue.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.08))
                )
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.12
            }
        }
    }
}

// MARK: - Drop Hint Banner (subtle, always visible)

private struct DropHintBanner: View {
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Drag text, images, or files here")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.5))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(isHovered ? 0.4 : 0.2))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Navbar Component (Horizontally Scrollable)

private struct MenuBarNavbar: View {
    @Binding var activeFilter: MenuBarFilterType
    let namespace: Namespace.ID
    let itemCountFor: (MenuBarFilterType) -> Int
    
    var body: some View {
        ZStack {
            // Scrollable chip row
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(MenuBarFilterType.allCases, id: \.self) { filter in
                            MenuBarNavItem(
                                filter: filter,
                                isActive: activeFilter == filter,
                                count: itemCountFor(filter),
                                namespace: namespace
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    activeFilter = filter
                                }
                            }
                            .id(filter)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 3)
                }
                .onChange(of: activeFilter) { newFilter in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        proxy.scrollTo(newFilter, anchor: .center)
                    }
                }
            }
            
            // Edge fade overlays
            HStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        .init(color: Color(nsColor: .windowBackgroundColor), location: 0),
                        .init(color: Color(nsColor: .windowBackgroundColor).opacity(0), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 12)
                .allowsHitTesting(false)
                
                Spacer()
                
                LinearGradient(
                    stops: [
                        .init(color: Color(nsColor: .windowBackgroundColor).opacity(0), location: 0),
                        .init(color: Color(nsColor: .windowBackgroundColor), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 12)
                .allowsHitTesting(false)
            }
        }
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Nav Item (Fixed single-line chip)

private struct MenuBarNavItem: View {
    let filter: MenuBarFilterType
    let isActive: Bool
    let count: Int
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(filter.rawValue)
                    .font(.system(size: 11, weight: isActive ? .bold : .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(isActive ? .white : (isHovered ? .primary.opacity(0.8) : .secondary))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                ZStack {
                    if isActive {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        filter.accentColor.opacity(0.8),
                                        filter.accentColor.opacity(0.55)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: filter.accentColor.opacity(0.3), radius: 4, y: 2)
                            .matchedGeometryEffect(id: "navIndicator", in: namespace)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    }
                }
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
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
    
    private var itemIcon: String {
        switch item.smartCategory {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .link: return "link"
        case .image: return "photo.fill"
        case .text: return "doc.plaintext.fill"
        }
    }
    
    private var itemColor: Color {
        switch item.smartCategory {
        case .code: return .green
        case .link: return .orange
        case .image: return .purple
        case .text: return .blue
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Clickable content area
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    // Type icon with background
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(itemColor.opacity(0.12))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: itemIcon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(itemColor)
                    }
                    
                    // Content preview
                    if item.type == .image, let img = item.imageData {
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
                    } else if item.looksLikeLink {
                        VStack(alignment: .leading, spacing: 2) {
                            if let domain = item.extractedDomain {
                                Text(domain)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.orange)
                                    .lineLimit(1)
                            }
                            Text(item.textData ?? "")
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if item.looksLikeCode {
                        Text(item.textData ?? "")
                            .font(.system(size: 11.5, design: .monospaced))
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(item.textData ?? "")
                            .font(.system(size: 13))
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .foregroundColor(.primary)
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
    
    private var previewLabel: String {
        if item.looksLikeCode { return "Code Preview" }
        if item.type == .image { return "Image Preview" }
        return "Text Preview"
    }
    
    private var previewIcon: String {
        if item.looksLikeCode { return "chevron.left.forwardslash.chevron.right" }
        if item.type == .image { return "photo.fill" }
        return "doc.plaintext.fill"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Preview header
            HStack {
                Image(systemName: previewIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(previewLabel)
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
                        .font(.system(size: 12, design: item.looksLikeCode ? .monospaced : .default))
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
