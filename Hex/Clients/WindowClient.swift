//
//  WindowClient.swift
//  Hex
//
//  TCA dependency for enumerating and focusing application windows
//  via the macOS Accessibility API.
//

import AppKit
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation
import HexCore

private let windowLogger = HexLog.voiceCommands

// MARK: - WindowInfo

/// Describes a single visible window from a running application.
struct WindowInfo: Identifiable, @unchecked Sendable {
    let appName: String
    let windowTitle: String
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let windowReference: AXUIElement?

    init(
        appName: String,
        windowTitle: String,
        processIdentifier: pid_t,
        bundleIdentifier: String? = nil,
        windowReference: AXUIElement?
    ) {
        self.appName = appName
        self.windowTitle = windowTitle
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.windowReference = windowReference
    }

    var id: String {
        "\(processIdentifier):\(windowTitle)"
    }
}

extension WindowInfo: Equatable {
    /// Custom Equatable that ignores `windowReference` since AXUIElement
    /// does not conform to Equatable.
    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.appName == rhs.appName
            && lhs.windowTitle == rhs.windowTitle
            && lhs.processIdentifier == rhs.processIdentifier
            && lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

// MARK: - WindowClient

@DependencyClient
struct WindowClient {
    var listWindows: @Sendable () async -> [WindowInfo] = { [] }
    var focusWindow: @Sendable (_ window: WindowInfo) async -> Bool = { _ in false }
}

// MARK: - DependencyKey

extension WindowClient: DependencyKey {
    static var liveValue: Self {
        Self(
            listWindows: {
                await WindowClientLive.listWindows()
            },
            focusWindow: { window in
                await WindowClientLive.focusWindow(window)
            }
        )
    }

    static var previewValue: Self {
        Self(
            listWindows: {
                [
                    WindowInfo(appName: "Safari", windowTitle: "Apple", processIdentifier: 100, bundleIdentifier: "com.apple.Safari", windowReference: nil),
                    WindowInfo(appName: "Slack", windowTitle: "General", processIdentifier: 200, bundleIdentifier: "com.tinyspeck.slackmacgap", windowReference: nil),
                    WindowInfo(appName: "Terminal", windowTitle: "bash", processIdentifier: 300, bundleIdentifier: "com.apple.Terminal", windowReference: nil),
                    WindowInfo(appName: "Xcode", windowTitle: "Hex.xcodeproj", processIdentifier: 400, bundleIdentifier: "com.apple.dt.Xcode", windowReference: nil),
                    WindowInfo(appName: "Notes", windowTitle: "Shopping List", processIdentifier: 500, bundleIdentifier: "com.apple.Notes", windowReference: nil),
                ]
            },
            focusWindow: { _ in true }
        )
    }
}

// MARK: - DependencyValues

extension DependencyValues {
    var windowClient: WindowClient {
        get { self[WindowClient.self] }
        set { self[WindowClient.self] = newValue }
    }
}

// MARK: - Live Implementation

private enum WindowClientLive {

    static func listWindows() async -> [WindowInfo] {
        // Run enumeration off the main thread
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let windows = enumerateWindows()
                continuation.resume(returning: windows)
            }
        }
    }

    static func focusWindow(_ window: WindowInfo) async -> Bool {
        guard let windowRef = window.windowReference else {
            windowLogger.error("focusWindow: windowReference is nil for \(window.appName, privacy: .public) – \(window.windowTitle, privacy: .private)")
            return false
        }

        // Step 1: Raise the specific window within the app's z-order
        let raiseResult = AXUIElementPerformAction(windowRef, kAXRaiseAction as CFString)
        guard raiseResult == .success else {
            windowLogger.error("focusWindow: AXRaiseAction failed (\(raiseResult.rawValue)) for \(window.appName, privacy: .public)")
            return false
        }

        // Step 2: Bring the application to front via AX API
        // NSRunningApplication.activate() fails in sandbox, so use AXUIElement instead
        let appElement = AXUIElementCreateApplication(window.processIdentifier)
        let frontmostResult = AXUIElementSetAttributeValue(
            appElement,
            kAXFrontmostAttribute as CFString,
            kCFBooleanTrue
        )

        if frontmostResult != .success {
            windowLogger.error("focusWindow: set frontmost failed (\(frontmostResult.rawValue)) for \(window.appName, privacy: .public)")
            return false
        }

        return true
    }

    // MARK: - Private Helpers

    private static func enumerateWindows() -> [WindowInfo] {
        var result: [WindowInfo] = []

        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        for app in runningApps {
            guard let appName = app.localizedName else { continue }
            let pid = app.processIdentifier

            let appElement = AXUIElementCreateApplication(pid)

            // Read the kAXWindowsAttribute to get the window array
            var windowsRef: CFTypeRef?
            let windowsResult = AXUIElementCopyAttributeValue(
                appElement,
                kAXWindowsAttribute as CFString,
                &windowsRef
            )

            guard windowsResult == .success,
                  let windowArray = windowsRef as? [AXUIElement]
            else {
                continue
            }

            for windowElement in windowArray {
                // Read kAXTitleAttribute for each window
                var titleRef: CFTypeRef?
                let titleResult = AXUIElementCopyAttributeValue(
                    windowElement,
                    kAXTitleAttribute as CFString,
                    &titleRef
                )

                guard titleResult == .success,
                      let title = titleRef as? String,
                      !title.isEmpty
                else {
                    // Skip windows without a readable title
                    continue
                }

                let info = WindowInfo(
                    appName: appName,
                    windowTitle: title,
                    processIdentifier: pid,
                    bundleIdentifier: app.bundleIdentifier,
                    windowReference: windowElement
                )
                result.append(info)
            }
        }

        return result
    }
}
