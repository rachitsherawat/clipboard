## 🚀 Download

👉 [Download Latest Version](https://github.com/rachitsherawat/clipboard/releases/latest)# 📋 Clipboard — macOS Clipboard Manager

A native macOS clipboard manager built with SwiftUI. Lives in your menu bar and keeps a searchable, filterable history of everything you copy.

## ✨ Features

### Menu Bar
- **Always accessible** — Clipboard icon in the macOS menu bar with a popover window
- **Recent history** — Shows your last 10 clipboard items (text & images)
- **Click to preview** — Tap any row to expand an inline preview panel directly below it
- **Copy button** — Hover to reveal a copy icon with checkmark confirmation
- **Drag & drop** — Drag text or images from the menu bar into any app

### Main App Window
- **Full clipboard history** — Up to 50 items, displayed as card-style rows grouped by date
- **Search** — Case-insensitive text search across clipboard items
- **Filter** — Toggle between All / Text / Image
- **Click to preview** — Click any card to open a full preview sheet (text or image)
- **Edit text** — Modify clipboard text items with the built-in editor
- **Copy & delete** — Hover over a card for quick copy, edit, and delete actions
- **Drag & drop** — Drag items out to other apps, or drop text/images/files into the app

### Design
- Native macOS translucent blur (vibrancy) backgrounds
- Borderless window with hidden title bar
- Spring-animated hover effects and smooth transitions
- Colored icon badges and circular action buttons

## 🛠️ Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Platform:** macOS 13+
- **Architecture:** Single shared `ClipboardManager` with persistent JSON storage

## 📁 Project Structure

```
Clipboard/
├── ClipboardApp.swift        # App entry point, MenuBarExtra, VisualEffectView helper
├── ClipboardManager.swift    # Clipboard monitoring, history persistence, CRUD operations
├── ClipboardItem.swift       # Data model (text/image, Codable, Equatable)
├── ContentView.swift         # Main window UI (list, search, filters, preview, drag & drop)
├── MenuBarView.swift         # Menu bar popover (list, inline preview, drag & drop)
└── Assets.xcassets/          # App icons and asset catalog
```

## 🚀 Getting Started

### Requirements
- macOS 13.0 or later
- Xcode 15+

### Build & Run
1. Clone the repository:
   ```bash
   git clone https://github.com/rachitsherawat/clipboard.git
   cd clipboard
   ```
2. Open `Clipboard.xcodeproj` in Xcode
3. Select the **Clipboard** scheme and click **Run** (⌘R)

The app will appear as a clipboard icon (📋) in your menu bar.

## 📸 How It Works

1. **Copy anything** — The app monitors your clipboard every second
2. **Access from menu bar** — Click the clipboard icon to see recent items
3. **Preview** — Click any item to expand an inline preview (menu bar) or open a preview sheet (main window)
4. **Re-copy** — Hover and click the copy button, or use the preview panel's copy button
5. **Drag & drop** — Drag items directly from the history list into other apps
6. **Search & filter** — Use the main window to search text or filter by type

## 📄 License

This project is open source. Feel free to use and modify.
