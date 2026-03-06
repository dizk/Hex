# Research: Voice Command Feedback

**Date:** 2026-03-06
**Based on:** BRAINSTORM.md
**Status:** Ready for alignment
**Feature:** command-feedback

## Findings

### 1. Voice Command Flow

**Question:** How does the current voice command flow work? Where is the command detected and the window focused, and where does it skip history?

**Finding:** The voice command flow is a self-contained pathway within `TranscriptionFeature` that completely bypasses the transcription history system. The full flow:

1. **Detection** (TranscriptionFeature.swift:429): `VoiceCommandDetector.detect(result)` is called on transcribed text after transcription completes but before any other processing.
2. **Detector** (VoiceCommandDetector.swift:8-101): Checks for trigger prefixes ("switch to", "bring up", "show me", "go to", "focus", "open", "show") in normalized (lowercased, whitespace-collapsed, punctuation-stripped) text. Extracts the target after the prefix.
3. **Window matching** (TranscriptionFeature.swift:437): `WindowMatcher.bestMatch()` scores candidate windows against the extracted target using fuzzy token-based matching (100pt exact token, 90pt substring, 80pt token overlap, 70pt prefix).
4. **Window focusing** (TranscriptionFeature.swift:442): `windowClient.focusWindow(matchedWindow)` uses Accessibility API -- raises the window with `AXUIElementPerformAction(windowRef, kAXRaiseAction)` and brings app to front via `AXUIElementSetAttributeValue`.
5. **Windows cached during recording** (TranscriptionFeature.swift:319-323): At `startRecording`, the feature calls `windowClient.listWindows()` and caches them in `state.cachedWindows`.

**History bypass is by design, not oversight:**
- **Success case** (lines 440-448): If a window matches, the audio file is deleted (line 441), the window is focused (line 442), and the function returns immediately. `finalizeRecordingAndStoreTranscript()` is never called.
- **Failure case** (lines 449-454): If no window matches, audio is deleted (line 452), and the function returns early. Again, no history entry.
- **Normal transcription path** (lines 456-509): Only if no command is detected does the code flow through word removal/remapping (lines 472-485) and `finalizeRecordingAndStoreTranscript()` (lines 497-504), which stores to history with `history.history.insert(transcript, at: 0)` (line 550).

Only window-focusing commands are currently implemented. `KeyboardCommand.swift` exists for a future auto-send feature but is not connected to voice command execution.

All decisions are logged to `voiceCommandLogger` (alias for `HexLog.voiceCommands`).

**Sources:**
- `Hex/Features/Transcription/TranscriptionFeature.swift` (lines 403-568, specifically 428-455 for command detection, 440-453 for execution and history bypass)
- `HexCore/Sources/HexCore/VoiceCommands/VoiceCommandDetector.swift` (lines 8-101)
- `HexCore/Sources/HexCore/VoiceCommands/WindowMatcher.swift` (lines 17-122)
- `Hex/Clients/WindowClient.swift` (lines 103-131)
- `HexCore/Sources/HexCore/Models/TranscriptionHistory.swift` (lines 1-37)
- `HexTests/VoiceCommandIntegrationTests.swift` (confirms: success = no paste, failure = no paste, normal transcription = paste + history)

**Recommendation:** Modify `handleTranscriptionResult()` so that both the success and failure command paths create history entries before returning. Introduce a new code path (e.g., `finalizeCommandExecution()`) that saves command entries with result metadata, rather than silently deleting audio and returning.

**Risk:** The early return for commands means `state.cachedWindows` is cleared (line 435) but the normal transcription flow's word removals/remappings (lines 472-485) are never applied to command text. This inconsistency is harmless now but could cause issues if command text ever needs transformation. Additionally, audio is deleted before window focusing is attempted -- if focusing fails, the audio is already gone with no record.

### 2. History Entry Structure

**Question:** How are history entries currently structured (HistoryFeature / TCA state)? What fields exist, and what needs to be added to support command entries?

**Finding:**

