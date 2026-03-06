---
name: cadence-ship
description: "Create a GitHub pull request from the current branch. Verifies tests pass, generates PR body from planning artifacts, and archives the feature."
---

# Ship

Create a GitHub pull request. That is the only thing this command does. There are no options to merge directly, discard changes, or keep the branch local. The output is a PR URL. Always.

## Purpose

Without ship, PRs get created ad hoc and the quality varies wildly. Here is what goes wrong:

- **No context for reviewers.** Someone runs `gh pr create -t "stuff"` and the reviewer opens a PR with no summary, no explanation of what changed, and no record of what decisions were made. They waste 30 minutes reading diffs trying to figure out what the PR even does, then leave a comment: "what does this do?"
- **Failing tests get shipped to CI.** Someone creates a PR without running tests first. CI fails. The reviewer sees a red build and ignores the PR until it is green. The author force-pushes a fix. The reviewer re-reviews. Two rounds of review for what should have been one.
- **Planning artifacts rot.** Features get shipped but their brainstorm and plan files stay in `.planning/in-progress/` forever. Future `/cadence-status` runs report stale features. Future brainstorm sessions show a cluttered in-progress list. Nobody remembers which features are actually in progress.
- **Inconsistent PR bodies.** Every PR looks different. Some have summaries. Some have test plans. Some have neither. Reviewers cannot develop a reading habit because the format changes every time.

Ship solves all of this by making the PR creation process deterministic: verify tests, read artifacts, generate a structured PR body, create the PR, archive the feature, output the URL.

## Process

### Step 0: Main-Branch Guard

Before anything else, check the current branch:

```
$ git rev-parse --abbrev-ref HEAD
```

**If the result is `main`:** Stop immediately. Tell the user:

> You're on main -- ship works from a feature branch. Switch to the feature branch you want to ship and run `/cadence-ship` again.

Do not proceed to Step 1 or any subsequent step. Ship requires a feature branch.

**If the result is anything other than `main`:** The user is on a feature branch. Proceed to Step 1 without any message or warning.

### Step 1: Verify Tests Pass

Run the project's full test suite. Look for common test runners in this order:

1. Check `package.json` for a `test` script and run `npm test` or the equivalent.
2. Check for `pytest`, `go test`, `cargo test`, `mix test`, `bundle exec rspec`, or whatever the project uses.
3. Check for a `Makefile` with a `test` target.
4. If you cannot identify a test runner, check whether the project has any test files at all (look for files matching `*test*`, `*spec*`, `__tests__/`, etc.).

**If tests fail:** Tell the user exactly which tests failed and stop. Do not create a PR with failing tests. Say: "These tests are failing. Fix them and run `/cadence-ship` again."

**If no test suite or no tests exist:** Warn the user: "This project has no test suite. Proceeding with PR creation, but consider adding tests." Then continue to Step 1.5.

### Step 1.5: Final Size Check

After tests pass, check the total size of the changes being shipped. Run:

```
$ git diff --stat main..HEAD -- ':!.planning'
```

This produces a summary line with total insertions and deletions, excluding planning documents from the count.

**If total changed lines (insertions + deletions) >= 400:** Inform the user:

> This PR is [N] lines changed (excluding planning docs). Just a heads up for your reviewer.

This is informational only. The build skill already gave the user the opportunity to split during the build process. Do not stop, do not ask questions, do not offer to split. Just note the size and proceed to Step 2.

**If total changed lines < 400:** Proceed to Step 2 without any message.

### Step 2: Feature Discovery and Read Planning Artifacts

Discover which feature you are shipping:

1. List directories in `.planning/in-progress/`.
2. If there is exactly **one** feature folder, use it automatically. Set `<feature>` to that folder name.
3. If there are **multiple** feature folders, ask the user which one they want to ship.
4. If there are **zero** feature folders, skip planning artifacts entirely and generate PR from git log.

Read the following files to build the PR body:

- `.planning/in-progress/<feature>/BRAINSTORM.md` -- Extract the **Core Idea** section. This becomes the PR summary and the source for the PR title.
- `.planning/in-progress/<feature>/PLAN.md` -- Extract the task list. Each task becomes a bullet in the "What Changed" section. Extract the "Decisions from Alignment" section for the "Decisions Made" section.
- Run `git log --oneline main..HEAD` (or the appropriate base branch) to get the commit history for this branch.

**If `BRAINSTORM.md` does not exist:** Skip the planning artifacts entirely. Generate the PR title from the branch name or the most recent commit message. Generate the PR body from the git log only.

**If `PLAN.md` does not exist:** Generate the "What Changed" section from the git log instead. Leave the "Decisions Made" section as "See commit history."

### Step 3: Generate PR Body

Read the PR body template from `templates/pr-body.md` (check `.claude/cadence/templates/pr-body.md` in the user's project first, then fall back to the Cadence repo's `templates/pr-body.md`).

Fill in each section:

- **Summary:** From BRAINSTORM.md Core Idea. What this PR delivers, in plain language. If no brainstorm exists, summarize the commit history in 2-3 sentences.
- **What Changed:** From PLAN.md tasks. One bullet per task describing what was built. If no plan exists, one bullet per commit.
- **Decisions Made:** From PLAN.md Decisions from Alignment. Key choices and their rationale. If no plan exists, write "See commit history."
- **Test Plan:** Describe what was tested and how. If TDD was used, state that tests were written first and all pass. If no tests exist, state "No automated tests. Manual verification recommended."

Derive the PR title from the BRAINSTORM.md Core Idea. It must be short, descriptive, and under 70 characters. If no brainstorm exists, derive it from the branch name or the first commit message.

#### Step 3.5: Iteration Context in PR Body

After generating the base PR body, check for iteration artifacts in `.planning/in-progress/<feature>/`:

**If `DIAGNOSIS.md` exists:** This PR is a debug iteration. Read the Hypothesis section from DIAGNOSIS.md and add the following section to the PR body (after the Summary section):

```markdown
## Debug Context
This PR addresses: [Hypothesis from DIAGNOSIS.md]
```

If the Iteration Metadata section in DIAGNOSIS.md has `iteration-count` > 1, append to the Debug Context section: "(Iteration [N])".

**If `SIMPLIFY.md` exists (and DIAGNOSIS.md does not):** This PR is a simplify iteration. Read the Core Idea section from SIMPLIFY.md and add the following section to the PR body (after the Summary section):

```markdown
## Simplification Context
This PR simplifies: [Core Idea from SIMPLIFY.md]
```

If the Iteration Metadata section in SIMPLIFY.md has `iteration-count` > 1, append to the Simplification Context section: "(Iteration [N])".

**If neither exists:** Skip this sub-step entirely. This is a normal feature PR.

### Step 4: Create the PR

1. **Check if the branch has been pushed.** Run `git status` and check if the current branch has an upstream. If not, push with `git push -u origin HEAD`.
2. **Check if `gh` CLI is available.** Run `which gh` or `gh --version`.
3. **Create the PR.** Run `gh pr create` with `--base main` so the PR explicitly targets the main branch. Use `--body-file -` with a single-quoted HEREDOC to avoid shell metacharacter issues (backticks, `$` signs, and other special characters in the PR body):

```
gh pr create --title "<title>" --base main --body-file - <<'EOF'
<generated PR body>
EOF
```

This ensures the PR body is passed via stdin with no shell expansion, which is critical when the body contains code snippets, variable references, or backtick-delimited text from planning artifacts.

**If `gh` CLI is not available:** Tell the user: "The GitHub CLI (`gh`) is not installed. Install it from https://cli.github.com/ and run `/cadence-ship` again. Here is the PR body so you can create the PR manually if you prefer:" Then output the full title and body.

**If `gh pr create` fails:** Show the error to the user. Common issues: not authenticated (tell them to run `gh auth login`), no remote (tell them to add a GitHub remote). Do not silently swallow errors.

### Step 5: Archive the Feature

If a `<feature>` folder was found in `.planning/in-progress/`:

1. Create `.planning/archive/` if it does not exist.
2. Move `.planning/in-progress/<feature>/` to `.planning/archive/<feature>/`.
3. Commit the move: `git add .planning/ && git commit -m "cadence: archive <feature>"`.

