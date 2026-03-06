# Implementation Plan: App Aliases for Voice Commands

**Date:** 2026-03-06
**Based on:** BRAINSTORM.md, RESEARCH.md
**Status:** Approved
**Feature:** app-aliases

## Summary

Add user-configurable app aliases so voice commands like "switch to terminal" can map to apps with hard-to-pronounce names like "Ghostty." Aliases are stored in HexSettings, resolved between voice command detection and window matching, and managed via a new "Aliases" settings tab.

## Wave 1: Data Model and Alias Resolution Logic

Independent tasks: the data model (HexCore), the resolver (HexCore), and settings schema registration can all be built in parallel since they touch separate files.

### Task 1.1: AppAlias Data Model

- **What:** Create an `AppAlias` struct in `HexCore/Sources/HexCore/Models/AppAlias.swift` following the exact pattern of `WordRemapping` (`HexCore/Sources/HexCore/Models/WordRemapping.swift`). The struct must conform to `Codable`, `Equatable`, `Identifiable`, and `Sendable`. Fields:
  - `id: UUID` (default `UUID()`)
  - `isEnabled: Bool` (default `true`)
  - `alias: String` — the speakable trigger word (e.g., "terminal")
  - `appName: String` — the display name of the target app (e.g., "Ghostty")

  Provide an initializer with defaults matching the WordRemapping pattern:
  ```swift
  public init(id: UUID = UUID(), isEnabled: Bool = true, alias: String, appName: String)
  ```

- **Files:**
  - Create: `HexCore/Sources/HexCore/Models/AppAlias.swift`
- **TDD:** Yes
- **Tests:** Create `HexCore/Tests/HexCoreTests/Models/AppAliasTests.swift`. Test cases:
  1. Default initializer sets `isEnabled` to `true` and generates a UUID
  2. Two `AppAlias` values with same fields (but different IDs) are not equal (Equatable uses ID)
  3. Round-trip encode/decode via JSONEncoder/JSONDecoder preserves all fields
  4. Decoding from JSON with missing `isEnabled` falls back to default behavior (or fails gracefully)
- **Acceptance:** `swift test --filter AppAliasTests` passes. The struct compiles, conforms to all four protocols, and round-trips through JSON.

### Task 1.2: AppAlias Resolution Logic

- **What:** Create an `AppAliasResolver` enum in `HexCore/Sources/HexCore/VoiceCommands/AppAliasResolver.swift`. This is a pure function that takes a voice command target string and an array of `AppAlias` entries, and returns either the resolved app name or the original target unchanged.

  The resolver must:
  - Accept a `target: String` (the extracted voice command target, already lowercased by VoiceCommandDetector) and `aliases: [AppAlias]`
  - Filter to only enabled aliases (`isEnabled == true`)
  - Compare the target (lowercased) against each alias's `alias` field (lowercased) for exact match
  - If a match is found, return the alias's `appName` field (preserving original casing from the alias definition — WindowMatcher will lowercase it during scoring)
  - If no match is found, return the original `target` unchanged
  - If multiple aliases match (edge case — two aliases with the same trigger), return the first match

  This is a stateless, pure function with no dependencies. It does NOT import Foundation beyond what `AppAlias` requires.

  ```swift
  public enum AppAliasResolver {
      public static func resolve(target: String, aliases: [AppAlias]) -> String
  }
  ```

- **Files:**
  - Create: `HexCore/Sources/HexCore/VoiceCommands/AppAliasResolver.swift`
