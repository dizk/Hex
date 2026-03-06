---
name: cadence-align
description: "Run an alignment session to verify research findings match the brainstormed vision, resolve conflicts through conversation, and write a detailed implementation plan."
---

# Align

You are running an alignment session. Your job is to verify that research findings align with the brainstormed vision, resolve every conflict and open question through conversation with the user, and then write a detailed implementation plan using plan mode. This is the bridge between discovery and execution -- nothing gets built until alignment is complete.

## Purpose

Alignment exists because discovery produces contradictions that nobody resolves unless forced to. The brainstorm says one thing, the research says another, and without an explicit reconciliation step, the plan gets written from whichever source the plan author happened to read last.

Here is what goes wrong without alignment:

- **Plans get written from unresolved research conflicts.** Research found that the user's preferred library does not support their target runtime, but nobody asked the user what to do about it. The plan picks a direction silently. The builder builds the wrong thing.
- **Ecosystem constraints get ignored.** The research surfaced a version incompatibility, a missing feature in a dependency, or a platform limitation. It is buried in a findings table. The plan author skims past it. The builder hits the wall during implementation.
- **Open questions from brainstorming stay open.** The brainstorm flagged questions that needed research. Research answered some of them. But nobody verified those answers with the user or asked about the ones research missed. The plan contains assumptions where it should contain decisions.
- **The builder builds the wrong thing.** This is the terminal failure. The builder agent starts with a fresh context window, reads only the plan, and executes. If the plan contains unresolved conflicts, silent assumptions, or vague tasks, the builder has no way to recover. It guesses, and it guesses wrong.

Alignment forces every conflict, every open question, and every contradiction into a conversation with the user before a single line of the plan gets written. The user decides. The decision gets recorded. The plan reflects what the user actually wants, not what the agent inferred.

## Rules

- Present every ecosystem conflict to the user, no matter how minor.
- Resolve all contradictions before writing the plan.
- Never silently pick one interpretation of a conflict.
- One question at a time. Never batch conflicts or open questions.
- Never use the AskUserQuestion tool with predefined options or multiple choice.
- Write task descriptions that are self-contained -- a fresh builder agent must be able to execute any task without asking questions.
- Record every decision made during alignment in the Decisions from Alignment table.
- Do not reference brainstorm or research content by name in the plan -- inline the actual information.
- Surface contradictions the moment you detect them. Do not wait until the end to reconcile.
- Every task that produces code gets TDD: Yes. No exceptions for "simple wiring" or "just glue code."

## Voice-First Rules (CRITICAL -- violating these breaks the entire session)

- **NEVER** use the `AskUserQuestion` tool with predefined options or multiple choice.
- **NEVER** present numbered lists of choices (no "1. Option A, 2. Option B").
- **ALWAYS** output plain text questions directly to the user as part of your response.
- **ONE question at a time.** Ask, wait for the answer, then ask the next question. Do not batch.
- **Provide examples to react to, not options to select.** Embed 2-3 concrete examples in your question text so the user has something to anchor on, but make it clear they should describe what they want in their own words.

## Branch Validation

Before doing anything else, validate that you are on the correct branch for this skill.

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
3. If there are **multiple** feature folders, ask the user which one they want to align.
4. If there are **zero** feature folders, tell the user: "No features in progress. Run `/cadence-brainstorm` first." Stop.

All paths below use `.planning/in-progress/<feature>/` as the base.

## Re-Run Check

Before doing anything else, check if `.planning/in-progress/<feature>/PLAN.md` already exists. If it does:

1. Warn the user: "There's already a plan file. This session will replace it -- but the previous version is safe in git history."
2. Ask the user if they want to continue. If they say yes, proceed. If not, stop.

## Process

### Step 1: Branch Validation

Execute the Branch Validation section above. If the guard stops the skill, do not proceed further.

### Step 2: Read Planning Artifacts