### Step 5.5: Continuation Plan for Unfinished Waves

After archiving, check whether the feature's PLAN.md contained waves that were not completed during this build cycle.

**How to detect unfinished waves:**

1. Read the archived PLAN.md from `.planning/archive/<feature>/PLAN.md`.
2. Extract all tasks from all waves (each task has a format like "Task N.M: [description]").
3. Run `git log --oneline main..HEAD` to get the commit history for this branch.
4. For each task in PLAN.md, check if there is a corresponding commit in the log (look for task identifiers like `task-N.M` in commit messages).
5. Any wave where **all** tasks lack corresponding commits is an unfinished wave. Waves where some but not all tasks have commits are considered partially complete -- include the remaining tasks from those waves as well.

**If unfinished waves exist:**

1. **Create a continuation PLAN.md.** Re-create the `.planning/in-progress/<feature>/` directory (yes, the same directory that was just moved to archive). Write a new PLAN.md with:
   - A note at the top: `> Continuation of [feature]. Previous waves shipped in PR #[number].`
   - The same Summary section from the original PLAN.md.
   - Only the unfinished waves, renumbered starting at Wave 1. Renumber tasks accordingly (e.g., if original Wave 3 becomes new Wave 1, Task 3.1 becomes Task 1.1).
   - The full Decisions from Alignment section from the original PLAN.md (preserved verbatim).
   - The original Execution section.

2. **Commit the continuation plan:**
   ```
   $ git add .planning/ && git commit -m "cadence: continuation plan for <feature>"
   ```

3. **Add deferred work to the PR body.** Update the PR that was already created in Step 4 by appending a section. Use `gh pr edit` to add to the body:
   ```markdown
   ## Deferred Work
   The following waves were deferred to keep this PR reviewable:
   - [Wave description: list of deferred task titles]
   - [Wave description: list of deferred task titles]
   ```

4. **Inform the user after the PR URL output (in Step 7).** After showing the PR URL, add:
   > Some planned work was deferred to keep the PR reviewable. The remaining waves are saved in `.planning/in-progress/<feature>/PLAN.md`. Run `/cadence-build` on a new branch to continue.

**If all waves were completed:** Skip this step entirely. Proceed to Step 6.

### Step 6: Clean Up the Feature Branch

After the archive commit, push the branch and the archive commit to the remote (if not already pushed) so the PR includes everything:

```
$ git push
```

Do **not** auto-delete the local branch. The PR has not been merged yet -- deleting the branch now would be premature. Instead, tell the user:

> After the PR is merged, you can delete the local branch with:
> ```
> git checkout main && git branch -d <feature>
> ```

Replace `<feature>` with the actual branch name. This is informational only -- the user decides when to clean up.

### Step 7: Report

Show the PR URL to the user.

Example output:

> PR created: https://github.com/org/repo/pull/42

**If Step 5.5 created a continuation plan:** After the PR URL, add:

> Some planned work was deferred to keep the PR reviewable. The remaining waves are saved in `.planning/in-progress/<feature>/PLAN.md`. Run `/cadence-build` on a new branch to continue.

**Otherwise:** Nothing else. No follow-up questions. No suggestions about what to do next. The PR URL is the final output.

## Rules

- **Always create a PR.** There is no alternative path. No "would you like to merge directly?" No "keep as local branch?" No "discard changes?" The only output is a PR URL.
- **Never suggest merging directly.** If the user asks to merge, respond: "Cadence creates PRs, not merges. Review the PR and merge through your normal process."
- **Never offer to discard changes.** If the user wants to discard, that is their decision to make outside of this command.
- **Never offer to keep changes as a local branch.** The point of shipping is creating a PR.
- **Never create a PR with failing tests.** Tests must pass first. No exceptions.
- **Do not ask the user questions.** This command runs to completion or fails with a clear error. There are no decision points that require user input.

## Anti-Patterns

### Creating a PR with failing tests