- **TDD:** Yes
- **Tests:** Create `HexCore/Tests/HexCoreTests/VoiceCommands/AppAliasResolverTests.swift`. Test cases:
  1. **Basic resolution:** target "terminal" with alias ("terminal" → "Ghostty") returns "Ghostty"
  2. **Case insensitive:** target "terminal" matches alias with `alias: "Terminal"` — returns the alias's `appName`
  3. **No match returns original:** target "chrome" with alias ("terminal" → "Ghostty") returns "chrome" unchanged
  4. **Disabled alias skipped:** target "terminal" with a disabled alias ("terminal" → "Ghostty", `isEnabled: false`) returns "terminal" unchanged
  5. **Empty aliases returns original:** target "slack" with empty aliases array returns "slack"
  6. **Multiple aliases for same app:** two aliases ("terminal" → "Ghostty") and ("console" → "Ghostty"), target "console" returns "Ghostty"
  7. **First match wins on duplicate triggers:** two aliases ("terminal" → "Ghostty") and ("terminal" → "iTerm"), target "terminal" returns "Ghostty" (first in array)
  8. **Alias overrides real app name:** target "safari" with alias ("safari" → "Firefox") returns "Firefox" — aliases take priority
  9. **Empty target returns empty:** target "" returns ""
  10. **Whitespace handling:** target "  terminal  " with alias ("terminal" → "Ghostty") — decide whether to trim. The VoiceCommandDetector already trims, so the target arriving here is already clean. Test that an exact match works without extra whitespace handling.
- **Acceptance:** `swift test --filter AppAliasResolverTests` passes. The resolver correctly maps aliases, handles case insensitivity, skips disabled entries, and falls through to the original target when no alias matches.

### Task 1.3: Register AppAliases in HexSettings and Schema

- **What:** Add `appAliases: [AppAlias]` to the `HexSettings` struct and register it in the settings schema so it persists to the JSON settings file. This involves four changes in `HexCore/Sources/HexCore/Settings/HexSettings.swift`:

  1. Add a property to `HexSettings`:
     ```swift
     public var appAliases: [AppAlias]
     ```
     Place it after `wordRemappings` (line 48).

  2. Add the parameter to the `init` with default `[]`:
     ```swift
     appAliases: [AppAlias] = []
     ```
     Add it after the `wordRemappings` parameter (line 79). Assign it in the init body after `self.wordRemappings = wordRemappings`.

  3. Add a new case to `HexSettingKey` enum:
     ```swift
     case appAliases
     ```
     Add it after `wordRemappings` (line 150).

  4. Register in `HexSettingsSchema.fields` array:
     ```swift
     SettingsField(.appAliases, keyPath: \.appAliases, default: defaults.appAliases).eraseToAny(),
     ```
     Add it after the `wordRemappings` field entry (line 282).

  No custom decode/encode strategy needed — the default `decodeIfPresent` with fallback to empty array handles forward compatibility (older settings files without `appAliases` will decode to `[]`).

- **Files:**
  - Modify: `HexCore/Sources/HexCore/Settings/HexSettings.swift`
- **TDD:** Yes
- **Tests:** Create `HexCore/Tests/HexCoreTests/Settings/AppAliasSettingsTests.swift`. Test cases:
  1. **Default value is empty array:** `HexSettings()` has `appAliases == []`
  2. **Round-trip encode/decode preserves aliases:** Create `HexSettings` with two `AppAlias` entries, encode to JSON, decode back, verify `appAliases` matches
  3. **Forward compatibility:** Decode a JSON string that does NOT contain an `appAliases` key — verify it decodes successfully with `appAliases == []` (this simulates an older settings file)
  4. **Init with aliases:** `HexSettings(appAliases: [AppAlias(alias: "terminal", appName: "Ghostty")])` stores the alias correctly
- **Acceptance:** `swift test --filter AppAliasSettingsTests` passes. Settings with aliases round-trip through JSON correctly. Settings without the key decode with an empty array default.

## Wave 2: Integration and Settings UI

These tasks depend on Wave 1 artifacts: Task 2.1 needs AppAliasResolver and the appAliases field on HexSettings; Tasks 2.2 and 2.3 need the AppAlias model and HexSettings field.

### Task 2.1: Integrate Alias Resolution into TranscriptionFeature