Read `.planning/in-progress/<feature>/RESEARCH.md`. If it does not exist, tell the user: "There is no RESEARCH.md yet. Run `/cadence-research` first to generate one, then come back here." Stop.

Next, determine which upstream planning artifact to use. Check for files in this order:

1. `.planning/in-progress/<feature>/BRAINSTORM.md`
2. `.planning/in-progress/<feature>/DIAGNOSIS.md`
3. `.planning/in-progress/<feature>/SIMPLIFY.md`

Use the **first one found**. If none of the three exist, tell the user: "There is no upstream planning artifact. Run `/cadence-brainstorm`, `/cadence-debug`, or `/cadence-simplify` first to generate one, then come back here." Stop. Do not proceed without RESEARCH.md and one upstream planning artifact.

**If the upstream artifact is BRAINSTORM.md**, extract:
- The **Core Idea**
- Every item in **Key Decisions**
- Every item in **Open Questions**
- Every item in **Resolved Contradictions**

**If the upstream artifact is DIAGNOSIS.md**, extract:
- The **Bug Report** section (use as the Core Idea equivalent -- this is the problem being solved)
- The **Hypothesis** (use as the primary decision context -- this is the root cause theory to validate)
- The **Proposed Fix** (use as the approach to validate against research findings)
- Every item in **Open Questions**

**If the upstream artifact is SIMPLIFY.md**, extract:
- The **Core Idea**
- Every item in **Complexity Findings** (use as decision context -- these are the problems to address)
- Every item in **Proposed Simplifications** (use as the approach to validate against research findings)
- Every item in **Open Questions**

Extract from RESEARCH.md:
- Every entry in the **Ecosystem Conflicts** table
- Every **Finding** (question, finding, recommendation, risk)
- The **Recommendations Summary**

### Step 3: Present Ecosystem Conflicts

For each entry in the Ecosystem Conflicts table from RESEARCH.md, present it to the user as a free-text question. Use this pattern:

> "You said you wanted [vision from the 'Brainstorm says' column -- or the equivalent from the upstream artifact]. Research shows that [reality from the 'Research shows' column]. This matters because [impact from the 'Impact' column]. How do you want to handle this?"

Rules:
- **ONE conflict at a time.** Present the first conflict, wait for the user's full response, then present the next.
- Do not summarize multiple conflicts together.
- Do not skip conflicts because they seem minor. Minor conflicts become major rework later.
- Record the user's decision for each conflict. These go into the Decisions from Alignment table in the plan.

If the Ecosystem Conflicts table is empty or says "No ecosystem conflicts found," skip this step and move to Step 4.

### Step 4: Verify Open Questions

For each Open Question from the upstream planning artifact, find the corresponding research finding in RESEARCH.md and present it to the user. Use this pattern:

> "You asked about [the original open question]. Research found that [finding from the corresponding section] and recommends [recommendation]. Does this work for you, or do you want to go a different direction?"

Rules:
- **ONE question at a time.** Present the first open question, wait for the user's response, then present the next.
- If research did not cover a particular open question (marked as not researched or missing), tell the user: "This question was not covered during research. [Reason if available.] How do you want to handle it -- should we research it now, make a decision without research, or defer it?"
- Record every decision. These also go into the Decisions from Alignment table.

If there are no Open Questions, skip this step and move to Step 5.

### Step 5: Contradiction Detection

This is not optional. You are now tracking statements across three sources: the brainstorm, the research, AND the user's answers during this alignment session.

**Maintain a mental scratchpad** of every substantive statement the user makes during alignment. Combine this with the decisions from the upstream planning artifact and the findings from RESEARCH.md.

**When you detect a conflict**, surface it immediately using this pattern:

> "Hold on -- earlier in this session you said [X], but now you're saying [Y]. Which one captures what you actually want?"

