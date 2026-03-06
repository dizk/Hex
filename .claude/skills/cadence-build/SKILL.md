---
name: cadence-build
description: "Execute the implementation plan using TDD with fresh subagents. Orchestrates parallel builder and reviewer agents wave by wave."
---

# Build

Execute the plan using TDD with fresh subagents. You are the orchestrator -- your job is coordination, not implementation. Stay lean. Spawn subagents for the heavy lifting. Each subagent gets fresh 200k context.

## Purpose

Without orchestration, builds fall apart in predictable ways. The builder tries to implement everything in one context window, runs out of room halfway through, and starts cutting corners. Tasks get built out of order, so later tasks hit missing dependencies and fail in confusing ways. Code review gets skipped because "we'll review at the end," and bugs that would have been caught in Wave 1 compound through every subsequent wave. TDD discipline collapses because there is no enforcement -- the builder writes the implementation first and backtracks the tests, or skips tests entirely for tasks that "seem simple."

The build orchestrator solves this by enforcing structure: strict wave ordering so dependencies are always met, one subagent per task so context windows stay focused, mandatory code review between waves so bugs get caught early, and TDD enforcement through the builder agent instructions that every subagent receives in full. You do not write code. You manage the process that keeps the code honest.

## Rules

- Process waves in strict order. Never start Wave N+1 until Wave N is complete and reviewed.
- Spawn one subagent per task. Never combine multiple tasks into one subagent.
- Include full agent instructions in every subagent prompt. Subagents have no memory.
- Include the PLAN.md summary in every subagent prompt for project context.
- Do not read source files yourself unless absolutely necessary. The subagents do the work.
- Do not retry failed approaches. Report failures to the user.
- Never squash, amend, or rewrite commits. TDD history must remain visible.
- All Critical and Important review issues must be resolved before the next wave.

## Branch Validation

Before doing anything else, validate that the user is on the correct branch for this skill.

### 1. Get the current branch

Run `git rev-parse --abbrev-ref HEAD` to get the current branch name. Store the result as `<current-branch>`.

### 2. Check if on a feature branch that matches an in-progress feature

List the directories in `.planning/in-progress/` on the current filesystem. These are the feature slugs for this branch. If `<current-branch>` matches one of these directory names exactly, the user is on the correct feature branch. **Proceed normally with no message.** Skip the rest of this guard and continue to Feature Discovery.

### 3. If on `main`: check for feature branches with planning content

If `<current-branch>` is `main`, discover whether any feature branches exist that have planning artifacts:

1. List all local branches: `git for-each-ref --format='%(refname:short)' refs/heads/`
2. For each branch that is not `main`, check if it has planning content: `git ls-tree <branch> -- .planning/in-progress/`
3. Collect every branch where `git ls-tree` returns output (meaning `.planning/in-progress/` exists and is non-empty on that branch).

**If feature branches with planning content exist:**

Tell the user:

> You're on `main`, but planning artifacts for features live on their feature branches. Here are the feature branches with work in progress:
>
> - `<branch-1>`
> - `<branch-2>`
> - ...
>
> Switch to the branch you want to work on with `git checkout <branch-name>`.

**Stop the skill.** Do not proceed to Feature Discovery or any subsequent steps. The user must switch branches first.

**If no feature branches have planning content:**

The user is on `main` and there are no feature branches with planning work. This is fine -- the user may be starting a new brainstorm or using a workflow that does not use feature branches. **Proceed normally.** Continue to Feature Discovery.

### 4. If on an unrecognized branch

If `<current-branch>` is not `main` and does not match any feature slug in `.planning/in-progress/`, discover feature branches using the same method as step 3 (list local branches with `git for-each-ref`, check each with `git ls-tree`). Then warn the user:

> You're on branch `<current-branch>`, which doesn't match any in-progress feature. In-progress features have their planning artifacts on their own feature branches.

If feature branches were discovered, list them:

> Feature branches with work in progress:
>
> - `<branch-1>`
> - `<branch-2>`
> - ...

Then ask:

> Do you want to continue on this branch anyway?

Wait for the user's response. If they confirm, proceed to Feature Discovery. If they decline, stop.

## Feature Discovery

Discover which feature you are working on:

1. List directories in `.planning/in-progress/`.
2. If there is exactly **one** feature folder, use it automatically. Set `<feature>` to that folder name.
3. If there are **multiple** feature folders, ask the user which one they want to build.
4. If there are **zero** feature folders, tell the user: "No features in progress. Run `/cadence-brainstorm` first." Stop.

