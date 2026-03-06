# Implementation Plan: Voice Command Feedback

**Date:** 2026-03-06
**Based on:** BRAINSTORM.md, RESEARCH.md
**Status:** Approved
**Feature:** command-feedback

## Summary

Add visual feedback (green/red flash on the transcription indicator) and history tracking for voice commands. When a voice command executes, the indicator reappears briefly with a green glow for success or a double red flash for failure, and every command is recorded in transcription history with the raw input, action taken, success/failure status, and the target app icon.

## Wave 1: Data Model and Indicator States
Independent tasks that can run in parallel.

### Task 1.1: Add CommandInfo to Transcript model

- **What:** Add a `CommandInfo` struct and an optional `commandInfo` field to the existing `Transcript` model in `HexCore/Sources/HexCore/Models/TranscriptionHistory.swift`. The `CommandInfo` struct must conform to `Codable`, `Equatable`, `Sendable` and contain:
  - `rawInput: String` -- the original transcribed text (e.g., "switch to chrome")
  - `actionDescription: String` -- what the app did (e.g., "Switched to Google Chrome") or failure reason (e.g., "No matching window found")
  - `success: Bool` -- whether the command succeeded
  - `targetAppBundleID: String?` -- bundle ID of the target app (for window-switching commands; nil for other command types or failures)
  - `targetAppName: String?` -- display name of the target app

  Add `var commandInfo: CommandInfo?` to `Transcript`. This field must be optional so existing persisted history entries (which lack this field) decode correctly with `nil` -- Swift's `Codable` handles missing optional keys by defaulting to `nil`, so no migration code is needed.

  Also add a convenience computed property `var isCommand: Bool { commandInfo != nil }` on `Transcript` for cleaner call-site checks.

- **Files:** `HexCore/Sources/HexCore/Models/TranscriptionHistory.swift`
- **TDD:** Yes
- **Tests:** Write tests in `HexCore/Tests/HexCoreTests/` (create `CommandInfoTests.swift` if needed):
  1. `CommandInfo` round-trips through JSON encode/decode with all fields populated
  2. `CommandInfo` round-trips with `targetAppBundleID` and `targetAppName` as nil
  3. A `Transcript` with `commandInfo: nil` encodes and decodes correctly (backward compat)
  4. A `Transcript` encoded WITHOUT a `commandInfo` key in JSON decodes with `commandInfo == nil` (simulate existing persisted data by manually constructing JSON without the field)
  5. A `Transcript` with a populated `commandInfo` round-trips correctly
  6. `isCommand` returns `true` when `commandInfo` is set, `false` when nil
- **Acceptance:** All tests pass. Existing `Transcript` usage throughout the app is unaffected (the field is optional and additive).

### Task 1.2: Add command feedback states to TranscriptionIndicatorView