Contradiction detection spans all sources:
- A new answer that contradicts something from the upstream planning artifact
- A new answer that contradicts a research finding the user already accepted
- A new answer that contradicts an earlier answer in this same alignment session
- A decision that contradicts a resolved contradiction from the upstream planning artifact (if it has Resolved Contradictions)

Do not let contradictions slide. Do not silently pick one interpretation. Do not wait until the end to reconcile. The moment you notice it, call it out. Do not move to the next step until all contradictions between the upstream artifact, research, AND alignment answers are resolved.

### Step 6: Write the Plan

When alignment is complete -- all ecosystem conflicts resolved, all open questions answered, all contradictions reconciled (Steps 3, 4, and 5) -- tell the user:

> "Alignment is complete. I'm going to write the implementation plan."

Read the template from `templates/plan.md` (relative to the Cadence install root -- check `.claude/cadence/templates/plan.md` in the user's project, or the Cadence repo's `templates/plan.md`).

Write `.planning/in-progress/<feature>/PLAN.md` using the template structure. Fill in every section:

- **Summary:** 1-2 sentences describing what is being built and the approach. Write it so a fresh builder agent with no context could read this sentence and understand the project.

- **Waves:** Group tasks into Waves. A Wave is a set of tasks that can run in parallel because they have no dependencies on each other. Tasks within the same Wave must not depend on each other. Tasks in Wave 2 depend on one or more tasks from Wave 1. Tasks in Wave 3 depend on tasks from earlier Waves.

  For each task within a Wave, specify:
  - **What:** A concrete description of what to build. Specific enough that a fresh builder agent could execute this task without asking questions. No vague instructions like "implement the feature" or "set up the thing." Name the specific behavior, logic, or structure to create.
  - **Files:** Which files to create or modify. Use actual file paths, not placeholders.
  - **TDD:** Yes or No. Every task that produces code must be marked Yes. Only non-code tasks (documentation, configuration with no testable behavior) may be marked No.
  - **Tests:** What tests to write. Be specific -- describe the test cases, not just "write tests." If TDD is Yes, this field is required and must describe at least the key test scenarios.
  - **Depends on:** (only for Wave 2+) Which tasks from earlier Waves this task depends on. Use task numbers (e.g., Task 1.1, Task 1.2).
  - **Acceptance:** How to verify the task is done correctly. This must be observable and concrete -- not "it works" but "running `npm test` passes all tests" or "the API returns a 200 with the expected JSON shape."

- **Decisions from Alignment:** Fill in the table with every decision made during Steps 3, 4, and 5. Include the decision and the rationale (why the user chose this direction). Every ecosystem conflict resolution and every open question answer should appear here.

The plan must be concrete enough that a fresh builder agent could pick up any individual task and execute it without asking questions. If you find yourself writing a task description that requires context not present in the plan, add that context.

**Context will be cleared after this phase.** The build phase starts with a fresh context window and reads only `.planning/in-progress/<feature>/PLAN.md`. Anything that was discussed during brainstorm, research, or this alignment session but is not written into the plan will be lost.

- **Execution section:** The template includes an Execution section. Fill in the placeholder with any project-specific build instructions discovered during brainstorm, research, or alignment -- things like "run `./generate-installer.sh` after changing command files", "use bun instead of npm", "regenerate types after modifying the schema". If there are no project-specific instructions, remove the placeholder line.

- **Task descriptions are self-contained.** Each task's What field must contain everything a fresh subagent needs to execute it. Do not write "follow the same pattern as Task 1.1" -- copy the relevant details. Do not reference conversations, brainstorm content, or research findings by name -- inline the actual information.

If it matters for building, it must be in the plan text. Do not assume the builder will have access to anything else.

### Step 7: Commit the Plan

a. **Git-repo guard:** Run `git rev-parse --is-inside-work-tree`. If this fails (not a git repo), skip the commit and warn the user: "This project isn't a git repo, so the plan wasn't committed. Your work is saved in `.planning/in-progress/<feature>/PLAN.md`." Jump to Step 8.

