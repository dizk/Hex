---
name: cadence-write-skill
description: "Create new skills for the Cadence system using TDD methodology. Use when someone says 'write a skill', 'create a skill', 'add a prompt for', 'teach Claude how to', or when creating any SKILL.md file. Do NOT use for editing existing skills or writing non-skill documentation."
---

# Write Skill

You are creating a new skill for the Cadence system. Skills are the atomic units of Cadence's knowledge -- each one teaches Claude how to do one thing well. Because this skill creates all other skills, you must follow every step precisely. No shortcuts.

## Skill Types

Before writing anything, determine which type of skill you are creating:

- **Technique:** How to do something. Teaches a process with clear steps. Examples: TDD, brainstorming, code review. The reader should be able to follow the steps and produce a result.
- **Pattern:** A reusable structure. Provides a template or format to fill in. Examples: PR descriptions, commit messages, planning documents. The reader applies it to their specific situation.
- **Reference:** Information to consult. A checklist, table, or decision guide that the reader looks up when needed. Examples: red flags lists, comparison tables, naming conventions.

If you are unsure which type fits, ask the user: "This skill sounds like it could be a [type A] or a [type B]. A [type A] would teach the process step by step, while a [type B] would provide a reusable structure to fill in. Which fits better for what you have in mind?"

## The TDD Cycle for Documentation

Skills are documentation, but they follow TDD just like code. This is not optional. The cycle is RED, GREEN, REFACTOR -- in that order, every time.

### RED: Baseline Test

Before writing the skill, you must know what failure looks like. Spawn a fresh subagent with no knowledge of the skill and give it a scenario where the skill would apply. Observe what happens.

**How to run the baseline test:**

1. Identify a realistic scenario where this skill would be needed. Be specific -- use concrete file names, user requests, and project contexts.
2. Spawn a subagent (using the Task tool) with this prompt:

```
You are working on a project. You have no special skills or instructions loaded.

[Describe the scenario in detail]

Complete this task to the best of your ability. When done, explain your approach and any decisions you made.
```

3. Record what the subagent does. Pay attention to:
   - What steps did it skip that it should not have?
   - What did it get wrong?
   - Where did it make assumptions instead of asking?
   - What rationalizations did it use to justify shortcuts?
   - What would a human reviewer catch that the subagent missed?

4. Write down the specific failures. These become your acceptance criteria -- the skill must prevent every one of these failures.

**Do not skip the baseline test.** See the Rationalization Table below for why every excuse to skip it is wrong.

### GREEN: Write the Skill

Now write the skill so that a fresh subagent given the same scenario would succeed. The skill must directly address every failure observed in the RED phase.

Use the SKILL.md Structure Template below. Every section exists for a reason.

After writing, run the same scenario again with a fresh subagent that has access to the new skill. Verify that every failure from the RED phase is now prevented.

If any failure still occurs, the skill is not done. Revise and test again.

### REFACTOR: Pressure Scenarios

The skill works for the happy path. Now break it. Design pressure scenarios that test the skill's boundaries:

- **Time pressure:** "The user says they need this done in 5 minutes. Does the skill still enforce its process?"
- **Ambiguity:** "The user gives a vague description. Does the skill guide toward specificity or accept vagueness?"
- **Edge cases:** "What if the project has no tests? What if there are conflicting requirements?"
- **Rationalization pressure:** "The subagent wants to skip a step because it seems unnecessary for this case. Does the skill prevent this?"
- **Scope creep:** "The user asks for something adjacent but different. Does the skill stay focused or drift?"

For each pressure scenario:

1. Spawn a fresh subagent with the skill loaded.
2. Present the pressure scenario.
3. If the subagent fails, add explicit guidance to the skill to handle that case.
4. Re-test until the scenario passes.

You are done refactoring when you cannot design a realistic pressure scenario that breaks the skill.

## SKILL.md Structure Template

Every skill follows this structure. Do not invent a new format.

```markdown
---
name: [skill-name]
description: [CSO-optimized description -- see CSO Guidance below]
---

# [Skill Title]

[One paragraph: What this skill does and why it exists. A reader should know within 5 seconds whether this skill is relevant to them.]

## Purpose

[What problem does this skill solve? What goes wrong without it? Be concrete -- describe the failure mode, not the abstract concept.]

## Rules

[Non-negotiable constraints. These are the things that must always be true when this skill is in use. Write them as imperative statements.]

- Rule 1
- Rule 2
- Rule 3

## Process

[Step-by-step instructions. Each step must be concrete enough that a fresh Claude instance with no prior context could follow it and produce the correct result.]

### Step 1: [Name]

[What to do. What the output looks like. How to verify it worked.]

### Step 2: [Name]

[Continue for each step.]

## Anti-Patterns

[Things that look right but are wrong. Each anti-pattern should include: what it looks like, why it seems correct, and why it fails.]

### [Anti-Pattern Name]

**Looks like:** [What the incorrect behavior looks like]
**Why it seems right:** [The rationalization for doing it this way]
**Why it fails:** [The concrete consequence]
**Do this instead:** [The correct behavior]

## Red Flags

[Observable signs that the skill is being applied incorrectly. These should be checkable by a reviewer or a code review subagent.]

- Red flag 1
- Red flag 2
- Red flag 3

## Examples

[At least one concrete example showing the skill applied correctly. Use realistic scenarios, not toy examples. If the skill is a Technique, show the full process. If it is a Pattern, show a filled-in template. If it is a Reference, show how to look something up.]
```

