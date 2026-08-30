---
name: corpus
description:
  Build or sync the training data of one project. Use for the corpus stage of a
  campaign. Takes the absolute project path.
---

# Stage — corpus

This stage builds or syncs the data that a campaign trains on. Each project
names it differently, so the runbook holds the map.

## The argument

This skill takes the absolute project path. Without it, stop and ask.

## The steps

1. State the clone and the project you read:

   ```sh
   echo "clone <project path>"; git -C <project path> rev-parse --short HEAD
   ```

2. Read `<project path>/train/RUNBOOK.md` for the verb of this stage. The
   runbook names the stage a project omits.
3. Read `<project path>/train/config.env` for the campaign pins and the shared
   names. The runbook must not restate them.
4. Run the verb from one command line, with an absolute path:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> <verb>
   ```

   The export is not optional. The `env` block of the checkout shadows every
   project key (D-05).

## The report

Report the clone, the git HEAD, the command, the exit code, and the counts the
run printed: the document count, the token count, and each split size. Report
each error string in full.
