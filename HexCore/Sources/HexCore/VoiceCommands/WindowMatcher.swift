import Foundation

/// A candidate window for voice command matching.
public struct WindowCandidate: Sendable {
    public let appName: String
    public let windowTitle: String
    public let index: Int

    public init(appName: String, windowTitle: String, index: Int) {
        self.appName = appName
        self.windowTitle = windowTitle
        self.index = index
    }
}

/// Scores candidate windows against a voice command target string and returns the best match.
public enum WindowMatcher {

    /// Separators used to split window titles and app names into tokens.
    private static let separatorCharacters = CharacterSet.whitespaces
        .union(CharacterSet(charactersIn: "|-:,"))

    /// Tokenize a string: lowercase, split by separators, remove empty tokens.
    private static func tokenize(_ string: String) -> [String] {
        string
            .lowercased()
            .components(separatedBy: separatorCharacters)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Score a target against a single text field (window title or app name).
    /// Returns the best score from the scoring heuristics.
    private static func score(target: String, against text: String) -> Int {
        let targetLower = target.lowercased()
        let textLower = text.lowercased()

        let targetTokens = tokenize(target)
        let textTokens = tokenize(text)

        guard !targetTokens.isEmpty, !textTokens.isEmpty else { return 0 }

        var best = 0

        // 1. Exact token match (score 100):
        //    The target as a whole equals one of the text tokens,
        //    or the set of target tokens exactly equals a subset of text tokens
        //    (all target tokens present and all text has them).
        if textTokens.contains(targetLower) {
            best = max(best, 100)
        }
        // Also check if all target tokens are in text tokens and they form an exact match
        // (e.g. target "shopping list" has tokens ["shopping", "list"] that all appear in text tokens)
        if targetTokens.allSatisfy({ token in textTokens.contains(token) }) && targetTokens.count > 1 {
            // Multi-token exact: all target tokens found in candidate tokens
            best = max(best, 100)
        }

        // 2. Substring containment (score 90):
        //    The target appears as a contiguous substring within the text.
        if textLower.contains(targetLower) {
            best = max(best, 90)
        }

        // 3. Token overlap (score = matching/total * 80):
        //    Count how many target tokens appear in the text tokens.
        let matchingCount = targetTokens.filter { targetToken in
            textTokens.contains(targetToken)
        }.count
        if matchingCount > 0 {
            let overlapScore = Int((Double(matchingCount) / Double(targetTokens.count)) * 80.0)
            best = max(best, overlapScore)
        }

        // 4. Prefix matching (score 70):
        //    Any text token starts with the full target string.
        if textTokens.contains(where: { $0.hasPrefix(targetLower) }) {
            best = max(best, 70)
        }

        return best
    }

    /// Find the best matching window candidate for a voice command target.
    ///
    /// - Parameters:
    ///   - target: The voice command target string (e.g. "huddle", "slack", "my document").
    ///   - candidates: Array of window candidates to match against.
    ///   - threshold: Minimum score required to return a match (default 50).
    /// - Returns: A tuple of the matching candidate's index and its score, or nil if no match meets the threshold.
    public static func bestMatch(
        target: String,
        candidates: [WindowCandidate],
        threshold: Int = 50
    ) -> (index: Int, score: Int)? {
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty, !candidates.isEmpty else { return nil }

        var bestIndex: Int? = nil
        var bestScore = 0

        for candidate in candidates {
            // Score against window title (no penalty)
            let titleScore = score(target: trimmedTarget, against: candidate.windowTitle)

            // Score against app name (with -5 penalty)
            let appRawScore = score(target: trimmedTarget, against: candidate.appName)
            let appScore = appRawScore > 0 ? appRawScore - 5 : 0

            let candidateScore = max(titleScore, appScore)

            // Only update if strictly better (preserves input order on ties)
            if candidateScore > bestScore {
                bestScore = candidateScore
                bestIndex = candidate.index
            }
        }

        guard let index = bestIndex, bestScore >= threshold else { return nil }
        return (index: index, score: bestScore)
    }
}
