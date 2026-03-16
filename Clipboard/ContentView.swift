import SwiftUI
import UniformTypeIdentifiers

enum FilterType: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case image = "Image"
    
    var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .text: return "doc.plaintext.fill"
        case .image: return "photo.fill"
        }
    }
}

struct ContentView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var filter: FilterType = .all
    @State private var searchText: String = ""
    @State private var editingItem: ClipboardItem?
    @State private var isDropTargeted = false
    @State private var previewingItem: ClipboardItem?
    
    var filteredHistory: [ClipboardItem] {
        var items = manager.history
        
        // Apply type filter
        switch filter {
        case .all: break
        case .text: items = items.filter { $0.type == .text }
        case .image: items = items.filter { $0.type == .image }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                if item.type == .text, let text = item.textData {
                    return text.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }
        
        return items
    }
    
    var groupedHistory: [(Date, [ClipboardItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredHistory) { item in
            calendar.startOfDay(for: item.dateCopied)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header & Filters
            VStack(alignment: .leading, spacing: 12) {
                Text("Clipboard History")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(.primary)
                HStack(spacing: 8) {
                    ForEach(FilterType.allCases, id: \.self) { type in
                        FilterButton(type: type, isSelected: filter == type) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                filter = type
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                TextField("Search clipboard items…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            
            // Drop Zone
            if isDropTargeted {
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                    Text("Drop to add")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.blue.opacity(0.05))
                        )
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Content List
            ScrollView {
                if filteredHistory.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(emptyStateMessage)
                            .font(.headline)
                        if filter == .all && searchText.isEmpty {
                            Text("Copy something to see it here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 100)
                } else {
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedHistory, id: \.0) { date, items in
                            Section(header: GroupHeaderView(date: date)) {
                                ForEach(items) { item in
                                    ClipboardItemView(
                                        item: item,
                                        onCopy: { manager.writeToPasteboard(item: item) },
                                        onDelete: { manager.deleteItem(item) },
                                        onPreview: { previewingItem = item },
                                        onEdit: { editingItem = item }
                                    )
                                    .onDrag {
                                        if item.type == .text, let text = item.textData {
                                            return NSItemProvider(object: text as NSString)
                                        } else if item.type == .image, let image = item.imageData {
                                            return NSItemProvider(object: image)
                                        }
                                        return NSItemProvider()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .scrollIndicators(.hidden)
            .onDrop(of: [.plainText, .image, .fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
            }
        }
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
        .sheet(item: $previewingItem) { item in
            ClipboardPreviewSheet(item: item)
        }
        .sheet(item: $editingItem) { item in
            TextEditorSheet(item: item) { updatedText in
                manager.updateItemText(item, newText: updatedText)
            }
        }
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No results for \"\(searchText)\""
        } else if filter == .all {
            return "Your clipboard history is empty"
        } else {
            return "No \(filter.rawValue.lowercased())s found"
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        
        for provider in providers {
            // Try plain text
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                    if let textData = data as? Data, let text = String(data: textData, encoding: .utf8) {
                        let item = ClipboardItem(id: UUID(), type: .text, textData: text, imageData: nil, dateCopied: Date())
                        DispatchQueue.main.async { manager.addItem(item) }
                    } else if let text = data as? String {
                        let item = ClipboardItem(id: UUID(), type: .text, textData: text, imageData: nil, dateCopied: Date())
                        DispatchQueue.main.async { manager.addItem(item) }
                    }
                }
                handled = true
            }
            // Try image
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { data, _ in
                    if let imageData = data as? Data, let image = NSImage(data: imageData) {
                        let item = ClipboardItem(id: UUID(), type: .image, textData: nil, imageData: image, dateCopied: Date())
                        DispatchQueue.main.async { manager.addItem(item) }
                    }
                }
                handled = true
            }
            // Try file URL (for image files)
            else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    if let urlData = data as? Data,
                       let url = URL(dataRepresentation: urlData, relativeTo: nil),
                       let image = NSImage(contentsOf: url) {
                        let item = ClipboardItem(id: UUID(), type: .image, textData: nil, imageData: image, dateCopied: Date())
                        DispatchQueue.main.async { manager.addItem(item) }
                    }
                }
                handled = true
            }
        }
        
        return handled
    }
}

// MARK: - Unified Preview Sheet

struct ClipboardPreviewSheet: View {
    let item: ClipboardItem
    @Environment(\.dismiss) private var dismiss
    @State private var justCopied = false
    @ObservedObject private var manager = ClipboardManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(item.type == .text ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: item.type == .text ? "doc.plaintext.fill" : "photo.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(item.type == .text ? .blue : .purple)
                    }
                    Text(item.type == .text ? "Text Preview" : "Image Preview")
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Spacer()
                
                // Copy button
                Button(action: handleCopy) {
                    HStack(spacing: 5) {
                        Image(systemName: justCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text(justCopied ? "Copied!" : "Copy")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(justCopied ? .green : .blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(justCopied ? Color.green.opacity(0.12) : Color.blue.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            
            Divider().opacity(0.3)
            
            // Content
            if item.type == .text, let text = item.textData {
                ScrollView {
                    Text(text)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.2))
                        .padding(8)
                )
            } else if item.type == .image, let img = item.imageData {
                ScrollView {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding(16)
                }
            }
            
            Divider().opacity(0.3)
            
            // Footer info
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("Copied at \(item.dateCopied, style: .time) on \(item.dateCopied, style: .date)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 520, height: 420)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
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

// MARK: - Text Editor Sheet

struct TextEditorSheet: View {
    let item: ClipboardItem
    let onSave: (String) -> Void
    
    @State private var editedText: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Clipboard Text")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            
            Divider().opacity(0.3)
            
            // Text Editor
            TextEditor(text: $editedText)
                .font(.system(size: 14, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.3))
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider().opacity(0.3)
            
            // Footer buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    onSave(editedText)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 480, height: 360)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onAppear {
            editedText = item.textData ?? ""
        }
    }
}

// MARK: - Supporting Views

struct GroupHeaderView: View {
    let date: Date
    
    var dateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        HStack {
            Text(dateString)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .cornerRadius(6)
        )
        .padding(.bottom, 4)
    }
}

struct FilterButton: View {
    let type: FilterType
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 12))
                Text(type.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .white : (isHovered ? .primary : .secondary))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.8) : (isHovered ? Color(nsColor: .windowBackgroundColor).opacity(0.5) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.clear, radius: 4, y: 2)
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Clipboard Item Card

struct ClipboardItemView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onPreview: () -> Void
    let onEdit: () -> Void
    
    @State private var isHovered = false
    @State private var justCopied = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Clickable content area — click opens preview
            Button(action: onPreview) {
                VStack(alignment: .leading, spacing: 4) {
                    if item.type == .text {
                        Text(item.textData ?? "")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .lineLimit(3)
                            .foregroundColor(.primary)
                    } else if item.type == .image, let img = item.imageData {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 120)
                            .cornerRadius(6)
                            .clipped()
                    }
                    
                    Text(item.dateCopied, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Hover Actions (copy, edit, delete — no separate preview button)
            if isHovered || justCopied {
                HStack(spacing: 10) {
                    if item.type == .text {
                        Button(action: onEdit) {
                            Image(systemName: "pencil.line")
                                .foregroundColor(.orange)
                                .font(.system(size: 16))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color.orange.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Edit text")
                    }
                
                    Button(action: handleCopy) {
                        Image(systemName: justCopied ? "checkmark" : "doc.on.doc.fill")
                            .foregroundColor(justCopied ? .green : .blue)
                            .font(.system(size: 16))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(justCopied ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")
                    
                    Button(action: {
                        withAnimation {
                            onDelete()
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red.opacity(0.8))
                            .font(.system(size: 16))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(isHovered ? 0.6 : 0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func handleCopy() {
        onCopy()
        withAnimation {
            justCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                justCopied = false
            }
        }
    }
}
