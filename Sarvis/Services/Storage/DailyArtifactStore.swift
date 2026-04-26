import Foundation

/// Generic helper for date-keyed JSON artifacts stored under
/// `Documents/processed/<folder>/<YYYY-MM-DD>.json`.
///
/// Usage examples:
/// ```swift
/// // Write today's news summary
/// DailyArtifactStore.shared.write(newsSummary, folder: "news", date: Date())
///
/// // Read today's plan
/// let plan: DailyPlan? = DailyArtifactStore.shared.read(folder: "plans", date: Date())
/// ```
final class DailyArtifactStore {
    static let shared = DailyArtifactStore()

    private let processedDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("processed", isDirectory: true)
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    private init() {}

    // MARK: - Public API

    /// Reads a date-keyed artifact from `Documents/processed/<folder>/<YYYY-MM-DD>.json`.
    /// Returns `nil` if the file does not exist or cannot be decoded.
    func read<T: Codable>(folder: String, date: Date) -> T? {
        let url = fileURL(folder: folder, date: date)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    /// Writes a date-keyed artifact to `Documents/processed/<folder>/<YYYY-MM-DD>.json`
    /// atomically. Creates the folder if it does not exist.
    func write<T: Codable>(_ value: T, folder: String, date: Date) {
        let dir = processedDir.appendingPathComponent(folder, isDirectory: true)
        createDirectoryIfNeeded(dir)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(value)
            try data.write(to: fileURL(folder: folder, date: date), options: .atomic)
        } catch {
            print("DailyArtifactStore write error (\(folder)/\(dateFormatter.string(from: date))):", error)
        }
    }

    // MARK: - Private helpers

    private func fileURL(folder: String, date: Date) -> URL {
        processedDir
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent("\(dateFormatter.string(from: date)).json")
    }

    private func createDirectoryIfNeeded(_ url: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path) else { return }
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            print("DailyArtifactStore: failed to create directory \(url.lastPathComponent):", error)
        }
    }
}
