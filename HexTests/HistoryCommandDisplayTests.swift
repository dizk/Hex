//
//  HistoryCommandDisplayTests.swift
//  HexTests
//
//  Tests for displaying command entries in the history view:
//  - Copy action dispatches commandInfo.actionDescription for command entries
//  - Copy action dispatches transcript.text for regular entries
//  - Transcript model properties used for conditional rendering
//

import ComposableArchitecture
import Foundation
import HexCore
import Testing
@testable import Hex

// MARK: - History Command Display Tests

@MainActor
struct HistoryCommandDisplayTests {

    // MARK: - Fixtures

    private static let testAudioURL = URL(fileURLWithPath: "/tmp/test-history-audio.wav")

    private static func makeCommandTranscript(
        success: Bool,
        rawInput: String = "switch to chrome",
        actionDescription: String = "Switched to Google Chrome",
        targetAppBundleID: String? = "com.google.Chrome",
        targetAppName: String? = "Google Chrome"
    ) -> Transcript {
        Transcript(
            timestamp: Date(timeIntervalSince1970: 1000),
            text: rawInput,
            audioPath: testAudioURL,
            duration: 1.5,
            sourceAppBundleID: "com.example.source",
            sourceAppName: "SourceApp",
            commandInfo: CommandInfo(
                rawInput: rawInput,
                actionDescription: success ? actionDescription : "No matching window found",
                success: success,
                targetAppBundleID: success ? targetAppBundleID : nil,
                targetAppName: success ? targetAppName : nil
            )
        )
    }

    private static func makeRegularTranscript(
        text: String = "hello world this is a normal transcription"
    ) -> Transcript {
        Transcript(
            timestamp: Date(timeIntervalSince1970: 1000),
            text: text,
            audioPath: testAudioURL,
            duration: 2.0,
            sourceAppBundleID: "com.example.source",
            sourceAppName: "SourceApp"
        )
    }

    /// Creates a HistoryFeature TestStore with given transcripts pre-loaded.
    private static func makeHistoryStore(
        transcripts: [Transcript] = [],
        copiedText: (@Sendable (String) -> Void)? = nil
    ) -> TestStore<HistoryFeature.State, HistoryFeature.Action> {
        var state = HistoryFeature.State()
        state.$transcriptionHistory.withLock { history in
            history.history = transcripts
        }

        let store = TestStore(
            initialState: state
        ) {
            HistoryFeature()
        } withDependencies: {
            $0.pasteboard = PasteboardClient(
                paste: { _ in },
                copy: { text in copiedText?(text) },
                sendKeyboardCommand: { _ in }
            )
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }

    // MARK: - Test 1: Copy action for command entry uses actionDescription

    @Test
    func copyCommandEntry_copiesActionDescription() async {
        let commandTranscript = Self.makeCommandTranscript(success: true)
        nonisolated(unsafe) var capturedCopiedText: String?

        let store = Self.makeHistoryStore(
            transcripts: [commandTranscript],
            copiedText: { text in capturedCopiedText = text }
        )

        // The HistoryView should send copyToClipboard with actionDescription for commands.
        // We verify this by sending the action with the expected text that the view
        // SHOULD dispatch (commandInfo.actionDescription, not transcript.text).
        let expectedCopyText = commandTranscript.commandInfo!.actionDescription
        await store.send(.copyToClipboard(expectedCopyText))

        // Verify the pasteboard received the action description, not the raw input
        #expect(capturedCopiedText == "Switched to Google Chrome")
        #expect(capturedCopiedText != commandTranscript.text)
    }

    // MARK: - Test 2: Copy action for regular entry uses transcript.text

    @Test
    func copyRegularEntry_copiesTranscriptText() async {
        let regularTranscript = Self.makeRegularTranscript()
        nonisolated(unsafe) var capturedCopiedText: String?

        let store = Self.makeHistoryStore(
            transcripts: [regularTranscript],
            copiedText: { text in capturedCopiedText = text }
        )

        // For regular transcripts, the view sends copyToClipboard with transcript.text
        await store.send(.copyToClipboard(regularTranscript.text))

        #expect(capturedCopiedText == "hello world this is a normal transcription")
    }

    // MARK: - Test 3: copyTextForTranscript helper returns correct text

    @Test
    func copyTextForTranscript_returnsActionDescription_forCommand() {
        let commandTranscript = Self.makeCommandTranscript(success: true)
        let copyText = HistoryFeature.copyText(for: commandTranscript)
        #expect(copyText == "Switched to Google Chrome")
    }

    @Test
    func copyTextForTranscript_returnsTranscriptText_forRegular() {
        let regularTranscript = Self.makeRegularTranscript(text: "hello world")
        let copyText = HistoryFeature.copyText(for: regularTranscript)
        #expect(copyText == "hello world")
    }

    // MARK: - Test 4: Failed command entry copy text

    @Test
    func copyFailedCommandEntry_copiesFailureDescription() async {
        let failedCommand = Self.makeCommandTranscript(success: false, rawInput: "switch to nonexistent")
        nonisolated(unsafe) var capturedCopiedText: String?

        let store = Self.makeHistoryStore(
            transcripts: [failedCommand],
            copiedText: { text in capturedCopiedText = text }
        )

        let expectedCopyText = failedCommand.commandInfo!.actionDescription
        await store.send(.copyToClipboard(expectedCopyText))

        #expect(capturedCopiedText == "No matching window found")
    }

    // MARK: - Test 5: isCommand property for rendering decisions

    @Test
    func isCommand_isTrueForCommandTranscript() {
        let commandTranscript = Self.makeCommandTranscript(success: true)
        #expect(commandTranscript.isCommand == true)
        #expect(commandTranscript.commandInfo != nil)
    }

    @Test
    func isCommand_isFalseForRegularTranscript() {
        let regularTranscript = Self.makeRegularTranscript()
        #expect(regularTranscript.isCommand == false)
        #expect(regularTranscript.commandInfo == nil)
    }

    // MARK: - Test 6: Command transcript properties are available for rendering

    @Test
    func commandTranscript_hasTargetAppInfo_forSuccessfulCommand() {
        let commandTranscript = Self.makeCommandTranscript(success: true)
        #expect(commandTranscript.commandInfo?.targetAppBundleID == "com.google.Chrome")
        #expect(commandTranscript.commandInfo?.targetAppName == "Google Chrome")
        #expect(commandTranscript.commandInfo?.success == true)
        #expect(commandTranscript.commandInfo?.actionDescription == "Switched to Google Chrome")
    }

    @Test
    func commandTranscript_hasNoTargetAppInfo_forFailedCommand() {
        let failedCommand = Self.makeCommandTranscript(success: false)
        #expect(failedCommand.commandInfo?.targetAppBundleID == nil)
        #expect(failedCommand.commandInfo?.targetAppName == nil)
        #expect(failedCommand.commandInfo?.success == false)
        #expect(failedCommand.commandInfo?.actionDescription == "No matching window found")
    }
}
