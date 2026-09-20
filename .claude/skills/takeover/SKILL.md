---
name: takeover
description:
  Read the newest handover file in the main checkout, restore the work, and
  continue the plan. Use at the start of a cold session that continues a run.
---

# takeover

This skill is the cold end of a long run. [handover](../handover/SKILL.md) is
the warm end, and it writes the four sections that this skill reads.

This session can start in a clean worktree of `main`. So the work comes from the
remote, and the handover file names each branch.

## The steps

1. Read the newest `SCRATCHPAD-<N>.md` in the main checkout. The highest number
   is the newest:

   ```sh
   MAIN=$(dirname $(git rev-parse --path-format=absolute --git-common-dir))
   ls $MAIN/SCRATCHPAD-*.md
   ```

2. Restore each repository that "Where to start" names:

   ```sh
   git -C <path> fetch origin
   git -C <path> checkout <branch>
   ```

3. Prove the state before you trust it. Confirm that each commit sits where the
   file says. A handover can be stale, and the repository decides.

4. Open the plan that "The plan" names, and read its ledger. Correct the ledger
   before you start when it disagrees with the repository.

5. Take the open steps of the plan, in the order of the plan. Stop at a step
   that "What remains" marks for a human, and report it.

## The bounds

- Do not re-plan. The plan holds the design and the order, and this skill
  changes neither.
- Do not repeat landed work. A merged commit is done.
- Read the Lessons before the first dispatch. They name what already cost the
  run time.
