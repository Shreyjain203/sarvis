import Foundation

/// Urgency levels for a shopping-list item. Persisted as raw string values.
enum ShoppingUrgency: String, Codable, CaseIterable, Identifiable {
    case today
    case nextVisit
    case thisWeek
    case someday

    var id: String { rawValue }

    /// Human-readable chip label.
    var label: String {
        switch self {
        case .today:     return "Today"
        case .nextVisit: return "Next visit"
        case .thisWeek:  return "This week"
        case .someday:   return "Someday"
        }
    }

    /// SF Symbol name for the chip icon.
    var symbol: String {
        switch self {
        case .today:     return "bolt.fill"
        case .nextVisit: return "bag"
        case .thisWeek:  return "calendar"
        case .someday:   return "infinity"
        }
    }
}
