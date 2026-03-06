# Implementation Plan: Voice Commands

**Date:** 2026-03-06
**Based on:** BRAINSTORM.md, RESEARCH.md
**Status:** Approved
**Feature:** voice-commands

## Summary

Add voice command support to Hex so that spoken commands like "switch to huddle" are detected and executed instead of pasted as text. The first command type is window focusing -- heuristic prefix detection identifies commands ("switch to", "go to", "open", etc.), token-based fuzzy string matching resolves the target against open window titles, and the AXUIElement accessibility API brings the matched window to the front. No ML models are needed; the MVP uses heuristic detection and string matching only.

## Wave 1: Core Components
Independent tasks that can run in parallel.

### Task 1.1: VoiceCommandDetector

- **What:** Create a `VoiceCommandDetector` struct in HexCore with a static `detect(_ transcription: String) -> String?` method. The method:
  1. Normalizes the input: lowercases, trims leading/trailing whitespace, strips trailing punctuation (periods, commas, exclamation marks, question marks).
  2. Checks if the normalized text starts with any of these trigger prefixes: "switch to", "go to", "open", "focus", "bring up", "show me", "show". The prefixes must be checked longest-first to avoid "show" matching before "show me".
  3. Handles common transcription misrecognitions: "switch two" should be treated as "switch to", "go too" as "go to".
  4. If a prefix matches, extracts the remaining text after the prefix as the target. Trims the target.
  5. Returns the target string if non-empty, or nil if no prefix matched or the target is empty.

  The detector should also reject transcriptions longer than 10 words (commands are short utterances). This prevents accidental command detection in longer dictation that happens to start with "open".

  Follow the same structural pattern as the existing `ForceQuitCommandDetector` in `TranscriptionFeature.swift` (around lines 587-600) -- a simple struct with a static detection method.

- **Files:** `HexCore/Sources/HexCore/VoiceCommands/VoiceCommandDetector.swift`, `HexCore/Tests/HexCoreTests/VoiceCommands/VoiceCommandDetectorTests.swift`
- **TDD:** Yes
- **Tests:**
  - "switch to huddle" returns "huddle"
  - "Switch To Huddle." returns "huddle" (case-insensitive, strips trailing period)
  - "go to slack" returns "slack"
  - "open terminal" returns "terminal"
  - "focus chrome" returns "chrome"
  - "bring up messages" returns "messages"
  - "show me the calendar" returns "the calendar"
  - "show finder" returns "finder"
  - "show me" is checked before "show" (prefix ordering): "show me finder" returns "finder", not "me finder"
  - "switch two huddle" returns "huddle" (misrecognition handling)
  - "hello world" returns nil (no prefix)
  - "switch to" returns nil (empty target after prefix)
  - "I was thinking about switching to a new approach for the project" returns nil (exceeds 10-word limit)
  - "" returns nil (empty string)
  - "  switch to  huddle  " returns "huddle" (whitespace handling)
- **Acceptance:** All tests pass when running `dev/scripts/test-core.sh` on the Mac host. The function is pure with no side effects or dependencies.

### Task 1.2: WindowMatcher

- **What:** Create a `WindowMatcher` struct in HexCore with a static method `bestMatch(target: String, candidates: [(appName: String, windowTitle: String, index: Int)], threshold: Int = 50) -> (index: Int, score: Int)?`. The method takes a voice command target string and an array of candidate windows (represented as tuples of app name, window title, and an index for identification), scores each candidate, and returns the best match above the threshold.

  Scoring algorithm:
  1. Lowercase both the target and candidate strings. Split into tokens by whitespace and common separators (`|`, `-`, `--`, `:`, `,`).
  2. **Exact token match (score 100):** The target (as a whole or as a set of tokens) exactly equals one or more tokens in the candidate.
  3. **Substring containment (score 90):** The target appears as a contiguous substring within the candidate's full title or app name (after lowercasing).
  4. **Token overlap (score = matching/total * 80):** Count how many target tokens appear in the candidate tokens. Score is `(matchingTokens / totalTargetTokens) * 80`.
  5. **Prefix matching (score 70):** Any candidate token starts with the full target string.
  6. Take the highest score from steps 2-5 for each candidate.
  7. When matching against app name instead of window title, apply a -5 penalty so window title matches are preferred when scores are close.
  8. Return the candidate with the highest score if it meets the threshold, or nil.
  9. If multiple candidates tie, return the first one (preserving input order, which should be front-to-back window order for recency preference).

