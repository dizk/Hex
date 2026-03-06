# Brainstorm: App Aliases for Voice Commands

**Date:** 2026-03-06
**Status:** Ready for research
**Feature:** app-aliases

## Core Idea

Some app names (like "Ghostty") are nearly impossible for the transcription model to recognize, making the "switch to" voice command useless for those apps. Users should be able to define their own aliases in Settings -- mapping a speakable word like "terminal" to the real app name "Ghostty" -- so voice-driven window switching works reliably for any app.

## Key Decisions

| Decision | Context | Resolved |
|----------|---------|----------|
| Aliases are user-configurable in the Settings UI | Needs to be discoverable and easy to edit, not a hidden config file | Yes |
| Multiple keywords can map to the same app | User might say "terminal" or "console" for Ghostty | Yes |
| Aliases are checked first, then fall back to real app names | Existing "switch to Chrome" behavior must keep working without configuration | Yes |
| Aliases override real app names on conflict | If user maps "chrome" to Firefox, that's their explicit intent -- respect it | Yes |
| Scope limited to focus-window command for now | Generic voice command system is a separate future feature (issue #3) | Yes |
| Designed with future extensibility in mind | The alias/mapping system should be structured so it can grow to support other command types later | Yes |

## Resolved Contradictions

| Originally said | Then said | Resolution |
|----------------|-----------|------------|
| Map any keywords to any commands (generic system) | Actually, scope to window switching for now | Focus on app aliases for the switch-to command. Generic command mapping parked as issue #3 |

## Open Questions (for Research)

- [ ] How does the current "switch to" voice command work? Where does app name matching happen in the codebase?
- [ ] Where are user settings stored in TCA -- what's the pattern for adding a new user-configurable collection (list of alias entries)?
- [ ] What UI pattern fits best for the alias editor in Settings? (add/edit/remove rows in a table vs. a simpler approach)
- [ ] Should aliases be case-insensitive? (e.g., "Terminal" and "terminal" both match)
- [ ] How should the app name on the right side of the mapping work -- should it match against bundle name, display name, or both?

## Deferred Ideas

- Generic user-configurable voice command system (issue #3)
- Flash mouse indicator voice command (issue #4)

---
*Brainstorm completed: 2026-03-06*