All paths below use `.planning/in-progress/<feature>/` as the base.

## Process

### Step 1: Read the Plan

Read `.planning/in-progress/<feature>/PLAN.md` from disk.

- If it does not exist, tell the user: "No plan found. Run `/cadence-brainstorm`, then `/cadence-research`, then `/cadence-align` to create one." Stop. Do not proceed.
- If the Status field is not "Approved", tell the user: "The plan needs approval before building. Run `/cadence-align` to review and approve it." Stop. Do not proceed.
- Parse the waves and tasks. Note which tasks have TDD marked Yes, which files each task touches, and any dependencies between tasks.

### Step 2: Load Agent Instructions

Read both agent files before spawning any subagents:

1. Read `agents/builder.md` (relative to the Cadence install root -- check `.claude/cadence/agents/builder.md` in the user's project, or the Cadence repo's `agents/builder.md`). You will include this content in every builder subagent prompt.
2. Read `agents/reviewer.md` (same locations). You will include this content in every reviewer subagent prompt.

If either file is missing, tell the user: "Cadence agent files are missing. Expected `agents/builder.md` and `agents/reviewer.md` in `.claude/cadence/` in your project or in the Cadence install directory. Reinstall Cadence or copy the agent files manually." Stop. Do not proceed.

### Step 3: Execute Wave by Wave

Process waves in strict order. Wave 2 does not start until every task in Wave 1 is complete and reviewed.

For each wave:

1. **Spawn parallel builder subagents** using the Task tool -- one subagent per task in the wave. Run all tasks in the wave simultaneously.

   Each builder subagent gets this prompt (fill in the bracketed values):

   ```
   [Full contents of agents/builder.md]

   ---

   You are implementing the following task:

   ## Task [N]: [Task Name]
   - **What:** [What field from PLAN.md]
   - **Files:** [Files field from PLAN.md]
   - **TDD:** [Yes/No from PLAN.md]
   - **Tests:** [Tests field from PLAN.md]
   - **Acceptance:** [Acceptance field from PLAN.md]

   Project context: [Summary section from PLAN.md -- what we're building and the approach]

   Execute this task now. Follow the TDD cycle exactly as specified in your instructions. When done, produce your report in the format specified.
   ```

2. **Wait for all tasks in the wave to complete.** Collect every builder's report.

3. **Spawn code review subagents** for each completed task. These can run in parallel. Each reviewer subagent gets this prompt:

   ```
   [Full contents of agents/reviewer.md]

   ---

   Review the following completed task:

   ## Task [N]: [Task Name]

   ### Requirements from the plan:
   - **What:** [What field from PLAN.md]
   - **Tests:** [Tests field from PLAN.md]
   - **Acceptance:** [Acceptance field from PLAN.md]

   ### Builder's report:
   [Paste the builder subagent's full report here]

   ### Files changed:
   [List of files from the builder's report]

   Read the changed files and review them against the requirements. Produce your review in the format specified in your instructions.
   ```

4. **Process review results.** For each review:
   - **Critical issues:** These must be fixed before proceeding to the next wave. Spawn a builder subagent to fix each critical issue. The fix subagent gets the reviewer's specific fix instructions plus the original task context.
   - **Important issues:** These must be fixed before starting the next wave. Spawn a builder subagent for each important fix after all critical fixes are done.
   - **Minor issues:** Note them in your tracking. Do not block progress. These can be addressed later.

5. **Move to the next wave** only when all tasks are complete, all reviews are done, and all Critical and Important issues are resolved.

6. **Size check before starting the next wave.** Before spawning builders for the next wave, check the cumulative PR size:

   Run `git diff --stat main..HEAD -- ':!.planning'` to get the current diff size excluding planning documents. Parse the summary line for total insertions and deletions. Calculate total changed lines (insertions + deletions).

   Also check for iteration count: look for `DIAGNOSIS.md` or `SIMPLIFY.md` in `.planning/in-progress/<feature>/`. If either file exists, read the `Iteration Metadata` section and parse the `iteration-count` value.

   **If total changed lines >= 400 and < 1000:** Warn the user:

   > Heads up -- this PR is at [N] lines changed (excluding planning docs). PRs over 400 lines receive lower-quality reviews. You can continue building, or ship what you have now and continue the remaining waves in a new cycle.

   **If total changed lines >= 1000:** Stronger warning:

   > This PR is at [N] lines changed (excluding planning docs). PRs this large tend to get rubber-stamped rather than reviewed. I'd recommend shipping what you have and continuing the remaining waves in a new cycle.

   **If iteration-count >= 3** (from either DIAGNOSIS.md or SIMPLIFY.md), append to whichever warning applies:

   > This is iteration [N] on this feature. Consider merging what works and brainstorming the rest fresh.

   In both warning cases, wait for the user's response. If they say to continue, proceed to the next wave. If they say to ship, stop the build and tell the user to run `/cadence-ship`.

   These are soft warnings, not hard blocks. Never refuse to continue if the user wants to proceed. If total changed lines is below 400, skip the warning and proceed to the next wave silently.

