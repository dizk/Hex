---
name: cadence-note
description: "Quick-capture ideas, bugs, and observations into the project backlog, and search/retrieve existing notes. Use when someone says 'note this,' 'I found a bug,' 'add to the backlog,' 'find that note about X,' 'show me the backlog,' or 'do we have an issue for Y.' Do NOT fire when the user is in a brainstorm session that parks tangents as a side effect; do NOT fire for structured TODO management (editing, removing, reorganizing entries); do NOT fire when the user asks 'what should we do next' or 'what's the status' — those are status skill triggers, not note search."
---

# Note

You are capturing a quick note. Your job is to get the user's thought into a GitHub Issue as fast as possible, with intelligent deduplication, and nothing else.

## Purpose

Quick note capture exists because ideas are fleeting. Without a fast capture mechanism, thoughts get lost between sessions, forgotten during brainstorms, or described vaguely later from memory. The note skill is the fastest path from "I just thought of something" to a durable, deduplicated entry in the project backlog.

## Rules

- **No codebase exploration.** The skill interacts only with GitHub Issues via the `gh` CLI. Never read source code, run tests, or investigate implementation.
- **Err conservative on merging.** When uncertain, do not merge. A duplicate is cheaper than a bad merge that loses information.
- **Never ask more than two follow-up questions.** Most notes should be captured with zero follow-up.
- **Always show the user what was captured.** For merges, show before and after.
- **Do not add information not present in the user's note or the existing entry.** Do not infer causality or connections not explicitly stated.

## GitHub CLI Guard

Before any other step, verify the `gh` CLI is available and authenticated:

1. Run `command -v gh`. If it fails, tell the user: "gh CLI is not installed. Install from https://cli.github.com/ and run `gh auth login`." Stop.
2. Run `gh auth status`. If it exits non-zero, tell the user: "gh CLI is not authenticated. Run `gh auth login`." Stop.

If a `gh` command fails at any point during the flow with a permission or authentication error, show the user the raw error output and suggest: "Your token may lack the required scopes. Try `gh auth refresh -s repo`." Stop. Do not retry. Do not fall back to any local file.

## Voice-First Rules (CRITICAL)

- **NEVER** use `AskUserQuestion` with predefined options or multiple choice.
- **NEVER** present numbered lists of choices.
- **ALWAYS** output plain text questions directly to the user as part of your response.
- **ONE question at a time.** Never batch questions.
- **Provide examples to react to, not options to select.**

## Mode Detection

Before entering the capture or search flow, determine which mode the user's message indicates:

- **Capture mode indicators:** The user is sharing a new thought, idea, bug, or observation. They want to save something. Phrases like "I have an idea," "note this," "I found a bug," "park this thought."
- **Targeted search indicators:** The user is looking for something specific in the backlog. Phrases like "find that note about X," "do we have an issue for Y," "any notes about Z," "search for X."
- **Broad browse indicators:** The user wants to see the whole backlog or a large slice of it. Phrases like "show me the backlog," "what's in the backlog," "to-dos," "to-do list," "pull up the issues."

If capture mode: proceed to the Flow section (Step 1: Receive and Assess) unchanged.
If targeted search: proceed to the Targeted Search section.
If broad browse: proceed to the Broad Browse section.

## Flow

### Step 1: Receive and Assess

Receive the user's note in natural language. The user may say anything from a complete description to a half-formed thought.

**Decision:** Is the note clear enough to act on?

- If the note describes a specific problem, idea, bug, or observation with enough context to write a meaningful entry: **proceed to Step 2 immediately with no questions.**
- If the note is vague or ambiguous (e.g., "something about auth," "that thing we discussed," "maybe a performance issue"): ask **one** sharpening question. Never more than two total. Use judgment -- most notes should be captured without follow-up.

Good sharpening question: "When you say 'something about auth,' what specifically came to mind? Like a bug you noticed, a feature gap, or a design concern?"

### Step 2: Filter Existing Issues

Read `prompts/issue-filter.md`, substitute `{{NOTE_TEXT}}` with the user's note text.

Spawn a haiku subagent using the Task tool (`subagent_type: "general-purpose"`, `model: "haiku"`) with the substituted prompt. The subagent fetches all open issues itself via `gh issue list`, filters them, and returns a JSON array of relevant issue objects (each with `title`, `body`, and `number` fields).

- If the subagent returns an empty array: skip to Step 4 (add new issue).
- If the subagent returns one or more issue objects: proceed to Step 3 with these candidates.

### Step 3: Overlap Detection (reasoning-first comparison)

This is where you determine whether the new note overlaps with an existing issue. Do NOT skip this step. Do NOT assume overlap or non-overlap without reasoning through it.

For each candidate issue from Step 2:

1. **Generate a one-sentence semantic summary** of what the existing issue is about. Focus on the core problem, idea, or observation -- not surface-level keywords.

