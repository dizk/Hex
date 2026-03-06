//
//  VoiceCommandIntegrationTests.swift
//  HexTests
//
//  Integration tests verifying that voice commands are detected and executed
//  within the TranscriptionFeature reducer flow.
//

import ComposableArchitecture
import Foundation
import HexCore
import Testing
@testable import Hex

// MARK: - Voice Command Integration Tests

@MainActor
struct VoiceCommandIntegrationTests {

    // MARK: - Helpers

    /// A test audio URL for transcription results.
    private static let testAudioURL = URL(fileURLWithPath: "/tmp/test-audio.wav")

    /// Standard test windows representing a realistic desktop.
    private static let testWindows: [WindowInfo] = [
        WindowInfo(appName: "Safari", windowTitle: "Apple - Start", processIdentifier: 100, windowReference: nil),
        WindowInfo(appName: "Slack", windowTitle: "Slack | Huddle with Kit", processIdentifier: 200, windowReference: nil),
        WindowInfo(appName: "Google Chrome", windowTitle: "GitHub - Pull Requests", processIdentifier: 300, windowReference: nil),
        WindowInfo(appName: "Terminal", windowTitle: "bash — 80x24", processIdentifier: 400, windowReference: nil),
        WindowInfo(appName: "Notes", windowTitle: "Shopping List", processIdentifier: 500, windowReference: nil),
    ]

    /// Creates a TestStore for TranscriptionFeature with voice command relevant
    /// state pre-set (transcribing, with cached windows).
    private static func makeTestStore(
        cachedWindows: [WindowInfo] = [],
        isTranscribing: Bool = true,
        isRecording: Bool = false,
        focusResult: Bool = true,
        focusedWindow: (@Sendable (WindowInfo) -> Void)? = nil,
        pastedText: (@Sendable (String) -> Void)? = nil,
        windowsForListing: [WindowInfo] = []
    ) -> TestStore<TranscriptionFeature.State, TranscriptionFeature.Action> {
        var initialState = TranscriptionFeature.State()
        initialState.isTranscribing = isTranscribing
        initialState.isRecording = isRecording
        initialState.cachedWindows = cachedWindows

        let store = TestStore(
            initialState: initialState
        ) {
            TranscriptionFeature()
        } withDependencies: {
            $0.recording = .testValue
            $0.transcription = .testValue
            $0.keyEventMonitor = .testValue
            $0.date = .constant(Date(timeIntervalSince1970: 1000))

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

            $0.transcriptPersistence = .testValue

            $0.windowClient = WindowClient(
                listWindows: { windowsForListing },
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

    // MARK: - Test: Voice command "switch to huddle" matches Slack window

    @Test
    func voiceCommand_switchToHuddle_focusesSlackWindow() async {
        nonisolated(unsafe) var capturedFocusedWindow: WindowInfo?
        nonisolated(unsafe) var capturedPastedText: String?

        let store = Self.makeTestStore(
            cachedWindows: Self.testWindows,
            focusResult: true,
            focusedWindow: { window in capturedFocusedWindow = window },
            pastedText: { text in capturedPastedText = text }
        )

        await store.send(.transcriptionResult("switch to huddle", Self.testAudioURL))
        await awaitEffects()

        // The Slack window with "Huddle with Kit" should have been focused.
        #expect(capturedFocusedWindow == Self.testWindows[1])
        // Text should NOT have been pasted.
        #expect(capturedPastedText == nil)
    }

    // MARK: - Test: Voice command "switch to nonexistent" - no match, no paste

    @Test
    func voiceCommand_noMatchingWindow_doesNotPasteCommandText() async {
        nonisolated(unsafe) var capturedPastedText: String?

        let store = Self.makeTestStore(
            cachedWindows: Self.testWindows,
            pastedText: { text in capturedPastedText = text }
        )

        await store.send(.transcriptionResult("switch to nonexistent", Self.testAudioURL))
        await awaitEffects()

        // Command prefix was detected but no window matched.
        // Text should NOT be pasted.
        #expect(capturedPastedText == nil)
    }

    // MARK: - Test: Normal sentence - no command detected, text is pasted

    @Test
    func normalTranscription_isHandledNormally() async {
        nonisolated(unsafe) var capturedPastedText: String?

        let store = Self.makeTestStore(
            cachedWindows: Self.testWindows,
            pastedText: { text in capturedPastedText = text }
        )

        await store.send(.transcriptionResult("hello this is a normal sentence", Self.testAudioURL))
        await awaitEffects()

        // No voice command prefix detected, so text should be pasted normally.
        #expect(capturedPastedText == "hello this is a normal sentence")
    }

    // MARK: - Test: Recording starts -> listWindows called and stored

    @Test
    func startRecording_cachesWindows() async {
        nonisolated(unsafe) var listWindowsCalled = false

        var initialState = TranscriptionFeature.State()
        initialState.cachedWindows = []

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
            $0.transcriptPersistence = .testValue
            $0.windowClient = WindowClient(
                listWindows: {
                    listWindowsCalled = true
                    return Self.testWindows
                },
                focusWindow: { _ in false }
            )
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.startRecording)
        await awaitEffects()

        #expect(listWindowsCalled == true)
        #expect(store.state.cachedWindows == Self.testWindows)
    }

    // MARK: - Test: Cancel clears cachedWindows

    @Test
    func cancel_clearsCachedWindows() async {
        let store = Self.makeTestStore(
            cachedWindows: Self.testWindows,
            isTranscribing: false,
            isRecording: true
        )

        await store.send(.cancel)

        // cachedWindows is cleared synchronously in the reducer.
        #expect(store.state.cachedWindows.isEmpty)
    }

    // MARK: - Test: Focus fails - still does not paste command text

    @Test
    func voiceCommand_focusFails_doesNotPasteCommandText() async {
        nonisolated(unsafe) var capturedFocusedWindow: WindowInfo?
        nonisolated(unsafe) var capturedPastedText: String?

        let store = Self.makeTestStore(
            cachedWindows: Self.testWindows,
            focusResult: false,
            focusedWindow: { window in capturedFocusedWindow = window },
            pastedText: { text in capturedPastedText = text }
        )

        await store.send(.transcriptionResult("switch to huddle", Self.testAudioURL))
        await awaitEffects()

        // Focus was attempted (command was recognized).
        #expect(capturedFocusedWindow != nil)
        // Even though focus failed, text should NOT be pasted.
        #expect(capturedPastedText == nil)
    }

    // MARK: - Test: "open chrome" matches Google Chrome window

    @Test
    func voiceCommand_openChrome_focusesChromeWindow() async {
        nonisolated(unsafe) var capturedFocusedWindow: WindowInfo?
        nonisolated(unsafe) var capturedPastedText: String?

        let store = Self.makeTestStore(
            cachedWindows: Self.testWindows,
            focusResult: true,
            focusedWindow: { window in capturedFocusedWindow = window },
            pastedText: { text in capturedPastedText = text }
        )

        await store.send(.transcriptionResult("open chrome", Self.testAudioURL))
        await awaitEffects()

        // Chrome window should have been focused (app name match).
        #expect(capturedFocusedWindow == Self.testWindows[2])
        // Text should NOT have been pasted.
        #expect(capturedPastedText == nil)
    }

    // MARK: - Test: Discard clears cachedWindows

    @Test
    func discard_clearsCachedWindows() async {
        let store = Self.makeTestStore(
            cachedWindows: Self.testWindows,
            isTranscribing: false,
            isRecording: true
        )

        await store.send(.discard)

        // cachedWindows is cleared synchronously in the reducer.
        #expect(store.state.cachedWindows.isEmpty)
    }
}
