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
    case note = "Note"
    
    var icon: String {
        switch self {
        case .all: return "square.stack.fill"
        case .text: return "doc.plaintext.fill"
        case .image: return "photo.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .link: return "link"
        case .note: return "pencil.line"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .all: return .blue
        case .text: return .cyan
        case .image: return .purple
        case .code: return .green
        case .link: return .orange
        case .note: return .yellow
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
    @State private var isHovered = false
    @State private var justCopied = false
    @State private var isDropTargeted = false
    @State private var dropFlashCount = 0
    @State private var quickNoteText: String = ""
    @State private var isNoteExpanded: Bool = false
    @State private var isSearchExpanded: Bool = false
    @State private var searchText: String = ""
    @Namespace private var filterNamespace
    
    private var recentItems: [ClipboardItem] {
        var items: [ClipboardItem]
        switch activeFilter {
        case .all:
            items = manager.history
        case .text:
            items = manager.history.filter { $0.smartCategory == .text }
        case .image:
            items = manager.history.filter { $0.smartCategory == .image }
        case .code:
            items = manager.history.filter { $0.smartCategory == .code }
        case .link:
            items = manager.history.filter { $0.smartCategory == .link }
        case .note:
            items = manager.history.filter { $0.smartCategory == .note }
        }
        
        if !searchText.isEmpty {
            items = items.filter { item in
                (item.textData?.localizedCaseInsensitiveContains(searchText) == true) ||
                (item.extractedDomain?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }
        
        let pinned = items.filter { $0.isPinned == true }
        let unpinned = items.filter { $0.isPinned != true }
        return Array((pinned + unpinned).prefix(15))
    }
    
    private func itemCountFor(_ filter: MenuBarFilterType) -> Int {
        switch filter {
        case .all: return min(manager.history.count, 15)
        case .text: return min(manager.history.filter { $0.smartCategory == .text }.count, 15)
        case .image: return min(manager.history.filter { $0.smartCategory == .image }.count, 15)
        case .code: return min(manager.history.filter { $0.smartCategory == .code }.count, 15)
        case .link: return min(manager.history.filter { $0.smartCategory == .link }.count, 15)
        case .note: return min(manager.history.filter { $0.smartCategory == .note }.count, 15)
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
                
                // Search toggle
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isSearchExpanded.toggle()
                        if !isSearchExpanded { searchText = "" }
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSearchExpanded ? .blue : .secondary)
                        .padding(4)
                        .background(isSearchExpanded ? Color.blue.opacity(0.15) : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                // Keep Open toggle
                KeepOpenToggle(isOn: $pinManager.keepOpen)
                
                // Settings button
                Button(action: {
                    SettingsWindowController.shared.show()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.white.opacity(0.0001)) // Make entire button area clickable
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // ─── Search Bar ───
            if isSearchExpanded {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("Search clipboard...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // ─── Navbar Filter ───
            MenuBarNavbar(
                activeFilter: $activeFilter,
                namespace: filterNamespace,
                itemCountFor: itemCountFor
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            
            // ─── Quick Note Editor ───
            QuickNoteEditorView(
                text: $quickNoteText,
                isExpanded: $isNoteExpanded,
                onSave: { saveNote() }
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            
            Divider().opacity(0.15)
            
            // ─── Content Area Container ───
            VStack(spacing: 0) {
                // ─── Drop Zone ───
                if isDropTargeted {
                    MenuBarDropZone(isTargeted: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // ─── Content ───
                ZStack(alignment: .top) {
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
                                if let text = item.textData {
                                    return NSItemProvider(object: text as NSString)
                                } else if let image = item.imageData {
                                    return NSItemProvider(object: image)
                                }
                                return NSItemProvider()
                            }
                        } // end ForEach
                    } // end LazyVStack
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                } // end ScrollView
            } // end else
        } // end ZStack
        .opacity(isNoteExpanded ? 0.3 : 1.0)
        .animation(.spring(response: 0.3), value: isNoteExpanded)
        .onTapGesture {
                    if isNoteExpanded {
                        withAnimation(.spring(response: 0.3)) {
                            saveNote()
                            isNoteExpanded = false
                        }
                    }
                }
            }
            // Localized drop target for content area, avoiding Quick Note input overlap
            .onDrop(of: [.plainText, .utf8PlainText, .image, .png, .tiff, .fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
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
        .onReceive(NotificationCenter.default.publisher(for: .menuBarDidShow)) { _ in
            // Focus is handled by internal editor state
        }
        // State is intentionally explicitly preserved on hide so the Quick Note doesn't delete or prematurely submit unless user taps 'Save'.
    }
    
    private func saveNote() {
        let trimmed = quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let item = ClipboardItem(
            id: UUID(),
            type: .note,
            textData: trimmed,
            imageData: nil,
            dateCopied: Date(),
            isNote: true
        )
        
        DispatchQueue.main.async {
            manager.addItem(item)
            quickNoteText = ""
            isNoteExpanded = false
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
            if activeFilter == .note {
                Text("No notes yet — start typing above")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
            } else if activeFilter == .all {
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
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) || provider.hasItemConformingToTypeIdentifier("public.image") {
                if provider.canLoadObject(ofClass: NSImage.self) {
                    provider.loadObject(ofClass: NSImage.self) { image, _ in
                        if let img = image as? NSImage {
                            let item = ClipboardItem(id: UUID(), type: .image, textData: nil, imageData: img, dateCopied: Date())
                            DispatchQueue.main.async {
                                manager.addItem(item)
                                flashDropSuccess()
                            }
                        }
                    }
                    handled = true
                }
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
                .onChange(of: activeFilter) { _, newFilter in
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
    @State private var isEditHovered = false
    @State private var isCopyHovered = false
    @ObservedObject private var manager = ClipboardManager.shared
    
    private var itemIcon: String {
        switch item.smartCategory {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .link: return "link"
        case .image: return "photo.fill"
        case .text: return "doc.plaintext.fill"
        case .note: return "pencil.line"
        }
    }
    
    private var itemColor: Color {
        switch item.smartCategory {
        case .code: return .green
        case .link: return .orange
        case .image: return .purple
        case .text: return .blue
        case .note: return .yellow
        }
    }
    
    private var rowBackgroundColor: Color {
        let isNote = item.smartCategory == .note
        if isSelected {
            return isNote ? Color.yellow.opacity(0.2) : Color.blue.opacity(0.18)
        } else if isHovered {
            return isNote ? Color.yellow.opacity(0.12) : Color(nsColor: .windowBackgroundColor).opacity(0.6)
        } else {
            return isNote ? Color.yellow.opacity(0.06) : Color.clear
        }
    }
    
    private var rowStrokeColor: Color {
        if isSelected {
            return Color.blue.opacity(0.8)
        }
        return isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.04)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Clickable content area
            HStack(alignment: .top, spacing: 12) {
                // Type icon with background
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(itemColor.opacity(0.12))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: itemIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(itemColor)
                }
                
                if item.type == .image, let img = item.imageData {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 36, height: 36)
                                .cornerRadius(6)
                                .clipped()
                            
                            Text("Image")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        if isSelected {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: 200)
                                .cornerRadius(6)
                                .clipped()
                        }
                    }
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
                            .lineLimit(isSelected ? nil : 1)
                            .truncationMode(.middle)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if item.looksLikeCode {
                    Text(item.textData ?? "")
                        .font(.system(size: 11.5, design: .monospaced))
                        .lineLimit(isSelected ? nil : 2)
                        .truncationMode(.tail)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(.init(item.textData ?? ""))
                        .font(.system(size: 13))
                        .lineLimit(isSelected ? nil : 2)
                        .truncationMode(.tail)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            
            // Right side container: Always show Timestamp
            VStack(alignment: .trailing, spacing: 0) {
                // Action Buttons appear above Date on hover
                if isHovered || justCopied {
                    HStack(spacing: 12) {
                        if item.type == .text || item.type == .note || item.type == .code || item.type == .link {
                            Button(action: {
                                manager.showDetail(for: item)
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: isEditHovered ? 14 : 12, weight: .medium))
                                    .foregroundColor(isEditHovered ? .orange : .secondary)
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { isEditHovered = $0 }
                            .help("Edit item")
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        Button(action: handleCopy) {
                            Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: isCopyHovered ? 14 : 12, weight: .medium))
                                .foregroundColor(justCopied ? .green : (isCopyHovered ? .blue : .secondary))
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { isCopyHovered = $0 }
                        .help("Copy to clipboard")
                        .transition(.scale.combined(with: .opacity))
                    }
                    .padding(.bottom, 2)
                }
                
                Spacer(minLength: 0)
                
                HStack(spacing: 4) {
                    if item.isPinned == true {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                    Text(item.dateCopied, style: .time)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.top, 4) // Spacing to ensure it sits nicely at the bottom right
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(rowStrokeColor, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .contextMenu {
            Button(action: {
                manager.togglePin(for: item)
            }) {
                Text((item.isPinned ?? false) ? "Unpin" : "Pin")
                Image(systemName: (item.isPinned ?? false) ? "pin.slash" : "pin")
            }
            
            Button(action: {
                manager.showDetail(for: item)
            }) {
                Text("Edit")
                Image(systemName: "pencil")
            }
            .disabled(item.type == .image)
            
            Button(action: handleCopy) {
                Text("Copy")
                Image(systemName: "doc.on.doc")
            }
            
            Menu("Move to Category") {
                Button("Text") { manager.updateItemType(for: item, to: .text) }
                Button("Code") { manager.updateItemType(for: item, to: .code) }
                Button("Link") { manager.updateItemType(for: item, to: .link) }
                Button("Note") { manager.updateItemType(for: item, to: .note) }
            }
            .disabled(item.type == .image)
            
            Divider()
            
            Button(action: {
                manager.deleteItem(item)
            }) {
                Text("Delete")
                Image(systemName: "trash")
            }
        }
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

// MARK: - Modular Quick Note Views

struct QuickNoteEditorView: View {
    @Binding var text: String
    @Binding var isExpanded: Bool
    let onSave: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ─── Editor Area ───
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("✏️ Write a quick note...")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 13))
                        .padding(.top, 10)
                        .padding(.leading, 8)
                }
                
                TextEditor(text: $text)
                    .font(.system(size: 13, weight: .regular))
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(6)
            }
            .frame(minHeight: 40, maxHeight: isExpanded ? 240 : 40)
            
            // ─── Toolbar Area ───
            if isExpanded {
                
                QuickNoteToolbarView(text: $text) {
                    withAnimation(.spring(response: 0.3)) {
                        onSave()
                        isExpanded = false
                        isFocused = false
                    }
                }
            }
        }
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isExpanded || isFocused ? Color.orange.opacity(0.8) : Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipped()
        .shadow(color: isExpanded ? Color.black.opacity(0.2) : .clear, radius: 10, y: 5)
        .animation(.spring(response: 0.3), value: isExpanded)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .onTapGesture {
            if !isExpanded {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded = true
                    isFocused = true
                }
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                isFocused = true
            }
        }
        .onChange(of: text) { oldValue, newValue in
            if !isExpanded && newValue.hasSuffix("\n") {
                text = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                withAnimation(.spring(response: 0.3)) {
                    onSave()
                    isExpanded = false
                    isFocused = false
                }
                return
            }
            
            if newValue.isEmpty && isExpanded {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded = false
                    isFocused = false
                }
            } else if !newValue.isEmpty && !isExpanded {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded = true
                }
            }
        }
    }
}

struct QuickNoteToolbarView: View {
    @Binding var text: String
    let onSaveAction: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            
            Button(action: onSaveAction) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .opacity(text.isEmpty ? 0.4 : 1.0)
            .disabled(text.isEmpty)
        }
        .font(.system(size: 15, weight: .medium))
        .buttonStyle(.plain)
        .foregroundColor(.primary.opacity(0.8))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
