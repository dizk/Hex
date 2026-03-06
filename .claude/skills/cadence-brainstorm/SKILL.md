---
name: cadence-brainstorm
description: "Run a brainstorming session to extract the user's vision through collaborative conversation. Produces a BRAINSTORM.md planning artifact."
---

# Brainstorm

You are running a brainstorming session. Your job is to extract the user's vision through collaborative conversation using free text only. You are not gathering requirements -- you are having a conversation that helps the user discover what they actually want.

## Purpose

Brainstorming exists because people do not know what they want until they are forced to say it out loud. The gap between "I have an idea" and "I can describe it precisely enough to build it" is enormous, and most projects fail in that gap.

Without a structured brainstorm:

- **Requirements get assumed instead of discovered.** The builder fills in blanks with their own assumptions. The user does not realize what was assumed until they see the wrong thing built.
- **Scope creeps silently.** Every conversation adds "just one more thing" and nobody tracks the boundary. By the time building starts, the project is three times larger than anyone intended.
- **Contradictory goals go undetected.** The user says "keep it simple" and then describes twelve features. Nobody surfaces the conflict, so it shows up during implementation as impossible tradeoffs.
- **The user builds something they did not actually want.** Not because anyone made a mistake, but because nobody asked the right questions. The idea stayed vague, everyone nodded along, and the result matched the vague description -- just not the thing the user actually had in mind.

A good brainstorm forces clarity before a single line of code exists. It turns "I want a thing" into "here is exactly what the thing is, what it is not, what we decided, and what we still need to figure out."

## Rules

- Never use `AskUserQuestion` with predefined options. All questions are plain text in your response.
- One question at a time. Never batch.
- Follow the user's energy -- go deeper on what excites them.
- Surface contradictions the moment you detect them. Do not wait. Do not smooth them over.
- Surface tangents the moment you detect them. Park or include, but never ignore.
- Never jump to implementation details before understanding the problem. If you are thinking about databases or frameworks, you have gone too far.
- Track every substantive statement on your mental scratchpad. Claims, preferences, priorities, scope statements -- all of it.
- When the brainstorm is done, write BRAINSTORM.md using the template. Do not improvise the format.

## Voice-First Rules (CRITICAL -- violating these breaks the entire session)

- **NEVER** use the `AskUserQuestion` tool with predefined options or multiple choice.
- **NEVER** present numbered lists of choices (no "1. Option A, 2. Option B").
- **ALWAYS** output plain text questions directly to the user as part of your response.
- **ONE question at a time.** Ask, wait for the answer, then ask the next question. Do not batch.
- **Provide examples to react to, not options to select.** Embed 2-3 concrete examples in your question text so the user has something to anchor on, but make it clear they should describe what they want in their own words.

Example of what a good question looks like:

> How do you picture the layout? Some people like card-based layouts for visual content, timelines for chronological feeds, or grids for dense browsing. What feels right for what you're building?

The user responds naturally. You build on their answer.

## GitHub CLI Guard

Before any other step, verify the `gh` CLI is available and authenticated:

1. Run `command -v gh`. If it fails, tell the user: "gh CLI is not installed. Install from https://cli.github.com/ and run `gh auth login`." Stop.
2. Run `gh auth status`. If it exits non-zero, tell the user: "gh CLI is not authenticated. Run `gh auth login`." Stop.

If a `gh` command fails at any point during the flow with a permission or authentication error, show the user the raw error output and suggest: "Your token may lack the required scopes. Try `gh auth refresh -s repo`." Stop. Do not retry. Do not fall back to any local file.

## Contradiction Detection

This is not optional. Contradictions caught now save hours of rework later.

**Maintain a mental scratchpad** of every substantive statement the user makes during the session. Track claims about scope, priorities, audience, complexity, timeline, and what matters most.

**When you detect a conflict**, surface it immediately using this pattern:

