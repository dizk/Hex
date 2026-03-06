# Research: App Aliases for Voice Commands

**Date:** 2026-03-06
**Based on:** BRAINSTORM.md
**Status:** Ready for alignment
**Feature:** app-aliases

## Findings

### 1. How the "switch to" voice command works

**Question:** How does the current "switch to" voice command work? Where does app name matching happen in the codebase?

**Finding:** The voice command operates through a four-stage pipeline:

1. **Command Detection** (`HexCore/Sources/HexCore/VoiceCommands/VoiceCommandDetector.swift`): Normalizes transcribed text (lowercase, trim, strip punctuation), checks for trigger prefixes (`"switch to"`, `"bring up"`, `"show me"`, `"go to"`, `"focus"`, `"open"`, `"show"`), handles misrecognitions (e.g., `"switch two"` -> `"switch to"`), and extracts the target string. Max 10-word limit rejects long dictations.

2. **Window Enumeration** (`Hex/Clients/WindowClient.swift`, lines 135-190): Runs when recording starts (not after transcription). Iterates `NSWorkspace.shared.runningApplications` filtering for `.regular` activation policy. For each app, creates `AXUIElement` and reads `kAXWindowsAttribute` + `kAXTitleAttribute`. Returns array of `WindowInfo` structs with `appName`, `windowTitle`, `processIdentifier`, `windowReference`.

3. **Window Matching** (`HexCore/Sources/HexCore/VoiceCommands/WindowMatcher.swift`): Multi-tier fuzzy scoring -- exact token match (100), substring containment (90), token overlap (0-80), prefix match (70). Scores against both window title and app name, with a -5 penalty for app name matches. Default threshold of 50. Tokenizes by splitting on whitespace + `|-:,`.

4. **Window Focusing** (`Hex/Clients/WindowClient.swift`, lines 103-131): Uses `AXUIElementPerformAction(kAXRaiseAction)` then `AXUIElementSetAttributeValue(kAXFrontmostAttribute)` to focus the matched window.

**Integration** (`Hex/Features/Transcription/TranscriptionFeature.swift`, lines 428-454): After transcription, if `VoiceCommandDetector.detect()` returns a target, build `WindowCandidate` list from cached windows, call `WindowMatcher.bestMatch()`, and focus the result. If no match, silently discard.

**Sources:**
- `HexCore/Sources/HexCore/VoiceCommands/VoiceCommandDetector.swift`
- `HexCore/Sources/HexCore/VoiceCommands/WindowMatcher.swift`
- `Hex/Clients/WindowClient.swift`
- `Hex/Features/Transcription/TranscriptionFeature.swift` (lines 319-323, 428-454)
- `HexCore/Tests/HexCoreTests/VoiceCommands/VoiceCommandDetectorTests.swift` (18 test cases)
- `HexCore/Tests/HexCoreTests/VoiceCommands/WindowMatcherTests.swift` (17 test cases)

**Recommendation:** The alias resolution should be inserted between VoiceCommandDetector (stage 1) and WindowMatcher (stage 3). After the detector extracts a target like "terminal", check aliases first. If a match is found, replace the target with the mapped app name (e.g., "Ghostty") before passing to WindowMatcher. This preserves the existing fuzzy matching pipeline and only adds one lookup step.

**Risk:** The window matcher scores app name matches with a -5 penalty vs window titles. If an alias maps to an app name (the common case), the resolved target will get this penalty. This is fine -- the penalty is small (95 vs 100) and the exact token match tier still scores 95, well above the threshold of 50.

### 2. TCA settings pattern for collections

**Question:** Where are user settings stored in TCA -- what's the pattern for adding a new user-configurable collection (list of alias entries)?

**Finding:** Settings follow a three-tier pattern:

1. **HexSettings struct** (`HexCore/Sources/HexCore/Settings/HexSettings.swift`): Codable struct containing all settings. Existing collections: `wordRemovals: [WordRemoval]` (line 47) and `wordRemappings: [WordRemapping]` (line 48). Both are `Identifiable`, `Codable`, `Equatable`, `Sendable` structs with `id: UUID`, `isEnabled: Bool`, and content fields.

2. **Schema-driven encoding** (`HexSettingsSchema`, lines 207-284): Each field registered as a `SettingsField` with key, keyPath, and default. Collections use the same pattern as scalars:
   ```swift
   SettingsField(.wordRemovals, keyPath: \.wordRemovals, default: defaults.wordRemovals)
   ```

