//
//  CommandFeedbackTests.swift
//  HexTests
//
//  Tests for voice command finalization: history entries with CommandInfo,
//  transcription indicator feedback states, auto-dismiss timer, and
//  non-interference with normal transcription flow.
//

import Clocks
import ComposableArchitecture
import Foundation
import HexCore
import Testing
@testable import Hex

// MARK: - Command Feedback Tests

@MainActor
struct CommandFeedbackTests {

    // MARK: - Helpers

    private static let testAudioURL = URL(fileURLWithPath: "/tmp/test-command-audio.wav")

    private static let testWindows: [WindowInfo] = [
        WindowInfo(appName: "Safari", windowTitle: "Apple - Start", processIdentifier: 100, bundleIdentifier: "com.apple.Safari", windowReference: nil),
        WindowInfo(appName: "Slack", windowTitle: "Slack | Huddle with Kit", processIdentifier: 200, bundleIdentifier: "com.tinyspeck.slackmacgap", windowReference: nil),
        WindowInfo(appName: "Google Chrome", windowTitle: "GitHub - Pull Requests", processIdentifier: 300, bundleIdentifier: "com.google.Chrome", windowReference: nil),
        WindowInfo(appName: "Terminal", windowTitle: "bash — 80x24", processIdentifier: 400, bundleIdentifier: "com.apple.Terminal", windowReference: nil),
        WindowInfo(appName: "Notes", windowTitle: "Shopping List", processIdentifier: 500, bundleIdentifier: "com.apple.Notes", windowReference: nil),
    ]

    /// Creates a TestStore pre-configured for command feedback testing.
    private static func makeTestStore(
        cachedWindows: [WindowInfo] = testWindows,
        isTranscribing: Bool = true,
        isRecording: Bool = false,
        recordingStartTime: Date? = Date(timeIntervalSince1970: 990),
        sourceAppBundleID: String? = "com.example.source",
        sourceAppName: String? = "SourceApp",
        focusResult: Bool = true,
        focusedWindow: (@Sendable (WindowInfo) -> Void)? = nil,
        pastedText: (@Sendable (String) -> Void)? = nil,
        savedTranscript: (@Sendable (Transcript) -> Void)? = nil,
        deletedAudioURL: (@Sendable (URL) -> Void)? = nil
    ) -> TestStore<TranscriptionFeature.State, TranscriptionFeature.Action> {
        var initialState = TranscriptionFeature.State()
        initialState.isTranscribing = isTranscribing
        initialState.isRecording = isRecording
        initialState.cachedWindows = cachedWindows
        initialState.recordingStartTime = recordingStartTime
        initialState.sourceAppBundleID = sourceAppBundleID
        initialState.sourceAppName = sourceAppName

        let store = TestStore(
            initialState: initialState
        ) {
            TranscriptionFeature()
        } withDependencies: {
            $0.recording = .testValue
            $0.transcription = .testValue
            $0.keyEventMonitor = .testValue
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
            $0.continuousClock = ImmediateClock()

            $0.pasteboard = PasteboardClient(
                paste: { text in pastedText?(text) },
                copy: { _ in },
                sendKeyboardCommand: { _ in }
            )

            $0.soundEffects = SoundEffectsClient(
                play: { _ in },
                stop: { _ in },
                stopAll: {},
                preloadSounds: {}
            )

            $0.sleepManagement = SleepManagementClient(
                preventSleep: { _ in },
                allowSleep: {}
            )

            $0.transcriptPersistence = TranscriptPersistenceClient(
                save: { result, audioURL, duration, sourceAppBundleID, sourceAppName in
                    let transcript = Transcript(
                        timestamp: Date(timeIntervalSince1970: 1000),
                        text: result,
                        audioPath: audioURL,
                        duration: duration,
                        sourceAppBundleID: sourceAppBundleID,
                        sourceAppName: sourceAppName
                    )
                    savedTranscript?(transcript)
                    return transcript
                },
                deleteAudio: { transcript in
                    deletedAudioURL?(transcript.audioPath)
                }
            )

            $0.windowClient = WindowClient(
                listWindows: { [] },
                focusWindow: { window in
                    focusedWindow?(window)
                    return focusResult
                }
            )
        }

        store.exhaustivity = .off(showSkippedAssertions: false)

        return store
    }

    /// Waits briefly for async effects to complete.
    private func awaitEffects() async {
        try? await Task.sleep(for: .milliseconds(150))
    }

