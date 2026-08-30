---
name: infra
description:
  Bring the campaign infrastructure of one project up, or take it down. Use for
  the lease, the watchdog, and the make infra targets. Takes the absolute
  project path.
---

# Stage — infra

This stage brings the campaign stack up or down. Billing starts at `infra-up`
and stops at `infra-down`, so this stage owns the lease and the watchdog.

1. Read `<project path>/train/RUNBOOK.md` for the verbs this project uses.
2. Read `<project path>/infra/persistent/RUNBOOK.md` for the offer probe and
   each manual platform step.
3. Run the verb on one command line:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> infra-<verb>
   ```

Report the lease expiry and the watchdog state after an up. The operator
contract holds the common rules.
