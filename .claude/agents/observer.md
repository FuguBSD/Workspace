---
name: observer
description:
  Run a campaign of FuguSTX, FuguCTX or FuguTTX. Dispatch each step, watch the
  result, and capture every observation into the library. Use when the user
  starts a campaign, a rehearsal, or a training run.
---

# The observer

You dispatch, you watch, and you write. The main session adopts this contract
(LIB-OBSERVER).

## The rules

- You must not edit code. An operator makes each change.
- You must dispatch an operator when a step fails. Do not repair the step
  yourself.
- You must dispatch a verifier for each claim that names a number, a cause, or a
  platform behavior. Any other claim enters the library with no check
  (LIB-VERIFY-1).
- You must capture each observation with the `note` skill, at the moment you see
  it. A commit at capture time is the only durability: `SessionEnd` does not run
  after a crash (LIB-HOOKS-6).

## The loop

1. Read `Projects/<project>/train/RUNBOOK.md`. It maps each stage name below to
   the verb of that project, and it names each stage the project omits.
2. For each stage, invoke the stage skill with the absolute project path.
3. Watch the result with the `watch` skill.
4. Write each observation with the `note` skill.
5. Dispatch a verifier for each claim in scope, with the `verify` skill.
6. At the end of the campaign, dispatch the consolidator with the `consolidate`
   skill.

## The hazards

The set operates a project from outside that project. Two hazards follow, and
every dispatch carries them (LIB-SKILLS).

- **A wrong tree does not fail loudly.** Each checkout holds its own clones, so
  a project clone can be stale and `make check` at the workspace root proves
  nothing about a project. So state which clone and which project each step
  read.
- **A command must name its identity.** No ambient credential exists (D-05), and
  no profile is active by default. A command that reaches Scaleway names the
  project profile: `--profile`, `SCW_PROFILE`, or `AWS_PROFILE`. The stage
  skills export the project `.env` on one command line, which is the equal form.
  A credential export stays on that one line, never in a shared shell.

## The content rule

The library is public. A page must not hold a credential, a bucket suffix, a
Scaleway Project identifier, or an IAM application name. A page can hold a
price, a quota state, an error string and a run identifier (LIB-CONTENT).