3. **TCA integration** (`Hex/Models/AppHexSettings.swift`, lines 49-58): Exposed via `@Shared(.hexSettings)` using `FileStorageKey` persisting to JSON at `~/Library/Application Support/com.kitlangton.Hex/hex_settings.json`.

4. **Reducer mutations** (`Hex/Features/Settings/SettingsFeature.swift`, lines 199-221): Add/remove actions mutate via `state.$hexSettings.withLock { }` for thread safety.

**Sources:**
- `HexCore/Sources/HexCore/Settings/HexSettings.swift` (lines 47-48, 78-79, 126-151, 207-284)
- `Hex/Models/AppHexSettings.swift` (lines 49-58)
- `Hex/Features/Settings/SettingsFeature.swift` (lines 89-93, 199-221)
- `HexCore/Sources/HexCore/Models/WordRemoval.swift`
- `HexCore/Sources/HexCore/Models/WordRemapping.swift`

**Recommendation:** Follow the exact WordRemoval/WordRemapping pattern:
1. Define `AppAlias` struct in HexCore with `id: UUID`, `isEnabled: Bool`, `alias: String`, `appName: String`
2. Add `appAliases: [AppAlias]` to `HexSettings`
3. Register in `HexSettingsSchema` with a new `HexSettingKey.appAliases` case
4. Add `addAppAlias` / `removeAppAlias(UUID)` actions to `SettingsFeature`
5. Mutate via `state.$hexSettings.withLock { }` in the reducer

**Risk:** All mutations must use `withLock { }` -- direct mutations will fail. The schema system handles forward compatibility (unknown keys are silently ignored during decode), so adding a new field is safe for older versions.

### 3. Settings UI patterns for editable collections

**Question:** What UI pattern fits best for the alias editor in Settings? (add/edit/remove rows in a table vs. a simpler approach)

**Finding:** The codebase uses a **custom row-based pattern** (not SwiftUI Table) for editable collections in `WordRemappingsView.swift`:

- **GroupBox containers** with `LazyVStack` for rows (lines 82-117, 119-152)
- **Custom row components** (`RemovalRow`, `RemappingRow`, lines 210-277) with: toggle checkbox (24px), text input fields (`.textFieldStyle(.roundedBorder)`), delete button (trash icon, 24px), `RoundedRectangle` backgrounds
- **Add button** at bottom with "plus" icon (lines 99-106)
- **Binding lookup** via `removalBinding(for: id)` returning `Binding<WordRemoval>?` (lines 186-198)
- **Segmented picker** for switching between removals and remappings (lines 57-63)
- **Dedicated tab** in settings window -- complex editable collections get their own view, not embedded in the main settings form (`AppFeature.swift`, lines 273-278, "Transforms" tab)

**Sources:**
- `Hex/Features/Remappings/WordRemappingsView.swift` (lines 57-63, 82-152, 186-198, 210-277)
- `Hex/Features/Settings/SettingsView.swift`
- `Hex/Features/App/AppFeature.swift` (lines 273-278)

**Recommendation:** Create an `AppAliasesView` following the WordRemappingsView pattern. Each row: enable toggle + alias text field + arrow indicator + app name text field + delete button. Either add it as a new settings tab ("Aliases") or integrate into the existing "Transforms" tab with a segmented picker section. Given that aliases are conceptually different from text transforms, a separate tab or a clearly labeled section within Transforms would work.

**Risk:** The custom row approach requires manual layout management. If there are many aliases, performance should be fine with `LazyVStack`. No risk of SwiftUI Table compatibility issues since the project targets macOS 14+.

### 4. Case sensitivity in alias matching

**Question:** Should aliases be case-insensitive? (e.g., "Terminal" and "terminal" both match)

**Finding:** **Yes -- the entire voice command pipeline is already case-insensitive by design.** Two independent normalization points ensure this:

1. **VoiceCommandDetector** (line 85): `text.lowercased()` normalizes all input before command extraction.
2. **WindowMatcher** (line 26): `tokenize()` calls `.lowercased()` on both target and candidate strings before scoring.

There is an explicit test confirming this behavior (`WindowMatcherTests.swift`, lines 140-148):
```swift
func caseInsensitive_uppercaseTargetMatchesLowercaseCandidate() {
    let candidates = [candidate("Slack", "General", 0)]
    let result = WindowMatcher.bestMatch(target: "SLACK", candidates: candidates)
    #expect(result != nil)
}
```

Transcription model output varies in casing (Whisper tends to sentence-case, Parakeet varies), but the normalization layer makes this irrelevant.

