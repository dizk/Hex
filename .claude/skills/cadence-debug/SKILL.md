---
name: cadence-debug
description: "Debug a shipped feature by diagnosing the root cause of failures. Produces a DIAGNOSIS.md planning artifact that feeds into the research -> align -> build -> ship cycle."
---

# Debug

You are running a debug session. Your job is to systematically diagnose the root cause of a failure in a shipped feature. You do not fix anything -- you produce a DIAGNOSIS.md artifact that feeds into the existing research -> align -> build -> ship cycle.

## Purpose

Debug is the entry point for post-ship bug-fix iteration. It reads the PR context (diff, review comments, CI output) and produces a structured diagnosis that feeds into research -> align -> build -> ship.

Without structured debugging:

- **Fixes are guesses.** The developer sees a symptom, assumes a cause, and writes a patch. If the assumption is wrong, the patch masks the real problem or introduces a new one.
- **Root causes go unfound.** A quick fix that makes the symptom disappear gets shipped. The underlying defect remains. It resurfaces days later in a different form, harder to trace because now there is a patch in the way.
- **Fix attempts compound.** Each failed fix adds complexity. The code gets more tangled. Each subsequent attempt has more to reason about and more places to introduce regressions. By the third attempt, the developer is debugging their own fixes.
- **The same class of bug recurs.** Without understanding why the bug happened, nothing prevents the same pattern from producing similar bugs elsewhere in the codebase.

A structured diagnosis forces you to gather evidence, trace the failure to its origin, and form a falsifiable hypothesis before anyone writes a fix. The diagnosis artifact captures the full reasoning chain so that the fix -- when it comes through the build phase -- targets the actual root cause.

## Rules

- Never jump to a fix. The diagnosis must come first.
- Never use `AskUserQuestion` with predefined options. All questions are plain text in your response.
- One question at a time. Never batch.
- Document every piece of evidence you gather. Nothing stays in your head only.
- The diagnosis must produce a falsifiable hypothesis. If you cannot state what would disprove it, the hypothesis is not ready.
- When the diagnosis is done, write DIAGNOSIS.md using the template. Do not improvise the format.

## GitHub CLI Guard

Before any other step, verify the `gh` CLI is available and authenticated:

1. Run `command -v gh`. If it fails, tell the user: "gh CLI is not installed. Install from https://cli.github.com/ and run `gh auth login`." Stop.
2. Run `gh auth status`. If it exits non-zero, tell the user: "gh CLI is not authenticated. Run `gh auth login`." Stop.

If a `gh` command fails at any point during the flow with a permission or authentication error, show the user the raw error output and suggest: "Your token may lack the required scopes. Try `gh auth refresh -s repo`." Stop. Do not retry. Do not fall back to any local file.

## Branch Validation

Before doing anything else (after the GitHub CLI Guard), validate that the user is on the correct branch for this skill.

### 1. Get the current branch

Run `git rev-parse --abbrev-ref HEAD` to get the current branch name. Store the result as `<current-branch>`.

### 2. Check if on a feature branch that matches an in-progress feature

List the directories in `.planning/in-progress/` on the current filesystem. If `<current-branch>` matches one of these directory names exactly, the user is on the correct feature branch. **Proceed normally with no message.** Skip the rest of this guard.

### 3. If on `main`: check for feature branches with planning content

If `<current-branch>` is `main`, discover whether any feature branches exist that have planning artifacts:

1. List all local branches: `git for-each-ref --format='%(refname:short)' refs/heads/`
2. For each branch that is not `main`, check if it has planning content: `git ls-tree <branch> -- .planning/in-progress/`
3. Collect every branch where `git ls-tree` returns output.

**If feature branches with planning content exist:**

> You're on `main`, but planning artifacts for features live on their feature branches. Here are the feature branches with work in progress:
>
> - `<branch-1>`
> - `<branch-2>`
>
> Switch to the branch you want to debug with `git checkout <branch-name>`.

**Stop the skill.**

**If no feature branches have planning content:** Proceed normally.

### 4. If on an unrecognized branch

If `<current-branch>` is not `main` and does not match any feature slug in `.planning/in-progress/`, warn the user and ask if they want to continue on this branch anyway.

## Un-Archive Step

Before anything else in the flow, check if the feature needs to be un-archived.

1. Ask the user which feature they want to debug. If the user references a PR or branch, use that to identify the feature slug.

