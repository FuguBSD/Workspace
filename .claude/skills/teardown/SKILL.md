---
name: teardown
description:
  Release the campaign infrastructure of one project and confirm the spend
  stops. Use at the end of a campaign, and after a failure. Takes the absolute
  project path.
---

# Stage — teardown

This stage releases the infrastructure. Run it at the end of a campaign, and run
it after a failure too. An instance that stays up bills by the hour.

1. Read `<project path>/train/RUNBOOK.md` for the verb of this stage, and
   `<project path>/infra/persistent/RUNBOOK.md` for each manual step.
2. Run the verb on one command line:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> infra-<verb>
   ```

3. Confirm the release. List the resources that stay, and state why each one
   stays. A persistent resource is normal; a running instance is not.

Report each resource that stays, and the total cost of the campaign. The
operator contract holds the common rules.