**Sources:**
- `HexCore/Sources/HexCore/VoiceCommands/VoiceCommandDetector.swift` (line 85)
- `HexCore/Sources/HexCore/VoiceCommands/WindowMatcher.swift` (line 26)
- `HexCore/Tests/HexCoreTests/VoiceCommands/WindowMatcherTests.swift` (lines 140-148)
- `Hex/Features/Transcription/TranscriptionFeature.swift` (lines 429-438)

**Recommendation:** Aliases must be case-insensitive to maintain consistency with the existing pipeline. When matching, normalize both the alias key and the transcribed target to lowercase. Store aliases with user-entered casing for display in the Settings UI.

**Risk:** None. Case-insensitive matching is the only consistent choice given the existing normalization. Implementing case-sensitive aliases would be a bug.

### 5. App name matching strategy (display name vs bundle name)

**Question:** How should the app name on the right side of the mapping work -- should it match against bundle name, display name, or both?

**Finding:** The current implementation uses **`NSRunningApplication.localizedName`** (display name) exclusively for app identification:

- **Window enumeration** (`WindowClient.swift`, lines 138-143): `guard let appName = app.localizedName else { continue }` -- this is the only app name property used.
- **Source app tracking** (`TranscriptionFeature.swift`, lines 302-305): Captures both `localizedName` and `bundleIdentifier`, but only for tracking the source app, not for voice command matching.
- **History lookups** (`HistoryFeature.swift`, lines 238-243): Uses `bundleIdentifier` to look up apps via `NSWorkspace.urlForApplication(withBundleIdentifier:)`.

There is no access to `CFBundleName` from `NSRunningApplication` -- only `localizedName` is available.

**Sources:**
- `Hex/Clients/WindowClient.swift` (lines 138-143 for enumeration, 103-131 for activation)
- `HexCore/Sources/HexCore/VoiceCommands/WindowMatcher.swift` (lines 102-110)
- `Hex/Features/Transcription/TranscriptionFeature.swift` (lines 302-305)
- `Hex/Features/History/HistoryFeature.swift` (lines 238-243)

**Recommendation:** Match alias targets against `localizedName` (display name), which is what users see in the Dock and what the existing system already uses. The user types "Ghostty" in the Settings UI, and at match time this is compared against window candidates whose `appName` field comes from `localizedName`. No need to support bundle identifiers for the initial implementation -- it adds complexity without clear benefit since the matching happens against the already-enumerated window list.

**Risk:**
- **Localization variance:** On non-English systems, `localizedName` may differ from the English name. An alias created for "Safari" would still work (Safari doesn't localize its name), but some apps do localize. This is an edge case for v1.
- **Display name collisions:** Multiple apps could theoretically share a display name. Extremely rare in practice.
- **App updates:** If an app's display name changes, aliases referencing the old name break. Users would need to update manually.

## Ecosystem Conflicts

No ecosystem conflicts found. The brainstormed vision aligns well with the existing codebase patterns:

| Brainstorm says | Research confirms | Status |
|----------------|-------------------|--------|
| Aliases checked first, fall back to real app names | Integration point exists between VoiceCommandDetector and WindowMatcher in TranscriptionFeature | Compatible |
| Aliases override real names on conflict | Replacing target before WindowMatcher achieves this naturally | Compatible |
| User-configurable in Settings UI | WordRemappingsView provides a proven, copy-able pattern | Compatible |
| Multiple keywords per app | Array storage in HexSettings supports this | Compatible |
| Future extensibility | The VoiceCommandDetector/WindowMatcher separation already enables adding new command types | Compatible |

The feature is well-scoped and fits cleanly into existing patterns. The only design decisions to resolve during alignment are UI placement (new tab vs section in Transforms) and whether alias resolution belongs in HexCore or in the app target.

## Recommendations Summary

1. **Insert alias resolution between command detection and window matching** -- check aliases after VoiceCommandDetector extracts a target, before WindowMatcher scores candidates. This is the minimal, non-invasive integration point.
2. **Follow the WordRemoval/WordRemapping pattern exactly** for the data model, settings storage, schema registration, and TCA actions. The pattern is battle-tested and handles persistence, binding, and thread safety.
3. **Build the UI as a custom row-based editor** matching WordRemappingsView's GroupBox + LazyVStack pattern. Either a new settings tab or a section within Transforms.
4. **Aliases must be case-insensitive** -- the entire pipeline already normalizes to lowercase. This is a consistency requirement, not a design choice.
5. **Match alias targets against `localizedName`** (display name) -- this is what the existing window enumeration uses and what users expect to type.

---
*Research completed: 2026-03-06*
