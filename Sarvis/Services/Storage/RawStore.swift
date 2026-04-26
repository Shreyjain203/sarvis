import Foundation

/// Persists every raw capture as an individual JSON file under `Documents/raw/<uuid>.json`.
/// The `classifier-pipeline` worker will read unprocessed entries from here and
/// distribute them into `Documents/processed/<type>.json`.
@MainActor
final class RawStore: ObservableObject {
    static let shared = RawStore()

    @Published private(set) var entries: [RawEntry] = []

    private let rawDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("raw", isDirectory: true)
    }()

    private init() {
        createRawDirectoryIfNeeded()
        loadAll()
    }

    // MARK: - Public API

    /// Persists a new `RawEntry` to `Documents/raw/<uuid>.json` and appends it
    /// to the in-memory array.
    func add(_ entry: RawEntry) {
        writeFile(entry)
        entries.append(entry)
    }

    /// Returns all entries that have not yet been processed by the classifier.
    func unprocessed() -> [RawEntry] {
        entries.filter { !$0.processed }
    }

    /// Marks the given entry as processed, stamps `processedAt`, rewrites its file,
    /// and updates the in-memory array.
    func markProcessed(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].processed = true
        entries[index].processedAt = Date()
        writeFile(entries[index])
    }

    /// Removes the entry's JSON file and its in-memory record.
    func delete(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let fileURL = entryURL(for: entries[index].id)
        try? FileManager.default.removeItem(at: fileURL)
        entries.remove(at: index)
    }

    // MARK: - Private helpers

    private func loadAll() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: rawDir,
            includingPropertiesForKeys: nil
        ) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var loaded: [RawEntry] = []
        for url in contents where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let entry = try? decoder.decode(RawEntry.self, from: data)
            else { continue }
            loaded.append(entry)
        }
        // Sort by capturedAt so the array is deterministic.
        entries = loaded.sorted { $0.capturedAt < $1.capturedAt }
    }

    private func writeFile(_ entry: RawEntry) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(entry)
            try data.write(to: entryURL(for: entry.id), options: .atomic)
        } catch {
            print("RawStore write error (\(entry.id)):", error)
        }
    }

    private func entryURL(for id: UUID) -> URL {
        rawDir.appendingPathComponent("\(id.uuidString).json")
    }

    private func createRawDirectoryIfNeeded() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: rawDir.path) else { return }
        do {
            try fm.createDirectory(at: rawDir, withIntermediateDirectories: true)
        } catch {
            print("RawStore: failed to create raw/ directory:", error)
        }
    }
}
