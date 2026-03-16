import SwiftUI
import AppKit

enum ItemType: String, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    let type: ItemType
    let textData: String?
    let imageRawData: Data?
    let dateCopied: Date
    
    var imageData: NSImage? {
        if let raw = imageRawData {
            return NSImage(data: raw)
        }
        return nil
    }
    
    init(id: UUID, type: ItemType, textData: String?, imageData: NSImage?, dateCopied: Date) {
        self.id = id
        self.type = type
        self.textData = textData
        self.imageRawData = imageData?.tiffRepresentation
        self.dateCopied = dateCopied
    }
    
    // For Equatable so we don't accidentally append duplicate items
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        if lhs.type != rhs.type { return false }
        if lhs.type == .text {
            return lhs.textData == rhs.textData
        } else {
            return lhs.imageRawData == rhs.imageRawData
        }
    }
}