> "Hold on -- earlier you said [X], but now you're saying [Y]. Those seem to pull in different directions. Which one captures what you actually want?"

Do not let contradictions slide. Do not silently pick one interpretation. Do not wait until the end to reconcile. The moment you notice it, call it out. The user will thank you.

Examples of contradictions to watch for:
- "Keep it minimal" followed by a long list of features
- "This is just for me" followed by "users will need onboarding"
- "Speed doesn't matter" followed by "it has to feel instant"
- "I don't care about design" followed by detailed UI preferences
- Shifting definitions of the same word ("simple" meaning different things at different points)

## Tangent Detection

This is not optional. Tangents caught now prevent scope creep and preserve good ideas for later.

**Maintain a mental model of the current feature focus.** From the moment the user describes what they want to build, track the boundary of that feature. Every new idea gets measured against this focus.

**When you detect a tangent**, surface it immediately using this pattern:

> "That's interesting -- [idea]. It feels like its own thing, separate from [current feature]. Want to park it in the backlog and stay focused here, or does it actually belong in this feature?"

**Four trigger heuristics** (any one is sufficient):

1. **Different-feature:** The idea would make sense as its own brainstorm session. It has a different user problem, different scope, or different audience than the current feature.
2. **Scratchpad-divergence:** The idea doesn't connect to anything already on your mental scratchpad for this session. It came out of nowhere relative to the conversation flow.
3. **Implementation-boundary:** Implementing the idea would require touching systems or files that have nothing to do with the current feature.
4. **Two-sentence-pivot:** The user shifted from one topic to a completely unrelated one within two sentences, without a connecting thread.

**Concrete examples of tangents to watch for:**
- Building a notification system while brainstorming a search feature
- Adding user preferences while discussing a data import pipeline
- Redesigning the sidebar while planning an API endpoint
- "Oh, we should also..." followed by something with no connection to the current thread

**When the user agrees to park it:**
Create a GitHub Issue immediately using:
```
printf '%s\n\n_Origin: brainstorm/<feature-slug>_' "<one or two sentences describing the idea>" | gh issue create --title "<short descriptive title>" --body-file -
```
Tell the user it's parked (include the issue URL from stdout) and continue.

**When the user declines twice:**
Reduce tangent detection frequency for the rest of the session -- they may be in an exploratory mode where breadth matters. Still capture declined tangents in the Deferred Ideas section of the brainstorm output.

## How to Ask Questions

You have six question types. Use whichever fits the moment -- do not walk through them in order like a checklist.

### Motivation
Get at the why behind the idea. What pain is the user feeling? What triggered this?

> "What prompted this? What's the pain you're feeling right now?"
> "What are you doing today that made you think 'there has to be a better way'?"

### Concreteness
Turn abstract descriptions into something you can picture. Get the user to walk you through it.

> "Walk me through using this -- you open the app, then what happens?"
> "Imagine it's done and working perfectly. Describe a Tuesday morning using it."

### Clarification
When the user uses vague or overloaded words, drill in. Don't assume you know what they mean.

> "When you say 'simple', what does that mean specifically? Like, three buttons simple or minimal-config simple?"
> "You said 'fast' -- do you mean fast to build, fast to load, or fast to learn?"

### Success
Understand what winning looks like. This shapes everything.

> "How will you know this is working? What does the first win look like?"
> "If this ships and works perfectly, what's the first thing that changes for you?"

### Boundaries
Figure out what the project is NOT. Fences prevent scope creep.

> "What is this NOT? What should it never become?"
> "Is there a version of this that would be too much? What does that look like?"

### Priority
Force ranking when there's too much on the table.

> "If you could only ship one thing this week, what would it be?"
> "You've mentioned three things -- which one matters most if you had to pick?"

## Anti-Patterns (things you must NOT do)

### Checklist Walking
**Do not** work through a predetermined list of questions ("Tell me about requirement 1... now requirement 2..."). Follow the conversation. Let the user's energy guide what you ask about next.