2. **Compare the new note's intent against each summary across three dimensions:**
   - **Same problem area?** Are both about the same system, component, or concern?
   - **Same proposed action?** Do both suggest doing the same thing or fixing the same thing?
   - **Same motivation?** Is the underlying reason for both the same?

3. **Decide:**
   - If there is **clear, unambiguous overlap** (same problem area AND same proposed action AND same motivation -- all three): **merge** into the existing issue. Proceed to Step 5.
   - If overlap is **uncertain or borderline** (one or two dimensions match but not all three): **do NOT merge.** Create a new issue (Step 4) and include a `See also: #N` reference in the body.
   - If there is **no overlap** (different problem area, different action, different motivation): create a new issue (Step 4).

### Step 4: Add New Issue

Create a new GitHub Issue using `gh issue create`:

```bash
printf '%s\n\n_Origin: note_' "<description>" | gh issue create --title "<title>" --body-file -
```

If a "See also" reference was determined in Step 3, include it before the Origin tag:

```bash
printf '%s\n\nSee also: #%d\n\n_Origin: note_' "<description>" "<issue-number>" | gh issue create --title "<title>" --body-file -
```

Capture the output URL from stdout to show the user.

Proceed to Step 6.

### Step 5: Merge into Existing Issue (rewrite-with-provenance)

When merging, follow these rules exactly:

1. **Read current body:** `gh issue view <number> --json body --jq '.body'`
2. **Read comments:** `gh issue view <number> --json comments --jq '.comments[] | select(.isMinimized == false) | {author: .author.login, date: .createdAt, body: .body}'`
3. **Construct merged body in LLM context.** Rewrite the body to incorporate the new note, following the same rules as today (preserve all details, keep title stable, update Origin tag). If there are non-minimized user comments whose content is not already reflected in the body, fold them in as well.
4. If the existing body is empty, just write the new content. If the existing body has content, construct a merged body that reads as a single coherent entry.
5. **Write back:** `printf '%s' "$MERGED_BODY" | gh issue edit <number> --body-file -`

**Merging rules:**

1. **Rewrite the entire description** as a single coherent text incorporating both the original issue body and the new note. The issue should read as if it were always one entry.
2. **Preserve all specific details from both sources.** Do not drop information. Do not add information not present in either source. Do not infer causality or connections not explicitly stated.
3. **Keep the title stable** unless the new information fundamentally changes the scope.
4. **Update the `_Origin:_` tag** to include both sources, comma-separated. Example: `_Origin: brainstorm/feature-slug, note_`
5. **Origin tags track source** (which skill produced the content), not dates. Git handles temporal tracking.

**Show the user what changed.** Display the before and after versions of the merged issue body so the user can verify nothing was lost:

```
**Before merge:**
### [Original title]
[Original body]

_Origin: [original origin]_

**After merge:**
### [Updated title]
[Merged body]

_Origin: [updated origin]_
```

Proceed to Step 6.

### Step 6: Grooming (optional)

After creating or merging, surface any issues that might be stale or resolved. Run `gh issue list --json title,number,createdAt --limit 100 --state open`. If any issues were created more than 30 days ago, mention them conversationally: "By the way, issue #N '[title]' has been open for a while. Is it still relevant, or can we close it?" Never auto-close -- always ask the user. If the user says to close an issue, run `gh issue close <number>`.

### Step 7: Confirm to User

Show the user what was captured. Be brief.

- For a **new issue**: show the issue that was created, including its URL.
- For a **merge**: the before/after was already shown in Step 5. Confirm the merge is complete and show the issue URL.
- For a **new issue with "See also"**: mention that a related issue exists and a cross-reference was added. Include the issue URL.

## Targeted Search

When the user is looking for something specific in the backlog:

1. Read `prompts/issue-search.md`, substitute `{{SEARCH_QUERY}}` with the user's search query text (extracted from their message -- the topic they're searching for, not the full trigger phrase).
2. Spawn a haiku subagent using the Agent tool (`subagent_type: "general-purpose"`, `model: "haiku"`) with the substituted prompt. The subagent fetches open issues, filters them against the query, and returns a JSON array of matching issue objects.
3. If the subagent returns an empty array: tell the user "No notes match that query" conversationally. Return control to the main agent. Do NOT offer to create a new note.
4. If the subagent returns results: present the matching issues to the user conversationally -- show title, number, and a brief summary of each. The user takes it from there (they may want to discuss, close, brainstorm, or just browse). The note skill's job ends at presentation.

## Broad Browse

When the user wants to see the whole backlog or a large slice of it (no subagent needed):

1. Fetch issue titles directly: `gh issue list --json title,number --limit 100 --state open`
2. If there are zero open issues: tell the user "The backlog is empty" conversationally.
3. If there are open issues: present them as a list showing title and number. Newest first (the default `gh issue list` sort order).
4. The note skill's job ends at presentation. The user takes it from there.

