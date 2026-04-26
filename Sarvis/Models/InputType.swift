import Foundation

enum InputType: String, Codable, CaseIterable, Identifiable {
    case task
    case note
    case idea
    case sensitive
    case other
    case diary
    case suggestion
    case shopping
    case quote

    var id: String { rawValue }

    var label: String {
        switch self {
        case .task:       return "Task"
        case .note:       return "Note"
        case .idea:       return "Idea"
        case .sensitive:  return "Sensitive"
        case .other:      return "Other"
        case .diary:      return "Diary"
        case .suggestion: return "Suggestion"
        case .shopping:   return "Shopping"
        case .quote:      return "Quote"
        }
    }

    var symbol: String {
        switch self {
        case .task:       return "checkmark.circle"
        case .note:       return "doc.text"
        case .idea:       return "lightbulb"
        case .sensitive:  return "lock.fill"
        case .other:      return "ellipsis.circle"
        case .diary:      return "book.closed"
        case .suggestion: return "lightbulb"
        case .shopping:   return "cart"
        case .quote:      return "quote.bubble"
        }
    }

    /// The JSON file name used to persist items of this type under Documents/processed/.
    var fileName: String {
        switch self {
        case .task:       return "tasks.json"
        case .note:       return "notes.json"
        case .idea:       return "ideas.json"
        case .sensitive:  return "sensitive.json"
        case .other:      return "other.json"
        case .diary:      return "diary.json"
        case .suggestion: return "suggestions.json"
        case .shopping:   return "shopping.json"
        case .quote:      return "quotes.json"
        }
    }
}