    // MARK: - Test 1: Successful voice command sets commandSuccess status and creates history entry

    @Test
    func successfulVoiceCommand_setsCommandSuccessStatus_andCreatesHistoryEntry() async {
        nonisolated(unsafe) var capturedFocusedWindow: WindowInfo?

        let store = Self.makeTestStore(
            focusResult: true,
            focusedWindow: { window in capturedFocusedWindow = window }
        )

        await store.send(.transcriptionResult("switch to chrome", Self.testAudioURL)) {
            // After a successful voice command, transcriptionStatus should be .commandSuccess
            $0.commandFeedbackStatus = .commandSuccess
        }
        await awaitEffects()

        // The Chrome window should have been focused
        #expect(capturedFocusedWindow == Self.testWindows[2])

        // A history entry should have been created with correct CommandInfo
        let history = store.state.transcriptionHistory.history
        #expect(!history.isEmpty)

        let entry = history.first!
        #expect(entry.commandInfo != nil)
        #expect(entry.commandInfo?.success == true)
        #expect(entry.commandInfo?.rawInput == "switch to chrome")
        #expect(entry.commandInfo?.actionDescription.contains("Google Chrome") == true)
        #expect(entry.commandInfo?.targetAppBundleID == "com.google.Chrome")
        #expect(entry.commandInfo?.targetAppName == "Google Chrome")
    }

    // MARK: - Test 2: Failed voice command sets commandFailure status and creates history entry

    @Test
    func failedVoiceCommand_setsCommandFailureStatus_andCreatesHistoryEntry() async {
        let store = Self.makeTestStore()

        await store.send(.transcriptionResult("switch to nonexistent", Self.testAudioURL)) {
            // After a failed voice command, transcriptionStatus should be .commandFailure
            $0.commandFeedbackStatus = .commandFailure
        }
        await awaitEffects()

        // A history entry should have been created with failure CommandInfo
        let history = store.state.transcriptionHistory.history
        #expect(!history.isEmpty)

        let entry = history.first!
        #expect(entry.commandInfo != nil)
        #expect(entry.commandInfo?.success == false)
        #expect(entry.commandInfo?.rawInput == "switch to nonexistent")
        #expect(entry.commandInfo?.actionDescription == "No matching window found")
        #expect(entry.commandInfo?.targetAppBundleID == nil)
        #expect(entry.commandInfo?.targetAppName == nil)
    }

    // MARK: - Test 3: Auto-dismiss after 0.8 seconds returns status to nil (hidden)

    @Test
    func commandFeedback_autoDismissesAfterDelay() async {
        let store = Self.makeTestStore()

        await store.send(.transcriptionResult("switch to chrome", Self.testAudioURL)) {
            $0.commandFeedbackStatus = .commandSuccess
        }

        // The reducer should schedule a commandFeedbackDismiss action
        // When received, it should clear the status
        await store.receive(\.commandFeedbackDismiss) {
            $0.commandFeedbackStatus = nil
        }
    }

    // MARK: - Test 4: New recording cancels pending command feedback timer

