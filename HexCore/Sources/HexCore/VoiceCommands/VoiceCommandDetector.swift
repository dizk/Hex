// MARK: - Voice Command Detection

/// Detects voice commands from transcribed text by checking for known trigger
/// prefixes ("switch to", "go to", "open", etc.) and extracting the target.
///
/// Follows the same structural pattern as `ForceQuitCommandDetector` in
/// `TranscriptionFeature.swift` -- a simple type with a static detection method.
public enum VoiceCommandDetector {
    /// Attempts to detect a voice command in the given transcription.
    ///
    /// - Parameter transcription: The raw transcribed text.
    /// - Returns: The extracted target (e.g., "huddle" from "switch to huddle"),
    ///   or `nil` if no command was detected.
    public static func detect(_ transcription: String) -> String? {
        // Stub: not yet implemented
        nil
    }
}