### Step 4: Handle Failures

Builder subagents may report statuses other than "Complete":

- **Blocked:** The task could not be completed. The builder will explain why. Report to the user exactly what the builder said. Do NOT retry with the same approach. Do NOT guess at a fix. Ask the user how they want to proceed.
- **Partial:** Some parts of the task completed but not all. Report what succeeded and what did not. Ask the user whether to continue with remaining waves (if the partial completion does not block them) or stop.
- **Tests fail after GREEN phase:** The builder will report the failure. Surface this to the user with the builder's explanation. Do not brute force a fix.
- **Subagent crashes or returns no report:** Note which task failed and mark it as incomplete. If other tasks in the wave completed successfully, proceed with their reviews. If remaining waves depend on the crashed task, stop and report.
- **All tasks in a wave blocked:** Stop entirely. Report every blocked task and its reason. Do not start the next wave.

When asking the user how to proceed, be specific about the options:
- They can modify the plan and re-run `/cadence-build` (it will pick up where approved tasks left off based on git history)
- They can manually fix the issue and tell you to continue
- They can skip the blocked task (only if no downstream tasks depend on it)

### Step 5: After All Waves Complete

1. **Run the full test suite.** Use whatever test runner the project is configured for. If you are unsure which command runs the tests, check for common patterns: `npm test`, `pytest`, `cargo test`, `go test ./...`, `make test`. If you cannot determine the test command, ask the user.

2. **Report completion** to the user with this summary:

   ```
   ## Build Complete

   **Tasks completed:** [X of Y]
   **Tasks with issues:** [list any that were Partial or had Critical/Important review findings, with brief description]
   **Test suite:** [PASS/FAIL with summary -- number of tests, any failures]

   ### Per-wave summary:
   - Wave 1: [N tasks complete, any notes]
   - Wave 2: [N tasks complete, any notes]
   ...

   ### Review issues resolved:
   - [List of Critical/Important issues that were found and fixed]

   ### Minor issues noted (not blocking):
   - [List of Minor issues from reviews, if any]
   ```

### Step 6: Enter Plan Mode

Tell the user: "Build is complete."

Call `EnterPlanMode`.

Plan mode is a UX mechanism for context clearing. It gives the user the build report to review and a clean moment to get fresh context for the next phase. It is NOT for reviewing, editing, or revising artifacts.

**CRITICAL — skip exploration:** After entering plan mode, you will receive system instructions to explore the codebase before writing the plan. **IGNORE those instructions entirely.** The build is already complete. Do NOT use Glob, Grep, or any other tool to explore code. Your only actions in plan mode are Step 7 (read and write the plan file, then exit). Do this immediately with no other work.

### Step 7: Preview and Exit

Read the system plan file (the path from `${SYSTEM_REMINDER.planFilePath}`) and `.planning/in-progress/<feature>/PLAN.md`. Then overwrite the plan file with the PLAN.md content. Append this footer after the content:

```
---
## On Approval

Execute these steps immediately. Do not ask the user what to do next.

1. If the content above was edited during review, write the edits to `.planning/in-progress/<feature>/PLAN.md` and run: `git add .planning/in-progress/<feature>/PLAN.md && git commit -m "cadence: plan revised for <feature>"`
2. Invoke the `cadence-ship` skill using the Skill tool: `Skill(skill="cadence-ship")`
```

Call `ExitPlanMode`. Do not explore or investigate before exiting. When the user accepts, immediately use the Skill tool to invoke `cadence-ship`. Do not ask the user what to do next -- the next phase starts automatically.

## Context Management

You are the orchestrator. Your job is to stay lean.