**Looks like:** Shipping fast. The tests are "probably fine" or "just flaky" or "I'll fix them after the PR is up."
**Why it seems right:** Getting the PR open early means reviewers can start looking at it sooner.
**Why it fails:** CI will fail. Reviewers will see the red build and either reject the PR or ignore it until it is green. You end up force-pushing a fix, the reviewer re-reviews, and the whole cycle takes longer than if you had just fixed the tests first.
**Do this instead:** Run the full test suite. If tests fail, stop and tell the user exactly what failed. Do not create the PR. Tests must pass first. No exceptions.

### Writing the PR body from memory instead of artifacts

**Looks like:** Saving time. You remember what the feature does, so you write a quick summary from what you know.
**Why it seems right:** The brainstorm and plan are right there in context, you just read them during the session.
**Why it fails:** Memory drifts. You will miss decisions that were made during alignment. You will describe what you think was built instead of what was actually planned and executed. The brainstorm and plan contain the actual decisions, the actual rationale, the actual scope. Use them.
**Do this instead:** Read BRAINSTORM.md and PLAN.md from disk. Extract the Core Idea, the task list, and the Decisions from Alignment. Generate the PR body from those artifacts, not from your understanding of them.

### Skipping the archive step

**Looks like:** A minor housekeeping miss. The PR is created, the URL is output, the job is done.
**Why it seems right:** Archiving is cleanup. The important work -- creating the PR -- is already finished.
**Why it fails:** `.planning/in-progress/` accumulates stale features. Future `/cadence-status` runs report features that are already shipped. Future `/cadence-brainstorm` sessions show a cluttered in-progress list and may nudge the user to archive old features instead of starting new work. The archive step is not optional cleanup -- it is the signal that a feature has left the building.
**Do this instead:** After creating the PR, move `.planning/in-progress/<feature>/` to `.planning/archive/<feature>/` and commit the move. Every time.

### Asking the user questions

**Looks like:** Being collaborative. "Would you like me to include the test plan section?" or "Should I push the branch first?"
**Why it seems right:** It feels polite to check before taking action.
**Why it fails:** Ship is designed to run to completion or fail with a clear error. There are no decision points. If tests fail, stop. If artifacts are missing, fall back to git log. If `gh` is not installed, stop. Every branch in the process has a defined outcome. Asking questions interrupts the flow and creates confusion about whether the user needs to make a decision.
**Do this instead:** Follow the process. If something is wrong, stop and say exactly what is wrong and how to fix it. Do not ask. The only exception is Step 2 when multiple features exist in `.planning/in-progress/` -- that is the one place where the user must choose.

### Offering to merge directly

**Looks like:** Convenience. "The PR is ready -- would you like me to merge it now?"
**Why it seems right:** If the PR looks good, merging it saves a step.
**Why it fails:** Cadence's workflow is PR-based. Review happens on the PR. Merging directly skips review. Even if the author is confident, the PR exists so that someone else (or the author with fresh eyes) can verify the work. Offering to merge undermines the entire point of creating a PR in the first place.
**Do this instead:** Output the PR URL and stop. The user merges through their normal review process.

## Red Flags

These are observable signs that ship was applied incorrectly. If any of these are true after a ship run, something went wrong.

- A PR was created while tests were failing.
- The PR body has no "What Changed" section or it says "various changes."
- Planning artifacts are still in `.planning/in-progress/` after the PR was created.
- The user was asked a question during the ship process (other than which feature to ship when multiple exist).
- The PR title is longer than 70 characters.
- The commit that archives planning artifacts is missing.
- The PR body references the brainstorm or plan file paths instead of inlining the content.

## Examples

### Complete ship run for `add-webhook-notifications`

The user runs `/cadence-ship`. Here is what happens.

**Step 1: Tests pass.**

```
$ npm test

> project@1.0.0 test
> jest --coverage

PASS  tests/webhooks.test.ts
PASS  tests/notifications.test.ts
PASS  tests/api.test.ts

Test Suites:  3 passed, 3 total
Tests:        14 passed, 14 total
```

All tests pass. Proceed to Step 1.5.

**Step 1.5: Final size check.**

```
$ git diff --stat main..HEAD -- ':!.planning'
 6 files changed, 312 insertions(+), 4 deletions(-)
```

