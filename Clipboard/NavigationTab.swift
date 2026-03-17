import SwiftUI

enum NavigationTab: String, CaseIterable, Identifiable {
    case history = "History"
    case favorites = "Favorites"
    case search = "Search"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .history: return "clock.arrow.circlepath"
        case .favorites: return "star.fill"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape.fill"
        }
    }
    
    var shortcutKey: KeyEquivalent {
        switch self {
        case .history: return "1"
        case .favorites: return "2"
        case .search: return "3"
        case .settings: return "4"
        }
    }
}
