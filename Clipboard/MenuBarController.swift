import SwiftUI
import Combine
import AppKit

extension Notification.Name {
    static let menuBarDidShow = Notification.Name("menuBarDidShow")
    static let menuBarDidHide = Notification.Name("menuBarDidHide")
}

/// Custom controller that replaces MenuBarExtra with a manually managed
/// NSStatusItem + NSPanel, giving us full control over dismiss behavior.

class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class MenuBarController: NSObject {
    static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var hostingView: NSHostingView<AnyView>!
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    var isVisible = false
    
    override init() {
        super.init()
        setupStatusItem()
        setupPanel()
    }
    
    // MARK: - Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "Clipboard")
            button.action = #selector(togglePanel)
            button.target = self
        }
    }
    
    private func setupPanel() {
        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 480
        
        panel = KeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovable = false
        panel.animationBehavior = .utilityWindow
        
        // Visual effect background — use .menu for proper menu-bar-panel look
        let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        visualEffectView.material = .menu
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.autoresizingMask = [.width, .height]
        
        // SwiftUI hosting view
        let menuBarView = MenuBarView()
        hostingView = NSHostingView(rootView: AnyView(menuBarView))
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        hostingView.autoresizingMask = [.width, .height]
        
        // Container with both layers
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true
        containerView.addSubview(visualEffectView)
        containerView.addSubview(hostingView)
        
        panel.contentView = containerView
    }
    
    // MARK: - Toggle & Show/Hide
    
    @objc func togglePanel() {
        if panel.isVisible {
            // Always allow manual toggle to close, even when pinned
            forceHide()
        } else {
            showPanel()
        }
    }
    
    func showPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }
        
        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)
        
        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 480
        
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.minY - panelHeight - 4
        
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        panel.makeKeyAndOrderFront(nil)
        
        // Activate so the panel is fully interactive (fixes grey overlay look)
        NSApp.activate(ignoringOtherApps: true)
        
        isVisible = true
        installMonitorIfNeeded()
        NotificationCenter.default.post(name: .menuBarDidShow, object: nil)
    }
    
    func hidePanel() {
        guard !MenuBarPinManager.shared.keepOpen else { return }
        panel.orderOut(nil)
        isVisible = false
        NotificationCenter.default.post(name: .menuBarDidHide, object: nil)
        removeMonitors()
    }
    
    func forceHide() {
        panel.orderOut(nil)
        isVisible = false
        NotificationCenter.default.post(name: .menuBarDidHide, object: nil)
        removeMonitors()
    }
    
    // MARK: - Click-Outside Monitor
    
    func installMonitorIfNeeded() {
        removeMonitors()
        
        if MenuBarPinManager.shared.keepOpen { return }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            // If click is inside the panel, allow it
            if event.window == self.panel {
                return event
            }
            // If click is on the status item button, let togglePanel handle it
            if event.window == self.statusItem.button?.window {
                return event
            }
            self.hidePanel()
            return event
        }
    }
    
    func removeMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    func onPinStateChanged(keepOpen: Bool) {
        if keepOpen {
            removeMonitors()
        } else if panel.isVisible {
            installMonitorIfNeeded()
        }
    }
}