- **Files:** `HexCore/Sources/HexCore/VoiceCommands/WindowMatcher.swift`, `HexCore/Tests/HexCoreTests/VoiceCommands/WindowMatcherTests.swift`
- **TDD:** Yes
- **Tests:**
  - "huddle" matches "Slack | Huddle with Kit" at score >= 90 (substring containment)
  - "slack" matches "Slack | General" via app name match
  - "chrome" matches "Google Chrome" via token match
  - "terminal" matches "Terminal" at score 100 (exact token match)
  - "my document" matches "my document.txt - TextEdit" at high score (substring)
  - "xyz123" returns nil when no candidates contain it (below threshold)
  - Empty target returns nil
  - Empty candidates array returns nil
  - Multiple candidates: returns the highest-scoring one
  - Tie-breaking: when scores are equal, returns the first candidate (index order)
  - Case insensitivity: "SLACK" matches "slack"
  - App name penalty: when a target matches both a window title token and an app name token equally, the window title match scores higher
  - Token separators: "huddle" matches window title with em-dash separator ("Huddle--Kit")
  - Multi-token target: "huddle kit" matches "Slack | Huddle with Kit" via token overlap
- **Acceptance:** All tests pass when running `dev/scripts/test-core.sh` on the Mac host. The function is pure with no side effects or dependencies.

### Task 1.3: WindowClient TCA Dependency

