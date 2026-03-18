import Combine
import SwiftUI
import AppKit

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var history: [ClipboardItem] = []
    
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    
    private var historyFileURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("ClipboardApp")
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
        return appSupportDir.appendingPathComponent("history.json")
    }
    
    init() {
        self.lastChangeCount = pasteboard.changeCount
        loadHistory()
        startTracking()
    }
    
    private func loadHistory() {
        do {
            let data = try Data(contentsOf: historyFileURL)
            let loaded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            DispatchQueue.main.async {
                self.history = loaded
            }
        } catch {
            print("No history found or failed to load: \(error)")
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(self.history)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    func startTracking() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
    
    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        // Try reading an image first
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            let item = ClipboardItem(id: UUID(), type: .image, textData: nil, imageData: image, dateCopied: Date())
            appendItem(item)
            return
        }
        
        // Try reading string
        if let string = pasteboard.string(forType: .string) {
            let item = ClipboardItem(id: UUID(), type: .text, textData: string, imageData: nil, dateCopied: Date())
            appendItem(item)
        }
    }
    
    private func appendItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            // Avoid adding immediate duplicates
            if let first = self.history.first, first == item { return }
            
            self.history.insert(item, at: 0)
            
            // Keep history lean (e.g. 50 items max)
            if self.history.count > 50 {
                self.history.removeLast()
            }
            
            self.saveHistory()
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            if let index = self.history.firstIndex(of: item) {
                self.history.remove(at: index)
                self.saveHistory()
            }
        }
    }
    
    func writeToPasteboard(item: ClipboardItem) {
        pasteboard.clearContents()
        if let text = item.textData, item.smartCategory != .image {
            pasteboard.setString(text, forType: .string)
        } else if item.type == .image, let image = item.imageData {
            pasteboard.writeObjects([image])
        }
        // Immediately update changeCount so we don't read our own write
        lastChangeCount = pasteboard.changeCount
    }
    
    func updateItemText(_ item: ClipboardItem, newText: String) {
        DispatchQueue.main.async {
            if let index = self.history.firstIndex(where: { $0.id == item.id }) {
                let updated = ClipboardItem(id: item.id, type: .text, textData: newText, imageData: nil, dateCopied: item.dateCopied)
                self.history[index] = updated
                self.saveHistory()
            }
        }
    }
    
    func addItem(_ item: ClipboardItem) {
        appendItem(item)
    }
}
