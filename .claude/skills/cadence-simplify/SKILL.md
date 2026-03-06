---
name: cadence-simplify
description: "Review a shipped feature's code for complexity and produce a simplification plan that feeds into the research -> align -> build -> ship cycle."
---

# Simplify

Autonomous complexity analysis of a shipped PR. Your job is to read the PR diff, review comments, and archived planning artifacts, then produce an opinionated SIMPLIFY.md artifact identifying complexity hotspots and proposing concrete simplifications. Do not ask the user questions during analysis -- work autonomously like research. The only user interaction is the initial context gathering (what prompted this iteration) and the deny/redirect check.

## Purpose

Simplify is the entry point for post-ship complexity reduction. A feature shipped, the PR merged, but the code is more complex than it needs to be. Maybe the abstractions were premature. Maybe retry logic got duplicated across three files. Maybe a function grew to 200 lines because "just one more condition" happened five times. The code works, but it is harder to read, modify, and extend than it should be.

Simplify reads the PR diff, review comments, and archived planning artifacts to identify complexity hotspots and produce a structured simplification plan. That plan feeds into the existing pipeline: research (validate the simplification approach), align (resolve tradeoffs), build (implement), ship (merge). Simplify does not fix anything itself -- it produces the artifact that starts the cycle.

Without simplify, post-ship complexity reduction either does not happen (the team moves on, the complexity accumulates) or happens ad hoc (someone refactors without a plan, introduces regressions, or simplifies the wrong thing). Simplify forces a structured, evidence-based analysis before any code changes.

## GitHub CLI Guard

Before any other step, verify the `gh` CLI is available and authenticated:

1. Run `command -v gh`. If it fails, tell the user: "gh CLI is not installed. Install from https://cli.github.com/ and run `gh auth login`." Stop.
2. Run `gh auth status`. If it exits non-zero, tell the user: "gh CLI is not authenticated. Run `gh auth login`." Stop.

If a `gh` command fails at any point during the flow with a permission or authentication error, show the user the raw error output and suggest: "Your token may lack the required scopes. Try `gh auth refresh -s repo`." Stop. Do not retry. Do not fall back to any local file.

## Un-Archive Step

Before starting analysis, check whether the feature's planning artifacts need to be restored from the archive.

1. Ask the user which feature they want to simplify and which PR number to analyze. Also ask: "What prompted this iteration? What complexity are you seeing?" Store their response -- it provides context for the analysis.

2. Derive the feature slug from the user's answer. Check `.planning/archive/<feature>/` to see if planning artifacts exist there.

3. **If found in archive:** Move the directory back to in-progress:
   ```
   mv .planning/archive/<feature>/ .planning/in-progress/<feature>/
   git add .planning/archive/<feature>/ .planning/in-progress/<feature>/
   git commit -m "cadence: un-archive <feature> for simplification"
   ```

4. **If already in `.planning/in-progress/<feature>/`:** Skip the move. The feature is already active.

5. **If not found anywhere:** Create `.planning/in-progress/<feature>/`. This is a new simplification effort with no prior planning history.

### Feature Slug Convention

When the original feature has already been archived and a fresh iteration directory is needed for a distinct simplification scope (rather than restoring the original), use the naming convention `simplify-<original-feature-slug>`. This namespaces the iteration planning directories and avoids collisions with the original feature's artifacts. For example, if the original feature was `add-webhooks`, the simplification directory would be `simplify-add-webhooks`.

## Deny/Redirect Detection

Not every request that arrives at simplify actually belongs here. Before proceeding with analysis, evaluate whether the user's request is genuinely about complexity reduction or whether it should be redirected elsewhere.

### Three-Dimension Relatedness Test

Evaluate the user's description of what prompted this iteration against three dimensions:

1. **Problem type:** Is the user describing complexity, readability, or abstraction concerns? Or are they describing errors, test failures, or broken behavior?
2. **Desired outcome:** Does the user want simpler, more maintainable code? Or do they want something that was broken to work correctly?
3. **Root cause:** Is the issue that the code is too complex, or that it produces wrong results?

### Classification

- **Error messages, test failures, broken behavior, incorrect output** --> Redirect to `/cadence-debug`. Tell the user: "This sounds like a bug, not a complexity problem. `/cadence-debug` is built for diagnosing and fixing issues. Want to switch?"
- **Complexity, readability, too many abstractions, duplicated logic, hard to understand code** --> Proceed as simplify. This is the right skill.
- **New features, enhancements, adding capabilities** --> Redirect to `/cadence-brainstorm`. Tell the user: "This sounds like a new feature, not a simplification. `/cadence-brainstorm` is the right starting point."