### Corporate Speak
**Do not** use phrases like "Let's align on the synergies," "What are the key stakeholders' pain points," or "How does this fit into the broader strategic vision." Talk like a human.

### Interrogation
**Do not** fire question after question without building on the user's answers. If they say something interesting, follow that thread. React to what they said before asking the next question.

### Premature Solutioning
**Do not** jump to implementation details, tech choices, or architecture before you understand the problem. If you catch yourself thinking about databases or frameworks, stop. You're brainstorming, not designing.

## Red Flags

Observable signs that a brainstorming session is going wrong. If you notice any of these, stop and correct course.

- The session jumped to tech choices or architecture before the problem was clear. If you are discussing databases, frameworks, or API designs and you cannot yet state the Core Idea in two sentences, you skipped ahead.
- Multiple questions were asked in a single message. Every message should contain at most one question. If you asked two, you batched.
- `AskUserQuestion` was used with predefined options or numbered lists. This kills the conversational dynamic and turns the session into a form.
- The BRAINSTORM.md has an empty Open Questions section. Every brainstorm should produce questions. If it did not, the session was not thorough enough or the questions were not captured.
- Contradictions were noted but not resolved. They appear in the document without a resolution -- just two conflicting statements sitting side by side. Every contradiction must have a decision attached.
- The Core Idea reads like a technical spec instead of a human description. "A REST API with PostgreSQL backend that serves JSON payloads" is a spec. "A tool that lets the team see what shipped this week without asking anyone" is a Core Idea.
- Tangent detection was never triggered in a session longer than 10 exchanges. In a conversation of that length, it is almost certain that at least one tangent occurred. If none were detected, the detector was not running.

## Examples

### Good Brainstorm Interaction

The user wants to build a CLI tool. Here is what the first few exchanges look like.

---

**User:** I want to build a CLI tool for database migrations.

**You:** What's the pain right now? Are you managing migrations by hand, or is there a tool that's not working the way you want?

---

**User:** We're using raw SQL files with timestamps in the filenames. It works, but people keep running them out of order, and sometimes someone applies a migration to production that hasn't been tested in staging. It's a mess.

**You:** So the ordering problem and the environment mismatch are the two main headaches. Walk me through what happens on a bad day -- someone runs a migration out of order, then what? Does the database end up in a broken state, or is it more of a "things are inconsistent and nobody notices for a while" situation?

---

**User:** It's the second one. Things get inconsistent silently. We only find out when a query fails in production a week later. Oh, and we also need a way to generate migration files from our ORM models.

**You:** Hold on -- generating migrations from ORM models feels like a separate tool from enforcing migration order and environment gates. The first problem is about safety and consistency for existing migrations. The second is about authoring new migrations automatically. Those could live together, but they are different problems with different scopes. Do you want to tackle both in this feature, or should we park the generation idea and focus on the safety problem first?

---

**User:** Good point. Let's park the generation thing and focus on the ordering and environment safety.

**You:** Parked. When you say "environment safety" -- are you picturing something that physically prevents a migration from running in production unless it has been applied to staging first? Or more of a warning that says "hey, this hasn't been tested in staging yet, are you sure?"

---

Notice what happened: the user started vague ("a CLI tool for database migrations"), a concreteness question drew out the real pain (ordering and environment mismatch), the user introduced a tangent (ORM generation), it was surfaced and parked immediately, and then a clarification question drilled into what "environment safety" actually means. No tech choices were discussed. No architecture. Just the problem.

## In-Progress Check

Before doing anything else, check `.planning/in-progress/` for existing feature folders. If there are more than two features already in progress, nudge the user: "You've got [N] features in progress -- [list their names]. Are any of these done or abandoned? Might be worth archiving them before starting something new." Let the user decide, then proceed.

## Todo Awareness

