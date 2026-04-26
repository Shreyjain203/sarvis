import Foundation

/// A lightweight JSON-value enum that lets element configs be typed without
/// bespoke `Codable` implementations per element.
@frozen
enum AnyCodableValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])
    case null

    // MARK: Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([AnyCodableValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: AnyCodableValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "AnyCodableValue: unsupported JSON structure")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:           try container.encodeNil()
        case .bool(let b):    try container.encode(b)
        case .int(let i):     try container.encode(i)
        case .double(let d):  try container.encode(d)
        case .string(let s):  try container.encode(s)
        case .array(let a):   try container.encode(a)
        case .object(let o):  try container.encode(o)
        }
    }

    // MARK: Convenience accessors

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let d) = self { return d }
        if case .int(let i)    = self { return Double(i) }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}
