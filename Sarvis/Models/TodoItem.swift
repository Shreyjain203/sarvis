import Foundation

enum Importance: Int, Codable, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var symbol: String {
        switch self {
        case .low: return "circle"
        case .medium: return "exclamationmark.circle"
        case .high: return "exclamationmark.triangle"
        case .critical: return "flame.fill"
        }
    }
}

struct TodoItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String
    var importance: Importance = .medium
    var isSensitive: Bool = false
    var type: InputType = .task
    var createdAt: Date = Date()
    var dueAt: Date?
    var isDone: Bool = false
    var notificationID: String?
}