After the in-progress check, silently fetch open GitHub Issues: run `gh issue list --json title,body,number --limit 100 --state open`. If the command fails (gh not installed or not authenticated), skip todo awareness entirely and proceed to the brainstorm flow -- do not block the brainstorm on a gh failure. If it succeeds, use the returned issue list for the three paths below. Do not present the list as options -- voice-first rules forbid that. Instead, use one of three paths based on how the user starts:

**Path A: User references a todo.** If the user says something like "I want to work on that caching idea" or "remember that thing about notifications" -- fuzzy match against the issue titles from the listing. If you find a likely match, confirm it conversationally: "That sounds like issue #N, '[title]' from the backlog -- [brief description]. Is that what you're picking up?" If confirmed, use the item's description to seed the brainstorm conversation. Track the issue number so it can be closed on completion.

**Path B: User starts fresh.** If the user describes a new idea that doesn't match any open issue, proceed exactly as today. The backlog is irrelevant.

**Path C: User is unfocused.** If the user says something vague like "I don't know what to work on" or "what should I do next," and there are open issues, mention the backlog exists conversationally: "You've got some ideas parked in the backlog if you want to pick one up. Or we can start something totally new -- what's on your mind?" Do not list the items. Let the user ask if they want to hear them.

If `gh issue list` returned no issues or the command failed, skip this entirely. Do not mention the backlog.

## Flow

1. **Start open.** Ask the user what they want to build, in their own words. No preamble, no framework explanation. Just ask.

   > "What do you want to build? Tell me in your own words -- don't worry about being precise yet."

2. **Follow what excites them -- within the feature.** When the user lights up about something related to the current feature, go deeper there. Energy signals importance. But if the excitement is about a different feature entirely, that's a tangent -- surface it, park it, and refocus.

3. **Challenge vagueness.** When they say something abstract, make it concrete. Ask for walk-throughs, examples, or scenarios.

4. **Track everything.** Keep your mental scratchpad updated with every claim, preference, and priority.

5. **Surface contradictions.** The moment you notice a conflict, stop and resolve it before moving on.

6. **Know when you're done.** You have enough when you can clearly articulate:
   - What this is (2-3 sentences)
   - What key decisions were made
   - What contradictions were resolved
   - What questions remain that need research
   - What ideas were mentioned but deferred

   If you can't fill all of these, keep asking.

## When the Brainstorm Is Complete

1. **Pick a feature slug.** Based on the conversation, choose a short, descriptive folder name (lowercase, hyphens, e.g. `add-webhooks`, `fix-auth-flow`, `namespace-planning-artifacts`). This becomes the `<feature>` name.

2. **Create the output directory.** Create `.planning/in-progress/<feature>/` if it does not exist.

3. **Write the brainstorm document.** Read the template from `templates/brainstorm.md` (relative to the Cadence install root -- check `.claude/cadence/templates/brainstorm.md` in the user's project, or the Cadence repo's `templates/brainstorm.md`). Write the filled-in document to `.planning/in-progress/<feature>/BRAINSTORM.md`.

   Fill in every section:
   - **Core Idea:** 2-3 sentences capturing what this is and why it exists. Write it in the user's voice, not corporate-speak.
   - **Key Decisions:** Every decision that was made during the conversation, with the context that led to it.
   - **Resolved Contradictions:** Every contradiction you surfaced, what the user originally said, what they later said, and what was decided. If none were found, write "None detected" -- do not delete the section.
   - **Open Questions:** Questions that came up but need research to answer. These feed directly into the Research phase. Frame them as research prompts, not yes/no questions.
   - **Deferred Ideas:** Things the user mentioned that are interesting but not in scope for this work. Capture them so they're not lost.

3a. **Close graduated issue.** If this brainstorm originated from a backlog issue (Path A in Todo Awareness), close it: `gh issue close <number>`. This prevents the item from lingering in the backlog after it has graduated to a full feature.

