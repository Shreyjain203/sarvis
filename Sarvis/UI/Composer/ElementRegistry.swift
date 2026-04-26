import SwiftUI

/// Central plug-in registry. Elements are registered by string type key and
/// rendered on demand by `DynamicScreen`.
///
/// Usage — registering a new element in 4 lines:
/// ```swift
/// ElementRegistry.shared.register("MyElement") { spec, state in
///     AnyView(MyElementView(spec: spec, state: state))
/// }
/// ```
@MainActor
final class ElementRegistry {
    static let shared = ElementRegistry()

    typealias Factory = (ElementSpec, ScreenState) -> AnyView

    private var factories: [String: Factory] = [:]

    private init() {}

    /// Register an element factory for `type`.
    func register(_ type: String, factory: @escaping Factory) {
        factories[type] = factory
    }

    /// Produce a view for `spec` using the registered factory, or fall back to
    /// `UnknownElementView` when no factory is found.
    func make(_ spec: ElementSpec, state: ScreenState) -> AnyView {
        factories[spec.type]?(spec, state) ?? AnyView(UnknownElementView(typeName: spec.type))
    }

    /// Wire every built-in element type to its factory.
    /// Call once from `SarvisApp.init()`.
    func registerBuiltIns() {
        // Input
        register("Input/TextInput") { spec, state in
            AnyView(TextInputView(spec: spec, state: state))
        }
        register("Input/CalendarPicker") { spec, state in
            AnyView(CalendarPickerView(spec: spec, state: state))
        }
        register("Input/TypeChip") { spec, state in
            AnyView(TypeChipView(spec: spec, state: state))
        }
        register("Input/ImportancePicker") { spec, state in
            AnyView(ImportancePickerView(spec: spec, state: state))
        }
        register("Input/ToggleRow") { spec, state in
            AnyView(ToggleRowView(spec: spec, state: state))
        }
        register("Input/ShoppingItem") { spec, state in
            AnyView(ShoppingItemView(spec: spec, state: state))
        }
        // Display
        register("Display/SummaryCard") { spec, state in
            AnyView(SummaryCardView(spec: spec, state: state))
        }
        register("Display/ActionButton") { spec, state in
            AnyView(ActionButtonView(spec: spec, state: state))
        }
        register("Display/TodoListRow") { spec, state in
            AnyView(TodoListRowView(spec: spec, state: state))
        }
        register("Display/NotesListRow") { spec, state in
            AnyView(NotesListRowView(spec: spec, state: state))
        }
        register("Display/ShoppingListRow") { spec, state in
            AnyView(ShoppingListRowView(spec: spec, state: state))
        }
        register("Display/DiaryEntry") { spec, state in
            AnyView(DiaryEntryView(spec: spec, state: state))
        }
        register("Display/QuoteCard") { spec, state in
            AnyView(QuoteCardView(spec: spec, state: state))
        }
        register("Display/NewsHeadline") { spec, state in
            AnyView(NewsHeadlineView(spec: spec, state: state))
        }
    }
}
