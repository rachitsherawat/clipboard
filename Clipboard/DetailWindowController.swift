import SwiftUI
import AppKit

class DetailWindowController: NSWindowController {
    var item: ClipboardItem?
    
    init(item: ClipboardItem) {
        let panelWidth: CGFloat = 500
        let panelHeight: CGFloat = 500
        
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Item Detail"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        
        // Ensure window opens over full-screen apps seamlessly without making a space
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .floating
        
        self.item = item
        super.init(window: window)
        
        let detailView = ClipboardDetailView(
            item: item,
            onSave: { [weak self] newText in
                ClipboardManager.shared.updateItemText(item, newText: newText)
                self?.close() // Close window upon save action
            },
            onCopy: {
                ClipboardManager.shared.writeToPasteboard(item: item)
            }
        )
        
        window.contentView = NSHostingView(rootView: detailView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
