---
name: cadence-status
description: "Report the current state of the Cadence planning process. Shows which features are in progress, their phase, and what to do next."
---

# Status

You are reporting the current state of the Cadence planning process. Your job is to check which planning artifacts exist, determine where the user is in the workflow, and tell them what to do next -- all in natural conversation. No tables, no bullet lists, no raw git output.

## Purpose

Status exists because people lose track. A feature starts in brainstorm, goes through research and alignment, and somewhere along the way the user forgets which phase they are in. They run `/cadence-build` on a feature that has not been aligned yet. They pick up work on Monday morning and cannot remember whether research was done or just brainstormed.

Without status, these things go wrong:

- The user forgets which phase a feature is in and runs the wrong command. They get an error message instead of forward progress, and they waste a context window figuring out where they left off.
- Stale planning artifacts go undetected. The brainstorm gets revised, but the research was done against the old version. The user builds from an outdated plan and only discovers the mismatch after implementation is underway.
- Features pile up in `.planning/in-progress/` and nobody notices. Three features sit half-finished while the user starts a fourth. Nothing ships.
- Uncommitted planning files get lost when the user switches branches. Hours of brainstorming vanish because the file was never committed.

Status catches all of this. It is the "where am I and what should I do next" command. The most valuable thing it does is staleness detection -- telling you when your plan is built on outdated foundations.

## Rules

- Never present tables, bullet lists, or raw git output. The output is natural conversational sentences, always.
- Speak in natural conversational sentences. Weave information together like you are catching someone up over coffee.
- Lead with the most important information: where the user is and what to do next. Git details and warnings come after.
- Check every in-progress feature for staleness. Compare commit timestamps between upstream and downstream planning files. If BRAINSTORM.md is newer than RESEARCH.md, or if either is newer than PLAN.md, warn the user.
- Warn about uncommitted planning files. If a planning file exists on disk but has never been committed, say so.
- Mention the backlog only if there are open issues. If `gh issue list` returns no issues, say nothing about the backlog.
- Keep it concise. If everything is clean and up to date, a few sentences is enough. Only elaborate when there are warnings, staleness, or something the user needs to act on.

## Voice-First Rules (CRITICAL)

- **NEVER** present tables or bullet lists.
- **NEVER** dump raw git output to the user.
- **ALWAYS** speak in natural, conversational sentences.
- Weave information together like you're catching someone up over coffee.

## GitHub CLI Guard

Before checking the backlog, verify the `gh` CLI is available and authenticated:

1. Run `command -v gh`. If it fails, set a flag to skip backlog checks. Warn the user: "Could not check the backlog -- gh CLI is not available or not authenticated."
2. Run `gh auth status`. If it exits non-zero, set a flag to skip backlog checks. Warn the user: "Could not check the backlog -- gh CLI is not available or not authenticated."

If a `gh` command fails at any point during the flow with a permission or authentication error, show the user the raw error output and suggest: "Your token may lack the required scopes. Try `gh auth refresh -s repo`." Skip the backlog section but continue with the rest of the status report.

## Process

### Step 1: Discover All In-Progress Features (Two-Phase Scan)

Feature discovery happens in two phases. Phase 1 checks the current branch's filesystem. Phase 2 checks all other local branches using git object inspection. Together, they build a complete picture of every in-progress feature across the entire repository.

#### Phase 1: Current Branch (filesystem)

Check if `.planning/in-progress/` exists on the current filesystem and list any feature folders inside it. Also check if `.planning/archive/` exists and list any archived features. Mark every feature found in this phase as a **current-branch feature**.

#### Phase 2: Other Branches (git object inspection)

Run `git rev-parse --is-inside-work-tree` to confirm this is a git repo. If it is not, skip Phase 2 entirely.

Get the current branch name: `git rev-parse --abbrev-ref HEAD`. Store it as `<current-branch>`.

List all local branches: `git for-each-ref --format='%(refname:short)' refs/heads/`

Count the branches (excluding the current branch). Choose the discovery method based on the count:

**If 5 or fewer other branches:** For each branch that is not `<current-branch>`, check if it has `.planning/in-progress/` content:

```
git ls-tree <branch> -- .planning/in-progress/
```

If the command returns output, that branch has planning content. List the feature directories inside it by examining the tree entries. For each feature directory found, record it as an **other-branch feature** and store which branch it lives on.

**If more than 5 other branches:** Use batch existence checks for performance. Construct the object references as `<branch>:.planning/in-progress/` for each non-current branch and pipe them to:

```
git cat-file --batch-check
```