### Sections That Are Always Required

Every section in the template above is required. If you think a section does not apply, you are wrong -- think harder. The Anti-Patterns section is where most skill authors cut corners. Do not cut corners there.

### Sections You May Add

If the skill genuinely needs additional sections, add them after Examples. Common additions:

- **Troubleshooting:** For techniques with common failure modes.
- **Variations:** For patterns that have context-dependent variants.
- **Related Skills:** When this skill connects to others in the Cadence system.

## CSO (Claude Search Optimization) Guidance

The `description` field in the YAML frontmatter is how Claude decides whether to surface this skill. Write it so Claude finds the skill when it is relevant and does not surface it when it is not.

### How to Write `description`

1. **Start with the trigger moment.** Describe the exact situation where someone would need this skill. Not the abstract category -- the concrete moment.

   Bad: "When writing documentation"
   Good: "Create new skills for the Cadence system using TDD methodology. Use when someone says 'write a skill', 'create a skill', 'add a prompt for', 'teach Claude how to', or when creating any SKILL.md file."

2. **Include concrete trigger phrases.** These are the words a user or another skill would actually use when this skill is needed.

   Bad: "For project planning"
   Good: "When someone says 'write a skill', 'create a new command', 'add a prompt for', 'teach Claude how to', or when you are creating any SKILL.md file in skills/"

3. **Include negative triggers.** State when this skill should NOT be used to prevent false matches.

   Bad: (nothing)
   Good: "Do NOT use for editing existing skills or writing non-skill documentation like READMEs."

4. **Keep it under 200 words.** Long descriptions dilute matching. Be precise.

### CSO Checklist

Before finalizing `description`, verify:

- [ ] It describes a specific moment, not a category
- [ ] It includes 3-5 trigger phrases a user might actually say
- [ ] It includes at least one negative trigger
- [ ] It is under 200 words
- [ ] A fresh Claude instance reading only this field would know whether the skill applies to their current task

## Cadence-Specific Paths

Skills and supporting files live in specific locations. Do not use paths from other systems.

| What | Where | Example |
|------|-------|---------|
| Skills | `skills/<name>/SKILL.md` | `skills/write-skill/SKILL.md` |
| Slash commands (stubs) | `commands/cadence/` | `commands/cadence/write-skill.md` |
| Agent prompts | `agents/` | `agents/researcher.md` |
| Templates | `templates/` | `templates/brainstorm.md` |
| Project-installed skills | `.claude/skills/<name>/SKILL.md` | User's project |
| Project-installed commands | `.claude/commands/cadence/` | User's project |
| Project-installed agents/templates | `.claude/cadence/` | User's project |

When creating a new skill, put the SKILL.md in `skills/<name>/SKILL.md`. The corresponding command stub (if needed) goes in `commands/cadence/<name>.md` and simply invokes the skill.

## Voice-First Design

Every skill that interacts with users must follow voice-first principles. Users speak or type free text. They do not select from numbered lists.

### Rules for Questions in Skills

- **Never present multiple choice options.** No numbered lists of choices. No "select A, B, or C."
- **Always ask open-ended questions.** Frame them so the user responds in their own words.
- **Provide examples to react to, not options to select.** Give 2-3 concrete examples embedded in the question text so the user has something to anchor on, but make it clear they should describe what they actually want.
- **One question at a time.** Do not batch questions. Ask, listen, then ask the next one.

### Example of Voice-First Question Design

Wrong:
```
What type of skill is this?
1. Technique
2. Pattern
3. Reference
```

Right:
```
What kind of skill are you creating? For example, a technique teaches
a process step by step (like TDD or brainstorming), a pattern provides
a reusable structure to fill in (like a PR template), and a reference
is something to look up when needed (like a checklist). Describe what
you have in mind and I'll figure out the right type.
```

The right version works naturally with speech-to-text, does not require the user to remember which number maps to which option, and invites elaboration that helps write a better skill.

## Rationalization Table

These are the most common excuses for cutting corners when writing skills. Every one of them is wrong. If you catch yourself thinking any of these, stop and do the right thing.