**Transcript model** (TranscriptionHistory.swift:3-29) -- current fields:
- `id: UUID`
- `timestamp: Date`
- `text: String` (the transcribed text)
- `audioPath: URL`
- `duration: TimeInterval`
- `sourceAppBundleID: String?` (bundle ID of active app when recording started)
- `sourceAppName: String?` (friendly name of active app)

The model is `Codable`, `Equatable`, `Identifiable`, and `Sendable`.

**Storage container:** `TranscriptionHistory` struct (line 31-37) containing `var history: [Transcript] = []`.

**Persistence:** File-based storage using TCA's shared reader keys (`FileStorageKey<TranscriptionHistory>`) in HistoryFeature.swift:37-46. Default path is `transcription_history.json` with automatic migration from legacy location (lines 50-60).

**Creation:** `TranscriptPersistenceClient.save()` (TranscriptPersistenceClient.swift:19-46) moves audio files to `~/Library/Application Support/com.kitlangton.Hex/Recordings/`, creates a `Transcript` object, and returns it. Audio files are named by Unix timestamp.

**Insertion:** Entries are prepended to the history array (newest first) at TranscriptionFeature.swift:550. Old entries are pruned when `maxHistoryEntries` is exceeded (lines 552-560).

**HistoryFeature TCA state** (HistoryFeature.swift:92-105):
- `@Shared(.transcriptionHistory) var transcriptionHistory: TranscriptionHistory`
- `playingTranscriptID: UUID?`
- `audioPlayer: AVAudioPlayer?`
- `audioPlayerController: AudioPlayerController?`

**HistoryFeature actions** (HistoryFeature.swift:107-116):
- `.playTranscript(UUID)`, `.stopPlayback`, `.copyToClipboard(String)`, `.deleteTranscript(UUID)`, `.deleteAllTranscripts`, `.confirmDeleteAll`, `.playbackFinished`, `.navigateToSettings`

**Sources:**
- `HexCore/Sources/HexCore/Models/TranscriptionHistory.swift` (lines 1-37)
- `Hex/Features/History/HistoryFeature.swift` (lines 37-116, 217-396)
- `HexCore/Sources/HexCore/TranscriptPersistenceClient/TranscriptPersistenceClient.swift` (lines 19-46)
- `Hex/Features/Transcription/TranscriptionFeature.swift` (lines 529-568)

**Recommendation:** Extend the `Transcript` model with optional command metadata fields rather than creating a separate type. Suggested additions:
- `commandInfo: CommandInfo?` where `CommandInfo` is a struct containing `rawInput: String`, `actionDescription: String`, `success: Bool`
- This keeps backward compatibility (existing entries decode with `commandInfo: nil`) and avoids complicating the persistence layer with a union type.

**Risk:** Adding optional fields to `Transcript` is safe for backward compatibility (Swift Codable defaults to `nil` for missing optional fields). However, any code that iterates history and assumes all entries are regular transcriptions (e.g., copy-to-clipboard actions) needs to be reviewed. Storing audio for every command attempt (including failures) could increase disk usage -- consider whether failed command audio should be retained.

### 3. Transcription Indicator Overlay

**Question:** How does the transcription indicator overlay (InvisibleWindow) currently display state? What animation/color mechanisms exist that could support green/red flashing?

**Finding:**

**InvisibleWindow** (InvisibleWindow.swift:17-103): An NSPanel subclass that renders SwiftUI views across the entire screen. Positioned at `.statusBar` level, configured with `nonactivatingPanel` to float above all applications. The transcription indicator is rendered via `InvisibleWindow.fromView()` (HexAppDelegate.swift:83).

**TranscriptionIndicatorView Status enum** (TranscriptionIndicatorView.swift:14-20) -- current 5 states:
- `.hidden` -- indicator not visible
- `.optionKeyPressed` -- user pressing modifier key (shows black dot)
- `.recording` -- actively recording audio
- `.transcribing` -- processing audio through model
- `.prewarming` -- model warming up