Any reference that returns a valid tree object (not "missing") has planning content. Then use `git ls-tree <branch> -- .planning/in-progress/` only for the branches that passed the batch check to list their feature directories.

**For each other-branch feature found**, read the planning artifacts using `git show`:

```
git show <branch>:.planning/in-progress/<feature>/BRAINSTORM.md
git show <branch>:.planning/in-progress/<feature>/RESEARCH.md
git show <branch>:.planning/in-progress/<feature>/PLAN.md
```

If a `git show` command fails (file does not exist on that branch), that artifact does not exist for that feature. Read the `**Status:**` field from each artifact that does exist.

**Silently skip branches with no planning content.** If `git ls-tree` returns empty output for a branch, do not mention that branch at all. Do not report "no features found on branch X."

#### Early Exit Check

Only after BOTH Phase 1 and Phase 2 have completed, check if any features were found. If Phase 1 found no features on the current filesystem AND Phase 2 found no features on any other branch, and there are no archived features, tell the user:

> "No planning files found. Run `/cadence-brainstorm` to get started."

Stop. Do not proceed.

### Step 2: Report on Each In-Progress Feature

For **current-branch features** (from Phase 1): check which files exist (`BRAINSTORM.md`, `RESEARCH.md`, `PLAN.md`) on the filesystem and read the `**Status:**` field from each.

For **other-branch features** (from Phase 2): you already read the artifacts via `git show` in Phase 2. Use the status fields you extracted there.

#### Recently Shipped Features

After reporting in-progress features, check for recently archived features. Look at `.planning/archive/` directories. For each archived feature, run `git log --format="%ar" -1 -- .planning/archive/<feature>/` to determine when it was archived. If any feature was archived within the last 7 days, mention it conversationally in your report -- for example: "You shipped [feature] [time ago]. If you want to iterate on it -- debug issues or simplify the code -- `/cadence-debug` and `/cadence-simplify` are available."

Only mention features archived within the last 7 days. Older archives are not worth surfacing. Keep it to one sentence per feature, woven naturally into the conversational report. Do not create a separate section or a list for these -- they are part of the same flowing update.

#### Continuation Plans (Deferred Waves)

Also check each in-progress feature for a continuation plan. If `.planning/in-progress/<feature>/PLAN.md` exists, read the first few lines. If the file begins with a "Continuation of" note (indicating deferred waves from a previous ship), mention it conversationally -- for example: "You have deferred waves for [feature] waiting to be built. Run `/cadence-build` to pick up where you left off."

This check applies to current-branch features only (read the file from disk). For other-branch features, use `git show <branch>:.planning/in-progress/<feature>/PLAN.md` and check the beginning of the content. Weave the mention naturally into the report alongside the feature's phase information -- do not create a separate section for it.

### Step 3: Determine Current Phase Per Feature

For each in-progress feature, determine where it is in the workflow and present it conversationally:

- If only BRAINSTORM.md exists: "[feature] has completed brainstorm. Next step is `/cadence-research`."
- If BRAINSTORM.md and RESEARCH.md exist: "[feature] has completed brainstorm and research. Next step is `/cadence-align`."
- If all three exist: "[feature] has a complete plan. Next step is `/cadence-build`."

**For other-branch features**, weave the branch information naturally into the conversational output. For example: "You're also working on add-webhooks over on its own branch -- it's been through brainstorm and research, next step is align." Or: "Over on the retry-logic branch, you've got a complete plan ready for build."

If there are archived features, mention them briefly: "You also have [N] archived features: [names]."

Adapt the phrasing naturally -- do not use these as rigid templates. Read the status fields to add nuance.

### Step 4: Issue Backlog

Run `gh issue list --json title,number,createdAt --limit 100 --state open`. If the command fails, skip this step (the guard already warned the user).

Count the number of returned issues.

- If there are more than 3 issues: mention the count and the 3 most recently created titles. For example: "You've also got 7 ideas in the backlog -- the most recent ones are about [title], [title], and [title]."
- If there are 1-3 issues: mention all titles conversationally. For example: "There's one issue in the backlog about [title]." or "A couple of ideas in the backlog -- [title] and [title]."
- If there are 0 issues: say nothing. Do not mention the backlog at all.

Weave this into the conversational report naturally. Do not use lists or tables.

### Step 5: Git Information

Check if this is a git repo by running `git rev-parse --is-inside-work-tree`. If it is NOT a git repo, skip this step entirely -- do not mention git at all.

If it IS a git repo:

#### For current-branch features:

a. **Commit timestamps:** For each planning file that exists, run `git log --format="%ar" -1 -- .planning/in-progress/<feature>/FILENAME.md`. If the file has been committed, weave the timestamp into your response naturally.

   If the git log returns nothing (file exists but was never committed), note this as part of the uncommitted files check below.

b. **Uncommitted files:** Run `git status --porcelain -- .planning/in-progress/<feature>/`. For any planning files that exist on disk but are not committed, warn the user. **This check applies only to current-branch features.** Everything on other branches in the git object store is committed by definition -- there is no concept of "uncommitted files" on a branch you are not on. Do not run `git status --porcelain` for other-branch features.

c. **Staleness detection:** Compare commit timestamps between planning files within each feature. Run `git log --format="%at" -1 -- .planning/in-progress/<feature>/FILENAME.md` for each committed file. If an upstream file was committed MORE RECENTLY than a downstream file, warn the user:

   - BRAINSTORM.md newer than RESEARCH.md: "BRAINSTORM.md is newer than RESEARCH.md -- you may want to re-run research."
   - BRAINSTORM.md or RESEARCH.md newer than PLAN.md: "The plan may be stale -- the brainstorm or research has been updated since the plan was written."

#### For other-branch features:

a. **Commit timestamps:** For each planning artifact, run `git log <branch> --format="%ar" -1 -- .planning/in-progress/<feature>/FILENAME.md` (note the `<branch>` argument to `git log`). Weave the relative timestamp into the conversational report.

b. **Staleness detection:** Compare commit timestamps between planning files using `git log <branch> --format="%at" -1 -- .planning/in-progress/<feature>/FILENAME.md` for each artifact. The same staleness rules apply: if an upstream file was committed more recently than a downstream file, warn the user. Include the branch context in the warning, e.g., "Over on the add-webhooks branch, the brainstorm was updated after the research was done -- the research might be stale."

c. **No uncommitted files check.** Do not run `git status --porcelain` for other-branch features. Everything on other branches is committed by definition (it lives in the git object store).

### Step 6: Deliver the Report

Combine all information from Steps 2-5 into a single, natural response. Do not present the information in sections or with headers. Weave it together conversationally, leading with the most important information (where they are and what to do next), then adding git context and any warnings.

For features on other branches, integrate them naturally. Do not create separate sections for "current branch features" and "other branch features." Weave them together as part of a single conversational update. The branch context should feel like a natural aside, not a category header.

Keep it concise. If everything is clean and up to date, a few sentences is enough. Only elaborate when there are warnings or staleness issues to surface.

## Ad-Hoc Issue Operations

Users may ask to interact with the backlog outside of brainstorm or status. Handle these naturally:

- **Show:** When the user asks "what's on the backlog" or "show me the issues," run `gh issue list --json title,body,number --state open` and summarize conversationally. Do not dump raw JSON.

- **Add:** When the user says something like "add X to the backlog" or "park this idea," tell them to use `/cadence-note` instead. The note skill handles capture, deduplication, and issue creation.

- **Remove:** When the user says "drop X from the backlog" or "I don't need that anymore," close the issue: `gh issue close <number>`. If you are unsure which issue they mean, list open issues and ask for clarification.

## Anti-Patterns

### Dumping a table of features and statuses

**Looks like:** Being thorough -- presenting a neat table with columns for Feature, Phase, Last Commit, and Next Step.
**Why it seems right:** Tables organize information clearly and let the user scan quickly.
**Why it fails:** The user asked for a status update, not a spreadsheet. Voice-first means conversational. A table forces the reader to parse rows and columns instead of just listening. It also makes every feature look equally important, when usually one feature is the thing that matters right now.
**Do this instead:** Weave the information into natural sentences. Lead with the feature that needs attention most.

### Showing raw git log output

**Looks like:** Being transparent -- pasting commit hashes, dates, and `--porcelain` output so the user can see exactly what git says.
**Why it seems right:** It is technically accurate and the user can verify it themselves.
**Why it fails:** Commit hashes and raw timestamps are noise. The user does not need to know that the last commit was `a3f7b2c`. They need to know the brainstorm was updated two days ago and the research has not been re-run since. Weave the relevant information into natural sentences and leave the hashes behind.
**Do this instead:** Extract the meaningful facts from git (relative timestamps, uncommitted files, staleness) and express them conversationally.

### Reporting on features without checking staleness

**Looks like:** A clean, simple report -- "add-webhooks is in the research phase, next step is align."
**Why it seems right:** It answers the question "where am I" and tells the user what to do next.
**Why it fails:** The most valuable thing status can tell you is when your plan is out of date. If the brainstorm was revised after research was completed, the research is stale and building on it will waste time. Staleness detection is the whole point of having git integration in status.
**Do this instead:** Always compare commit timestamps between upstream and downstream files. If there is a staleness issue, lead with it -- it is more important than the phase report.