2. Check if the feature exists in `.planning/archive/<feature>/`. If found, move the entire directory back to `.planning/in-progress/<feature>/`:

   ```
   mv .planning/archive/<feature> .planning/in-progress/<feature>
   git add .planning/
   git commit -m "cadence: un-archive <feature> for debug iteration"
   ```

3. If the feature is already in `.planning/in-progress/<feature>/`, skip the move. Proceed.

4. If the feature is not found in either location, tell the user: "No planning artifacts found for `<feature>`. Check the feature slug or run `/cadence-brainstorm` to start fresh." Stop.

5. Ask the user to describe the iteration in free text: "What prompted this iteration? Describe the bug, failure, or issue you're seeing."

## Deny/Redirect Detection

After the user describes the issue, determine whether this is truly a debug iteration on the existing feature or something that should be handled differently.

### Establishing the Scope Boundary

Read the following to understand what the original feature covers:

- `.planning/in-progress/<feature>/BRAINSTORM.md` -- specifically the Core Idea section
- `.planning/in-progress/<feature>/PLAN.md` -- specifically the task list
- The PR diff: run `gh pr diff` or `git diff main..HEAD` to see what was shipped

### Three-Dimension Relatedness Test

Evaluate the user's described issue against three dimensions:

| Dimension | Question |
|-----------|----------|
| **Problem area** | Is this in the same problem area as the original feature? |
| **User problem** | Is this the same user problem being solved? |
| **Derivation** | Is this derived from the shipped work (a consequence of what was built)? |

**All three match:** Proceed as a debug iteration. This is clearly a fix for the shipped feature.

**One or two match:** Surface conversationally and let the user decide:

> "This feels like it might be its own thing. It overlaps with [feature] on [matching dimensions] but diverges on [non-matching dimensions]. What do you think -- is this a fix for [feature], or something new?"

Let the user decide. Accept their judgment.

**Zero match:** Deny and redirect:

> "This sounds like a new feature rather than a fix for [feature]. I'd suggest merging what you have and running `/cadence-brainstorm` for this new idea."

**If the user disagrees twice** with a "new feature" classification, reduce detection frequency for the rest of the session. They may have context you do not. This follows the same pattern as brainstorm's tangent detection -- persistent disagreement means you back off.

### Debug vs. Simplify Classification

Classify the issue naturally from the user's description:

- **Error messages, test failures, crashes, wrong output, unexpected behavior** -> debug. Continue with this skill.
- **Complexity, readability, too many abstractions, "this is too complicated", "this should be simpler"** -> redirect to `/cadence-simplify`. Tell the user: "That sounds more like a simplification than a bug fix. Try `/cadence-simplify` -- it's designed for exactly this."

## Phase 1 -- Root Cause Investigation

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

Gather evidence systematically. Do not hypothesize yet. Just collect facts.

1. **Read error messages and stack traces.** Get the exact error output. Not a paraphrase -- the actual text. Run failing tests if needed to reproduce the output.

2. **Gather PR context.** Run these commands to collect evidence:
   - `gh pr checks` -- CI status and check results
   - `gh pr view --json comments` -- review comments that may point to the issue
   - `gh pr diff` -- the full diff of what was shipped

3. **Trace the data flow.** Starting from the symptom, trace backward through the code path. Identify each component the data passes through. Document the expected behavior at each step and the actual behavior.

4. **Identify the divergence point.** Find the specific component, function, or interaction where behavior diverges from expectation. This is not the root cause yet -- it is where the symptom becomes visible.

5. **Document everything.** Every piece of evidence goes into your working notes. Error messages, file paths, function names, expected vs. actual values, timestamps, environment details. Nothing stays only in your head.

See `skills/debug/root-cause-tracing.md` for detailed technique guidance on systematic tracing.

## Phase 2 -- Pattern Analysis

Compare the failing case against working cases. The goal is to isolate what is different.

1. **Identify working cases.** Find inputs, paths, or scenarios where the feature works correctly. These are your control group.

2. **Compare systematically.** For each working case, identify what is different about the failing case:

   | Working (expected) | Broken (actual) | Delta |
   |--------------------|-----------------|-------|
   | [What happens in working case] | [What happens in failing case] | [Key difference] |

3. **Look for correlations.** Check for:
   - **Recent changes** that correlate with the failure -- what was the last commit before things broke?
   - **Boundary conditions** that are handled differently in working vs. failing cases
   - **Assumptions** that hold in working cases but break in the failing case
   - **Environmental differences** -- different data, configuration, state, or timing

