---
name: handover
description:
  Push the work of this session, and write the handover file in the main
  checkout. Use when the context has no room for the next deliverable, and the
  plan still holds work.
---

# handover

This skill is the warm end of a long run. [takeover](../takeover/SKILL.md) is
the cold end, and it reads what this skill writes.

An operator can remove this worktree. So the work must sit on the remote, and
the handover file must sit in the main checkout. Keep nothing here.

## The steps

1. Update the ledger of the plan.

2. Commit each change, in this repository and in each clone that holds work.
   Write a Conventional Commit message.

3. Push each of those repositories. Push `HEAD` to its own branch name, or to
   `handover-<N>` when the work sits on `main`. Never push to `main`:

   ```sh
   git push -u origin HEAD
   ```

4. Take the next free number in the main checkout, one time in this session.
   Write that same file again after each later deliverable, so one session
   leaves one handover file. A `SCRATCHPAD-*.md` file is gitignored, so the
   number is local to the checkout:

   ```sh
   MAIN=$(dirname $(git rev-parse --path-format=absolute --git-common-dir))
   ls $MAIN/SCRATCHPAD-*.md
   ```

5. Write `$MAIN/SCRATCHPAD-<N>.md` with these four sections, and nothing else:

   - **The plan.** The path of the plan, and the section that holds the ledger.
     Name the file, not a summary of it.
   - **Where to start.** One line for each repository: the path, the remote
     branch, the commit, and the pull request.
   - **What remains.** One line for each open step, in the order of the plan.
     Name each step that a human must do, and say why an agent cannot.
   - **Lessons.** One line for each thing that cost this session time. State the
     cause, not the story.

## The bounds

- The takeover can start in a clean worktree of `main`. So a fact that it needs
  must sit on the remote, or in the handover file.
- The handover holds no design and no schedule. The plan holds both.
- Keep each section under ten lines. A long handover is a plan in the wrong
  place.
- Cite a commit, a branch or a path. Never cite a memory of this session.
