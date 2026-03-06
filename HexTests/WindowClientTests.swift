//
//  WindowClientTests.swift
//  HexTests
//
//  Tests for the WindowClient TCA dependency.
//

import ApplicationServices
import Dependencies
import Testing
@testable import Hex

// MARK: - WindowInfo Tests

struct WindowInfoTests {

    // MARK: - Initialization

    @Test
    func initializesWithAllFields() {
        let info = WindowInfo(
            appName: "Safari",
            windowTitle: "Apple",
            processIdentifier: 1234,
            windowReference: nil
        )

        #expect(info.appName == "Safari")
        #expect(info.windowTitle == "Apple")
        #expect(info.processIdentifier == 1234)
        #expect(info.windowReference == nil)
    }

    // MARK: - Equatable

    @Test
    func equality_matchesOnAppNameWindowTitleAndPID() {
        let a = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: nil
        )
        let b = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: nil
        )

        #expect(a == b)
    }

    @Test
    func equality_ignoresWindowReference() {
        // Two WindowInfo values with identical scalar fields but different
        // windowReference values should still compare equal, because the
        // custom Equatable implementation intentionally ignores that field.
        let a = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: AXUIElementCreateSystemWide()
        )
        let b = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: nil
        )

        #expect(a == b)
    }

    @Test
    func inequality_differentAppName() {
        let a = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: nil
        )
        let b = WindowInfo(
            appName: "Discord",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: nil
        )

        #expect(a != b)
    }

    @Test
    func inequality_differentWindowTitle() {
        let a = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: nil
        )
        let b = WindowInfo(
            appName: "Slack",
            windowTitle: "Random",
            processIdentifier: 42,
            windowReference: nil
        )

        #expect(a != b)
    }

    @Test
    func inequality_differentProcessIdentifier() {
        let a = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: nil
        )
        let b = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 99,
            windowReference: nil
        )

        #expect(a != b)
    }

    // MARK: - Identifiable

    @Test
    func identifiable_sameFieldsProduceSameID() {
        let a = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: nil
        )
        let b = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: nil
        )

        #expect(a.id == b.id)
    }

    @Test
    func identifiable_differentPIDProducesDifferentID() {
        let a = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: nil
        )
        let b = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 99,
            windowReference: nil
        )

        #expect(a.id != b.id)
    }

    @Test
    func identifiable_differentTitleProducesDifferentID() {
        let a = WindowInfo(
            appName: "Slack",
            windowTitle: "General",
            processIdentifier: 42,
            windowReference: nil
        )
        let b = WindowInfo(
            appName: "Slack",
            windowTitle: "Random",
            processIdentifier: 42,
            windowReference: nil
        )

        #expect(a.id != b.id)
    }
}

// MARK: - WindowClient Mock Override Tests

struct WindowClientTests {

    @Test
    func mockListWindows_returnsExpectedArray() async {
        let expectedWindows = [
            WindowInfo(appName: "Safari", windowTitle: "Apple", processIdentifier: 100, windowReference: nil),
            WindowInfo(appName: "Slack", windowTitle: "General", processIdentifier: 200, windowReference: nil),
        ]

        let client = WindowClient(
            listWindows: { expectedWindows },
            focusWindow: { _ in false }
        )

        let result = await client.listWindows()
        #expect(result == expectedWindows)
        #expect(result.count == 2)
        #expect(result[0].appName == "Safari")
        #expect(result[1].appName == "Slack")
    }

    @Test
    func mockFocusWindow_receivesCorrectWindowAndReturnsTrue() async {
        let targetWindow = WindowInfo(
            appName: "Terminal",
            windowTitle: "bash",
            processIdentifier: 300,
            windowReference: nil
        )

        nonisolated(unsafe) var receivedWindow: WindowInfo?

        let client = WindowClient(
            listWindows: { [] },
            focusWindow: { window in
                receivedWindow = window
                return true
            }
        )

        let result = await client.focusWindow(targetWindow)
        #expect(result == true)
        #expect(receivedWindow == targetWindow)
    }

    @Test
    func mockFocusWindow_returnsFalseWhenConfigured() async {
        let targetWindow = WindowInfo(
            appName: "Terminal",
            windowTitle: "bash",
            processIdentifier: 300,
            windowReference: nil
        )

        let client = WindowClient(
            listWindows: { [] },
            focusWindow: { _ in false }
        )

        let result = await client.focusWindow(targetWindow)
        #expect(result == false)
    }

    @Test
    func mockListWindows_returnsEmptyArray() async {
        let client = WindowClient(
            listWindows: { [] },
            focusWindow: { _ in false }
        )

        let result = await client.listWindows()
        #expect(result.isEmpty)
    }

    @Test
    func testValue_returnsDefaults() async {
        // The @DependencyClient macro generates a testValue that returns
        // the default closures (empty array for listWindows, false for
        // focusWindow) rather than failing with unimplemented, matching
        // the pattern used by other clients like RecordingClient.
        await withDependencies {
            $0.windowClient = .testValue
        } operation: {
            @Dependency(\.windowClient) var client

            let windows = await client.listWindows()
            #expect(windows.isEmpty)

            let dummyWindow = WindowInfo(
                appName: "Test",
                windowTitle: "Window",
                processIdentifier: 1,
                windowReference: nil
            )
            let focused = await client.focusWindow(dummyWindow)
            #expect(focused == false)
        }
    }
}