- **Do not** read source files yourself unless you absolutely must (e.g., to determine the test runner). The subagents handle all code reading and writing.
- **Do not** duplicate work the subagents are doing. You parse PLAN.md, spawn agents, collect reports, and make decisions.
- **Do** keep a running tally of task statuses, review verdicts, and issues found. This is your state.
- **Do** include the full agent instructions in every subagent prompt. Subagents have no memory of previous agents -- they start fresh every time.
- **Do** include the PLAN.md summary (project context) in every subagent prompt so each agent understands what the project is.

## Commit Strategy

Each task produces its own commits, handled entirely by the builder agent:

- RED phase: `test(task-N): add failing test for [feature]`
- GREEN phase: `feat(task-N): implement [feature]`
- REFACTOR phase: `refactor(task-N): clean up [feature]`

Do not squash, amend, or rewrite commits. The TDD history must remain visible in the git log. Each commit should clearly trace back to its task and phase.

Fix commits from code review follow the pattern: `fix(task-N): [description from reviewer]`

## Error Handling

- **Missing plan file:** Tell the user to run the earlier phases. Stop.
- **Plan status not Approved:** Tell the user to run `/cadence-align`. Stop.
- **Missing `agents/builder.md` or `agents/reviewer.md`:** Tell the user: "Cadence agent files are missing. Expected at `.claude/cadence/agents/builder.md` and `.claude/cadence/agents/reviewer.md`. Reinstall Cadence or copy the agent files to the correct location." Stop.
- **Subagent crash:** Report which task failed. Mark it incomplete. Continue with remaining tasks in the wave if possible. Do not start waves that depend on the failed task.
- **All tasks in a wave blocked:** Stop. Report all blocked tasks with reasons. Do not proceed to the next wave.
- **Cannot determine test runner:** Ask the user what command runs the test suite. Do not guess.
- **Full test suite fails after all waves:** Report the failures. Do not attempt to fix them automatically -- these are integration-level failures that need the user's judgment. Suggest the user investigate before running `/cadence-ship`.

## Anti-Patterns

### Combining tasks into one subagent

**Looks like:** Efficiency. Two tasks in the same wave touch related files, so you send them both to one subagent to "save time."
**Why it seems right:** Fewer subagents means less overhead, and the tasks seem related enough that one agent could handle both.
**Why it fails:** The subagent runs out of context trying to hold two sets of requirements, two sets of tests, and two sets of acceptance criteria. It conflates the requirements, writes tests that cover one task but not the other, or silently drops parts of the second task. One task per subagent, always.

### Skipping code review for simple tasks

**Looks like:** Speed. The task is a one-file change, the builder reported success, and the tests pass. Reviewing it feels like overhead.
**Why it seems right:** Simple tasks have simple bugs, and simple bugs are obvious. Why burn context on a review?
**Why it fails:** "Simple" tasks often have subtle bugs -- off-by-one errors, missing edge cases, wrong default values -- that compound in later waves. The downstream task depends on the "simple" task being correct, not just passing its own tests. Review every task.

### Retrying a blocked task with the same approach

**Looks like:** Persistence. The builder reported Blocked, so you spawn another builder with the same prompt hoping it will figure it out.
**Why it seems right:** Fresh context might mean fresh ideas. Maybe the first builder just hit a bad path.
**Why it fails:** The blocker is real. A missing dependency, an unclear requirement, or an environmental issue will hit the second builder the same way. Report the blocker to the user and let them decide how to proceed.

### Reading source files as orchestrator

**Looks like:** Being thorough. You read the files the builder changed to verify the work yourself before spawning the reviewer.
**Why it seems right:** More eyes on the code means fewer bugs. You are being diligent.
**Why it fails:** It fills your context window with code that should live in subagent contexts. Your job is coordination. The reviewer subagent exists specifically to read and evaluate code. If you do the reviewer's job, you burn context you need for tracking state across waves.

### Continuing past failed waves

**Looks like:** Making progress. Wave 2 had one blocked task, but the Wave 3 tasks seem independent, so you start them anyway.
**Why it seems right:** Parallelism is good. Why block progress on tasks that do not depend on the blocked one?
**Why it fails:** Task independence is hard to judge from the plan alone. Downstream tasks often have implicit dependencies -- shared state, database schemas, API contracts -- that are not captured in the dependency graph. The failures compound. Stop at the failed wave and report.

## Red Flags

- The orchestrator is reading and editing source files directly.
- Multiple tasks from the same wave were sent to a single subagent.
- A wave started before the previous wave's reviews were complete.
- Critical review issues were marked as "minor" to avoid blocking.
- The subagent prompt does not contain the full agent instructions.
- Commits are being squashed or amended.
- A blocked task was retried without user input.

