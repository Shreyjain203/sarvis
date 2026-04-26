import SwiftUI

/// Holds the mutable state bag for a dynamic screen.
/// Elements read and write values keyed by `ElementSpec.bindingKey`.
@MainActor
final class ScreenState: ObservableObject {
    @Published var values: [String: AnyCodableValue] = [:]

    /// Returns a two-way SwiftUI `Binding` for `key`, falling back to `defaultValue`
    /// when no value is present.
    func binding(for key: String, default defaultValue: AnyCodableValue) -> Binding<AnyCodableValue> {
        Binding(
            get: { [weak self] in self?.values[key] ?? defaultValue },
            set: { [weak self] in self?.values[key] = $0 }
        )
    }

    /// Convenience: read a string value (or nil).
    func string(for key: String) -> String? {
        values[key]?.stringValue
    }

    /// Convenience: read a bool value (or nil).
    func bool(for key: String) -> Bool? {
        values[key]?.boolValue
    }

    /// Reset all values to empty (used after a save action).
    func reset() {
        values = [:]
    }
}
