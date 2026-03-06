import Testing
@testable import HexCore

struct AppAliasResolverTests {

    // MARK: - Basic resolution

    @Test
    func basicResolution_terminalAlias_returnsGhostty() {
        let aliases = [
            AppAlias(alias: "terminal", appName: "Ghostty"),
        ]
        let result = AppAliasResolver.resolve(target: "terminal", aliases: aliases)
        #expect(result == "Ghostty")
    }

    // MARK: - Case insensitive matching

    @Test
    func caseInsensitive_lowercaseTargetMatchesCapitalizedAlias() {
        let aliases = [
            AppAlias(alias: "Terminal", appName: "Ghostty"),
        ]
        let result = AppAliasResolver.resolve(target: "terminal", aliases: aliases)
        #expect(result == "Ghostty")
    }

    // MARK: - No match returns original

    @Test
    func noMatch_returnsOriginalTarget() {
        let aliases = [
            AppAlias(alias: "terminal", appName: "Ghostty"),
        ]
        let result = AppAliasResolver.resolve(target: "chrome", aliases: aliases)
        #expect(result == "chrome")
    }

    // MARK: - Disabled alias skipped

    @Test
    func disabledAlias_isSkipped_returnsOriginal() {
        let aliases = [
            AppAlias(isEnabled: false, alias: "terminal", appName: "Ghostty"),
        ]
        let result = AppAliasResolver.resolve(target: "terminal", aliases: aliases)
        #expect(result == "terminal")
    }

    // MARK: - Empty aliases returns original

    @Test
    func emptyAliases_returnsOriginalTarget() {
        let result = AppAliasResolver.resolve(target: "slack", aliases: [])
        #expect(result == "slack")
    }

    // MARK: - Multiple aliases for same app

    @Test
    func multipleAliasesForSameApp_matchesCorrectAlias() {
        let aliases = [
            AppAlias(alias: "terminal", appName: "Ghostty"),
            AppAlias(alias: "console", appName: "Ghostty"),
        ]
        let result = AppAliasResolver.resolve(target: "console", aliases: aliases)
        #expect(result == "Ghostty")
    }

    // MARK: - First match wins on duplicate triggers

    @Test
    func duplicateTriggers_firstMatchWins() {
        let aliases = [
            AppAlias(alias: "terminal", appName: "Ghostty"),
            AppAlias(alias: "terminal", appName: "iTerm"),
        ]
        let result = AppAliasResolver.resolve(target: "terminal", aliases: aliases)
        #expect(result == "Ghostty")
    }

    // MARK: - Alias overrides real app name

    @Test
    func aliasOverridesRealAppName() {
        let aliases = [
            AppAlias(alias: "safari", appName: "Firefox"),
        ]
        let result = AppAliasResolver.resolve(target: "safari", aliases: aliases)
        #expect(result == "Firefox")
    }

    // MARK: - Empty target returns empty

    @Test
    func emptyTarget_returnsEmpty() {
        let result = AppAliasResolver.resolve(target: "", aliases: [])
        #expect(result == "")
    }

    // MARK: - Whitespace handling (no extra trimming needed)

    @Test
    func exactMatchRequired_noWhitespaceTrimming() {
        let aliases = [
            AppAlias(alias: "terminal", appName: "Ghostty"),
        ]
        // Target with extra whitespace should NOT match since VoiceCommandDetector
        // already trims input before it reaches the resolver
        let result = AppAliasResolver.resolve(target: "  terminal  ", aliases: aliases)
        #expect(result == "  terminal  ")
    }
}