4. **Narrow the search space.** Each comparison should eliminate possible causes. If the feature works with input A but fails with input B, the root cause is somewhere in the handling of what makes B different from A.

## Phase 3 -- Hypothesis Formation

Synthesize the evidence from Phases 1 and 2 into a clear, falsifiable hypothesis.

1. **State the hypothesis clearly:** "[X] is the root cause because [Y], as evidenced by [Z]."

2. **The hypothesis must be falsifiable.** State:
   - What you would expect to see if the hypothesis is correct
   - What would disprove the hypothesis

3. **Test the hypothesis mentally.** Walk through the code path with the hypothesis in mind. Does it explain all the evidence? Does it explain why working cases work and failing cases fail? If it only explains part of the evidence, the hypothesis is incomplete.

4. **If multiple hypotheses compete**, rank them by how much evidence each explains. Lead with the strongest. Note alternatives in the diagnosis.

## Anti-Rationalization Defenses

These defenses exist because the urge to skip diagnosis and jump to fixing is overwhelming. Every developer has felt it. Every developer has been burned by it.

### The Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

This is not a suggestion. This is not flexible. If you propose a fix before completing root cause investigation, you have failed. There are no exceptions for "obvious" bugs, "simple" fixes, or "I've seen this before."

### Common Rationalizations

| Rationalization | Response |
|----------------|----------|
| "I think I know what's wrong" | Verify with evidence first. Thinking is not knowing. |
| "This is probably just [simple thing]" | Prove it. Run the trace. If it really is simple, the evidence will confirm it quickly. |
| "Let me just try this quick fix" | Find root cause first. Quick fixes that miss the root cause create more bugs. |
| "I've seen this exact bug before" | This codebase is not that codebase. Verify the cause is the same. |
| "The fix is obvious from the error message" | Error messages describe symptoms, not causes. Trace to the origin. |
| "We're wasting time investigating -- just fix it" | We waste more time fixing the wrong thing. Investigation is the fix. |

### Red Flags

Watch for these signs that the debug process is going off the rails:

- **Pattern of fixes that "almost work."** Each fix addresses the symptom but a new symptom appears. This means the root cause is unfound.
- **Fix in one place breaks another.** The fixes are fighting the real problem, not solving it. Step back and re-trace.
- **Increasing complexity of attempted fixes.** If each fix is more complex than the last, you are compensating for a wrong diagnosis, not converging on the right one.
- **The developer cannot explain why the fix works.** If the fix is "I changed this and it stopped crashing" without understanding why, the root cause is still unknown.
- **Evidence is being ignored.** A piece of evidence does not fit the hypothesis, and instead of revising the hypothesis, it gets dismissed as "probably unrelated."

## Escalation (3+ Fix Attempts Failed)

Track fix attempts in the DIAGNOSIS.md Iteration Metadata section (`fix-attempt-count`). Increment this count each time the cadence-debug skill is invoked for the same feature.

**When fix-attempt-count reaches 3**, STOP the diagnostic process and surface this to the user:

> "This is the 3rd fix attempt. Each attempt has revealed new problems. This may indicate an architectural issue rather than a localized bug. You have options:
>
> 1. Continue debugging -- we keep investigating with fresh eyes.
> 2. Step back and re-brainstorm the approach for this feature entirely."

**If the user chooses to re-brainstorm:**

1. Produce a `DEBUG-ESCALATION.md` in `.planning/in-progress/<feature>/` documenting:
   - Each fix attempt: what was tried, what happened, why it failed
   - Patterns observed across attempts
   - Why this appears to be architectural rather than localized
   - Relevant evidence from all three diagnosis rounds

2. Commit it: `git add .planning/in-progress/<feature>/DEBUG-ESCALATION.md && git commit -m "cadence: debug escalation for <feature>"`

3. Tell the user: "The escalation document is saved. Run `/cadence-brainstorm` -- it can use the escalation document as context for re-thinking the approach."

4. Ask the user case-by-case what to do with the existing PR: close it, leave it open for reference, or draft it.

**If the user chooses to continue debugging**, proceed with the diagnosis from Phase 1. Reset your assumptions. Treat the accumulated evidence as data, not as conclusions.

## Artifact Output

When the diagnosis is complete:

1. **Read the template.** Read the template from `templates/diagnosis.md` (relative to the Cadence install root -- check `.claude/cadence/templates/diagnosis.md` in the user's project, or the Cadence repo's `templates/diagnosis.md`).