| Rationalization | Why It Is Wrong | What To Do Instead |
|---|---|---|
| "This skill is too simple for TDD." | Simple skills are the ones most likely to have hidden gaps. The baseline test takes 2 minutes and catches assumptions you did not know you were making. | Run the baseline test. It will be fast precisely because the skill is simple. |
| "I will add tests later." | You will not. Later never comes. And without the RED phase, you do not know what failures to prevent, so the skill will have blind spots. | Run the baseline test now, before writing a single line of the skill. |
| "The user is in a hurry." | A rushed skill that does not work costs more time than a tested skill that does. The user will have to fix the skill later or deal with the failures it does not prevent. | Tell the user: "This will take a few extra minutes to test properly. The alternative is a skill that looks right but fails under pressure." |
| "I already know what the skill should say." | You know what you think it should say. The baseline test reveals what it actually needs to say. These are often different. | Run the baseline test and be surprised. |
| "The Anti-Patterns section is not needed for this skill." | Every skill has anti-patterns. If you cannot think of any, you do not understand the skill well enough yet. | Think about what a rushed or confused Claude instance would do wrong when trying to follow this skill. Those are your anti-patterns. |
| "This is just a reference skill, it does not need a process section." | Reference skills need a process for how to look things up and apply what you find. A table without usage guidance is just data. | Write a brief process: When to consult this reference, how to find the relevant entry, and how to apply it to your current task. |
| "I can skip the REFACTOR phase because the GREEN test passed." | The GREEN test only covers the happy path. Real usage involves time pressure, ambiguity, edge cases, and scope creep. The REFACTOR phase is where you discover the skill's actual boundaries. | Design at least 3 pressure scenarios and test each one. |
| "The frontmatter is boilerplate, I will fill it in at the end." | The `description` field determines whether the skill is ever found. Writing it last means it gets the least thought. Writing it first forces you to clarify what the skill is actually for. | Write the YAML frontmatter first. It takes 5 minutes and shapes everything that follows. |

## Red Flags for Skill Quality

If you notice any of these while writing or reviewing a skill, the skill is not ready:

- **Too vague to be actionable.** If a fresh Claude instance could read the skill and still not know what to do in a concrete scenario, the skill needs more specificity. Every instruction should pass the test: "Could someone follow this without asking a clarifying question?"
- **No concrete examples.** Examples are not optional decoration. They are the proof that the skill works. A skill without examples is a theory, not a skill.
- **Missing Anti-Patterns section.** This is the most common sign of a skill written in a hurry. Anti-patterns are what separate a skill that works in ideal conditions from one that works under pressure.
- **Overly complex.** A skill should teach one thing. If the skill has more than 7 process steps or covers multiple distinct topics, it should be split into multiple skills. Focused skills are easier to find, easier to follow, and easier to test.
- **No negative triggers in `description`.** Without negative triggers, the skill will be surfaced in situations where it does not apply, leading to confused or incorrect behavior.
- **Rules section is a wish list.** Rules should be enforceable constraints, not aspirational goals. "Write good code" is not a rule. "Every function must have at least one test" is a rule.
- **Process steps have no verification.** Each step should explain how to know it was done correctly. A step without verification is a step that can silently fail.
- **Examples use toy scenarios.** "FooBar" and "MyWidget" examples teach nothing. Use realistic scenarios from actual projects.

## The Full Process

When the user asks you to write a skill, follow these steps in order. Do not reorder, skip, or combine steps.

### Step 1: Understand What the Skill Should Do

Ask the user to describe the skill in their own words. For example: "What should this skill teach Claude to do? Walk me through a scenario where you would want Claude to have this skill -- what is happening, what does the user ask for, and what should Claude do differently than it would without the skill?"

Listen for:
- The trigger moment (when does someone need this?)
- The desired outcome (what should be different after?)
- The failure mode (what goes wrong without this skill?)

If the user's description is vague, ask follow-up questions until you can describe a concrete test scenario.

### Step 2: Determine the Skill Type

Based on the user's description, determine whether this is a Technique, Pattern, or Reference. If unclear, ask using the voice-first question format described above.

### Step 3: Write the YAML Frontmatter

Write the `name` and `description` fields. Follow the CSO Guidance above. This comes before the baseline test because `description` forces you to clarify exactly what the skill is for.

### Step 4: RED -- Run the Baseline Test

Design a realistic scenario and run it with a fresh subagent as described in the TDD Cycle section. Record every failure. These failures become the skill's acceptance criteria.

### Step 5: GREEN -- Write the Skill Body

Write the full skill using the SKILL.md Structure Template. Every failure from Step 4 must be addressed by a specific part of the skill. If you cannot trace a failure to a section of the skill, the skill has a gap.

After writing, run the same scenario with a fresh subagent that has the skill loaded. Verify every failure from Step 4 is now prevented.

### Step 6: REFACTOR -- Pressure Test

Design at least 3 pressure scenarios as described in the TDD Cycle section. Run each with a fresh subagent. Revise the skill until all pressure scenarios pass.

### Step 7: Place the File

Put the skill in `skills/<name>/SKILL.md`. If the skill needs a user-invocable command, create a stub in `commands/cadence/<name>.md` that invokes the skill.

### Step 8: Report

Tell the user:
- What the skill does (one sentence)
- Where the file was placed
- What failures the baseline test revealed
- What pressure scenarios were tested
- Any open questions or known limitations

## Final Warning

This is the skill that creates all other skills. If this skill is sloppy, every skill it produces will inherit that sloppiness. Do not rush. Do not skip steps. Do not rationalize. The TDD cycle, the structure template, the anti-patterns section, the pressure scenarios -- all of these exist because their absence causes real failures. Follow the process.
