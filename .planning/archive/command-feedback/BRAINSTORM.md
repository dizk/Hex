# Brainstorm: Voice Command Feedback

**Date:** 2026-03-06
**Status:** Ready for research
**Feature:** command-feedback

## Core Idea

When a voice command is executed, the user has no way of knowing what happened -- did it work, fail, or get pasted as text? The app needs to give immediate visual feedback (green/red flash on the transcription indicator) and record every command in transcription history with both the raw input and the action taken, so users can see at a glance what the app understood and did.

## Key Decisions

| Decision | Context | Resolved |
|----------|---------|----------|
| Green flash on indicator for command success | User wants instant, non-intrusive confirmation that a command was recognized and executed | Yes |
| Double red flash on indicator for command failure | Distinct from success -- double flash makes failure unmistakable without reading text | Yes |
| Reuse existing transcription indicator overlay | No need for a new UI element -- the InvisibleWindow overlay is already visible during transcription | Yes |
| History entries show both input transcript and result action | User wants to see what they said ("switch to chrome") and what the app did ("Switched to Google Chrome") | Yes |
| History entries are visually distinct from regular transcriptions | Commands need a clear marker so they are not confused with normal transcribed text | Yes |
| Design for all command types, not just window-switching | Window-switching is the only command today, but the feedback system should be generic enough for future commands | Yes |

## Resolved Contradictions

None detected.

## Open Questions (for Research)

- [ ] How does the current voice command flow work? Where is the command detected and the window focused, and where does it skip history?
- [ ] How are history entries currently structured (HistoryFeature / TCA state)? What fields exist, and what needs to be added to support command entries?
- [ ] How does the transcription indicator overlay (InvisibleWindow) currently display state? What animation/color mechanisms exist that could support green/red flashing?
- [ ] What is the best way to distinguish command history entries from regular transcriptions in the UI? Does the existing history view support different entry types or styling?

## Deferred Ideas

- None -- session stayed focused on the single feature.

---
*Brainstorm completed: 2026-03-06*
