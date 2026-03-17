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
    
    /// Heuristic: does this text item look like a code snippet?
    var looksLikeCode: Bool {
        guard type == .text, let text = textData, text.count > 10 else { return false }
        
        let codeIndicators: [String] = [
            "{", "}", "func ", "class ", "struct ", "enum ", "import ",
            "def ", "return ", "if (", "if(", "for (", "for(",
            "->", "=>", "console.log", "print(", "println",
            "var ", "let ", "const ", "public ", "private ",
            "#include", "#import", "package ", "using ",
        ]
        
        let lines = text.components(separatedBy: .newlines)
        let indentedLines = lines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }
        let hasIndentation = indentedLines.count >= 2
        let hasSemicolons = text.contains(";")
        
        let matchCount = codeIndicators.reduce(0) { count, indicator in
            count + (text.contains(indicator) ? 1 : 0)
        }
        
        return matchCount >= 2 || (matchCount >= 1 && (hasIndentation || hasSemicolons))
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
