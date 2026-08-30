---
name: evaluate
description:
  Score a model of one project against its tiers or its bars. Use for the
  evaluate stage of a campaign. Takes the absolute project path.
---

# Stage — evaluate

This stage scores a model. The threshold policy differs across the three
projects, so read the specification, never a memory of it.

1. Read `<project path>/train/RUNBOOK.md` for the verb of this stage.
2. Read `<project path>/spec/evaluation.md` for the threshold policy.
3. Run the verb on one command line:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> <verb>
   ```

Report each tier score against its threshold, and state which tier passed and
which failed. Do not call a run successful when a tier failed: a wrong pass
reaches the library. The operator contract holds the common rules.