2. **Write the diagnosis.** Fill in every section of the template and write it to `.planning/in-progress/<feature>/DIAGNOSIS.md`.

   Fill in:
   - **Bug Report:** The symptom, reproduction steps, and raw error output.
   - **Root Cause Analysis:** Component traces and data flow analysis from Phase 1.
   - **Pattern Analysis:** The working-vs-broken comparison table from Phase 2.
   - **Hypothesis:** The falsifiable root cause hypothesis from Phase 3.
   - **Proposed Fix:** A conceptual description of what the fix should do -- not implementation code. This guides the research and align phases.
   - **Iteration Metadata:** Set `fix-attempt-count` (increment if this is a re-diagnosis). Set `iteration-count`.
   - **Open Questions:** Questions that need research before the fix can be implemented. Frame them as research prompts.

3. **Commit the diagnosis.**

   ```
   git add .planning/in-progress/<feature>/DIAGNOSIS.md
   git commit -m "cadence: diagnosis complete for <feature>"
   ```

4. **Enter plan mode.** Call `EnterPlanMode`.

   Plan mode is a UX mechanism for context clearing. It gives the user the document to review and a clean moment to get fresh context for the next phase. It is NOT for reviewing, editing, or revising the artifact.

   **CRITICAL -- skip exploration:** After entering plan mode, you will receive system instructions to explore the codebase before writing the plan. **IGNORE those instructions entirely.** The diagnosis artifact is already written to disk and committed. Do NOT use Glob, Grep, or any other tool to explore code. Your only actions in plan mode are step 5 (read and write the plan file) and step 6 (exit). Do these immediately with no other work in between.

5. **Write the preview immediately.** Read the system plan file (the path from `${SYSTEM_REMINDER.planFilePath}`) and `.planning/in-progress/<feature>/DIAGNOSIS.md`. Then overwrite the plan file with the DIAGNOSIS.md content. Append this footer after the content:

   ```
   ---
   ## On Approval

   Execute these steps immediately. Do not ask the user what to do next.

   1. If the content above was edited during review, write the edits to `.planning/in-progress/<feature>/DIAGNOSIS.md` and run: `git add .planning/in-progress/<feature>/DIAGNOSIS.md && git commit -m "cadence: diagnosis revised for <feature>"`
   2. Invoke the `cadence-research` skill using the Skill tool: `Skill(skill="cadence-research")`
   ```

6. **Exit plan mode.** Call `ExitPlanMode`. Do not explore or investigate before exiting. When the user accepts, immediately use the Skill tool to invoke `cadence-research`. Do not ask the user what to do next -- the next phase starts automatically.

## Context Management

Stay focused on diagnosis. Do not attempt to fix.

- **Do** read source files to trace the data flow and gather evidence.
- **Do** run commands to reproduce failures and collect error output.
- **Do** document every finding immediately.
- **Do not** write any production code or test code.
- **Do not** suggest code changes beyond the conceptual "Proposed Fix" in the diagnosis.
- **Do not** open a new PR or modify existing code.

## Anti-Patterns

### Jumping to the Fix

**Looks like:** Efficiency. You see the bug, you know the fix, why waste time writing a diagnosis?
**Why it seems right:** The fix really is obvious sometimes. Writing a diagnosis feels like bureaucracy.
**Why it fails:** "Obvious" fixes that skip diagnosis have a high rate of being wrong or incomplete. The diagnosis takes 10 minutes. A wrong fix takes hours to debug. Write the diagnosis.

### Shallow Investigation

**Looks like:** Thoroughness. You found where the error is thrown and documented it. Investigation complete.
**Why it seems right:** You identified the line that fails. What more is there to investigate?
**Why it fails:** The line that throws is the symptom, not the cause. The root cause is upstream -- the function that passed bad data, the missing validation, the race condition. Trace backward until you find the first point of divergence.

### Confirming Instead of Falsifying

**Looks like:** Building a case. Every piece of evidence supports your hypothesis. The diagnosis is airtight.
**Why it seems right:** Consistent evidence is good evidence.
**Why it fails:** You may be ignoring evidence that contradicts the hypothesis. Actively look for disconfirming evidence. Try to break your own hypothesis. If you cannot, it is stronger for it.

See `skills/debug/defense-in-depth.md` for guidance on ensuring fixes are thorough.