312 lines changed -- under 400. No size warning needed. Proceed to Step 2.

**Step 2: Feature discovery and artifact reading.**

```
$ ls .planning/in-progress/
add-webhook-notifications/
```

One feature folder. Use it automatically. Read the artifacts:

`.planning/in-progress/add-webhook-notifications/BRAINSTORM.md` contains:

```
## Core Idea
Add webhook notifications so external services can subscribe to project events
(new deploy, build failure, config change). Users register a URL, pick which
events they care about, and we POST a signed JSON payload when those events fire.
```

`.planning/in-progress/add-webhook-notifications/PLAN.md` contains tasks:

```
### Wave 1
- Task 1.1: Create webhook registration endpoint (POST /webhooks)
- Task 1.2: Add webhook_subscriptions database table

### Wave 2
- Task 2.1: Implement event dispatcher that POSTs to registered URLs
- Task 2.2: Add HMAC-SHA256 payload signing
- Task 2.3: Add retry logic with exponential backoff (3 attempts)
```

And the Decisions from Alignment table:

```
| Decision | Rationale |
|----------|-----------|
| HMAC-SHA256 for signing | Industry standard, supported by all major webhook consumers |
| 3 retries with exponential backoff | Balances reliability with not hammering failing endpoints |
| No fan-out queue for v1 | Synchronous dispatch is fine for <100 subscriptions, revisit if scale demands it |
```

```
$ git log --oneline main..HEAD
a1b2c3d feat(task-2.3): implement retry with exponential backoff
e4f5g6h feat(task-2.2): add HMAC-SHA256 payload signing
i7j8k9l feat(task-2.1): implement event dispatcher
m0n1o2p feat(task-1.2): add webhook_subscriptions table and migration
q3r4s5t feat(task-1.1): create POST /webhooks registration endpoint
u6v7w8x test(task-1.1): add failing tests for webhook registration
```

**Step 3: Generate PR body.**

PR title: `Add webhook notifications for project events`

PR body:

```markdown
## Summary
Adds webhook notifications so external services can subscribe to project events
(new deploy, build failure, config change). Users register a URL, pick which
events they care about, and we POST a signed JSON payload when those events fire.

## What Changed
- Created webhook registration endpoint (POST /webhooks) with URL validation
  and event type selection
- Added webhook_subscriptions database table with migration
- Implemented event dispatcher that POSTs JSON payloads to registered URLs
- Added HMAC-SHA256 payload signing for webhook delivery verification
- Added retry logic with exponential backoff (3 attempts) for failed deliveries

## Decisions Made
- **HMAC-SHA256 for signing:** Industry standard, supported by all major webhook
  consumers.
- **3 retries with exponential backoff:** Balances reliability with not hammering
  failing endpoints.
- **No fan-out queue for v1:** Synchronous dispatch is fine for <100 subscriptions.
  Revisit if scale demands it.

## Test Plan
TDD was used throughout. Tests were written before implementation for each task.
All 14 tests pass across 3 test suites covering webhook registration, event
dispatching, payload signing, and retry behavior.

---
Generated by [Cadence](https://github.com/your-org/cadence)
```

**Step 4: Create the PR.**

```
$ git push -u origin HEAD
$ gh pr create --title "Add webhook notifications for project events" --base main --body-file - <<'EOF'
## Summary
Adds webhook notifications so external services can subscribe to project events...

## What Changed
...

## Test Plan
...

---
Generated by [Cadence](https://github.com/your-org/cadence)
EOF

https://github.com/acme/project/pull/47
```

**Step 5: Archive the feature.**

```
$ mkdir -p .planning/archive
$ mv .planning/in-progress/add-webhook-notifications .planning/archive/add-webhook-notifications
$ git add .planning/ && git commit -m "cadence: archive add-webhook-notifications"
```

**Step 6: Clean up the feature branch.**

```
$ git push
```

> After the PR is merged, you can delete the local branch with:
> ```
> git checkout main && git branch -d add-webhook-notifications
> ```

**Step 7: Report.**

> PR created: https://github.com/acme/project/pull/47