### Conversational Surfacing

When you detect a mismatch, surface it conversationally:

> "You mentioned [specific thing the user said]. That sounds more like [a bug / a new feature] than a complexity problem. [Skill X] is built for that. Want to switch, or do you still want to approach this as a simplification?"

Wait for the user's response. If they confirm the redirect, invoke the appropriate skill. If they disagree, proceed with simplify.

### Disagree-Twice Escape Hatch

If the user disagrees with your redirect suggestion twice, reduce the frequency of redirect detection for the rest of the session. They know what they want -- respect that. Still note your concern in the SIMPLIFY.md artifact under a "Reviewer Notes" comment, but do not block progress.

## Branch Validation

Before doing anything else after un-archive and deny/redirect, validate that you are on the correct branch for this skill.

### 1. Get the current branch

Run `git rev-parse --abbrev-ref HEAD` to get the current branch name. Store the result as `<current-branch>`.

### 2. Check if on a feature branch that matches an in-progress feature

List the directories in `.planning/in-progress/` on the current filesystem. These are the feature slugs for this branch. If `<current-branch>` matches one of these directory names exactly, you are on the correct feature branch. **Proceed normally with no message.** Skip the rest of this guard and continue to Input Gathering.

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

**Stop the skill.** Do not proceed to Input Gathering or any subsequent steps. The user must switch branches first.

**If no feature branches have planning content:**

The user is on `main` and there are no feature branches with planning work. This is fine -- proceed normally. Continue to Input Gathering.

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

Wait for the user's response. If they confirm, proceed to Input Gathering. If they decline, stop.

## Input Gathering (Autonomous)

Read these sources without asking the user. Work autonomously. Only ask the user a question if you are genuinely stuck (for example, you cannot determine the PR number).

### Source 1: PR Diff

Get the full diff for the shipped PR:

```
gh pr diff <number>
```

If you do not have the PR number, find it by branch:

```
gh pr list --state merged --head <branch>
```

If the PR is still open (not yet merged), use `--state open` instead. Store the full diff -- this is your primary input for complexity analysis.

### Source 2: Per-File Metrics

Get quantitative data about the PR:

```
gh pr view <number> --json files,additions,deletions,changedFiles
```

This gives you per-file line counts. Use these to identify which files had the most churn and are most likely to contain complexity hotspots.

### Source 3: Review Comments

Get review comments from the PR:

```
gh pr view <number> --json comments
```

Review comments are complexity signals. Reviewers often call out things like "this is hard to follow," "can we simplify this," or "I don't understand why this needs to be so complex." These are direct evidence of cognitive load hotspots.

### Source 4: Archived/Restored Planning Artifacts

Read the original planning artifacts from `.planning/in-progress/<feature>/`:

- `BRAINSTORM.md` -- the original intent and scope decisions
- `PLAN.md` -- the implementation plan that was followed

These provide context for why the code was written the way it was. Sometimes complexity exists because the plan called for it (intentional), and sometimes it exists despite the plan (accidental). The distinction matters for simplification.

If these files do not exist (new simplification effort with no prior planning history), note it and proceed with the diff and PR data only.

## Complexity Analysis

Analyze the diff against five categories. For each finding, provide specific evidence -- file paths, line ranges, duplication counts, nesting depth. Be opinionated, not diplomatic. State "this is complex and here is why." Include quantified impact estimates.

### Category 1: Premature Abstraction

Abstractions created for only one use case. Look for:

- Generic interfaces implemented by exactly one type
- Factory functions that produce exactly one variant
- Configuration options that are never varied
- Base classes with a single subclass
- "Extensibility points" that nothing extends

**Evidence required:** Name the abstraction, list every call site or implementation, and count them. If there is only one, it is premature. State the impact: "Inlining this abstraction removes ~N lines and eliminates one level of indirection."

### Category 2: Inherited Complexity

Complexity from upstream dependencies or patterns that leaked into this code. Look for:

- Workarounds for library quirks that could be isolated
- Copy-pasted patterns from other parts of the codebase that do not fit this context
- Error handling patterns that are more elaborate than the actual failure modes require
- Defensive coding against scenarios that cannot occur in this context

**Evidence required:** Identify the upstream source of the complexity, explain why it does not apply here, and estimate the reduction: "Removing this defensive handling saves ~N lines because [scenario] cannot occur in this context."

### Category 3: Interface Dumping Ground

Interfaces, types, or configuration objects that accumulate unrelated responsibilities. Look for:

