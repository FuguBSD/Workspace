---
name: train
description:
  Run one training pass of one project, such as a CPT or an SFT pass. Use for
  the train stage of a campaign. Takes the absolute project path.
---

# Stage — train

This stage runs one training pass. FuguSTX and FuguTTX run a CPT pass. FuguCTX
runs none, per its decision C4, so its runbook names this stage as omitted.

## The argument

This skill takes the absolute project path. Without it, stop and ask.

## The steps

1. State the clone and the project you read:

   ```sh
   echo "clone <project path>"; git -C <project path> rev-parse --short HEAD
   ```

2. Read `<project path>/train/RUNBOOK.md` for the verb of this stage, and for
   the pass this project runs.
3. Read `<project path>/train/config.env` for the campaign pins.
4. Confirm the lease and the watchdog are active before you start. A training
   pass that outlives its lease costs money.
5. Run the verb from one command line, with an absolute path:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> <verb>
   ```

## The report

Report the clone, the git HEAD, the command, and the exit code. Report the loss
at each checkpoint, the step count, the wall time, and the cost. Report each
error string in full.

A number in your report can become a claim. So take each number from the run
log, never from an estimate.