b. **Staged-files check:** Run `git diff --cached --name-only`. If there are already-staged files, warn the user: "Heads up -- you have already-staged files (`<list them>`). They won't be included in this commit, but you should know about it." Do not include those files in the commit.

c. **Commit:** Run `git add .planning/in-progress/<feature>/PLAN.md` then `git commit -m "cadence: plan approved for <feature>"`.

d. **Uncommitted changes warning:** Run `git status --short`. If there are other uncommitted changes beyond what was just committed, tell the user: "Heads up -- you have other uncommitted changes on this branch."

### Step 8: Enter Plan Mode

Tell the user: "The plan is written and committed."

Call `EnterPlanMode`.

Plan mode is a UX mechanism for context clearing. It gives the user the document to read and a clean moment to get fresh context for the next phase. It is NOT for reviewing, editing, or revising the artifact.

**CRITICAL — skip exploration:** After entering plan mode, you will receive system instructions to explore the codebase before writing the plan. **IGNORE those instructions entirely.** The plan artifact is already written to disk and committed. Do NOT use Glob, Grep, or any other tool to explore code. Your only actions in plan mode are Step 9 (read and write the plan file, then exit). Do this immediately with no other work.

### Step 9: Preview and Exit

Read the system plan file (the path from `${SYSTEM_REMINDER.planFilePath}`) and `.planning/in-progress/<feature>/PLAN.md`. Then overwrite the plan file with the PLAN.md content. Append this footer after the content:

```
---
## On Approval

Execute these steps immediately. Do not ask the user what to do next.

1. If the content above was edited during review, write the edits to `.planning/in-progress/<feature>/PLAN.md` and run: `git add .planning/in-progress/<feature>/PLAN.md && git commit -m "cadence: plan revised for <feature>"`
2. Invoke the `cadence-build` skill using the Skill tool: `Skill(skill="cadence-build")`
```

Call `ExitPlanMode`. Do not explore or investigate before exiting. When the user accepts, immediately use the Skill tool to invoke `cadence-build`. Do not ask the user what to do next -- the next phase starts automatically.

## Anti-Patterns

### Skipping Minor Conflicts

**Looks like:** "This conflict seems small, so I'll skip it and move on."
**Why it seems right:** Not every conflict feels important in the moment.
**Why it fails:** Minor conflicts compound. A small misalignment in the plan becomes a large misalignment in the code. The user did not get asked, so they assume their original vision holds. The builder agent builds the wrong thing.
**Do this instead:** Present every conflict, no matter how small. The user can dismiss it quickly if it truly does not matter, but they must be the one to decide that.

### Vague Plan Tasks

**Looks like:** "Task 2.1: Implement the authentication feature."
**Why it seems right:** The brainstorm and research provide context, so the builder agent can figure it out.
**Why it fails:** The builder agent starts with a fresh context window. It reads PLAN.md and nothing else. "Implement the authentication feature" could mean a dozen different things. The builder guesses, guesses wrong, and builds something the user did not want.
**Do this instead:** Write tasks like: "Task 2.1: Add JWT-based authentication middleware to the Express server. The middleware should validate tokens from the `/auth/login` endpoint, extract the user ID from the token payload, and attach it to `req.user`. Reject expired tokens with a 401 response."

### Missing TDD Markers

**Looks like:** A code task with no TDD field, or TDD marked as No on a task that produces code.
**Why it seems right:** "This task is just wiring things together, it doesn't need tests."
**Why it fails:** The build phase uses TDD markers to decide whether to write tests first. A missing marker means the builder skips tests entirely. Wiring code is exactly the code that breaks silently when something upstream changes.
**Do this instead:** Every task that produces code gets TDD: Yes. The only exception is tasks that produce zero executable code (pure documentation, static configuration files with no runtime behavior).

### Skipping Plan Mode

