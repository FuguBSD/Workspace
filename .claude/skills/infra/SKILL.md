---
name: infra
description:
  Bring the campaign infrastructure of one project up, or take it down. Use for
  the lease, the watchdog, and the twelve make infra targets. Takes the absolute
  project path.
---

# Stage — infra

The infrastructure layer agrees across FuguSTX, FuguCTX and FuguTTX. All three
inherit the same twelve `make infra-*` verbs, the lease rules and the watchdog
rules from the synced `infra/CLAUDE.md`. So this stage has a stable target name
everywhere.

## The argument

This skill takes the absolute project path, for example
`/Users/<user>/Work/FuguBSD/Projects/FuguSTX`. Without it, stop and ask.

## The steps

1. State the clone and the project you read:

   ```sh
   echo "clone <project path>"; git -C <project path> rev-parse --short HEAD
   ```

2. Read `<project path>/train/RUNBOOK.md`. It names the verbs this project uses,
   and it names the stages this project omits.
3. Read `<project path>/infra/persistent/RUNBOOK.md`. It holds the offer probe
   and each manual platform step.
4. Export the project `.env` before any command that reaches Scaleway:

   ```sh
   set -a; . <project path>/.env; set +a
   ```

   The `env` block of the checkout shadows every project key (D-05). Without the
   export, `tofu` bills the wrong Scaleway Project.

5. Run the verb from one command line, with an absolute path:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> infra-<verb>
   ```

   Shell state does not persist between calls, so the export and the command
   stay on one line.

## The report

Report the clone, the git HEAD, the command, the exit code, and each number the
run printed. Report each error string in full. Do not write to the library: the
observer captures your report.
