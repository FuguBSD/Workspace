---
name: promote
description:
  Publish the artifact of a passing run of one project. Use for the promote
  stage of a campaign. Takes the absolute project path.
---

# Stage — promote

This stage publishes the artifact of a run that passed. The three projects
differ here more than anywhere else.

- FuguSTX copies the GGUF, per its rule TRN-EXEC-5.
- FuguCTX has no promote step.
- FuguTTX has no promote step. Its variant rule VAR-PROMOTE sits under its
  decision D5.

So read the runbook first. A promote that a project does not define is a stage
you must skip, not a stage you must invent.

## The argument

This skill takes the absolute project path. Without it, stop and ask.

## The steps

1. State the clone and the project you read:

   ```sh
   echo "clone <project path>"; git -C <project path> rev-parse --short HEAD
   ```

2. Read `<project path>/train/RUNBOOK.md`. Stop when it names this stage as
   omitted.
3. Confirm the evaluate stage passed. Do not promote a run that failed a tier.
4. Run the verb from one command line, with an absolute path:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> <verb>
   ```

## The report

Report the clone, the git HEAD, the command, and the exit code. Report the
artifact name and its size. Report each error string in full.

Do not report a bucket suffix. The library is public, and LIB-CONTENT-1 forbids
one.