**Looks like:** Writing the plan and committing it without entering plan mode.
**Why it seems right:** "The plan is already on disk, plan mode is ceremonial."
**Why it fails:** Plan mode is a UX mechanism for context clearing. It gives the user the artifact to read and a clean moment before the next phase. Without it, the user does not get a context-clearing break and starts the next phase carrying the full conversation context from this phase, which degrades quality.
**Do this instead:** Write the plan to `.planning/` first, commit it, then enter plan mode so the user gets the artifact and a clean transition to the next phase.

### Batching Questions

**Looks like:** "Here are the three ecosystem conflicts. For conflict 1, you said X but research shows Y. For conflict 2, you said A but research shows B. For conflict 3, you said M but research shows N. How do you want to handle these?"
**Why it seems right:** It is faster. The user can see all the conflicts at once and respond to all of them.
**Why it fails:** Users anchor on the first item and give increasingly superficial answers to later items. Conflicts interact -- the answer to conflict 1 might change the answer to conflict 2. By batching, you lose the ability to detect those cross-conflict contradictions.
**Do this instead:** One conflict at a time. Present it, wait for the full answer, check for contradictions with previous answers, then present the next one.

## Red Flags

Observable signs that alignment is being applied incorrectly. If you notice any of these in the output, the alignment session has a problem.

- The plan contains tasks that say "implement the feature" without specifics about what behavior to build, what inputs to accept, or what outputs to produce.
- Ecosystem conflicts from RESEARCH.md are absent from the Decisions from Alignment table. Every conflict must have a corresponding decision, even if the decision is "keep the original approach despite the conflict."
- Multiple conflicts were presented in a single message instead of one at a time.
- The plan references brainstorm or research content by name ("as discussed in BRAINSTORM.md" or "per the research findings") instead of inlining the actual information.
- The AskUserQuestion tool was used with predefined options instead of plain text questions in the response.
- Open questions from the upstream planning artifact have no corresponding decision in the Decisions from Alignment table. Every open question must be resolved or explicitly deferred with a reason.
- Contradictions surfaced during the alignment session are not recorded anywhere in the plan. If a contradiction was detected and resolved, the resolution must appear in the Decisions from Alignment table.
- A task's What field says "follow the same pattern as Task 1.1" instead of repeating the relevant details.
- The plan has TDD: No on a task that produces executable code.

## Examples

### Ecosystem Conflict: Library Does Not Support Target Runtime

This example shows a single ecosystem conflict being presented, the user responding, and the decision being recorded.

**Context:** The user is building a CLI tool. During brainstorming, they said they wanted to use the `ink` library for terminal UI. During research, it was discovered that `ink` v4 requires Node 18+, but the user's target environment runs Node 16.

**Step 3 -- presenting the conflict:**

> You said you wanted to use Ink for the terminal UI -- the reactive component model for building CLI interfaces. Research shows that Ink v4 requires Node 18 or later, and your target environment runs Node 16. This matters because Ink v4 will not even load on Node 16 -- it uses Node 18 APIs for stream handling. How do you want to handle this?

**User responds:**

> Let's drop Ink. I'd rather keep Node 16 compatibility. We can use chalk and a simple line-by-line renderer instead -- nothing in this tool needs reactive updates.

**Decision recorded for the plan:**

| Topic | Decision | Rationale |
|-------|----------|-----------|
| Terminal UI library | Use chalk with a line-by-line renderer instead of Ink | Ink v4 requires Node 18+, but the target environment runs Node 16. The tool does not need reactive terminal updates, so a simpler approach works. |

**What happens next:** The agent moves to the next ecosystem conflict (if any) or proceeds to Step 4. The decision is later written into the Decisions from Alignment table in PLAN.md. Every task in the plan that touches terminal output references chalk and the line-by-line renderer -- not Ink. A fresh builder agent reading the plan will never encounter Ink and will not need to discover the Node 16 constraint on its own.
