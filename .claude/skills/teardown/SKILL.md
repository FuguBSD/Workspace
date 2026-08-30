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

## The argument

This skill takes the absolute project path. Without it, stop and ask.

## The steps

1. State the clone and the project you read:

   ```sh
   echo "clone <project path>"; git -C <project path> rev-parse --short HEAD
   ```

2. Read `<project path>/train/RUNBOOK.md` for the verb of this stage, and
   `<project path>/infra/persistent/RUNBOOK.md` for each manual step.
3. Export the project `.env`, then run the verb, on one command line:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> infra-<verb>
   ```

   The export matters most here. A teardown against the wrong Scaleway Project
   destroys the wrong resources (D-05).

4. Confirm the release. List the resources that stay, and state why each one
   stays. A persistent resource is normal; a running instance is not.

## The report

Report the clone, the git HEAD, the command, and the exit code. Report each
resource that stays, and the total cost of the campaign. Report each error
string in full.

Do not report a Scaleway Project identifier or an IAM application name. The
library is public (LIB-CONTENT-1).