**Color system** (lines 25-54): Each status has `backgroundColor`, `strokeColor`, and `innerShadowColor` computed properties using SwiftUI's `.mix()` method. Recording state uses red tones; transcribing uses blue/purple tones.

**Animation infrastructure:**
1. **Pow library** (v1.0.5, imported at line 8): `.changeEffect(.glow())` for color-changing glow effects (line 120), `.changeEffect(.shine())` for periodic shine animations (line 121)
2. **Meter-driven animations** (lines 30, 79, 95): Recording state has real-time visualization using `meter.averagePower` and `meter.peakPower` to create dynamic red glows and overlays
3. **Core SwiftUI animations**: `.animation(.interactiveSpring(), value: meter)` for meter-driven updates (line 111), `.animation(.bouncy(duration: 0.3), value: status)` for status transitions (line 119)
4. **Shadow and opacity effects** (lines 103-118): Multiple shadow layers and opacity/scale effects support color transitions
5. **Task-based animation loop** (lines 123-128): Continuous loop drives effects during transcribing state

**Sound effects** (SoundEffect.swift:18-21): Existing cases for `.pasteTranscript`, `.startRecording`, `.stopRecording`, `.cancel`. No command-specific sounds.

**Feasibility: Very high.** The infrastructure is already in place:
- Add `.commandSuccess` and `.commandFailure` to the Status enum
- Define green color variants for success, red for failure in the existing switch statements
- Use existing `.changeEffect(.glow(color: .green, radius: 8))` for success flash
- Use a task-driven double-flash loop (similar to transcribing effect) for failure
- Auto-dismiss after 0.5-1.0 seconds using `.animation(.bouncy(duration: 0.3), value: status)`

**Sources:**
- `Hex/Views/InvisibleWindow.swift` (lines 17-103)
- `Hex/Features/Transcription/TranscriptionIndicatorView.swift` (lines 1-150)
- `Hex/Features/Transcription/TranscriptionFeature.swift` (lines 614-624)
- `Hex/App/HexAppDelegate.swift` (lines 76-85)
- `Hex/Clients/SoundEffect.swift` (lines 17-30)

**Recommendation:** Add two new Status cases (`.commandSuccess`, `.commandFailure`) to TranscriptionIndicatorView. Use the Pow library's glow effect with green for success and red for failure. For the "double red flash" requirement, use a task-driven animation loop that toggles opacity twice before auto-dismissing. Dispatch these states from `handleTranscriptionResult()` after voice command success/failure is determined. Use a TCA cancellation ID to ensure previous feedback is cleanly cancelled if a new command arrives quickly.

**Risk:** Timing complexity -- the auto-dismiss timer must not interfere with rapid successive commands. If a user triggers another recording while the feedback flash is showing, the indicator must transition cleanly. Consider blocking new recordings during the brief feedback window (0.5-1.0s) or ensuring the status transition from feedback to recording is smooth.

### 4. History UI Entry Styling

**Question:** What is the best way to distinguish command history entries from regular transcriptions in the UI? Does the existing history view support different entry types or styling?

**Finding:**

**Current TranscriptView rendering** (HistoryFeature.swift:217-329) is uniform for all entries:
1. **Main content** (line 226): `Text(transcript.text)` at `.body` font -- no differentiation
2. **Metadata footer** (lines 236-258): App icon + name, clock icon + relative date, exact time, duration
3. **Action buttons** (lines 261-290): Play, Copy, Delete with state-based colors (green when copied, blue when playing)
4. **Background** (lines 297-303): `Color(.windowBackgroundColor).opacity(0.5)` with `Color.secondary.opacity(0.2)` rounded rectangle border

**No conditional rendering** by entry type exists in TranscriptView.

**Existing patterns for conditional styling** elsewhere in the codebase:
- `TranscriptionIndicatorView` Status enum maps each case to different colors, opacities, animations (lines 26-54)
- `CuratedRow.swift` (lines 23-99): Uses conditional background colors based on selection state (`Color.blue.opacity(0.08)` for selected vs `Color(NSColor.controlBackgroundColor)`)
- SF Symbols are used throughout the app (clock, play, clipboard, trash icons in history; various icons in settings)

