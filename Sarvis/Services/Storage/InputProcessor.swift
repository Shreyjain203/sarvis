import Foundation

// MARK: - Raw input (pre-processing)

struct RawInput {
    var text: String
    var importance: Importance
    var isSensitive: Bool
    var type: InputType?
    var dueAt: Date?
}

// MARK: - Processed output (post-processing)

struct ProcessedInput {
    var item: TodoItem
}

// MARK: - Middleware processor

enum InputProcessor {
    /// Transforms a `RawInput` into a `ProcessedInput` containing the final `TodoItem`.
    ///
    /// Currently a no-op pass-through. The resolved `InputType` defaults:
    /// - If `raw.type` is provided, it is used as-is.
    /// - If `raw.type` is nil and `raw.isSensitive` is true → `.sensitive`.
    /// - Otherwise → `.task`.
    ///
    /// TODO: future classification — insert ML/rule-based classification logic here.
    ///       Ideas: auto-detect sensitive content and set `isSensitive`, classify
    ///       free-form text into note/task/idea buckets, apply redaction for PII,
    ///       enrich with tags or categories before persistence.
    @discardableResult
    static func process(_ raw: RawInput) -> ProcessedInput {
        let resolvedType: InputType
        if let explicitType = raw.type {
            resolvedType = explicitType
        } else if raw.isSensitive {
            resolvedType = .sensitive
        } else {
            resolvedType = .task
        }

        let item = TodoItem(
            text: raw.text,
            importance: raw.importance,
            isSensitive: raw.isSensitive,
            type: resolvedType,
            dueAt: raw.dueAt
        )

        return ProcessedInput(item: item)
    }
}
