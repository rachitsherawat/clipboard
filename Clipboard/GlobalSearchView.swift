import SwiftUI

struct GlobalSearchView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var searchQuery: String = ""
    
    private var searchResults: [ClipboardItem] {
        guard !searchQuery.isEmpty else { return [] }
        return manager.history.filter { item in
            if item.type == .text, let text = item.textData {
                return text.localizedCaseInsensitiveContains(searchQuery)
            }
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15, weight: .medium))
                TextField("Search all clipboard items…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Results
            if searchQuery.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Search Clipboard")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.7))
                    Text("Find text across your entire clipboard history")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No results for \"\(searchQuery)\"")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults) { item in
                            SearchResultRow(item: item) {
                                manager.writeToPasteboard(item: item)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    
    @State private var isHovered = false
    @State private var justCopied = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "doc.plaintext.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.textData ?? "")
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                Text(item.dateCopied, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if isHovered || justCopied {
                Button(action: handleCopy) {
                    Image(systemName: justCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(justCopied ? .green : .blue)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(isHovered ? 0.5 : 0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private func handleCopy() {
        onCopy()
        withAnimation { justCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { justCopied = false }
        }
    }
}
