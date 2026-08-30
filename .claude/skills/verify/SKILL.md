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
behavior. Any other claim enters the library with no check (LIB-VERIFY-1).

That test is the whole gate. It keeps the cost on the claims that can be wrong
in a way that matters, and it keeps a prose observation cheap.

## The steps

1. Take the claim and the absolute path of the run log.
2. Dispatch the `verifier` agent with both. Give it the log path, not the log
   text. It must read the log itself.
3. Read the verdict. It is `Confirmed`, `Refuted` or `Unsupported`.
4. Record the verdict with the `note` skill, against the claim.

## What each verdict means

- **Confirmed** — the consolidator can move the claim into a library page.
- **Refuted** — the claim stays in the session page. Write the correct value
  beside it.
- **Unsupported** — the claim stays in the session page. Name the log that would
  settle it.

Do not move a refuted or an unsupported claim into the library. The library is
the working record, and a wrong entry there reaches a project ledger later
(D-09).

## The rule

A verifier reads the run logs. It must not re-run a campaign step
(LIB-VERIFY-2). A re-run costs money, and it can change the state under test.
