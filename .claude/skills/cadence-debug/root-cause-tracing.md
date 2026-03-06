# Root Cause Tracing

A technique guide for systematic root cause tracing. This document is referenced by the cadence-debug skill during Phase 1 -- Root Cause Investigation.

## The Principle

Start from the symptom. Trace backward through the call chain. Identify the first point where behavior diverges from expectation. Document each step of the trace.

Root cause tracing is not about finding the line that throws an error. It is about finding the line that made the error inevitable. These are often far apart -- the throw happens in a handler, but the root cause is a missing validation three function calls upstream.

## The Technique

### Step 1: Capture the Symptom Precisely

Before tracing anything, write down exactly what is going wrong. Not your interpretation -- the observable behavior.

**Good symptom capture:**
- "The API returns 500 with body `{"error":"Cannot read property 'id' of undefined"}` when POST /users is called with a valid payload."
- "Test `should create user with email` fails. Expected status 201, received 500. Console shows `TypeError: Cannot read property 'id' of undefined` at `src/handlers/user.js:42`."

**Bad symptom capture:**
- "User creation is broken." (Too vague. What specifically fails? What is the error?)
- "Something is wrong with the database connection." (Interpretation, not observation. What did you actually see?)

### Step 2: Identify the Throw Point

Find the exact location where the error originates. This is your starting point, not your conclusion.

- Read the stack trace. The top frame is the throw point.
- If there is no stack trace, reproduce the failure and capture one.
- If the failure is silent (wrong output, no error), identify the function that produces the wrong result.

### Step 3: Trace Backward

From the throw point, move upstream through the call chain. At each step, ask:

1. **What data does this function receive?** Read the inputs.
2. **What does this function expect?** Read the code to understand assumptions.
3. **Is the expectation met?** Compare actual inputs to expected inputs.
4. **If not, where did the bad data come from?** Move to the caller.

Document each step:

```
[Function C] throws TypeError: Cannot read 'id' of undefined
  <- receives `user` parameter, which is undefined
  <- called by [Function B] at line 38
  <- [Function B] passes `result.user` to Function C
  <- `result` is the return value of [Function A]
  <- [Function A] returns `{ data: user }` not `{ user: user }`
  <- ROOT CAUSE: Function A returns `{ data: user }` but Function B reads `result.user`
```

### Step 4: Find the Divergence Point

The divergence point is where the actual behavior first differs from the expected behavior. Everything downstream of this point is a consequence, not a cause.

Signs you have found the divergence point:
- Upstream of this point, everything behaves as expected.
- At this point, a specific assumption breaks.
- Downstream of this point, the broken assumption cascades into the visible symptom.

Signs you have NOT found the divergence point:
- You can ask "but why is this data wrong?" and trace further upstream.
- The "cause" you identified is itself a symptom of something else.
- Fixing this point would mask the problem but not prevent it from recurring with different inputs.

## Good Traces vs. Shallow Investigation

### Good Trace

**Symptom:** Test fails with "expected 3 items, got 2."

**Trace:**
1. `getItems()` returns 2 items instead of 3.
2. `getItems()` calls `db.query('SELECT * FROM items WHERE active = true')`.
3. Query returns 2 rows. Checked database directly -- there are 3 active items.
4. Item #3 has `active = 1` (integer) while items #1 and #2 have `active = true` (boolean).
5. The migration that added item #3 used a raw INSERT with integer 1 instead of boolean true.
6. SQLite treats `WHERE active = true` as `WHERE active = 1` but PostgreSQL does not. Tests run on PostgreSQL.
7. **Root cause:** Migration uses integer 1 for boolean column. PostgreSQL strict type comparison excludes it.

This trace is thorough because it follows the data from symptom to origin, checks assumptions at each step, and identifies a root cause that explains all the evidence.

### Shallow Investigation

**Symptom:** Test fails with "expected 3 items, got 2."

**Investigation:**
1. `getItems()` returns 2 items instead of 3.
2. The query looks correct.
3. Must be a data issue. Added a third test fixture.
4. Test passes now.

This investigation is shallow because it stopped at "the query looks correct" without verifying what the query actually returns and why. The "fix" (adding a fixture) masks the real problem. The same bug will surface again when production data has the same integer-vs-boolean mismatch.

## Common Tracing Mistakes

### Stopping at the First Anomaly

You find something unexpected and declare it the root cause. But the first anomaly you find may be a red herring or a secondary effect. Keep tracing until you reach a point where everything upstream is correct.

### Trusting the Code Instead of Running It

You read the code and decide "this should work." But "should work" and "does work" are different. Run the code. Print the values. Check the actual state. Code that "should work" is the most common location for bugs.

### Skipping Layers

You trace from the API handler directly to the database, skipping the service layer and the ORM. The root cause was in the service layer -- a transformation that silently drops a field. Trace every layer. Do not skip.

### Assuming the Test is Correct

The test expects a certain behavior. The code does something different. You assume the code is wrong. But sometimes the test is wrong -- it encodes a misunderstanding of the requirements. Verify the test's expectations against the actual requirements before assuming the code is at fault.
