import Testing
@testable import HexCore

struct WindowMatcherTests {

    // MARK: - Helpers

    private func candidate(_ appName: String, _ windowTitle: String, _ index: Int) -> WindowCandidate {
        WindowCandidate(appName: appName, windowTitle: windowTitle, index: index)
    }

    // MARK: - Substring containment

    @Test
    func huddle_matchesSlackHuddleWithKit_substringContainment() {
        let candidates = [
            candidate("Slack", "Huddle with Kit", 0),
            candidate("Safari", "Google Search", 1),
        ]
        let result = WindowMatcher.bestMatch(target: "huddle", candidates: candidates)
        #expect(result != nil)
        #expect(result!.index == 0)
        #expect(result!.score >= 90)
    }

    // MARK: - App name match

    @Test
    func slack_matchesSlackGeneral_viaAppName() {
        let candidates = [
            candidate("Slack", "General", 0),
            candidate("Safari", "Google Search", 1),
        ]
        let result = WindowMatcher.bestMatch(target: "slack", candidates: candidates)
        #expect(result != nil)
        #expect(result!.index == 0)
    }

    // MARK: - Token match

    @Test
    func chrome_matchesGoogleChrome_tokenMatch() {
        let candidates = [
            candidate("Google Chrome", "New Tab", 0),
            candidate("Safari", "Apple", 1),
        ]
        let result = WindowMatcher.bestMatch(target: "chrome", candidates: candidates)
        #expect(result != nil)
        #expect(result!.index == 0)
    }

    // MARK: - Exact token match

    @Test
    func terminal_matchesTerminal_exactTokenMatch() {
        // Terminal.app typically shows its name in the window title
        let candidates = [
            candidate("Terminal", "Terminal -- bash", 0),
        ]
        let result = WindowMatcher.bestMatch(target: "terminal", candidates: candidates)
        #expect(result != nil)
        #expect(result!.index == 0)
        #expect(result!.score == 100)
    }

    // MARK: - Substring match with file name

    @Test
    func myDocument_matchesMyDocumentTxt_substring() {
        let candidates = [
            candidate("TextEdit", "my document.txt - TextEdit", 0),
            candidate("Safari", "Apple", 1),
        ]
        let result = WindowMatcher.bestMatch(target: "my document", candidates: candidates)
        #expect(result != nil)
        #expect(result!.index == 0)
        #expect(result!.score >= 80)
    }

    // MARK: - No match (below threshold)

    @Test
    func xyz123_returnsNil_whenNoCandidateMatches() {
        let candidates = [
            candidate("Slack", "General", 0),
            candidate("Safari", "Google", 1),
        ]
        let result = WindowMatcher.bestMatch(target: "xyz123", candidates: candidates)
        #expect(result == nil)
    }

    // MARK: - Empty target

    @Test
    func emptyTarget_returnsNil() {
        let candidates = [
            candidate("Slack", "General", 0),
        ]
        let result = WindowMatcher.bestMatch(target: "", candidates: candidates)
        #expect(result == nil)
    }

    // MARK: - Empty candidates

    @Test
    func emptyCandidates_returnsNil() {
        let result = WindowMatcher.bestMatch(target: "slack", candidates: [])
        #expect(result == nil)
    }

    // MARK: - Multiple candidates: returns highest scoring

    @Test
    func multipleCandidates_returnsHighestScoring() {
        let candidates = [
            candidate("Safari", "Google Search", 0),
            candidate("Terminal", "terminal - bash", 1),
            candidate("Slack", "General", 2),
        ]
        let result = WindowMatcher.bestMatch(target: "terminal", candidates: candidates)
        #expect(result != nil)
        #expect(result!.index == 1)
    }

    // MARK: - Tie-breaking: first candidate wins

    @Test
    func tieBreaking_returnsFirstCandidate() {
        let candidates = [
            candidate("Notes", "Shopping List", 0),
            candidate("Notes", "Shopping List", 1),
        ]
        let result = WindowMatcher.bestMatch(target: "shopping list", candidates: candidates)
        #expect(result != nil)
        #expect(result!.index == 0)
    }

    // MARK: - Case insensitivity

    @Test
    func caseInsensitive_uppercaseTargetMatchesLowercaseCandidate() {
        let candidates = [
            candidate("Slack", "General", 0),
        ]
        let result = WindowMatcher.bestMatch(target: "SLACK", candidates: candidates)
        #expect(result != nil)
        #expect(result!.index == 0)
    }

    // MARK: - App name penalty

    @Test
    func appNamePenalty_windowTitleMatchScoredHigherThanAppNameMatch() {
        // "notes" appears as a token in both the app name and the window title of different candidates.
        // The window title match (candidate 1) should score higher than the app name match (candidate 0).
        let candidates = [
            candidate("Notes", "Shopping List", 0),
            candidate("Safari", "Notes on Swift", 1),
        ]
        let result = WindowMatcher.bestMatch(target: "notes", candidates: candidates)
        #expect(result != nil)
        #expect(result!.index == 1)
    }

    // MARK: - Token separators

    @Test
    func tokenSeparators_huddle_matchesEmDashSeparator() {
        let candidates = [
            candidate("Slack", "Huddle--Kit", 0),
        ]
        let result = WindowMatcher.bestMatch(target: "huddle", candidates: candidates)
        #expect(result != nil)
        #expect(result!.index == 0)
    }

    // MARK: - Multi-token target (token overlap)

    @Test
    func multiTokenTarget_huddleKit_matchesSlackHuddleWithKit() {
        let candidates = [
            candidate("Slack", "Huddle with Kit", 0),
            candidate("Safari", "Google Search", 1),
        ]
        let result = WindowMatcher.bestMatch(target: "huddle kit", candidates: candidates)
        #expect(result != nil)
        #expect(result!.index == 0)
        // All target tokens found -> exact token match -> score 100
        #expect(result!.score >= 80)
    }
}
