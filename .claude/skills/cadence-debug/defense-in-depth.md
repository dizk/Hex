# Defense in Depth

A guide for when the obvious fix is not enough. This document is referenced by the cadence-debug skill to ensure fixes are thorough and do not introduce new failure modes.

## The Principle

Finding the root cause and fixing it is necessary but not sufficient. A complete diagnosis also considers whether the same class of bug can occur elsewhere, whether the fix introduces new failure modes, and whether the underlying design made this bug likely in the first place.

## After Finding Root Cause

Once you have a root cause hypothesis, ask these three questions before declaring the diagnosis complete.

### Question 1: Can the Same Class of Bug Occur Elsewhere?

The bug you found is one instance of a pattern. The pattern may exist in other places.

**How to check:**
- Identify the abstract pattern of the bug. For example: "A function assumes its input is non-null but the caller can pass null in edge cases."
- Search the codebase for the same pattern. Look for other callers of the same function, other functions with the same assumption, or other data flows with the same shape.
- Document any additional instances you find in the diagnosis. These become research questions or additional tasks in the fix plan.

**Example:** The root cause is that `processOrder()` assumes `order.items` is a non-empty array, but `createOrder()` allows orders with zero items. Checking the codebase reveals that `shipOrder()` and `invoiceOrder()` make the same assumption. The fix should address all three, not just `processOrder()`.

### Question 2: Does the Fix Introduce New Failure Modes?

Every code change has consequences. A fix that solves one problem may create another.

**How to check:**
- Walk through the proposed fix mentally. At each step, ask: "What if this new code receives unexpected input?"
- Check for callers of the changed code. Will they behave correctly with the new behavior?
- Look for implicit contracts. If a function previously always returned a value and the fix adds a case where it returns null, every caller needs to handle null.
- Consider concurrency. If the fix adds a check-then-act pattern, is there a race condition between the check and the act?

**Example:** The fix for the null-items bug is to add `if (!order.items || order.items.length === 0) return;` at the top of `processOrder()`. But `processOrder()` is called by `fulfillOrder()`, which does not check the return value and assumes processing always succeeds. The early return causes `fulfillOrder()` to mark the order as fulfilled without actually processing it. The fix needs to either throw an error or the caller needs to handle the no-items case.

### Question 3: Did the Design Make This Bug Likely?

Some bugs are accidents. Others are inevitable consequences of a design that makes certain errors easy to make. Understanding which category a bug falls into determines whether a localized fix is sufficient or whether a broader change is needed.

**Signs the design made the bug likely:**
- The same data is represented differently in different layers (string in one place, object in another, integer in a third). Conversion errors are inevitable.
- A function has preconditions that are not enforced, only documented (or not documented at all). Callers will eventually violate them.
- Shared mutable state is accessed from multiple code paths. Ordering and race conditions are inevitable.
- The failure requires understanding behavior spread across many files. The interaction is too complex to hold in one person's head.

**Signs the bug was an accident:**
- A simple typo or copy-paste error.
- A one-time mistake in a migration or configuration.
- An edge case that genuinely could not have been anticipated from the design.

**If the design made the bug likely**, note this in the diagnosis. The research and align phases should consider whether the fix should include a small structural improvement that makes this class of bug harder to introduce in the future. This does not mean rewriting the system -- it means targeted hardening at the failure point.

## Levels of Fix Thoroughness

When writing the "Proposed Fix" section of the diagnosis, consider which level is appropriate:

### Level 1: Point Fix

Fix the specific bug. Nothing more.

**When appropriate:** The bug is an accident. The code is otherwise well-structured. The same class of bug does not exist elsewhere.

**Example:** A comparison uses `==` instead of `===` in one specific place. Fix that comparison.

### Level 2: Class Fix

Fix the specific bug and all other instances of the same pattern.

**When appropriate:** The same class of bug exists in multiple places. Fixing only the reported instance will leave the others as time bombs.

**Example:** Multiple functions assume non-null input without validation. Add validation to all of them, not just the one that crashed.

### Level 3: Structural Fix

Fix the bug, fix the class, and make a targeted structural change that prevents the class from recurring.

**When appropriate:** The design makes this class of bug likely. Without a structural change, new instances will be introduced as the codebase grows.

**Example:** Functions across the codebase make assumptions about input types. Introduce a validation layer or type-safe interface at the boundary so that invalid data is caught before it reaches these functions.

The diagnosis should recommend the appropriate level. The research phase will determine how to implement it. The align phase will scope and sequence the work.

## Red Flags in Fix Proposals

Watch for these signs that a proposed fix is insufficient:

- **The fix only addresses the symptom.** It catches the error and returns a default value, but the invalid data still flows through the system.
- **The fix requires understanding the full system to verify.** If you cannot verify the fix by looking at the changed code alone, it may have unintended interactions.
- **The fix adds a special case.** Special cases are where bugs hide. If the fix is "if this specific input, do something different," ask whether the general case should handle it instead.
- **The fix duplicates logic.** If the fix copies validation or transformation logic from another location, the two copies will diverge over time. Consider extracting the shared logic.
- **The fix makes the code harder to understand.** A fix that solves the bug but makes the code more confusing is setting up the next bug. Clarity prevents bugs.
