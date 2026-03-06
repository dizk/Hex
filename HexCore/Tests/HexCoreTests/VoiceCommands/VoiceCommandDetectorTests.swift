import Testing
@testable import HexCore

struct VoiceCommandDetectorTests {

    // MARK: - Basic prefix detection

    @Test
    func switchToHuddle() {
        #expect(VoiceCommandDetector.detect("switch to huddle") == "huddle")
    }

    @Test
    func switchToHuddle_caseInsensitive_stripsPeriod() {
        #expect(VoiceCommandDetector.detect("Switch To Huddle.") == "huddle")
    }

    @Test
    func goToSlack() {
        #expect(VoiceCommandDetector.detect("go to slack") == "slack")
    }

    @Test
    func openTerminal() {
        #expect(VoiceCommandDetector.detect("open terminal") == "terminal")
    }

    @Test
    func focusChrome() {
        #expect(VoiceCommandDetector.detect("focus chrome") == "chrome")
    }

    @Test
    func bringUpMessages() {
        #expect(VoiceCommandDetector.detect("bring up messages") == "messages")
    }

    @Test
    func showMeTheCalendar() {
        #expect(VoiceCommandDetector.detect("show me the calendar") == "the calendar")
    }

    @Test
    func showFinder() {
        #expect(VoiceCommandDetector.detect("show finder") == "finder")
    }

    // MARK: - Prefix ordering: "show me" before "show"

    @Test
    func showMe_checkedBeforeShow() {
        #expect(VoiceCommandDetector.detect("show me finder") == "finder")
    }

    // MARK: - Misrecognition handling

    @Test
    func switchTwo_treatedAsSwitchTo() {
        #expect(VoiceCommandDetector.detect("switch two huddle") == "huddle")
    }

    // MARK: - No match cases

    @Test
    func noPrefix_returnsNil() {
        #expect(VoiceCommandDetector.detect("hello world") == nil)
    }

    @Test
    func emptyTargetAfterPrefix_returnsNil() {
        #expect(VoiceCommandDetector.detect("switch to") == nil)
    }

    @Test
    func exceedsWordLimit_returnsNil() {
        #expect(
            VoiceCommandDetector.detect(
                "I was thinking about switching to a new approach for the project"
            ) == nil
        )
    }

    @Test
    func emptyString_returnsNil() {
        #expect(VoiceCommandDetector.detect("") == nil)
    }

    // MARK: - Whitespace handling

    @Test
    func extraWhitespace_isTrimmed() {
        #expect(VoiceCommandDetector.detect("  switch to  huddle  ") == "huddle")
    }

    // MARK: - Trailing punctuation stripping

    @Test
    func stripsTrailingComma() {
        #expect(VoiceCommandDetector.detect("open terminal,") == "terminal")
    }

    @Test
    func stripsTrailingExclamation() {
        #expect(VoiceCommandDetector.detect("open terminal!") == "terminal")
    }

    @Test
    func stripsTrailingQuestionMark() {
        #expect(VoiceCommandDetector.detect("open terminal?") == "terminal")
    }

    // MARK: - Misrecognition: "go too" as "go to"

    @Test
    func goToo_treatedAsGoTo() {
        #expect(VoiceCommandDetector.detect("go too slack") == "slack")
    }
}
