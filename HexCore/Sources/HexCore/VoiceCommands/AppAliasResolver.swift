// MARK: - App Alias Resolution

/// Resolves voice command targets against user-configured app aliases.
///
/// Given a target string (e.g. "terminal") and an array of `AppAlias` entries,
/// returns the mapped app name if a matching enabled alias is found, or the
/// original target unchanged.
///
/// This is a stateless, pure function with no side effects. The target is
/// expected to arrive already trimmed/lowercased from `VoiceCommandDetector`.
public enum AppAliasResolver {

    /// Resolves the given target against the provided aliases.
    ///
    /// - Parameters:
    ///   - target: The voice command target (e.g. "terminal").
    ///   - aliases: The user's configured app aliases.
    /// - Returns: The alias's `appName` if a matching enabled alias is found,
    ///   or the original `target` if no match exists.
    public static func resolve(target: String, aliases: [AppAlias]) -> String {
        let targetLower = target.lowercased()

        for alias in aliases where alias.isEnabled {
            if alias.alias.lowercased() == targetLower {
                return alias.appName
            }
        }

        return target
    }
}