## Anti-Patterns (things you must NOT do)

### Over-questioning

**Looks like:** Asking "What browser?" or "What page?" or "Can you elaborate?" after the user says "I found a bug where the login form doesn't validate email format."
**Why it seems right:** More context always seems helpful. Extra detail might make the issue more actionable.
**Why it fails:** It slows down capture and annoys the user. The whole point of the cadence-note skill is speed -- idea to backlog in seconds. A clear bug report with a specific problem does not need clarification.
**Do this instead:** If the note has a specific problem, idea, or observation, capture immediately with zero questions.

### Silent Merging

**Looks like:** Finding an overlapping issue, rewriting it with the new information merged in, and telling the user "Done, merged into the existing issue."
**Why it seems right:** The merge was correct and the user trusts you. Showing diffs feels like unnecessary ceremony.
**Why it fails:** The user cannot verify that nothing was lost. Merges rewrite prose, and rewriting can accidentally drop details. Without before/after, the user has no way to catch this until they re-read the issue later (which they won't).
**Do this instead:** Always show the before and after versions of the merged issue, exactly as specified in Step 5.

### Aggressive Merging

**Looks like:** Merging "Improve API error handling" with "Rate limiter rejects valid requests during bursts" because both are about the API.
**Why it seems right:** They are related. Combining them reduces backlog clutter and creates a more comprehensive issue.
**Why it fails:** They are different problems with different solutions. Merging them creates a muddled issue that conflates two distinct problems. A reader later cannot tell whether the issue is about error messages or rate limiting.
**Do this instead:** When overlap is uncertain or only surface-level, do not merge. Create a new issue with "See also" if borderline.

### Codebase Exploration

**Looks like:** Reading source code files, running tests, or checking implementations to "better understand" the user's note before capturing it.
**Why it seems right:** Understanding the codebase would help you write a more precise issue. You could verify whether the bug is real or add implementation context.
**Why it fails:** The skill's job is capture, not investigation. Reading source code burns time and context, and the user's observation is valid regardless of what the code currently does. Investigation happens during research or build phases, not note capture.
**Do this instead:** Capture the note as the user described it. The skill's world is GitHub Issues. Period.

## Red Flags

Observable signs that the skill is being executed incorrectly. Stop and correct course if any of these occur:

- **More than two follow-up questions were asked.** You are over-questioning. Capture what you have.
- **A merge happened without showing before/after.** Go back and show the user what changed.
- **An issue was created without fetching existing issues first.** You must always fetch first to check for overlaps.
- **The skill explored source code files.** Stop immediately. Your world is GitHub Issues only.
- **Information was added to an entry that the user did not provide.** Remove inferred content.

## Examples

### Example 1: Clear Note, No Follow-up

**User:** "I just noticed that our CSV export doesn't handle unicode characters -- it mangles accented names."

**What the skill does:**
1. The note is clear and specific. No follow-up needed.
2. Read `prompts/issue-filter.md`, substitute `{{NOTE_TEXT}}`, and spawn a haiku subagent. The subagent fetches open issues, filters them, and returns `[]` -- no relevant issues.
3. Overlap detection: skipped (no candidates).
4. Create new issue:

```bash
printf '%s\n\n_Origin: note_' "The CSV export doesn't handle unicode characters correctly -- accented names get mangled in the output." | gh issue create --title "CSV export mangles unicode characters" --body-file -
```

Output: `https://github.com/owner/repo/issues/42`

5. Grooming: check for stale issues. None older than 30 days.
6. Show user: "Captured: 'CSV export mangles unicode characters' -- created as issue #42. https://github.com/owner/repo/issues/42"

### Example 2: Vague Note, One Sharpening Question

**User:** "Something about auth."

**What the skill does:**
1. The note is too vague to capture meaningfully. Ask one question.
2. Respond: "When you say 'something about auth,' what came to mind? Like a bug you hit, a missing feature, or a design concern?"

**User:** "Oh right -- I noticed that expired tokens aren't being cleaned up from the session store. They just accumulate."

**What the skill does:**
3. Now it's clear. Read `prompts/issue-filter.md`, substitute `{{NOTE_TEXT}}`, and spawn a haiku subagent. The subagent fetches open issues, filters them, and returns `[]` -- no relevant issues.
4. Create new issue:

```bash
printf '%s\n\n_Origin: note_' "Expired tokens are not being cleaned up from the session store -- they just accumulate over time." | gh issue create --title "Expired tokens accumulate in session store" --body-file -
```

Output: `https://github.com/owner/repo/issues/43`

5. Grooming: check for stale issues. None older than 30 days.
6. Show user: "Captured: 'Expired tokens accumulate in session store' -- created as issue #43. https://github.com/owner/repo/issues/43"

### Example 3: Clear Overlap, Merge with Before/After

**Existing issue #12:**
```
Title: Token rotation isn't clearing old tokens
Body:
When tokens are rotated, the old tokens remain valid and are not removed from storage. This creates a growing backlog of stale tokens.

_Origin: brainstorm/auth-cleanup_
```

**User:** "Just realized the token cleanup problem is worse than we thought -- expired tokens are also not being purged during scheduled maintenance runs."

**What the skill does:**
1. Note is clear. No follow-up needed.
2. Read `prompts/issue-filter.md`, substitute `{{NOTE_TEXT}}`, and spawn a haiku subagent. The subagent fetches open issues, filters them, and returns `[{"title": "Token rotation isn't clearing old tokens", "body": "When tokens are rotated, the old tokens remain valid and are not removed from storage. This creates a growing backlog of stale tokens.\n\n_Origin: brainstorm/auth-cleanup_", "number": 12}]`.
3. Overlap detection:
   - Existing issue summary: "Old tokens are not cleaned up during rotation, leading to stale token accumulation."
   - New note intent: "Expired tokens are not purged during scheduled maintenance."
   - Same problem area? Yes -- both about stale/expired token cleanup.
   - Same proposed action? Yes -- both about removing old tokens that should be gone.
   - Same motivation? Yes -- both about preventing token accumulation.
   - Verdict: **Clear overlap. Merge.**

4. Read current body: `gh issue view 12 --json body --jq '.body'`
5. Read comments: `gh issue view 12 --json comments --jq '.comments[] | select(.isMinimized == false) | {author: .author.login, date: .createdAt, body: .body}'`
6. Merge and show before/after:

**Before merge:**
```
### Token rotation isn't clearing old tokens
When tokens are rotated, the old tokens remain valid and are not removed from storage. This creates a growing backlog of stale tokens.

_Origin: brainstorm/auth-cleanup_
```

**After merge:**
```
### Token rotation isn't clearing old tokens
When tokens are rotated, the old tokens remain valid and are not removed from storage. Additionally, expired tokens are not being purged during scheduled maintenance runs. This creates a growing backlog of stale tokens from both sources.

_Origin: brainstorm/auth-cleanup, note_
```

7. Write back: `printf '%s' "$MERGED_BODY" | gh issue edit 12 --body-file -`
8. Grooming: check for stale issues.
9. Confirm: "Merged your observation about maintenance purging into the existing 'Token rotation isn't clearing old tokens' entry (issue #12). The before/after is above -- let me know if anything looks wrong."

### Example 4: Borderline Related, Add Separately with "See Also"

**Existing issue #7:**
```
Title: Improve API error handling
Body:
Our API returns generic 500 errors for most failure cases. We should implement structured error responses with proper HTTP status codes, error codes, and human-readable messages.

_Origin: brainstorm/api-cleanup_
```

**User:** "Our API rate limiter doesn't handle burst traffic correctly -- it rejects legitimate requests during traffic spikes."

**What the skill does:**
1. Note is clear. No follow-up needed.
2. Read `prompts/issue-filter.md`, substitute `{{NOTE_TEXT}}`, and spawn a haiku subagent. The subagent fetches open issues, filters them, and returns `[{"title": "Improve API error handling", "body": "Our API returns generic 500 errors for most failure cases. We should implement structured error responses with proper HTTP status codes, error codes, and human-readable messages.\n\n_Origin: brainstorm/api-cleanup_", "number": 7}]`.
3. Overlap detection:
   - Existing issue summary: "API returns generic errors; need structured error responses with proper status codes."
   - New note intent: "Rate limiter incorrectly rejects legitimate requests during traffic bursts."
   - Same problem area? Borderline -- both are about the API, but different subsystems (error formatting vs. rate limiting).
   - Same proposed action? No -- one is about improving error messages, the other is about fixing rate limiting logic.
   - Same motivation? No -- one is about developer experience with error responses, the other is about avoiding false rejections.
   - Verdict: **Not the same issue. Different problem areas, different actions, different motivations. Add separately.** The entries are loosely related (both API concerns) but not overlapping. Add a "See also" reference.

4. Create new issue with cross-reference:

```bash
printf '%s\n\nSee also: #%d\n\n_Origin: note_' "The API rate limiter doesn't handle burst traffic correctly -- legitimate requests are rejected during traffic spikes." "7" | gh issue create --title "Rate limiter rejects legitimate requests during burst traffic" --body-file -
```

Output: `https://github.com/owner/repo/issues/44`

5. Grooming: check for stale issues.
6. Show user: "Captured: 'Rate limiter rejects legitimate requests during burst traffic' -- created as issue #44. There's a loosely related issue about API error handling (#7), so I added a cross-reference. https://github.com/owner/repo/issues/44"