**Color conventions** in the app:
- Blue for primary selection and playback states
- Green for success states (copied, downloaded)
- Red for recording/error states
- Secondary/tertiary for non-interactive content
- Opacity variations (0.08, 0.2, 0.5) for visual hierarchy

**Sources:**
- `Hex/Features/History/HistoryFeature.swift` (lines 217-329 for TranscriptView, 341-396 for HistoryView)
- `Hex/Features/Transcription/TranscriptionIndicatorView.swift` (lines 14-54 for enum-based conditional styling)
- `Hex/Features/Settings/ModelDownload/CuratedRow.swift` (lines 23-99 for conditional background/icon styling)

**Recommendation:** Add conditional rendering to TranscriptView based on `transcript.commandInfo`:
1. **Badge/icon**: Show a small SF Symbol in the metadata footer -- `terminal.fill` or `command.circle.fill` for commands, distinguishing success (green) from failure (orange/red)
2. **Subtitle line**: Below the main text, show the action taken (e.g., "Switched to Google Chrome") or failure reason ("No matching window found")
3. **Background tint**: Use `Color.green.opacity(0.08)` for successful commands, `Color.orange.opacity(0.08)` for failed ones -- following the existing pattern from CuratedRow
4. **Main text display**: For commands, show the raw input ("switch to chrome") as the main text, with the action description as secondary text below it

**Risk:** TranscriptView currently assumes a simple text-only display. Adding conditional rendering increases complexity. Keep it minimal -- a colored badge icon and a subtitle line are sufficient to distinguish commands without overcomplicating the view. The "Copy" action should copy the action description for commands (not the raw voice input), or offer both.

## Ecosystem Conflicts

No ecosystem conflicts found. The brainstorm's vision aligns with the codebase reality:

- The brainstorm correctly identified that commands skip history (confirmed: early return by design, not oversight)
- The brainstorm's plan to reuse the existing indicator overlay is well-supported (the Pow library and Status enum make adding new visual states straightforward)
- The brainstorm's desire for generic command support beyond window-switching is compatible with the architecture (the `Transcript` model can be extended with optional command metadata)
- The brainstorm's "double red flash" for failure is achievable using the existing task-driven animation loop pattern

The only nuance is that the brainstorm says "reuse existing transcription indicator overlay" -- the indicator is indeed reusable, but it currently hides after transcription completes and before command execution. The implementation must ensure the indicator stays visible long enough to show the success/failure flash.

## Recommendations Summary

1. **Extend `Transcript` model with optional `commandInfo` field** -- a small `CommandInfo` struct containing `rawInput`, `actionDescription`, and `success`. This preserves backward compatibility (existing entries decode with nil) and avoids a union type.

2. **Add `.commandSuccess` and `.commandFailure` to TranscriptionIndicatorView.Status** -- use existing Pow glow effects with green/red colors and a task-driven double-flash loop for failure. Auto-dismiss after 0.5-1.0 seconds.

3. **Create a `finalizeCommandExecution()` path in TranscriptionFeature** -- parallel to `finalizeRecordingAndStoreTranscript()` but for commands. Save the command entry to history with result metadata, then dispatch the visual feedback state to the indicator.

4. **Update TranscriptView with conditional rendering** -- show a colored badge icon and subtitle line for command entries, with a subtle background tint. Follow existing CuratedRow/TranscriptionIndicatorView patterns for conditional styling.

5. **Keep audio for successful commands, consider discarding for failures** -- successful command audio has replay value (user can hear what they said); failed command audio is less useful and adds storage overhead.

6. **Use TCA cancellation IDs for feedback timing** -- ensure rapid successive commands don't leave stale feedback states. Cancel previous feedback effects when a new recording starts.

---
*Research completed: 2026-03-06*
