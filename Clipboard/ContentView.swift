import SwiftUI

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
    @StateObject private var manager = ClipboardManager()
    @State private var filter: FilterType = .all
    @State private var previewImage: NSImage?
    
    var filteredHistory: [ClipboardItem] {
        switch filter {
        case .all:
            return manager.history
        case .text:
            return manager.history.filter { $0.type == .text }
        case .image:
            return manager.history.filter { $0.type == .image }
        }
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
            .padding(.bottom, 16)
            
            // Content List
            ScrollView {
                if filteredHistory.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(filter == .all ? "Your clipboard history is empty" : "No \(filter.rawValue.lowercased())s found")
                            .font(.headline)
                        if filter == .all {
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
                                        onPreview: { previewImage = item.imageData }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.clear)
        .sheet(item: Binding<PreviewIdentifier?>(
            get: { previewImage.map { PreviewIdentifier(image: $0) } },
            set: { if $0 == nil { previewImage = nil } }
        )) { wrapper in
            // Image Preview Modal
            VStack {
                HStack {
                    Spacer()
                    Button(action: { previewImage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding([.top, .trailing], 16)
                }
                Image(nsImage: wrapper.image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
            .frame(width: 500, height: 400)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        }
    }
}

struct PreviewIdentifier: Identifiable {
    let id = UUID()
    let image: NSImage
}

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

// Subview for individual cards
struct ClipboardItemView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onPreview: () -> Void
    
    @State private var isHovered = false
    @State private var justCopied = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Internal content
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
            
            // Hover Actions
            if isHovered || justCopied {
                HStack(spacing: 12) {
                    if item.type == .image {
                        Button(action: onPreview) {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 18))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                    }
                
                    Button(action: handleCopy) {
                        Image(systemName: justCopied ? "checkmark" : "doc.on.doc.fill")
                            .foregroundColor(justCopied ? .green : .blue)
                            .font(.system(size: 18))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation {
                            onDelete()
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red.opacity(0.8))
                            .font(.system(size: 18))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
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