- **What:** Create a `WindowClient` as a TCA dependency following the same pattern as `PasteboardClient` and `RecordingClient` in `Hex/Clients/`. The client provides two capabilities:

  1. **`listWindows() async -> [WindowInfo]`**: Enumerates all visible windows across running applications.
  2. **`focusWindow(_ window: WindowInfo) async -> Bool`**: Brings a specific window to the front. Returns true on success.

  **`WindowInfo` struct** (defined in the same file): `appName: String`, `windowTitle: String`, `processIdentifier: pid_t`, `windowReference: AXUIElement?` (nil in test/preview values). Must be `Equatable` and `Identifiable` (id derived from processIdentifier + windowTitle). The `Equatable` conformance should ignore `windowReference` (compare only appName, windowTitle, processIdentifier) since AXUIElement does not conform to Equatable.

  **Live implementation** (`liveValue`):
  - `listWindows()`: Iterate `NSWorkspace.shared.runningApplications` filtered to `.activationPolicy == .regular`. For each app, call `AXUIElementCreateApplication(pid)`, read `kAXWindowsAttribute` to get the window array, then read `kAXTitleAttribute` on each window element. Build and return an array of `WindowInfo`. Skip apps or windows where AX attributes fail to read (some apps don't expose titles). Log errors using `HexLog(.voiceCommands)` (the `.voiceCommands` log category will be added in Task 2.1). Run enumeration work off the main thread.
  - `focusWindow()`: First call `AXUIElementPerformAction(windowReference, kAXRaiseAction)` to raise the specific window within the app's z-order, then call `NSRunningApplication(processIdentifier: processIdentifier)?.activate(options: .activateIgnoringOtherApps)` to bring the app in front of all other apps. **Order matters: raise first, then activate.** Return false if `windowReference` is nil or either operation fails.

  Hex already uses AXUIElement APIs in `PasteboardClient.swift` (lines 350-379) and `KeyEventMonitorClient.swift` (lines 497-505) -- reference those files for the AX calling conventions and error handling patterns used in this codebase.

  **Test value** (`testValue`): Both methods unimplemented (TCA's `XCTUnimplemented` pattern), requiring explicit overrides in tests.
  **Preview value** (`previewValue`): `listWindows` returns a hardcoded array of 5 sample windows. `focusWindow` returns true.

- **Files:** `Hex/Clients/WindowClient.swift`
- **TDD:** Yes
- **Tests:** Write tests in the Xcode test target that verify:
  - The `testValue` calls are unimplemented by default (standard TCA unimplemented pattern)
  - A mock override of `listWindows` returns the expected `[WindowInfo]` array
  - A mock override of `focusWindow` receives the correct `WindowInfo` and returns the expected Bool
  - `WindowInfo` initializes correctly with all fields
  - `WindowInfo` equality compares appName, windowTitle, and processIdentifier (ignores windowReference)
  - `WindowInfo` conforms to Identifiable
- **Acceptance:** Tests pass when running `dev/scripts/test.sh` on the Mac host. The client follows the same structural pattern as `PasteboardClient` in `Hex/Clients/`.

## Wave 2: Feature Integration
Depends on Wave 1 completion.

### Task 2.1: Integrate Voice Commands into TranscriptionFeature

- **What:** Modify `TranscriptionFeature` to detect and execute voice commands after transcription completes. This wires together VoiceCommandDetector (from HexCore), WindowMatcher (from HexCore), and WindowClient (from Hex/Clients) into the existing transcription flow. Follow the same pattern as the existing `ForceQuitCommandDetector` integration.

  **Changes to TranscriptionFeature:**

  1. **Add `WindowClient` as a dependency** on the TranscriptionFeature reducer, following the same pattern as other `@Dependency` declarations in the file.

  2. **Add state for cached windows.** Add `var cachedWindows: [WindowInfo] = []` to the feature's `State` struct.

  3. **Enumerate windows when recording starts.** In the existing action/effect that begins audio recording, add an async effect that calls `windowClient.listWindows()` and stores the result in `cachedWindows`. This runs concurrently with recording so the window list is ready by transcription time.

  4. **Check for voice commands after transcription completes.** In the existing code path where transcribed text is received (before the text is pasted), insert this logic:
     a. Call `VoiceCommandDetector.detect(transcribedText)`.
     b. If a target is returned, map `cachedWindows` to the tuple format `(appName, windowTitle, index)` and call `WindowMatcher.bestMatch(target:candidates:)`.
     c. If a match is found, call `windowClient.focusWindow(cachedWindows[matchIndex])` **instead of pasting the text**. The text must not be pasted when a command is executed.
     d. If no command is detected or no window matches, proceed with normal paste behavior (existing code path, completely unchanged).

  5. **Clear cached windows** when recording ends or is cancelled.

  6. **Add logging.** Add a `.voiceCommands` case to the `HexLog` category enum in `HexCore/Sources/HexCore/Logging.swift`. Log at `.info` level: command detection (target extracted), match result (window matched + score, or no match), and focus result (success/failure).

  **What NOT to change:** Do not modify hotkey handling, recording flow, transcription engine selection, audio processing, or any other existing behavior. The voice command check is an additional step between "transcription completed" and "paste text." All existing behavior is preserved when no command prefix is detected.

- **Files:** `Hex/Features/Transcription/TranscriptionFeature.swift`, `HexCore/Sources/HexCore/Logging.swift` (add `.voiceCommands` category), tests in the Xcode test target
- **TDD:** Yes
- **Depends on:** Task 1.1, Task 1.2, Task 1.3
- **Tests:** Write TCA reducer tests that verify:
  - When transcription returns "switch to huddle" and `cachedWindows` contains a window with title "Slack | Huddle with Kit", `focusWindow` is called with that window and text is NOT pasted
  - When transcription returns "switch to nonexistent" and no window title matches, text is pasted normally (existing behavior preserved)
  - When transcription returns "hello this is a normal sentence", no command is detected, text is pasted normally
  - When recording starts, `listWindows` is called and its result is stored in `cachedWindows`
  - When recording is cancelled, `cachedWindows` is cleared
  - When a command is detected and matched but `focusWindow` returns false (focus failed), text is still NOT pasted (the command was recognized, execution just failed -- do not fall through to pasting command text)
  - When transcription returns "open chrome" and cached windows contain "Google Chrome", the Chrome window is focused
- **Acceptance:** All tests pass when running `dev/scripts/test.sh`. Normal transcription-to-paste behavior is completely unchanged when no voice command prefix is detected. Voice commands with matching windows trigger window focus instead of paste. Commands with no matching window do not paste the command text.

## Decisions from Alignment

| Decision | Rationale |
|----------|-----------|
| Use fuzzy string matching as primary matching, not a model | Token-based fuzzy matching handles most window matching ("huddle" to "Slack \| Huddle with Kit") in sub-millisecond time with zero dependencies. Models are only needed for semantic leaps like "my email" to "Gmail", which are uncommon enough to defer. |
| Defer LLM and API tiers entirely | Ship heuristic prefix detection + fuzzy string matching only. Gather real usage data first. Local LLM (MLX Swift + Qwen3-0.6B-4bit) and API fallback (Groq with Llama 3.1 8B) will be added only if users report unmatched commands that fuzzy matching cannot handle. |
| Prefix-only command detection for MVP | Only detect commands starting with trigger prefixes ("switch to", "go to", "open", "focus", "bring up", "show me", "show"). Short-utterance matching (bare "huddle" without a prefix) deferred to a later iteration. |
| Groq (not Grok) for future API fallback | The brainstorm mentioned "Grok" (xAI), but "Groq" (LPU inference company, ~200-400ms total latency for short prompts) was the intended provider. Deferred along with the entire API tier. |
| AXUIElement for all window operations | Use Accessibility API (AXUIElement) exclusively for window listing and focusing. No Screen Recording permission needed. Hex already has Accessibility permission granted by users. Use the kAXRaiseAction + NSRunningApplication.activate() pattern proven by AltTab, Hammerspoon, and Rectangle. |
| No new permissions or entitlements needed | Hex's existing Accessibility permission and com.apple.security.automation.apple-events entitlement cover all window management operations required for this feature. |
| Enumerate windows at recording start | Trigger window listing when the user starts recording (async, background thread) so results are cached by the time transcription completes. Avoids adding latency to the command execution path. |

## Execution

This plan is executed using `/cadence-build`. The build phase reads this file and spawns fresh subagents per task. Key details:
- **TDD is enforced.** Every task marked TDD: Yes follows RED -> GREEN -> REFACTOR. No production code without a failing test first.
- **Fresh subagents.** Each task runs in a fresh 200k context window. Subagents only see this plan and their agent instructions -- they have no memory of the conversation that produced this plan.
- **Wave ordering is strict.** All tasks in a wave must complete and pass code review before the next wave starts.
- **Commit convention:** RED: `test(task-N): ...`, GREEN: `feat(task-N): ...`, REFACTOR: `refactor(task-N): ...`
- **After all waves:** Run the full test suite, then `/cadence-ship` to create a PR.
- **VM to Mac workflow:** After code changes, run `bash dev/scripts/sync.sh` to sync to the shared folder. The user builds and tests on the Mac host. Read build results from `~/shared/Hex/dev/logs/build-summary.log`, HexCore test results from `~/shared/Hex/dev/logs/test-core-summary.log`, and full test results from `~/shared/Hex/dev/logs/test-summary.log`.
- **Logging:** Use `HexLog` for all diagnostic output (defined in `HexCore/Sources/HexCore/Logging.swift`). Add a `.voiceCommands` category. Never use `print()`.

---
*Plan created: 2026-03-06*
