---
name: verify
description:
  Check one claim against the run logs before it enters the library. Use for a
  claim that names a number, a cause, or a platform behavior.
---

# verify

This skill dispatches a verifier for one claim, and it records the verdict.

## The scope

Dispatch a verifier for a claim that names a number, a cause, or a platform
behavior. Any other claim enters the library with no check (LIB-VERIFY-1). That
test is the whole gate: it keeps the cost on the claims that can be wrong in a
way that matters.

## The steps

1. Take the claim and the absolute path of the run log.
2. Dispatch the `verifier` agent with both. Give it the log path, not the log
   text. It must read the log itself.
3. Record the verdict with the `note` skill, against the claim. The consolidator
   moves a confirmed claim; a refuted or an unsupported claim stays in the
   session page.