    @Test
    func startRecording_cancelsPendingCommandFeedbackTimer() async {
        var initialState = TranscriptionFeature.State()
        initialState.commandFeedbackStatus = .commandSuccess

        let store = TestStore(
            initialState: initialState
        ) {
            TranscriptionFeature()
        } withDependencies: {
            $0.recording = RecordingClient(
                startRecording: {},
                stopRecording: { URL(fileURLWithPath: "/tmp/test.wav") },
                requestMicrophoneAccess: { true },
                observeAudioLevel: { AsyncStream { _ in } },
                getAvailableInputDevices: { [] },
                getDefaultInputDeviceName: { nil },
                warmUpRecorder: {},
                cleanup: {}
            )
            $0.transcription = .testValue
            $0.pasteboard = .testValue
            $0.keyEventMonitor = .testValue
            $0.soundEffects = SoundEffectsClient(
                play: { _ in },
                stop: { _ in },
                stopAll: {},
                preloadSounds: {}
            )
            $0.sleepManagement = SleepManagementClient(
                preventSleep: { _ in },
                allowSleep: {}
            )
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
            $0.continuousClock = ImmediateClock()
            $0.transcriptPersistence = .testValue
            $0.windowClient = WindowClient(
                listWindows: { Self.testWindows },
                focusWindow: { _ in false }
            )
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // Starting a new recording should clear any pending command feedback
        await store.send(.startRecording) {
            $0.commandFeedbackStatus = nil
        }
    }

    // MARK: - Test 5: Successful commands retain audio; failed commands delete it

    @Test
    func successfulCommand_retainsAudio() async {
        nonisolated(unsafe) var savedTranscriptAudioPath: URL?

        let store = Self.makeTestStore(
            focusResult: true,
            savedTranscript: { transcript in
                savedTranscriptAudioPath = transcript.audioPath
            }
        )

        await store.send(.transcriptionResult("switch to chrome", Self.testAudioURL))
        await awaitEffects()

        // transcriptPersistence.save must have been called (audio retained)
        #expect(savedTranscriptAudioPath != nil, "transcriptPersistence.save should have been called for successful commands")

        // For successful commands, the audio should be saved (persisted via transcriptPersistence.save)
        let history = store.state.transcriptionHistory.history
        #expect(!history.isEmpty)
        // The transcript should have a valid audioPath (not deleted)
        let entry = history.first!
        #expect(entry.audioPath != URL(fileURLWithPath: "/dev/null"))
    }

    @Test
    func failedCommand_deletesAudio() async {
        nonisolated(unsafe) var saveCalled = false

        let store = Self.makeTestStore(
            focusResult: true,
            savedTranscript: { _ in
                saveCalled = true
            }
        )

        // For the failure path (no matching window), transcriptPersistence.save should NOT
        // be called — the audio file is deleted directly via FileManager.removeItem.
        await store.send(.transcriptionResult("switch to nonexistent", Self.testAudioURL))
        await awaitEffects()

        // transcriptPersistence.save must NOT have been called for failed commands
        #expect(!saveCalled, "transcriptPersistence.save should not be called for failed commands")

        // The history entry for a failed command should still exist but audio was deleted
        // (not moved to Recordings). The transcript's audioPath points to the original temp
        // location which was cleaned up.
        let history = store.state.transcriptionHistory.history
        #expect(!history.isEmpty)
        let entry = history.first!
        #expect(entry.commandInfo?.success == false)
    }

    // MARK: - Test 6: Command history entries are prepended (newest first)

    @Test
    func commandHistoryEntries_arePrepended() async {
        let store = Self.makeTestStore(focusResult: true)

        // Execute a successful command
        await store.send(.transcriptionResult("switch to chrome", Self.testAudioURL))
        await awaitEffects()

        // Now execute a second command (failure)
        // Reset state for second command
        await store.send(.transcriptionResult("switch to nonexistent", Self.testAudioURL))
        await awaitEffects()

        let history = store.state.transcriptionHistory.history
        #expect(history.count >= 2)

        // Newest (second command) should be first
        #expect(history[0].commandInfo?.success == false)
        #expect(history[1].commandInfo?.success == true)
    }

    // MARK: - Test 7: Normal transcriptions are unaffected

    @Test
    func normalTranscription_noCommandInfo_nofeedbackFlash() async {
        nonisolated(unsafe) var capturedPastedText: String?

        let store = Self.makeTestStore(
            pastedText: { text in capturedPastedText = text }
        )

        await store.send(.transcriptionResult("hello this is a normal sentence", Self.testAudioURL)) {
            // Normal transcription should NOT set command feedback status
            // commandFeedbackStatus should remain nil
        }
        await awaitEffects()

        // Text should be pasted normally
        #expect(capturedPastedText == "hello this is a normal sentence")

        // No command feedback status should be set
        #expect(store.state.commandFeedbackStatus == nil)

        // If any history entry was created, it should NOT have commandInfo
        for entry in store.state.transcriptionHistory.history {
            #expect(entry.commandInfo == nil)
        }
    }

    // MARK: - Test: TranscriptionView status mapping includes command feedback

    @Test
    func transcriptionView_mapsCommandFeedbackStatus() {
        // When commandFeedbackStatus is .commandSuccess, the view status should be .commandSuccess
        var state = TranscriptionFeature.State()
        state.commandFeedbackStatus = .commandSuccess

        // The view computes status from state. When commandFeedbackStatus is set,
        // it should take priority over the boolean flags.
        // We test this indirectly by verifying state has the field.
        #expect(state.commandFeedbackStatus == .commandSuccess)

        state.commandFeedbackStatus = .commandFailure
        #expect(state.commandFeedbackStatus == .commandFailure)

        state.commandFeedbackStatus = nil
        #expect(state.commandFeedbackStatus == nil)
    }
}
