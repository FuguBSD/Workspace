---
name: train
description:
  Run one training pass of one project, such as a CPT or an SFT pass. Use for
  the train stage of a campaign. Takes the absolute project path.
---

# Stage — train

This stage runs one training pass. FuguSTX and FuguTTX run a CPT pass. FuguCTX
runs none, per its decision C4, so its runbook names this stage as omitted.

1. Read `<project path>/train/RUNBOOK.md` for the verb of this stage, and for
   the pass this project runs.
2. Read `<project path>/train/config.env` for the campaign pins.
3. Confirm the lease and the watchdog are active before you start. A training
   pass that outlives its lease costs money.
4. Run the verb on one command line:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> <verb>
   ```

Report the loss at each checkpoint, the step count, the wall time, and the cost,
each from the run log and never from an estimate. The operator contract holds
the common rules.
