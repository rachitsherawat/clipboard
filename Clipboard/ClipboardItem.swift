import SwiftUI
import AppKit

enum ItemType: String, Codable {
    case text
    case image
    case link
    case code
    case note
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = ItemType(rawValue: value) ?? .text
        } else {
            self = .text
        }
    }
}

struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    let type: ItemType
    let textData: String?
    let imageRawData: Data?
    let dateCopied: Date
    let isNote: Bool?
    
    
    var imageData: NSImage? {
        if let raw = imageRawData {
            return NSImage(data: raw)
        }
        return nil
    }
    
    init(id: UUID, type: ItemType, textData: String?, imageData: NSImage?, dateCopied: Date, isNote: Bool? = nil) {
        self.id = id
        self.type = type
        self.textData = textData
        self.imageRawData = imageData?.tiffRepresentation
        self.dateCopied = dateCopied
        self.isNote = isNote
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
    
    /// Heuristic: does this text item look like a URL/link?
    var looksLikeLink: Bool {
        guard type == .text, let text = textData?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        // Single-line URL check
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count <= 3 else { return false } // Links are usually 1-3 lines max
        
        let urlPatterns = ["http://", "https://", "www.", "ftp://"]
        let domainEndings = [".com", ".org", ".net", ".io", ".dev", ".co", ".app", ".me",
                            ".edu", ".gov", ".uk", ".in", ".ai", ".xyz"]
        
        let hasURLScheme = urlPatterns.contains(where: { text.lowercased().contains($0) })
        let hasDomain = domainEndings.contains(where: { text.lowercased().contains($0) })
        
        return hasURLScheme || (hasDomain && !looksLikeCode)
    }
    
    /// Extract the domain from a URL for display
    var extractedDomain: String? {
        guard looksLikeLink, let text = textData?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if let url = URL(string: text), let host = url.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        // Fallback: extract manually
        let cleaned = text.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        return cleaned.components(separatedBy: "/").first
    }
    
    /// Auto-classification for smart category tagging
    enum SmartCategory: String {
        case text = "Text"
        case code = "Code"
        case link = "Link"
        case image = "Image"
        case note = "Note"
    }
    
    var smartCategory: SmartCategory {
        if type == .note || isNote == true { return .note }
        if type == .image { return .image }
        if type == .code || looksLikeCode { return .code }
        if type == .link || looksLikeLink { return .link }
        return .text
    }
    
    // For Equatable so we don't accidentally append duplicate items
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        if lhs.type != rhs.type { return false }
        if lhs.type == .text || lhs.type == .note || lhs.type == .code || lhs.type == .link {
            return lhs.textData == rhs.textData && lhs.isNote == rhs.isNote
        } else {
            return lhs.imageRawData == rhs.imageRawData
        }
    }
}