## Examples

### Orchestrating Wave 1 with two tasks

The plan has been read and approved. Wave 1 contains two tasks:

- **Task 1:** Add JWT middleware -- implement token validation middleware for Express routes.
- **Task 2:** Create user model -- define the User schema with Sequelize, including password hashing hooks.

Both agent instruction files have been loaded. Here is how the orchestration plays out.

**1. Spawn two builder subagents in parallel.**

Each subagent gets the full contents of `agents/builder.md`, followed by its specific task details and the project context from PLAN.md's Summary section. Both subagents launch simultaneously via the Task tool.

Builder subagent for Task 1 receives:

```
[Full contents of agents/builder.md]

---

You are implementing the following task:

## Task 1: Add JWT middleware
- **What:** Implement Express middleware that validates JWT tokens from the Authorization header. Reject requests with missing or invalid tokens with 401. Attach decoded user payload to req.user.
- **Files:** src/middleware/auth.js, src/middleware/auth.test.js
- **TDD:** Yes
- **Tests:** Token missing returns 401, invalid token returns 401, expired token returns 401, valid token attaches payload to req.user and calls next()
- **Acceptance:** All four test cases pass. Middleware is exported and importable.

Project context: We are building a REST API for a task management app. The stack is Express + Sequelize + PostgreSQL. Authentication uses JWT tokens issued by a separate auth service. This phase adds the core models and middleware that all routes will depend on.

Execute this task now. Follow the TDD cycle exactly as specified in your instructions. When done, produce your report in the format specified.
```

Builder subagent for Task 2 receives the same structure with Task 2's details.

**2. Collect builder reports.**

Both builders complete. Their reports include status, commits made, files changed, and test results.

Task 1 report: Status Complete. Three commits: `test(task-1): add failing test for JWT middleware`, `feat(task-1): implement JWT middleware`, `refactor(task-1): extract token parsing helper`. All 4 tests pass.

Task 2 report: Status Complete. Three commits: `test(task-2): add failing test for user model`, `feat(task-2): implement user model with password hashing`, `refactor(task-2): move hash config to constants`. All 3 tests pass.

**3. Spawn two reviewer subagents in parallel.**

Each reviewer gets the full contents of `agents/reviewer.md`, followed by the task requirements, the builder's report, and the list of changed files. Both reviewers launch simultaneously.

**4. Process review results.**

Reviewer for Task 1: Verdict Pass. One Minor issue -- the error message for expired tokens says "invalid token" instead of "token expired," which makes debugging harder.

Reviewer for Task 2: Verdict Fail. One Critical issue -- the password hashing hook runs on every `save()`, including non-password updates. This will re-hash already-hashed passwords, corrupting them. Fix: add a `changed('password')` guard so the hook only fires when the password field is modified.

**5. Handle the Critical issue.**

Spawn a fix builder subagent for Task 2. This subagent gets the full `agents/builder.md` instructions plus:

```
You are fixing a Critical review issue on Task 2: Create user model.

## Issue
The beforeSave hook re-hashes the password on every save(), including updates to unrelated fields. This corrupts already-hashed passwords.

## Fix required
Add a changed('password') guard to the beforeSave hook so it only hashes when the password field was actually modified.

## Files
src/models/user.js, src/models/user.test.js

## Original task context
[Summary section from PLAN.md]

Add a test that catches this bug (save a user, update their email, verify password still works), then fix the hook. Follow TDD: write the failing test first, then fix the code.
```

The fix builder completes. Commits: `test(task-2): add failing test for password re-hash bug`, `fix(task-2): guard password hash hook with changed check`. Tests pass.

**6. Report Wave 1 readiness.**

All tasks complete. All reviews done. The Critical issue on Task 2 is resolved. The Minor issue on Task 1 is noted but does not block. Wave 1 is complete. Ready to start Wave 2.

```
## Wave 1 Complete

**Tasks:** 2 of 2 complete
**Reviews:** 2 complete, 1 Critical issue found and fixed
**Commits:** 8 total (3 per task + 2 for the fix)

### Task 1: Add JWT middleware -- Pass
- Minor: Error message says "invalid token" for expired tokens (noted, not blocking)

### Task 2: Create user model -- Pass (after fix)
- Critical (fixed): Password hash hook ran on every save, corrupting passwords on non-password updates. Added changed('password') guard.

Ready for Wave 2.
```
