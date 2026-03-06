# Brainstorm: Voice Commands

**Date:** 2026-03-06
**Status:** Ready for research
**Feature:** voice-commands

## Core Idea

Add voice command support to Hex so that a transcription can be recognized as a command and executed instead of pasted as text. The first command is window focusing -- say "switch to huddle" and Hex finds the matching window (even a specific window within an app, like Slack's huddle window buried behind other Slack windows) and brings it to the front. This solves the pain of alt-tabbing and digging through overlapping windows of the same app.

## Key Decisions

| Decision | Context | Resolved |
|----------|---------|----------|
| Same hotkey for commands and transcription | No separate mode or gesture -- Hex auto-detects whether the transcription is a command or text to paste | Yes |
| Auto-detection, not explicit mode switching | Hex analyzes the transcription after recording and decides if it's a command | Yes |
| False positives are acceptable | The cost of accidentally executing a command is low -- just switch back. Speed matters more than caution | Yes |
| Window-level targeting, not just app-level | The key pain is specific windows (e.g., Slack huddle hidden behind main Slack window), not just switching between apps | Yes |
| Fuzzy matching on window titles | User says natural phrases like "switch to huddle" and Hex matches against window titles like "Slack \| Huddle with Kit" | Yes |
| Use a model for command-to-window matching | Natural language phrasing won't be exact substrings of window titles, so a model handles the fuzzy matching | Yes |
| Try local small LLM first, API as fallback | A local model keeps it instant and offline; API (Grok or similar) is acceptable if local isn't good enough | Yes |
| Window focusing is the only command for now | Scope is intentionally narrow -- one command type done well | Yes |

## Resolved Contradictions

None detected.

## Open Questions (for Research)

- [ ] How does macOS expose the list of all open windows (titles, app names, window IDs)? What APIs or accessibility frameworks are needed? Does the sandbox allow this?
- [ ] What local small LLMs are suitable for command detection and window matching? Research Qwen 3.5, and any models specifically designed for instruction parsing or intent classification
- [ ] How to run a small local LLM on macOS efficiently? What frameworks exist (llama.cpp, MLX, Core ML conversion)?
- [ ] How to bring a specific window to the front on macOS programmatically? What APIs handle window focusing (especially for a specific window within a multi-window app)?
- [ ] What's the best approach for command detection -- should the same model handle both "is this a command?" and "which window?" or should command detection be a simpler heuristic (e.g., starts with "switch to", "open", "go to")?
- [ ] What fast API services (Grok, etc.) would work as a fallback if local models aren't good enough? What's the latency like?
- [ ] What entitlements/permissions does Hex need for window management? Does accessibility access need to be granted?

## Deferred Ideas

- Window arrangement commands (e.g., "tile Chrome and Slack side by side") -- user always forgets the hotkey for this
- Extending the command system beyond window management in the future

---
*Brainstorm completed: 2026-03-06*