- **What:** Wire `AppAliasResolver.resolve()` into the voice command pipeline in `Hex/Features/Transcription/TranscriptionFeature.swift`. After `VoiceCommandDetector.detect()` extracts a target and before `WindowMatcher.bestMatch()` scores candidates, resolve the target through aliases.

  In `TranscriptionFeature.swift`, find the voice command handling block (around lines 428-454). Currently:
  ```swift
  if let voiceCommandTarget = VoiceCommandDetector.detect(result) {
      // ... builds candidates, calls WindowMatcher.bestMatch(target: voiceCommandTarget, ...)
  ```

  Change to:
  ```swift
  if let voiceCommandTarget = VoiceCommandDetector.detect(result) {
      let aliases = state.hexSettings.appAliases
      let resolvedTarget = AppAliasResolver.resolve(target: voiceCommandTarget, aliases: aliases)
      // ... use resolvedTarget instead of voiceCommandTarget for WindowMatcher.bestMatch and logging
  ```

  Update the logging to show both the original and resolved target when they differ:
  ```swift
  if resolvedTarget != voiceCommandTarget {
      voiceCommandLogger.info("Alias resolved: '\(voiceCommandTarget, privacy: .private)' → '\(resolvedTarget, privacy: .private)'")
  }
  ```

  Pass `resolvedTarget` to `WindowMatcher.bestMatch(target: resolvedTarget, candidates: candidates)` instead of `voiceCommandTarget`.

  The `state.hexSettings` is already available in the reducer (it's `@Shared(.hexSettings)`), so no new dependencies are needed.

- **Files:**
  - Modify: `Hex/Features/Transcription/TranscriptionFeature.swift`
- **TDD:** Yes
- **Tests:** The TranscriptionFeature is in the app target (not HexCore), so integration tests are limited. However, the core logic is already tested via AppAliasResolverTests (Task 1.2) and WindowMatcherTests. Add a focused test to verify the resolver integrates correctly with the window matcher by testing the combined flow in `HexCore/Tests/HexCoreTests/VoiceCommands/AppAliasResolverTests.swift` (append to existing file from Task 1.2):
  1. **End-to-end: alias + window matching:** Create an alias ("terminal" → "Ghostty"), resolve target "terminal" to "Ghostty", then call `WindowMatcher.bestMatch(target: "Ghostty", candidates: [WindowCandidate(appName: "Ghostty", windowTitle: "~", index: 0)])` and verify it returns index 0 with a score >= 50
  2. **End-to-end: no alias, fallback works:** No aliases defined, target "slack" passed through resolver unchanged, WindowMatcher matches against candidate with appName "Slack" successfully
  3. **End-to-end: disabled alias, fallback to real name:** Disabled alias ("slack" → "Discord"), target "slack" passes through as "slack", WindowMatcher matches "Slack" app name
- **Depends on:** Task 1.2, Task 1.3
- **Acceptance:** The voice command pipeline resolves aliases before matching windows. When a user says "switch to terminal" and an alias maps "terminal" to "Ghostty", the Ghostty window is focused. Existing voice commands without aliases continue to work unchanged. The app builds without errors (`dev/scripts/build.sh`).

### Task 2.2: Add/Remove AppAlias Actions in SettingsFeature

- **What:** Add TCA actions for adding and removing app aliases in `Hex/Features/Settings/SettingsFeature.swift`, following the exact pattern of `addWordRemapping` / `removeWordRemapping` (lines 211-221).

  1. Add two new action cases to the `Action` enum (after `removeWordRemapping`, around line 92):
     ```swift
     case addAppAlias
     case removeAppAlias(UUID)
     ```

  2. Add reducer cases in the `Reduce` body (after the `removeWordRemapping` case, around line 221):
     ```swift
     case .addAppAlias:
         state.$hexSettings.withLock {
             $0.appAliases.append(.init(alias: "", appName: ""))
         }
         return .none

     case let .removeAppAlias(id):
         state.$hexSettings.withLock {
             $0.appAliases.removeAll { $0.id == id }
         }
         return .none
     ```

  All mutations use `state.$hexSettings.withLock { }` for thread safety — this is mandatory.

- **Files:**
  - Modify: `Hex/Features/Settings/SettingsFeature.swift`
- **TDD:** Yes
- **Tests:** Since SettingsFeature is in the app target, add a focused test file. Create `HexCore/Tests/HexCoreTests/Settings/AppAliasSettingsTests.swift` — if this file already exists from Task 1.3, append to it. Otherwise, the builder should verify the action wiring manually. The key test scenarios (if testable from HexCore):
  1. Verify `HexSettings` mutation: starting from `appAliases: []`, appending `.init(alias: "", appName: "")` results in one entry
  2. Verify removal: starting from `appAliases: [alias1, alias2]`, removing by `alias1.id` leaves only `alias2`

  If the SettingsFeature reducer cannot be tested from HexCore (it's in the app target), document that the acceptance criteria below covers verification.
- **Depends on:** Task 1.1, Task 1.3
- **Acceptance:** The SettingsFeature reducer handles `addAppAlias` and `removeAppAlias` actions. Adding creates an entry with empty alias and appName. Removing by UUID deletes the correct entry. The app builds without errors.

### Task 2.3: App Aliases Settings Tab UI

- **What:** Create an `AppAliasesView` in `Hex/Features/Aliases/AppAliasesView.swift` and register it as a new "Aliases" tab in the settings navigation. Follow the layout pattern from `WordRemappingsView` (`Hex/Features/Remappings/WordRemappingsView.swift`).

  **The view (`AppAliasesView.swift`):**
  - Takes a `StoreOf<SettingsFeature>` (same as WordRemappingsView)
  - Uses `@ObserveInjection var inject` and `.enableInjection()` for hot reload support
  - Structure:
    ```
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("App Aliases").font(.title2.bold())
                Text("Map speakable words to app names for voice commands like \"switch to terminal.\"")
                    .font(.callout).foregroundStyle(.secondary)
            }

            // Aliases list
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    // Column headers
                    aliasColumnHeaders

                    // Rows
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(store.hexSettings.appAliases) { alias in
                            if let aliasBinding = aliasBinding(for: alias.id) {
                                AliasRow(alias: aliasBinding) {
                                    store.send(.removeAppAlias(alias.id))
                                }
                            }
                        }
                    }

                    // Add button
                    HStack {
                        Button { store.send(.addAppAlias) } label: {
                            Label("Add Alias", systemImage: "plus")
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Command Aliases").font(.headline)
                    Text("When you say \"switch to [alias]\", the matching app will be focused.")
                        .settingsCaption()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
    ```

  - **Column headers:** "On" (toggle width), "Alias" (expanding), arrow icon, "App Name" (expanding), delete spacer. Follows `remappingsColumnHeaders` pattern from WordRemappingsView (lines 167-184).

  - **AliasRow** (private struct): Toggle + "Alias" text field + arrow.right icon + "App Name" text field + trash button. Follows `RemappingRow` pattern (lines 240-277). Use the same `Layout` constants: `toggleColumnWidth: 24`, `deleteColumnWidth: 24`, `arrowColumnWidth: 16`, `rowHorizontalPadding: 10`, `rowVerticalPadding: 6`, `rowCornerRadius: 8`.

  - **Binding helper:** `aliasBinding(for: UUID) -> Binding<AppAlias>?` following the `remappingBinding` pattern (lines 193-198):
    ```swift
    private func aliasBinding(for id: UUID) -> Binding<AppAlias>? {
        guard let index = store.hexSettings.appAliases.firstIndex(where: { $0.id == id }) else { return nil }
        return $store.hexSettings.appAliases[index]
    }
    ```

  **Register the tab in `AppFeature.swift`:**

  1. Add `case aliases` to the `ActiveTab` enum (after `remappings`, line 19):
     ```swift
     case aliases
     ```

  2. Add a sidebar button in `SettingsWindow` body (after the "Transforms" button, around line 279):
     ```swift
     Button {
         store.send(.setActiveTab(.aliases))
     } label: {
         Label("Aliases", systemImage: "character.bubble")
     }
     .buttonStyle(.plain)
     .tag(AppFeature.ActiveTab.aliases)
     ```

  3. Add the detail view case (after the `.remappings` case, around line 309):
     ```swift
     case .aliases:
         AppAliasesView(store: store.scope(state: \.settings, action: \.settings))
             .navigationTitle("Aliases")
     ```

- **Files:**
  - Create: `Hex/Features/Aliases/AppAliasesView.swift`
  - Modify: `Hex/Features/App/AppFeature.swift`
- **TDD:** Yes
- **Tests:** UI views in the app target are difficult to unit test directly. Create a minimal test to verify the data flow works. In `HexCore/Tests/HexCoreTests/Models/AppAliasTests.swift` (append to file from Task 1.1), add:
  1. **Binding simulation:** Create an `AppAlias`, mutate its `alias` field, verify it changes (confirms the struct is mutable as expected for bindings)
  2. **Array operations:** Append an `AppAlias` to an array, find it by ID, remove it by ID — verifying the operations the view will perform

  The primary acceptance test for the UI is visual verification on the Mac after building.
- **Depends on:** Task 1.1, Task 1.3, Task 2.2
- **Acceptance:** A new "Aliases" tab appears in the settings sidebar between "Transforms" and "History" (or after "Transforms"). Clicking it shows the alias editor with a header, an empty list, and an "Add Alias" button. Adding an alias creates a row with toggle, alias field, arrow, app name field, and delete button. Editing fields updates the settings. Deleting removes the row. The app builds without errors (`dev/scripts/build.sh`).

## Decisions from Alignment

| Decision | Rationale |
|----------|-----------|
| Insert alias resolution between VoiceCommandDetector and WindowMatcher | This is the minimal integration point — one lookup step added to the existing pipeline, no changes to detection or matching logic |
| Follow WordRemoval/WordRemapping pattern for data model and settings | The pattern is battle-tested, handles persistence, binding, and thread safety correctly. Consistency reduces maintenance burden |
| New "Aliases" settings tab (not embedded in Transforms) | Aliases are conceptually different from text transforms (word removals/remappings). A separate tab makes them more discoverable and avoids overloading the Transforms view |
| Case-insensitive alias matching | The entire voice command pipeline already normalizes to lowercase at two points (VoiceCommandDetector and WindowMatcher). Case-sensitive matching would be a consistency bug |
| Match alias targets against localizedName (display name) only | The existing window enumeration uses NSRunningApplication.localizedName exclusively. Bundle identifiers add complexity without benefit since matching happens against the already-enumerated window list |

## Execution

This plan is executed using `/cadence-build`. The build phase reads this file and spawns fresh subagents per task. Key details:
- **TDD is enforced.** Every task marked TDD: Yes follows RED -> GREEN -> REFACTOR. No production code without a failing test first.
- **Fresh subagents.** Each task runs in a fresh 200k context window. Subagents only see this plan and their agent instructions -- they have no memory of the conversation that produced this plan.
- **Wave ordering is strict.** All tasks in a wave must complete and pass code review before the next wave starts.
- **Commit convention:** RED: `test(task-N): ...`, GREEN: `feat(task-N): ...`, REFACTOR: `refactor(task-N): ...`
- **After all waves:** Run the full test suite, then `/cadence-ship` to create a PR.
- **Sync before build:** After code changes, run `bash dev/scripts/sync.sh` to sync to the Mac shared folder. The user builds on Mac with `dev/scripts/build.sh` and tests with `dev/scripts/test-core.sh` (HexCore unit tests).
- **HexCore tests only:** All TDD tests live in `HexCore/Tests/HexCoreTests/`. The app target (`Hex/`) code is verified via build success and manual testing on Mac.
- **Test framework:** Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) not XCTest. See existing tests in `HexCore/Tests/HexCoreTests/VoiceCommands/` for the pattern.

---
*Plan created: 2026-03-06*