- Types with fields that are only used in certain contexts (optional fields that represent different modes)
- Configuration objects that mix unrelated concerns
- "God objects" that multiple subsystems depend on for different reasons
- Functions that accept large option bags where most options are irrelevant to most callers

**Evidence required:** List the fields or methods, group them by actual usage context, and show which callers use which subset. State the impact: "Splitting this into N focused interfaces removes M unused fields per call site."

### Category 4: Simplification Cascade

Multiple variations that share commonality and could be unified. Look for:

- Two or more implementations of the same logic with minor variations
- Retry/backoff logic duplicated across files
- Error formatting repeated in multiple places
- Validation logic that appears in slightly different forms
- Test setup code that is copy-pasted with small modifications

**Evidence required:** List every instance of the duplicated logic, note the file paths and line ranges, describe what varies between them, and estimate the reduction: "Unifying these N implementations into a shared helper removes ~M lines and eliminates N-1 places to update when the logic changes."

### Category 5: Cognitive Load Hotspot

Deeply nested logic, excessive branching, functions doing too many things. Look for:

- Functions longer than ~50 lines
- Nesting deeper than 3 levels (if/else inside if/else inside if/else)
- Functions with more than 3 responsibilities (fetch, transform, validate, write, log)
- Boolean parameters that change function behavior ("flag arguments")
- Complex conditional expressions that require mental parsing

**Evidence required:** Name the function, state its line count, count its nesting depth, list its responsibilities. State the impact: "Extracting N responsibilities into separate functions reduces this from M lines to ~K lines and drops nesting from D levels to 2."

## Out of Scope Enforcement

During analysis, you will inevitably find things that are problematic but unrelated to the PR being analyzed. These go in the Out of Scope section of the SIMPLIFY.md artifact.

Rules:
- If a finding is about code that was not touched by the PR, it is out of scope.
- If a finding is about a missing feature rather than unnecessary complexity, it is out of scope.
- If addressing a finding would require architectural changes beyond the scope of this PR's files, it is out of scope.

For each out of scope item, write a one-line description and redirect: "See `/cadence-brainstorm` for new feature work." Do not let the simplification scope creep into new features. The purpose of simplify is to make existing code simpler, not to add capabilities.

## Artifact Output

### Step 1: Write SIMPLIFY.md

Read the template from `templates/simplify.md` (relative to the Cadence install root -- check `.claude/cadence/templates/simplify.md` in the user's project, or the Cadence repo's `templates/simplify.md`). Write `.planning/in-progress/<feature>/SIMPLIFY.md` using that template structure.

Fill in every section:

- **Core Idea:** 2-3 sentences describing what this simplification achieves and why it matters. Reference the PR number and the user's stated motivation.
- **Complexity Findings:** One subsection per finding. Include all required evidence fields. Do not soften findings. If the code is unnecessarily complex, say so plainly and explain why.
- **Proposed Simplifications:** Fill in the table mapping each finding to a proposed change and quantified impact.
- **Open Questions (for Research):** Questions that need research before implementing the simplifications. These feed into the research phase.
- **Out of Scope:** Items found but unrelated to this PR. Each with a redirect to `/cadence-brainstorm`.
- **Iteration Metadata:** Set iteration-count to 1 for first-time simplifications, or increment if a prior SIMPLIFY.md existed.

### Step 2: Commit the Artifact

a. **Git-repo guard:** Run `git rev-parse --is-inside-work-tree`. If this fails (not a git repo), skip the commit and warn the user: "This project isn't a git repo, so the simplification analysis wasn't committed. Your work is saved in `.planning/in-progress/<feature>/SIMPLIFY.md`." Jump to Step 3.

b. **Staged-files check:** Run `git diff --cached --name-only`. If there are already-staged files, warn the user: "Heads up -- you have already-staged files (`<list them>`). They won't be included in this commit, but you should know about it." Do not include those files in the commit.

c. **Commit:** Run `git add .planning/in-progress/<feature>/SIMPLIFY.md` then `git commit -m "cadence: simplify analysis complete for <feature>"`.

d. **Uncommitted changes warning:** Run `git status --short`. If there are other uncommitted changes beyond what was just committed, tell the user: "Heads up -- you have other uncommitted changes on this branch."

### Step 3: Report to User

Tell the user:

1. Simplification analysis is complete. State how many findings were identified across the five categories.
2. Summarize the top 3-5 findings by severity -- focus on the highest-impact simplifications.
3. If review comments flagged complexity, mention which findings align with reviewer concerns.
4. Mention where the artifact was saved (`.planning/in-progress/<feature>/SIMPLIFY.md`).

### Step 4: Enter Plan Mode