- **What:** Add two new cases to the `TranscriptionIndicatorView.Status` enum: `.commandSuccess` and `.commandFailure`. Implement their visual presentation:

  **Status enum** (in `Hex/Features/Transcription/TranscriptionIndicatorView.swift`):
  - Add `case commandSuccess` and `case commandFailure` to the `Status` enum (currently has: `.hidden`, `.optionKeyPressed`, `.recording`, `.transcribing`, `.prewarming`)

  **Color properties** -- extend the existing `backgroundColor`, `strokeColor`, and `innerShadowColor` computed properties:
  - `.commandSuccess`: green tones -- use `Color.green` variants similar to how `.recording` uses red tones. Background: `Color.green`, stroke: `Color.green.mix(with: .white, by: 0.3)`, inner shadow: `Color.green.mix(with: .black, by: 0.3)`
  - `.commandFailure`: red tones -- reuse the same red palette as `.recording` (background: `Color.red`, stroke: `Color.red.mix(with: .white, by: 0.3)`, inner shadow: `Color.red.mix(with: .black, by: 0.3)`)

  **Visibility** -- in the view body, both new statuses must be visible (not hidden). They should render the indicator dot at full opacity and normal scale, similar to the `.transcribing` state. The indicator should NOT show the audio meter visualization (that's only for `.recording`).

  **Glow effects** -- use the existing Pow library:
  - `.commandSuccess`: apply `.changeEffect(.glow(color: .green, radius: 8))` triggered on status change
  - `.commandFailure`: apply `.changeEffect(.glow(color: .red, radius: 8))` triggered on status change. For the "double flash" effect, use a task-based animation loop (similar to the existing transcribing animation loop at lines 123-128) that toggles the indicator's opacity between 1.0 and 0.0 twice with ~150ms intervals, creating a visible double-blink

  **No meter interaction** -- these states do not use `meter.averagePower` or `meter.peakPower`. The meter-driven glow overlay (lines 79-95) should not render for command states.

- **Files:** `Hex/Features/Transcription/TranscriptionIndicatorView.swift`
- **TDD:** Yes
- **Tests:** Write tests in `HexTests/` (create `TranscriptionIndicatorStatusTests.swift` if needed). Since this is a SwiftUI view, focus on the Status enum's computed properties rather than visual rendering:
  1. `.commandSuccess` returns green-based colors for `backgroundColor`, `strokeColor`, `innerShadowColor`
  2. `.commandFailure` returns red-based colors for `backgroundColor`, `strokeColor`, `innerShadowColor`
  3. Both new statuses are not `.hidden` (verify they would be visible -- check that opacity/scale computed values are non-zero if such properties exist, or verify through the color properties being non-clear)
  4. Existing statuses still return their original colors (regression check for `.recording`, `.transcribing`)
- **Acceptance:** The indicator compiles with the new cases. All switch statements over `Status` handle the new cases. Color properties return the correct values. The app builds without warnings about non-exhaustive switches.

## Wave 2: Command Execution Path
Depends on Wave 1 completion.

### Task 2.1: Create command finalization path in TranscriptionFeature

- **What:** Modify `TranscriptionFeature.swift` to save voice command results to history and dispatch visual feedback, instead of silently deleting audio and returning early.

  **New method `finalizeCommandExecution()`:** Create a new method in `TranscriptionFeature` (parallel to the existing `finalizeRecordingAndStoreTranscript()`) that:
  1. Creates a `CommandInfo` struct populated with the command result data
  2. Creates a `Transcript` with the `commandInfo` field set, using the transcribed text as `text`, the recording duration, and the source app info from `state.sourceApp`
  3. For successful window commands: populates `targetAppBundleID` and `targetAppName` from the matched window's app info (available from `WindowMatcher.Match` which contains the window data)
  4. For `actionDescription`: on success, use "Switched to {appName}" (using the matched window's app name); on failure, use "No matching window found"
  5. Saves the transcript to history using the same `@Shared(.transcriptionHistory)` insertion pattern as `finalizeRecordingAndStoreTranscript()` (prepend to array, prune if over `maxHistoryEntries`)
  6. Handles audio: keep the audio file for successful commands (move it to the Recordings directory like normal transcriptions), delete it for failed commands

  **Modify the command success path** (currently at TranscriptionFeature.swift lines 440-448):
  - Remove the line that deletes the audio file before focusing
  - After `windowClient.focusWindow(matchedWindow)`, call `finalizeCommandExecution()` with success=true and the matched window data
  - Set `state.transcriptionStatus` to `.commandSuccess`
  - Schedule a TCA effect that waits 0.8 seconds then sets `state.transcriptionStatus` to `.hidden`. Use a cancellation ID (e.g., `CancelID.commandFeedback`) so rapid commands cancel previous feedback timers

  **Modify the command failure path** (currently at TranscriptionFeature.swift lines 449-454):
  - Call `finalizeCommandExecution()` with success=false and no matched window
  - Delete the audio file (no value in keeping failed command audio)
  - Set `state.transcriptionStatus` to `.commandFailure`
  - Schedule the same auto-dismiss effect (0.8s → `.hidden`) with the same cancellation ID

  **Add cancellation ID:** Add a new case to the existing `CancelID` enum (or create one if it doesn't exist): `case commandFeedback`. When a new recording starts, cancel any pending `commandFeedback` effect so stale feedback doesn't interfere.

  **TranscriptionStatus mapping:** The `state.transcriptionStatus` field drives the `TranscriptionIndicatorView.Status`. Ensure the new `.commandSuccess` and `.commandFailure` values from Task 1.2 are correctly mapped. Check how `transcriptionStatus` is currently defined -- if it's the same enum as `TranscriptionIndicatorView.Status`, the new cases are already available. If it's a separate type that maps to the view's Status, add the corresponding cases and mapping.

- **Files:** `Hex/Features/Transcription/TranscriptionFeature.swift`
- **TDD:** Yes
- **Tests:** Write tests in `HexTests/` (create `CommandFeedbackTests.swift` or add to existing transcription tests). Use TCA's `TestStore` to test the reducer:
  1. When a voice command succeeds (transcription text matches "switch to chrome" and a window matches), the state's `transcriptionStatus` becomes `.commandSuccess`, a history entry is created with `commandInfo.success == true`, `commandInfo.actionDescription` contains the target app name, and `commandInfo.targetAppBundleID` is populated
  2. When a voice command fails (transcription text is "switch to nonexistent" and no window matches), `transcriptionStatus` becomes `.commandFailure`, a history entry is created with `commandInfo.success == false` and `commandInfo.actionDescription == "No matching window found"`, and `commandInfo.targetAppBundleID` is nil
  3. After 0.8 seconds, `transcriptionStatus` returns to `.hidden` (test the scheduled effect)
  4. A new recording starting cancels any pending command feedback timer
  5. Successful commands retain audio (transcript has a valid `audioPath`); failed commands delete audio
  6. Command history entries are prepended to history (newest first), same as regular transcriptions
  7. Normal (non-command) transcriptions still work exactly as before -- no `commandInfo`, no feedback flash, normal paste behavior
- **Depends on:** Task 1.1, Task 1.2
- **Acceptance:** Voice commands create history entries with correct `CommandInfo` metadata. The transcription indicator shows the correct feedback state. The auto-dismiss timer works. Normal transcription flow is unaffected.

## Wave 3: History UI
Depends on Wave 2 completion.

### Task 3.1: Update history view to display command entries

- **What:** Modify `TranscriptView` in `Hex/Features/History/HistoryFeature.swift` to render command history entries with distinct visual styling, while keeping regular transcription entries unchanged.

  **Conditional rendering based on `transcript.commandInfo`:**

  When `transcript.commandInfo` is non-nil (command entry):

  1. **Main text:** Display `transcript.text` (the raw voice input, e.g., "switch to chrome") as the primary text, same as regular entries

  2. **Action subtitle:** Below the main text, add a `Text(commandInfo.actionDescription)` line in `.subheadline` font with `.secondary` foreground color. This shows "Switched to Google Chrome" for success or "No matching window found" for failure

  3. **Command badge in metadata footer:** In the metadata row (where the source app icon and name currently appear), show a command-specific icon:
     - Success: SF Symbol `checkmark.circle.fill` in green (`Color.green`)
     - Failure: SF Symbol `xmark.circle.fill` in orange (`Color.orange`)
     - Place this before the app info in the metadata row

  4. **Target app icon:** For successful window commands where `commandInfo.targetAppBundleID` is non-nil, show the target app's icon using the same `NSWorkspace.shared.icon(forFile:)` or bundle-ID-based icon loading mechanism that the existing source app icon uses (look at how the current metadata footer loads the app icon from `transcript.sourceAppBundleID` and replicate that pattern with `commandInfo.targetAppBundleID`). Display the target app name from `commandInfo.targetAppName` next to the icon

  5. **Background tint:** Apply a subtle background tint to the entire entry:
     - Success: `Color.green.opacity(0.06)`
     - Failure: `Color.orange.opacity(0.06)`
     - This follows the existing pattern from `CuratedRow.swift` which uses `Color.blue.opacity(0.08)` for selected state

  6. **Copy behavior:** When the user clicks "Copy" on a command entry, copy `commandInfo.actionDescription` (e.g., "Switched to Google Chrome") to the clipboard, not the raw voice input. The `copyToClipboard` action already takes a `String` parameter, so pass `commandInfo.actionDescription` instead of `transcript.text`

  When `transcript.commandInfo` is nil (regular transcription):
  - No changes. Render exactly as today.

- **Files:** `Hex/Features/History/HistoryFeature.swift`
- **TDD:** Yes
- **Tests:** Write tests in `HexTests/` (create `HistoryCommandDisplayTests.swift` or add to existing history tests). Since the view logic is in a SwiftUI view within the reducer file, test what's testable:
  1. The `copyToClipboard` action copies `commandInfo.actionDescription` when the transcript has `commandInfo`, and copies `transcript.text` when it doesn't. Test this through the TCA `TestStore` by sending the action and verifying the pasteboard client receives the correct string
  2. Create `Transcript` fixtures with and without `commandInfo` and verify the `isCommand` property works correctly for conditional rendering decisions
  3. Verify that a command transcript with `targetAppBundleID` set would use that bundle ID for icon loading (test the data flow, not the SwiftUI rendering)
- **Depends on:** Task 2.1
- **Acceptance:** Command entries in history show the action subtitle, command badge, target app icon (for successful window commands), and subtle background tint. Regular transcription entries look exactly the same as before. Copy action copies the appropriate text for each entry type. The app builds and runs without errors.

## Decisions from Alignment

| Decision | Rationale |
|----------|-----------|
| Use optional `commandInfo` field on `Transcript` instead of a type hierarchy/enum | YAGNI -- an optional field preserves backward compatibility with zero migration, avoids touching every call site that uses `Transcript`, and is sufficient for the current need. A type hierarchy would require custom Codable, data migration, and changes throughout TCA state, persistence, and views. |
| Create a parallel `finalizeCommandExecution()` path for commands | Commands need different finalization than regular transcriptions -- they store command metadata, skip paste/word-removal, and dispatch visual feedback states. A separate method keeps the concerns cleanly separated. |
| Flash appears after transcription completes, not during | The indicator hides after transcription, then reappears briefly with the success/failure flash. This is a natural post-action confirmation rather than trying to keep the indicator continuously visible through the command execution. |
| Keep audio for successful commands, delete for failures | Successful command audio has replay value (user can hear what they said). Failed command audio adds storage overhead with little benefit. |
| Show target app icon in command history entries | Reuses the existing app-icon infrastructure from the source app display. For window-switching commands, showing the Chrome/Slack/etc. icon makes the history entry immediately scannable. |
| Copy action copies `actionDescription` for command entries | The action description ("Switched to Google Chrome") is what's useful to copy, not the raw voice input ("switch to chrome"). |
| Auto-dismiss feedback after 0.8 seconds with TCA cancellation ID | Brief enough to not block the user, long enough to register visually. Cancellation ID ensures rapid successive commands don't leave stale feedback states. |
| Double red flash for failure, single green glow for success | Failure needs to be more attention-grabbing than success. A double-blink is unmistakable without requiring the user to read text. |

## Execution

This plan is executed using `/cadence-build`. The build phase reads this file and spawns fresh subagents per task. Key details:
- **TDD is enforced.** Every task marked TDD: Yes follows RED -> GREEN -> REFACTOR. No production code without a failing test first.
- **Fresh subagents.** Each task runs in a fresh 200k context window. Subagents only see this plan and their agent instructions -- they have no memory of the conversation that produced this plan.
- **Wave ordering is strict.** All tasks in a wave must complete and pass code review before the next wave starts.
- **Commit convention:** RED: `test(task-N): ...`, GREEN: `feat(task-N): ...`, REFACTOR: `refactor(task-N): ...`
- **After all waves:** Run the full test suite, then `/cadence-ship` to create a PR.
- This is a macOS app developed in a Linux VM. Code changes must be synced to the Mac host via `bash dev/scripts/sync.sh` before building/testing. The builder cannot run `xcodebuild` or `swift test` directly -- it writes code and tests, then the user builds on the Mac. HexCore unit tests (Task 1.1) can be run via `dev/scripts/test-core.sh` on the Mac. Full app tests (Tasks 1.2, 2.1, 3.1) require `dev/scripts/test.sh`. Build results appear in `~/shared/Hex/dev/logs/`.

---
*Plan created: 2026-03-06*
