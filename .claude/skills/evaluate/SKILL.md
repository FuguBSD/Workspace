---
name: evaluate
description:
  Score a model of one project against its tiers or its bars. Use for the
  evaluate stage of a campaign. Takes the absolute project path.
---

# Stage — evaluate

This stage scores a model. The threshold policy differs across the three
projects, so read the specification, never a memory of it.

- FuguSTX fixes its thresholds by a baseline run.
- FuguCTX fixes its thresholds by a baseline.
- FuguTTX pre-registers its bars.

## The argument

This skill takes the absolute project path. Without it, stop and ask.

## The steps

1. State the clone and the project you read:

   ```sh
   echo "clone <project path>"; git -C <project path> rev-parse --short HEAD
   ```

2. Read `<project path>/train/RUNBOOK.md` for the verb of this stage.
3. Read `<project path>/spec/evaluation.md` for the threshold policy. The
   runbook must not restate it.
4. Run the verb from one command line, with an absolute path:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> <verb>
   ```

## The report

Report the clone, the git HEAD, the command, and the exit code. Report each tier
score against its threshold, and state which tier passed and which failed.
Report each error string in full.

Do not call a run successful when a tier failed. The observer captures the
result, and a wrong pass reaches the library.
