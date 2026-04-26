import Foundation

/// Loads LLM prompt bodies from bundled markdown files.
///
/// Each `.md` file in `Sarvis/Resources/Prompts/` starts with a YAML-style
/// header block (lines before the first `---` separator), followed by `---`, then the
/// prompt body.  `PromptLibrary.body(for:fallback:)` strips the header and returns
/// just the trimmed body text.
///
/// To add a new prompt:
/// 1. Create `prompts/<name>.md` in the repo root (with the required header).
/// 2. Run `./tools/sync-prompts.sh` to copy it into `Sarvis/Resources/Prompts/`.
/// 3. Call `PromptLibrary.body(for: "<name>", fallback: "…")` wherever you need it.
enum PromptLibrary {

    /// Returns the body of a prompt file bundled as `<name>.md`.
    ///
    /// The file is expected to contain a YAML-style header separated from the body
    /// by a `---` line:
    /// ```
    /// purpose: …
    /// when_used: …
    /// variables: …
    /// ---
    /// <body text>
    /// ```
    /// Everything up to and including the first `---` line is stripped.
    /// If the file is missing, unreadable, or empty after stripping, `fallback` is
    /// returned so the caller always has a usable string.
    ///
    /// - Parameters:
    ///   - name: The base name of the markdown file (without `.md` extension).
    ///   - fallback: The string to use when the file cannot be loaded.
    /// - Returns: The trimmed prompt body, or `fallback`.
    static func body(for name: String, fallback: String) -> String {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "md"),
            let raw = try? String(contentsOf: url, encoding: .utf8)
        else {
            return fallback
        }

        // Split on lines, find the first `---` separator, return everything after it.
        let lines = raw.components(separatedBy: "\n")
        guard let separatorIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            // No separator found — treat the entire file as the body.
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? fallback : trimmed
        }

        let bodyLines = lines[(separatorIndex + 1)...]
        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? fallback : body
    }
}
