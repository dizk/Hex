// MARK: - Voice Command Detection

/// Detects voice commands from transcribed text by checking for known trigger
/// prefixes ("switch to", "go to", "open", etc.) and extracting the target.
///
/// Follows the same structural pattern as `ForceQuitCommandDetector` in
/// `TranscriptionFeature.swift` -- a simple type with a static detection method.
public enum VoiceCommandDetector {

    /// Maximum number of words allowed in a voice command. Transcriptions longer
    /// than this are assumed to be dictation, not commands.
    private static let maxWordCount = 10

    /// Trigger prefixes checked in order. Longer prefixes come first so that
    /// "show me" is matched before "show", and "bring up" before "bring".
    private static let prefixes = [
        "switch to",
        "bring up",
        "show me",
        "go to",
        "focus",
        "open",
        "show",
    ]

    /// Common transcription misrecognitions mapped to the intended prefix text.
    /// Applied before prefix matching so that e.g. "switch two" is treated as
    /// "switch to".
    private static let misrecognitions: [(wrong: String, correct: String)] = [
        ("switch two", "switch to"),
        ("go too", "go to"),
    ]

    /// Attempts to detect a voice command in the given transcription.
    ///
    /// - Parameter transcription: The raw transcribed text.
    /// - Returns: The extracted target (e.g., "huddle" from "switch to huddle"),
    ///   or `nil` if no command was detected.
    public static func detect(_ transcription: String) -> String? {
        let normalized = normalize(transcription)

        // Reject if empty or exceeds word limit
        guard !normalized.isEmpty else { return nil }
        let wordCount = normalized.split(separator: " ").count
        guard wordCount <= maxWordCount else { return nil }

        // Apply misrecognition corrections
        var text = normalized
        for m in misrecognitions {
            if text.hasPrefix(m.wrong) {
                text = m.correct + text.dropFirst(m.wrong.count)
            }
        }

        // Check each prefix (longest-first ordering)
        for prefix in prefixes {
            guard text.hasPrefix(prefix) else { continue }

            let afterPrefix = text.dropFirst(prefix.count)

            // The character right after the prefix must be a space (or end of string)
            if afterPrefix.isEmpty {
                // Prefix matches but no target
                return nil
            }
            guard afterPrefix.first == " " else {
                // Prefix is a substring of a longer word (e.g. "shower")
                continue
            }

            let target = afterPrefix.drop(while: { $0 == " " })
            let trimmed = String(target).trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }

    // MARK: - Private

    /// Normalizes input: lowercases, trims whitespace, collapses internal runs of
    /// whitespace to single spaces, and strips trailing punctuation.
    private static func normalize(_ text: String) -> String {
        var result = text
            .lowercased()
            .trimmingCharacters(in: .whitespaces)

        // Collapse multiple spaces into one
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        // Strip trailing punctuation (periods, commas, exclamation, question marks)
        let trailingPunctuation: Set<Character> = [".", ",", "!", "?"]
        while let last = result.last, trailingPunctuation.contains(last) {
            result = String(result.dropLast())
        }

        return result.trimmingCharacters(in: .whitespaces)
    }
}