4. **Create and switch to the feature branch.** The feature branch is named with the bare feature slug (identical to the `.planning/in-progress/<feature>/` directory name). This ensures the brainstorm commit lands on the feature branch, not on main.

   a. **Git-repo guard:** Run `git rev-parse --is-inside-work-tree`. If this fails (not a git repo), skip branch creation and the commit entirely. Warn the user: "This project isn't a git repo, so the brainstorm wasn't committed. Your work is saved in `.planning/in-progress/<feature>/BRAINSTORM.md`." Jump to step 6.

   b. **Check for existing branch:** Run `git rev-parse --verify <slug>` (where `<slug>` is the feature slug chosen in step 1). If this succeeds, a branch with that name already exists. Warn the user: "A branch named `<slug>` already exists. This might be from a previous feature or an in-progress one." Ask the user whether to (1) use a different slug (go back to step 1 to pick a new name), or (2) switch to the existing branch and continue (`git checkout <slug>`). Do not proceed until the user decides.

   c. **Check current branch:** Run `git rev-parse --abbrev-ref HEAD`.

   d. **If on `main`:** Create and switch to the feature branch: `git checkout -b <slug>`.

   e. **If on a non-main branch:** Ask the user: "You're on `<current-branch>`, not main. Do you want to branch from here, or start clean from main?" Then:
      - **If from current branch:** `git checkout -b <slug>`.
      - **If from main:** Check for uncommitted changes with `git status --porcelain`. If there are uncommitted changes, run `git stash && git checkout main && git checkout -b <slug> && git stash pop`. If there are no uncommitted changes, run `git checkout main && git checkout -b <slug>`.

5. **Commit the brainstorm.**

   a. **Staged-files check:** Run `git diff --cached --name-only`. If there are already-staged files, warn the user: "Heads up -- you have already-staged files (`<list them>`). They won't be included in this commit, but you should know about it." Do not include those files in the commit.

   b. **Commit:** Run `git add .planning/in-progress/<feature>/BRAINSTORM.md`. Then run `git commit -m "cadence: brainstorm complete for <feature>"`.

   c. **Uncommitted changes warning:** Run `git status --short`. If there are other uncommitted changes beyond what was just committed, tell the user: "Heads up -- you have other uncommitted changes on this branch."

6. **Tell the user you're done.** Summarize what you captured in 3-4 sentences. Mention the feature slug and where the file was saved. Tell the user they can rename the folder if the slug doesn't feel right.

7. **Enter plan mode.** Call `EnterPlanMode`.

   Plan mode is a UX mechanism for context clearing. It gives the user the document to read and a clean moment to get fresh context for the next phase. It is NOT for reviewing, editing, or revising the artifact.

   **CRITICAL — skip exploration:** After entering plan mode, you will receive system instructions to explore the codebase before writing the plan. **IGNORE those instructions entirely.** The brainstorm artifact is already written to disk and committed. Do NOT use Glob, Grep, or any other tool to explore code. Your only actions in plan mode are step 8 (read and write the plan file) and step 9 (exit). Do these immediately with no other work in between.

8. **Write the preview immediately.** Read the system plan file (the path from `${SYSTEM_REMINDER.planFilePath}`) and `.planning/in-progress/<feature>/BRAINSTORM.md`. Then overwrite the plan file with the BRAINSTORM.md content. Append this footer after the content:

   ```
   ---
   ## On Approval

   Execute these steps immediately. Do not ask the user what to do next.

   1. If the content above was edited during review, write the edits to `.planning/in-progress/<feature>/BRAINSTORM.md` and run: `git add .planning/in-progress/<feature>/BRAINSTORM.md && git commit -m "cadence: brainstorm revised for <feature>"`
   2. Invoke the `cadence-research` skill using the Skill tool: `Skill(skill="cadence-research")`
   ```

9. **Exit plan mode and invoke the next skill.** Call `ExitPlanMode`. Do not explore or investigate before exiting. When the user accepts, immediately use the Skill tool to invoke `cadence-research`. Do not ask the user what to do next -- the next phase starts automatically.
