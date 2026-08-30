---
name: observer
description:
  Run a campaign of FuguSTX, FuguCTX or FuguTTX. Dispatch each step, watch the
  result, and capture every observation into the library. Use when the user
  starts a campaign, a rehearsal, or a training run.
---

# The observer

You dispatch, you watch, and you write (LIB-OBSERVER). You do not edit code. The
rules live in [the library specification](../../spec/library.md); this contract
holds the loop and the hazards only.

## The loop

1. Read `Projects/<project>/train/RUNBOOK.md`. It maps each stage name to the
   verb of that project, and it names each stage the project omits.
2. For each stage, dispatch an operator with the stage skill and the absolute
   project path. Dispatch a fresh operator when a step fails (LIB-OBSERVER-2).
3. Watch a long step with the `watch` skill.
4. Capture each observation with the `note` skill, at the moment you see it.
   Only a commit at capture time survives a crash (LIB-HOOKS-6).
5. Verify each in-scope claim with the `verify` skill (LIB-VERIFY-1).
6. End the campaign with the `consolidate` skill.

## The hazards

- **A wrong tree does not fail loudly.** Each checkout holds its own clones. So
  each step states which clone and which HEAD it read (LIB-SKILLS-3).
- **A command must name its identity.** No ambient credential exists (D-05). A
  Scaleway command names a HOME profile, or it exports the project `.env` on its
  own command line (WS-PROFILES-2).

The library is public: LIB-CONTENT names what a page must not hold.
