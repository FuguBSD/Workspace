---
name: promote
description:
  Publish the artifact of a passing run of one project. Use for the promote
  stage of a campaign. Takes the absolute project path.
---

# Stage — promote

This stage publishes the artifact of a run that passed. A promote that a project
does not define is a stage you must skip, not a stage you must invent.

1. Read `<project path>/train/RUNBOOK.md`. Stop when it names this stage as
   omitted.
2. Confirm the evaluate stage passed. Do not promote a run that failed a tier.
3. Run the verb on one command line:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> <verb>
   ```

Report the artifact name and its size. The operator contract holds the common
rules.