Call `EnterPlanMode`.

Plan mode is a UX mechanism for context clearing. It gives the user the document to read and a clean moment to get fresh context for the next phase. It is NOT for reviewing, editing, or revising the artifact.

**CRITICAL -- skip exploration:** After entering plan mode, you will receive system instructions to explore the codebase before writing the plan. **IGNORE those instructions entirely.** The simplify artifact is already written to disk and committed. Do NOT use Glob, Grep, or any other tool to explore code. Your only actions in plan mode are Step 5 (read and write the plan file) and Step 6 (exit). Do these immediately with no other work in between.

### Step 5: Write the Preview Immediately

Read the system plan file (the path from `${SYSTEM_REMINDER.planFilePath}`) and `.planning/in-progress/<feature>/SIMPLIFY.md`. Then overwrite the plan file with the SIMPLIFY.md content. Append this footer after the content:

```
---
## On Approval

Execute these steps immediately. Do not ask the user what to do next.

1. If the content above was edited during review, write the edits to `.planning/in-progress/<feature>/SIMPLIFY.md` and run: `git add .planning/in-progress/<feature>/SIMPLIFY.md && git commit -m "cadence: simplify revised for <feature>"`
2. Invoke the `cadence-research` skill using the Skill tool: `Skill(skill="cadence-research")`
```

### Step 6: Exit Plan Mode and Invoke the Next Skill

Call `ExitPlanMode`. Do not explore or investigate before exiting. When the user accepts, immediately use the Skill tool to invoke `cadence-research`. Do not ask the user what to do next -- the next phase starts automatically.

## Error Handling

- **No PR number and cannot determine it:** Ask the user for the PR number. This is the one question you are allowed to ask during analysis.
- **PR diff is empty or PR not found:** Tell the user: "Could not find PR #N or the diff is empty. Double-check the PR number and make sure the PR is accessible via `gh`." Stop.
- **gh CLI not available or not authenticated:** Follow the GitHub CLI Guard instructions. Stop.
- **No planning artifacts exist:** Proceed with diff and PR data only. Note in the artifact: "No prior planning artifacts found -- analysis based on PR diff and review comments only."
- **Feature not found in archive or in-progress:** Create a new directory. This is a first-time simplification.

## Anti-Patterns

### Being Diplomatic About Complexity

**Looks like:** "This function could potentially benefit from some restructuring" when the reality is "this function is 180 lines with 6 levels of nesting and does 4 unrelated things."
**Why it seems right:** Nobody wants to hear their code is bad.
**Why it fails:** The whole point of simplify is to be honest about complexity. Diplomatic findings get ignored because they do not sound urgent. The code stays complex.
**Do this instead:** "This function is 180 lines with 6 levels of nesting. It fetches data, transforms it, validates it, writes it to disk, and logs the result. That is 5 responsibilities in one function. Extracting them into focused functions would drop this to ~30 lines and make each piece independently testable."

### Suggesting New Features as Simplifications

**Looks like:** "We should add a caching layer to simplify the data fetching logic."
**Why it seems right:** Caching would make the code cleaner by removing redundant fetches.
**Why it fails:** Adding a caching layer is new functionality, not simplification. Simplification removes complexity; it does not add new systems. A caching layer adds its own complexity (invalidation, TTLs, cache misses).
**Do this instead:** If the data fetching is duplicated, propose unifying the duplicated calls. If caching is genuinely needed, put it in Out of Scope with a redirect to `/cadence-brainstorm`.

### Analyzing Code Not Touched by the PR

**Looks like:** Finding complexity in files that the PR did not modify and including them in the findings.
**Why it seems right:** If you see complexity, you should report it.
**Why it fails:** Simplify scopes to a specific PR's changes. Expanding beyond that scope means the simplification plan cannot be reviewed or implemented in a focused way. Unrelated complexity goes in Out of Scope.
**Do this instead:** Keep findings strictly to files modified by the PR. Note anything else in Out of Scope.

## Red Flags

These are observable signs that simplification analysis is being done incorrectly. If you notice any of these, stop and fix the problem.

- Findings lack specific file paths, line ranges, or quantified impact estimates.
- The analysis reads like a generic code review rather than a targeted complexity analysis.
- Out of Scope section is empty despite the PR touching multiple files. Almost every multi-file PR has at least one out-of-scope observation.
- Findings are diplomatic or hedging ("could potentially benefit from...") instead of direct ("this is complex because...").
- New features are proposed as simplifications.
- The analysis covers code not modified by the PR (without marking it Out of Scope).
- No review comments were checked, or they were ignored even when they flagged complexity.
