# Implementation Plan: [Feature/Project Name]

**Date:** [date]
**Based on:** BRAINSTORM.md, RESEARCH.md
**Status:** Approved / Pending approval
**Feature:** <slug>

## Summary
[1-2 sentences: what we're building and the approach]

## Wave 1: [Description]
Independent tasks that can run in parallel.

### Task 1.1: [Task name]
- **What:** [What to build]
- **Files:** [Which files to create/modify]
- **TDD:** Yes/No
- **Tests:** [What tests to write]
- **Acceptance:** [How to verify it works]

### Task 1.2: [Task name]
...

## Wave 2: [Description]
Depends on Wave 1 completion.

### Task 2.1: [Task name]
- **What:** [What to build]
- **Files:** [Which files to create/modify]
- **TDD:** Yes/No
- **Tests:** [What tests to write]
- **Depends on:** Task 1.1, Task 1.2
- **Acceptance:** [How to verify it works]

## Decisions from Alignment
| Decision | Rationale |
|----------|-----------|
| [Choice made during align] | [Why] |

## Execution
This plan is executed using `/cadence-build`. The build phase reads this file and spawns fresh subagents per task. Key details:
- **TDD is enforced.** Every task marked TDD: Yes follows RED → GREEN → REFACTOR. No production code without a failing test first.
- **Fresh subagents.** Each task runs in a fresh 200k context window. Subagents only see this plan and their agent instructions -- they have no memory of the conversation that produced this plan.
- **Wave ordering is strict.** All tasks in a wave must complete and pass code review before the next wave starts.
- **Commit convention:** RED: `test(task-N): ...`, GREEN: `feat(task-N): ...`, REFACTOR: `refactor(task-N): ...`
- **After all waves:** Run the full test suite, then `/cadence-ship` to create a PR.
[Add any project-specific build instructions here -- e.g., "run ./generate-installer.sh after changing command files", "use bun instead of npm", etc.]

---
*Plan created: [date]*
