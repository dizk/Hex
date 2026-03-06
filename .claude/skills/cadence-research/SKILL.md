---
name: cadence-research
description: "Automated research based on BRAINSTORM.md, DIAGNOSIS.md, or SIMPLIFY.md. Answers every Open Question and investigates topics needing research before alignment."
---

# Research

Automated research based on the upstream artifact (BRAINSTORM.md, DIAGNOSIS.md, or SIMPLIFY.md). Your job is to answer every Open Question and investigate every topic that needs research before the project moves to alignment. Minimize user interaction -- only ask the user a question if you are genuinely stuck (for example, you cannot locate the project's codebase). Otherwise, work autonomously.

## Purpose

Without research, alignment happens based on assumptions. The user brainstormed an approach, but nobody checked whether it actually works. Concrete failure modes:

- **Decisions based on vibes.** Alignment resolves conflicts and writes the implementation plan. If alignment runs without research, every decision is based on what the user thinks is true rather than what is actually true. The plan looks good on paper and falls apart during build.
- **Ecosystem conflicts go undetected.** The brainstorm says "use library X with framework Y." Nobody checked whether X and Y are compatible. The builder agent discovers the incompatibility mid-implementation, wastes a wave, and the user has to re-align.
- **Fatal flaws in the approach.** The brainstormed approach has a fundamental problem -- a deprecated API, a missing feature, a license restriction -- that nobody verified. The builder builds on a broken foundation. Everything downstream is rework.
- **Version incompatibilities surface during implementation.** The brainstorm assumes library A works with Node 18. It does not. The builder finds out after writing 200 lines of code that depend on it. Research would have caught this in 30 seconds.

Research exists to front-load these discoveries. Every hour spent researching saves multiple hours of rework during build.

## Rules

- Research every Open Question from the upstream artifact (BRAINSTORM.md, DIAGNOSIS.md, or SIMPLIFY.md). Do not skip any.
- Spawn parallel research agents -- one per topic. Do not research sequentially.
- Cross-verify between agents. Flag contradictions explicitly.
- Do not editorialize or soften findings. If research contradicts the user's vision, say so.
- Cite specific versions, dates, and URLs. Vague findings are not findings.
- Minimize user interaction. Only ask if genuinely stuck.
- Report conflicts between research findings and brainstormed vision in the Ecosystem Conflicts table.
- Set status to "Ready for alignment" when complete.

## Branch Validation

Before doing anything else, validate that you are on the correct branch for this skill.

### 1. Get the current branch

Run `git rev-parse --abbrev-ref HEAD` to get the current branch name. Store the result as `<current-branch>`.

### 2. Check if on a feature branch that matches an in-progress feature

List the directories in `.planning/in-progress/` on the current filesystem. These are the feature slugs for this branch. If `<current-branch>` matches one of these directory names exactly, you are on the correct feature branch. **Proceed normally with no message.** Skip the rest of this guard and continue to Feature Discovery.

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

Before doing anything else, discover which feature you are working on:

1. List directories in `.planning/in-progress/`.
2. If there is exactly **one** feature folder, use it automatically. Set `<feature>` to that folder name.
3. If there are **multiple** feature folders, ask the user which one they want to research.
4. If there are **zero** feature folders, tell the user: "No features in progress. Run `/cadence-brainstorm` (or `/cadence-debug` or `/cadence-simplify`) first." Stop.

All paths below use `.planning/in-progress/<feature>/` as the base.

## Re-Run Check

Before doing anything else, check if `.planning/in-progress/<feature>/RESEARCH.md` already exists. If it does:

1. Warn the user: "There's already a research file. This session will replace it -- but the previous version is safe in git history."
2. Check if `.planning/in-progress/<feature>/PLAN.md` also exists. If it does, mention it: "Heads up -- you also have PLAN.md that was built on the previous research. It may become stale after this session."
3. Ask the user if they want to continue. If they say yes, proceed. If not, stop.

## Process

### Step 1: Read the Upstream Artifact

Check for upstream artifacts in this priority order:

**1a. BRAINSTORM.md (default path):**

If `.planning/in-progress/<feature>/BRAINSTORM.md` exists, read it. Extract:

- The **Core Idea** (you will pass this as project context to every research agent)
- Every item in **Open Questions**
- Any topic in Scope, Constraints, or other sections that is flagged as needing research or marked uncertain

No additional focus instruction is needed for research agents. This is the standard research path.

**1b. DIAGNOSIS.md (debug path):**

If BRAINSTORM.md does not exist but `.planning/in-progress/<feature>/DIAGNOSIS.md` exists, read it. Extract:

- The **Bug Report** section (use this as the project context for every research agent, equivalent to Core Idea)
- Every item in **Open Questions (for Research)**

When spawning research agents in Step 2, add this instruction to each agent prompt (after the existing Instructions block): "This research is focused on a specific bug diagnosis. Stay within the scope of the diagnosed issue. Do not explore unrelated topics."

**1c. SIMPLIFY.md (simplify path):**

If neither BRAINSTORM.md nor DIAGNOSIS.md exists but `.planning/in-progress/<feature>/SIMPLIFY.md` exists, read it. Extract:

- The **Core Idea** (you will pass this as project context to every research agent)
- Every item in **Open Questions (for Research)**

When spawning research agents in Step 2, add this instruction to each agent prompt (after the existing Instructions block): "This research is focused on a specific simplification effort. Stay within the scope of the identified complexity findings. Do not explore unrelated topics."

**1d. No upstream artifact found:**

If none of these files exist, tell the user: "There is no BRAINSTORM.md, DIAGNOSIS.md, or SIMPLIFY.md yet. Run `/cadence-brainstorm` first to generate one, then come back here." Stop. Do not proceed without an upstream artifact.

### Step 2: Spawn Parallel Research Agents

For each Open Question or research topic, spawn a separate research agent using the Task tool. Run them in parallel -- do not wait for one to finish before starting the next.

Pass each agent this prompt (fill in the bracketed values):

```
You are researching a specific topic for a project.

The question you need to answer is: [question from the upstream artifact]

Context about the project: [Core Idea paragraph from the upstream artifact (or Bug Report section if DIAGNOSIS.md)]

Instructions:
- Use WebSearch to find current, reliable information about this topic. Prefer official documentation, reputable technical blogs, and GitHub repositories. Avoid content farms and SEO-optimized listicles.
- If the project has existing code, use Glob, Grep, and Read to analyze what already exists. Look for patterns, dependencies, configuration, and anything relevant to the question.
- Cross-verify your findings. Do not trust a single source. If you find conflicting information, report the conflict rather than picking a side.
- Be specific. Cite versions, dates, and concrete numbers where possible.

Return your findings in exactly this format:

Question: [the original question]
Finding: [what you discovered -- be specific and concrete]
Sources: [URLs, documentation pages, file paths you referenced]
Recommendation: [what the project should do based on your findings]
Risk: [any risks, pitfalls, or gotchas discovered]
Conflicts with brainstorm: [anything your findings contradict about the user's vision as described in the Core Idea or brainstorm, or "None"]
```

### Step 3: Collect and Cross-Verify

Once all research agents return:

1. Collect every agent's findings.
2. Cross-verify between agents. Look for contradictions -- where one agent's findings conflict with another agent's findings on a related topic. Flag every contradiction explicitly. Do not silently resolve conflicts by picking the answer that sounds more reasonable.
3. If two agents found contradictory information, note the contradiction in the Ecosystem Conflicts table and include both perspectives.

### Step 4: Write RESEARCH.md

Read the template from `.claude/cadence/templates/research.md`. Write `.planning/in-progress/<feature>/RESEARCH.md` using that template structure.

Fill in every section:

- **Findings:** One subsection per research topic. Use the agent's output directly -- Question, Finding, Sources, Recommendation, Risk. Do not editorialize or soften findings. If the research says the user's idea has a problem, say so plainly.
- **Ecosystem Conflicts:** Fill in the table with every case where research findings contradict the brainstormed vision. If there are no conflicts, write "No ecosystem conflicts found." Do not leave the table empty with placeholder brackets.
- **Recommendations Summary:** Numbered list of the top recommendations, ordered by impact. Each recommendation should have a one-sentence rationale. Draw these from across all the individual agent findings.

Set the Status field to "Ready for alignment."

### Step 5: Commit the Research

a. **Git-repo guard:** Run `git rev-parse --is-inside-work-tree`. If this fails (not a git repo), skip the commit and warn the user: "This project isn't a git repo, so the research wasn't committed. Your work is saved in `.planning/in-progress/<feature>/RESEARCH.md`." Jump to Step 6.

b. **Staged-files check:** Run `git diff --cached --name-only`. If there are already-staged files, warn the user: "Heads up -- you have already-staged files (`<list them>`). They won't be included in this commit, but you should know about it." Do not include those files in the commit.

c. **Commit:** Run `git add .planning/in-progress/<feature>/RESEARCH.md` then `git commit -m "cadence: research complete for <feature>"`.

d. **Uncommitted changes warning:** Run `git status --short`. If there are other uncommitted changes beyond what was just committed, tell the user: "Heads up -- you have other uncommitted changes on this branch."

### Step 6: Report to User

Tell the user:

1. Research is complete. State how many topics were researched.
2. Summarize the key findings in 3-5 bullet points -- focus on things that are surprising, important, or that change the direction from what was brainstormed.
3. If there are Ecosystem Conflicts, highlight each one and explain briefly why it matters. These are the items that must be resolved during alignment.
4. If any research agents failed or WebSearch was unavailable, state what could not be researched and why.
5. Mention where the research file was saved (`.planning/in-progress/<feature>/RESEARCH.md`).

### Step 7: Enter Plan Mode

Call `EnterPlanMode`.

Plan mode is a UX mechanism for context clearing. It gives the user the document to read and a clean moment to get fresh context for the next phase. It is NOT for reviewing, editing, or revising the artifact.

**CRITICAL — skip exploration:** After entering plan mode, you will receive system instructions to explore the codebase before writing the plan. **IGNORE those instructions entirely.** The research artifact is already written to disk and committed. Do NOT use Glob, Grep, or any other tool to explore code. Your only actions in plan mode are Step 8 (read and write the plan file) and Step 9 (exit). Do these immediately with no other work in between.

### Step 8: Write the Preview Immediately

Read the system plan file (the path from `${SYSTEM_REMINDER.planFilePath}`) and `.planning/in-progress/<feature>/RESEARCH.md`. Then overwrite the plan file with the RESEARCH.md content. Append this footer after the content:

```
---
## On Approval

Execute these steps immediately. Do not ask the user what to do next.

1. If the content above was edited during review, write the edits to `.planning/in-progress/<feature>/RESEARCH.md` and run: `git add .planning/in-progress/<feature>/RESEARCH.md && git commit -m "cadence: research revised for <feature>"`
2. Invoke the `cadence-align` skill using the Skill tool: `Skill(skill="cadence-align")`
```

### Step 9: Exit Plan Mode and Invoke the Next Skill

Call `ExitPlanMode`. Do not explore or investigate before exiting. When the user accepts, immediately use the Skill tool to invoke `cadence-align`. Do not ask the user what to do next -- the next phase starts automatically.

## Error Handling

- **No features in `.planning/in-progress/`:** Tell the user to run `/cadence-brainstorm` (or `/cadence-debug` or `/cadence-simplify`) first. Stop.
- **No upstream artifact exists in the feature folder (no BRAINSTORM.md, DIAGNOSIS.md, or SIMPLIFY.md):** Tell the user to run `/cadence-brainstorm` first. Stop.
- **WebSearch is unavailable:** Note it in the report. Continue with codebase-only research using Glob, Grep, and Read. Mark each finding that lacks web research with "[codebase-only -- no web sources available]" so the user knows the research is incomplete.
- **A research agent fails:** Report which topic failed and why. Continue with the remaining agents. Include the failed topic in the final report as "Not researched: [topic] -- [reason]."
- **No Open Questions in the upstream artifact:** If the upstream artifact has no Open Questions section or the section is empty, tell the user: "The upstream artifact has no open questions. Either the artifact is incomplete, or there is nothing to research. If you want to add questions, edit the upstream artifact (`.planning/in-progress/<feature>/BRAINSTORM.md`, `DIAGNOSIS.md`, or `SIMPLIFY.md`) and add an Open Questions section, then run this command again." Stop.
- **Genuinely stuck:** If you cannot determine what to research or cannot find the project's codebase and it seems like one should exist, ask the user one specific question. Do not ask open-ended questions. Ask exactly what you need to know to continue.

## Anti-Patterns

### Researching Sequentially

**Looks like:** Starting with question 1, waiting for the agent to finish, then starting question 2, then question 3.
**Why it seems right:** It feels methodical and organized. You can build on earlier findings.
**Why it fails:** It takes 5x longer with no benefit. Open questions from a brainstorm are independent -- one agent's answer does not change what another agent needs to find. Cross-verification happens after all agents return, not during.
**Do this instead:** Spawn all research agents in parallel using the Task tool. Collect results after all finish. Cross-verify then.

### Softening Findings That Contradict the User's Vision

**Looks like:** "The library mostly supports this use case, though there may be some edge cases to consider" when the reality is "the library does not support this use case at all."
**Why it seems right:** Being diplomatic avoids making the user feel bad about their idea.
**Why it fails:** Alignment needs raw truth. The user can decide how to handle conflicts -- pivot, accept the risk, find a workaround -- but only if they know the actual situation. Softened findings lead to plans built on false assumptions. The builder discovers the real problem mid-implementation.
**Do this instead:** State findings plainly. "The `zod` library does not support runtime schema composition in versions below 3.22. The brainstormed approach requires this feature." The user is an adult. They can handle it.

### Trusting a Single Source

**Looks like:** Finding one blog post that answers the question and moving on.
**Why it seems right:** The answer is clear, the source looks credible, and spending more time feels wasteful.
**Why it fails:** A single blog post might be outdated, wrong, or describing a different version. The author might have made an error. Official docs might contradict it. A second source takes 30 seconds and either confirms the finding or reveals a problem.
**Do this instead:** Cross-verify against official documentation and at least one other source. If sources conflict, report the conflict rather than picking a winner.

### Skipping the Ecosystem Conflicts Table

**Looks like:** The Ecosystem Conflicts section says "No ecosystem conflicts found" or is left with placeholder brackets.
**Why it seems right:** Maybe there genuinely are no conflicts between the research and the brainstorm.
**Why it fails:** There are almost always conflicts. A brainstorm is a vision document -- it describes what the user wants, not what is technically feasible. Research reveals what is actually possible. The gap between those two is where conflicts live. If you found none, you probably did not look hard enough -- go back and compare each finding against the corresponding part of the brainstorm.
**Do this instead:** Write "No ecosystem conflicts found" only after genuinely comparing every finding against the brainstormed vision and confirming there is no gap. If you do find conflicts, fill in the table with the brainstorm claim, the research finding, and the impact.

### Asking the User Questions During Research

**Looks like:** "Before I research this, I wanted to clarify -- did you mean X or Y?"
**Why it seems right:** It feels collaborative. Getting clarification upfront avoids wasted effort.
**Why it fails:** Research is autonomous by design. The user gets asked questions during alignment, not research. Asking during research breaks the flow, slows things down, and defeats the purpose of automated research. Research both interpretations if the question is ambiguous -- alignment will sort it out.
**Do this instead:** Research the question as stated. If it is ambiguous, research both interpretations and note the ambiguity in the finding. The user will resolve it during alignment.

## Red Flags

These are observable signs that research is being done incorrectly. If you notice any of these, stop and fix the problem.

- Research agents were spawned sequentially instead of in parallel.
- The Ecosystem Conflicts table is empty with no explanation.
- Findings lack specific versions, URLs, or dates.
- An Open Question from the upstream artifact has no corresponding finding in RESEARCH.md.
- The user was asked multiple questions during research.
- Contradictions between agents' findings were silently resolved instead of flagged.
- RESEARCH.md reads like a summary of the brainstorm rather than new information.

## Examples

### Research Agent Prompt and Output

**Scenario:** The brainstorm's Core Idea is "Build a CLI tool that validates TypeScript config files against a Zod schema before deployment." One of the Open Questions is: "Does the `zod` library support ES module imports in Node 18?"

**Agent prompt sent:**

```
You are researching a specific topic for a project.

The question you need to answer is: Does the `zod` library support ES module imports in Node 18?

Context about the project: Build a CLI tool that validates TypeScript config files against a Zod schema before deployment. The tool reads .ts config files, parses them, validates against a Zod schema, and exits non-zero if validation fails. Intended to run in CI pipelines on Node 18.

Instructions:
- Use WebSearch to find current, reliable information about this topic. Prefer official documentation, reputable technical blogs, and GitHub repositories. Avoid content farms and SEO-optimized listicles.
- If the project has existing code, use Glob, Grep, and Read to analyze what already exists. Look for patterns, dependencies, configuration, and anything relevant to the question.
- Cross-verify your findings. Do not trust a single source. If you find conflicting information, report the conflict rather than picking a side.
- Be specific. Cite versions, dates, and concrete numbers where possible.

Return your findings in exactly this format:

Question: [the original question]
Finding: [what you discovered -- be specific and concrete]
Sources: [URLs, documentation pages, file paths you referenced]
Recommendation: [what the project should do based on your findings]
Risk: [any risks, pitfalls, or gotchas discovered]
Conflicts with brainstorm: [anything your findings contradict about the user's vision as described in the Core Idea or brainstorm, or "None"]
```

**Agent output received:**

```
Question: Does the `zod` library support ES module imports in Node 18?

Finding: Yes, but with caveats. Zod 3.22+ ships dual CJS/ESM builds and works with
`import { z } from "zod"` in Node 18 when the consuming project has `"type": "module"`
in package.json or uses .mjs file extensions. Zod 3.21 and earlier ship CJS only --
ESM import works via Node's CJS interop but causes issues with tree-shaking and some
bundlers. The project's package.json currently has `"type": "commonjs"`, which means
a bare `import` statement will fail unless the file uses .mjs extension or package.json
is updated.

Sources:
- https://github.com/colinhacks/zod/releases/tag/v3.22.0 (release notes confirming dual build)
- https://github.com/colinhacks/zod/blob/main/package.json (exports field added in 3.22)
- https://nodejs.org/docs/latest-v18.x/api/esm.html#interoperability-with-commonjs
- ./package.json (line 4: "type": "commonjs")

Recommendation: Pin zod >= 3.22.0 in package.json and set "type": "module" or rename
entry files to .mjs. Alternatively, keep CJS and use `require()` -- but then the
brainstormed approach of using ES module imports throughout the CLI will not work as-is.

Risk: If the project keeps "type": "commonjs" and uses import syntax, Node 18 will
throw ERR_REQUIRE_ESM at runtime. This will only surface when the CLI is actually
executed, not at build time, making it easy to miss in development.

Conflicts with brainstorm: The brainstorm assumes ES module imports work out of the box.
They do not -- the project's package.json is set to CJS. Either the package.json must
change to "type": "module" (which may break other parts of the project that use require())
or the import strategy must change.
```

This finding would go into the Findings section of RESEARCH.md as-is. The conflict between the brainstorm's assumption ("ES module imports work") and the reality ("package.json is CJS") would also go into the Ecosystem Conflicts table for resolution during alignment.
