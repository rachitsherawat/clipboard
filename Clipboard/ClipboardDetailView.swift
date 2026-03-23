import SwiftUI
import AppKit
import Combine

struct ClipboardDetailView: View {
    @ObservedObject var item: ObservableClipboardItem
    var onSave: (String) -> Void
    var onCopy: () -> Void
    
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    init(item: ClipboardItem, onSave: @escaping (String) -> Void, onCopy: @escaping () -> Void) {
        self.item = ObservableClipboardItem(item: item)
        self.onSave = onSave
        self.onCopy = onCopy
        _text = State(initialValue: item.textData ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(item.accentColor.opacity(0.12))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: item.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(item.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.categoryName)
                            .font(.system(size: 13, weight: .bold))
                        Text(item.dateCopied, style: .date)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onCopy) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.1)))
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider().opacity(0.1)
            
            // Content
            if item.type == .image, let nsImage = item.imageData {
                ScrollView {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.system(size: 14, design: item.type == .code ? .monospaced : .default))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(12)
                        .focused($isFocused)
                    
                    if text.isEmpty {
                        Text("Enter text...")
                            .foregroundColor(.secondary.opacity(0.5))
                            .font(.system(size: 14))
                            .padding(.top, 20)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            Divider().opacity(0.1)
            
            // Footer
            HStack {
                Spacer()
                
                Button(action: {
                    onSave(text)
                    // Visual feedback could be added here
                }) {
                    Text("Save Changes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.blue))
                }
                .buttonStyle(.plain)
                .disabled(item.type == .image || text == item.textData)
                .opacity(item.type == .image || text == item.textData ? 0.5 : 1.0)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.3))
        }
        .frame(minWidth: 400, minHeight: 400)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea())
    }
}

class ObservableClipboardItem: ObservableObject {
    @Published var item: ClipboardItem
    
    init(item: ClipboardItem) {
        self.item = item
    }
    
    var type: ItemType { item.type }
    var textData: String? { item.textData }
    var imageData: NSImage? { item.imageData }
    var dateCopied: Date { item.dateCopied }
    
    var icon: String {
        switch item.smartCategory {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .link: return "link"
        case .image: return "photo.fill"
        case .text: return "doc.plaintext.fill"
        case .note: return "pencil.line"
        }
    }
    
    var accentColor: Color {
        switch item.smartCategory {
        case .code: return .green
        case .link: return .orange
        case .image: return .purple
        case .text: return .blue
        case .note: return .yellow
        }
    }
    
    var categoryName: String {
        item.smartCategory.rawValue
    }
}