### Mentioning the backlog when it is empty

**Looks like:** Being complete -- "You have no backlog items" or "The backlog is empty."
**Why it seems right:** It covers all the bases and the user knows they have not forgotten anything.
**Why it fails:** "You have no backlog items" is noise. Silence means empty. Mentioning an empty backlog wastes the user's attention on something that does not exist.
**Do this instead:** If `gh issue list` returns no open issues, say nothing about the backlog. The user will ask if they want to know.

### Listing every archived feature

**Looks like:** Completeness -- naming every feature that has ever been archived, with dates and summaries.
**Why it seems right:** The user might want to know the full history of what has been shipped.
**Why it fails:** Archived features are done. They are history. A brief mention of the count is enough -- "You have 4 archived features" -- and only if the user is likely to care. Listing them all turns the status report into a history lesson.
**Do this instead:** Mention the count briefly. If the user wants details, they will ask.

## Red Flags

These are observable signs that the status report was done incorrectly. If any of these are true, the output needs to be rewritten.

- The output contains a markdown table.
- The output contains bullet points listing features and their phases.
- Raw git output (commit hashes, `--porcelain` format) is visible in the response.
- Staleness detection was skipped -- no timestamp comparison was performed between planning files within the same feature.
- The backlog was mentioned when there are no open issues.
- The report is longer than 10 sentences when everything is clean and up to date.
- The output says "run git status" or shows the user a command to run instead of doing it.

## Examples

### Scenario 1: Single Feature on Current Branch (Staleness)

The project has one feature in progress: `add-webhooks`. Inside `.planning/in-progress/add-webhooks/`, there are two files: `BRAINSTORM.md` and `RESEARCH.md`. Research was committed 2 days ago. But BRAINSTORM.md was updated more recently -- it was committed yesterday, after the research was already done. This means the research is stale. There are no uncommitted files. There are 2 items parked in the backlog. There are no archived features. No other branches have planning content.

### Good output

"You're working on add-webhooks, which has been through brainstorm and research -- so the next step would normally be `/cadence-align`. But heads up: the brainstorm was updated yesterday, which is more recent than the research from two days ago. The research might be out of date now, so you probably want to re-run `/cadence-research` before moving to alignment.

You've also got a couple of ideas parked in the backlog -- one about rate limiting and one about retry logic."

### Why this works

The report leads with what matters: where the feature is, what to do next, and the staleness warning. The staleness issue is surfaced immediately and the next-step recommendation adjusts accordingly. The backlog is mentioned because it has items, but briefly. There are no tables, no bullet lists, no commit hashes, and no raw git output. The whole thing reads like a person catching you up, not a system generating a report.

### Scenario 2: Features Across Multiple Branches

The user is on the `add-webhooks` branch. `.planning/in-progress/add-webhooks/` has `BRAINSTORM.md` and `RESEARCH.md` on the current filesystem. Another branch `retry-logic` exists and has `.planning/in-progress/retry-logic/BRAINSTORM.md`, `RESEARCH.md`, and `PLAN.md` committed. The backlog has 1 issue about rate limiting.

### Good output

"You're on the add-webhooks branch, which has been through brainstorm and research -- next step is `/cadence-align`. You're also working on retry-logic over on its own branch -- that one has a complete plan and is ready for `/cadence-build`.

There's one idea in the backlog about rate limiting."

### Why this works

Both features are reported in a single conversational flow. The other-branch feature is introduced naturally with "over on its own branch" -- no headers, no separate sections. The branch context is woven in like an aside, not a category.

### Scenario 3: On Main with Features on Feature Branches

The user is on `main`. No `.planning/in-progress/` exists on the current filesystem. Two feature branches exist: `add-webhooks` (brainstorm and research done) and `retry-logic` (only brainstorm done). There are no backlog issues.

### Good output

"You've got two features in progress on their feature branches. Add-webhooks is over on its branch with brainstorm and research complete -- next step there would be `/cadence-align`. Retry-logic is on its own branch too, just through brainstorm so far -- next up is `/cadence-research`.

Switch to a feature branch with `git checkout <branch-name>` to pick up where you left off."

### Why this works

Even though `main` has no planning files, the status report discovers features on other branches and reports them. The "no planning files found" message is suppressed because features do exist -- they are just on other branches. The suggestion to switch branches is helpful without being preachy.
