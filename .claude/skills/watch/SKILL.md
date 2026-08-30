---
name: watch
description:
  Watch a running campaign step and report what changed. Use after a stage skill
  starts a long run, to follow the lease, the cost and the log.
---

# watch

This skill follows a running step. It reads, and it changes nothing.

## The argument

This skill takes the absolute project path. Without it, stop and ask.

## What to watch

1. **The lease.** A run that outlives its lease bills by the hour. Read the
   lease expiry, and report the time that is left.
2. **The log.** Read the tail of the run log. Report each new error string in
   full.
3. **The cost.** Report the cost so far, against the budget the campaign set.
4. **The watchdog.** Confirm it is active. A teardown watchdog is the last guard
   against a run that hangs.

Run each command with an absolute path, and export the project `.env` first:

```sh
set -a; . <project path>/.env; set +a; make -C <project path> infra-status
```

## The report

State the clone you read and its git HEAD. Then report the four items above.

Write an observation with the `note` skill as soon as you see it. Do not hold
observations until the run ends: a crash loses them (LIB-HOOKS-6).

A number that you report can become a claim, and a verifier checks it. So take
each number from the log, never from an estimate.
