---
name: watch
description:
  Watch a running campaign step and report what changed. Use after a stage skill
  starts a long run, to follow the lease, the cost and the log.
---

# watch

This skill follows a running step. It reads, and it changes nothing.

## What to watch

1. **The lease.** A run that outlives its lease bills by the hour. Report the
   time that is left.
2. **The log.** Read the tail of the run log. Report each new error string in
   full.
3. **The cost.** Report the cost so far, against the budget the campaign set.
4. **The watchdog.** Confirm it is active. It is the last guard against a run
   that hangs.

Run each check on one command line:

```sh
set -a; . <project path>/.env; set +a; make -C <project path> infra-status
```

Write an observation with the `note` skill as soon as you see it: a crash loses
a held observation (LIB-HOOKS-6). Take each number from the log, never from an
estimate. The operator contract holds the common rules.
