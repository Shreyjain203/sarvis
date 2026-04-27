import Foundation
import SwiftUI

final class TodoStore: ObservableObject {
    static let shared = TodoStore()

    /// Flattened view of all items across every typed file. Existing accessors
    /// (`todayItems`, `sensitiveItems`, `todayItems(importance:)`) read from here.
    @Published private(set) var items: [TodoItem] = []

    private let documentsDir: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]

    private var processedDir: URL {
        documentsDir.appendingPathComponent("processed", isDirectory: true)
    }

    // MARK: - Init + migration

    init() {
        createProcessedDirectoryIfNeeded()
        migrateIfNeeded()
        loadAll()
    }

    // MARK: - Public CRUD

    func add(_ item: TodoItem) {
        items.append(item)
        writeTypeFile(item.type)
    }

    func update(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        let oldType = items[i].type
        items[i] = item
        if oldType != item.type {
            // Item changed type — rewrite both files.
            writeTypeFile(oldType)
        }
        writeTypeFile(item.type)
    }

    func delete(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let type = items[i].type
        items.remove(at: i)
        writeTypeFile(type)
    }

    func toggleDone(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isDone.toggle()
        // Stamp / clear completedAt to keep the completed-history view sortable.
        items[i].completedAt = items[i].isDone ? Date() : nil
        writeTypeFile(items[i].type)
    }

    // MARK: - Category query

    func items(in type: InputType) -> [TodoItem] {
        items.filter { $0.type == type }
    }

    // MARK: - Computed views used by TodayView

    var todayItems: [TodoItem] {
        let cal = Calendar.current
        return items
            .filter { item in
                if let due = item.dueAt { return cal.isDateInToday(due) }
                return cal.isDateInToday(item.createdAt)
            }
            .sorted { $0.importance.rawValue > $1.importance.rawValue }
    }

    var sensitiveItems: [TodoItem] {
        todayItems.filter { $0.isSensitive }
    }

    func todayItems(importance: Importance) -> [TodoItem] {
        todayItems.filter { $0.importance == importance && !$0.isSensitive }
    }

    // MARK: - Widget / public capture API

    /// Persists a raw capture to `Documents/raw/<uuid>.json` and returns a
    /// synthesized in-memory `TodoItem` for the caller's local use (e.g. to
    /// schedule a notification immediately). The returned item is NOT written
    /// to any `processed/<type>.json` bucket — that's the classifier's job.
    ///
    /// Stable API surface:
    ///   `TodoStore.shared.capture(text:type:importance:isSensitive:dueAt:)`
    ///
    /// Callers that previously relied on the saved item appearing in
    /// `TodoStore.items` immediately must now click "Process" (which runs the
    /// classifier) before items materialise into the processed buckets.
    @discardableResult
    func capture(
        text: String,
        type: InputType? = nil,
        importance: Importance = .medium,
        isSensitive: Bool = false,
        dueAt: Date? = nil
    ) -> TodoItem {
        // Build and persist the raw entry — single source of truth for new captures.
        let rawID = UUID()
        let entry = RawEntry(
            id: rawID,
            text: text,
            importance: importance,
            isSensitive: isSensitive,
            suggestedType: type,
            dueAt: dueAt,
            capturedAt: Date(),
            processed: false,
            processedAt: nil,
            notificationID: nil
        )
        Task { @MainActor in RawStore.shared.add(entry) }

        // Synthesize an in-memory TodoItem for the caller. NOT persisted to
        // TodoStore — the classifier will materialise the canonical item.
        // The id matches the raw entry id so the caller can correlate them
        // (e.g. to write a notificationID back onto the raw via RawStore).
        return TodoItem(
            id: rawID,
            text: text,
            importance: importance,
            isSensitive: isSensitive,
            type: type ?? .other,
            createdAt: entry.capturedAt,
            dueAt: dueAt,
            isDone: false,
            notificationID: nil
        )
    }

    // MARK: - Private persistence helpers

    private func fileURL(for type: InputType) -> URL {
        processedDir.appendingPathComponent(type.fileName)
    }

    private func createProcessedDirectoryIfNeeded() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: processedDir.path) else { return }
        do {
            try fm.createDirectory(at: processedDir, withIntermediateDirectories: true)
        } catch {
            print("TodoStore: failed to create processed/ directory:", error)
        }
    }

    /// Write only the items belonging to `type` into its dedicated JSON file.
    private func writeTypeFile(_ type: InputType) {
        let subset = items.filter { $0.type == type }
        do {
            let data = try JSONEncoder().encode(subset)
            try data.write(to: fileURL(for: type), options: .atomic)
        } catch {
            print("TodoStore write error (\(type.fileName)):", error)
        }
    }

    /// Load all typed files and flatten into `items`.
    private func loadAll() {
        var all: [TodoItem] = []
        for type in InputType.allCases {
            let url = fileURL(for: type)
            guard let data = try? Data(contentsOf: url) else { continue }
            let decoded = (try? JSONDecoder().decode([TodoItem].self, from: data)) ?? []
            all.append(contentsOf: decoded)
        }
        items = all
    }

    // MARK: - Migration

    /// Handles two migration steps:
    /// 1. Moves flat `Documents/<type>.json` files into `Documents/processed/<type>.json`
    ///    (migration from storage-layout-v1 to v2).
    /// 2. If the legacy `Documents/todos.json` still exists, decodes and distributes its
    ///    items into the new per-type files under `processed/`, then removes it.
    /// Errors are logged and originals are left untouched on failure.
    private func migrateIfNeeded() {
        let fm = FileManager.default

        // Step 1: Move flat per-type files into processed/ if the new path doesn't yet exist.
        for type in InputType.allCases {
            let oldURL = documentsDir.appendingPathComponent(type.fileName)
            let newURL = fileURL(for: type)
            guard fm.fileExists(atPath: oldURL.path),
                  !fm.fileExists(atPath: newURL.path) else { continue }
            do {
                try fm.moveItem(at: oldURL, to: newURL)
                print("TodoStore: moved \(type.fileName) → processed/\(type.fileName)")
            } catch {
                print("TodoStore: could not move \(type.fileName) — leaving original:", error)
            }
        }

        // Step 2: Migrate legacy todos.json if present.
        let legacyURL = documentsDir.appendingPathComponent("todos.json")
        guard fm.fileExists(atPath: legacyURL.path) else { return }
        do {
            let data = try Data(contentsOf: legacyURL)
            var legacy = try JSONDecoder().decode([TodoItem].self, from: data)

            // Infer type for items that were stored without one (default decoding gives .task).
            // Override: if isSensitive → .sensitive.
            for i in legacy.indices {
                if legacy[i].isSensitive {
                    legacy[i].type = .sensitive
                }
                // else: already defaulted to .task by Codable synthesised init
            }

            // Distribute into per-type buckets and write atomically under processed/.
            for type in InputType.allCases {
                let subset = legacy.filter { $0.type == type }
                guard !subset.isEmpty else { continue }
                let encoded = try JSONEncoder().encode(subset)
                try encoded.write(to: fileURL(for: type), options: .atomic)
            }

            // Remove the old file only after all new files have been written.
            try fm.removeItem(at: legacyURL)
            print("TodoStore: migrated \(legacy.count) items from todos.json → processed/")
        } catch {
            print("TodoStore migration error — leaving todos.json intact:", error)
        }
    }
}
