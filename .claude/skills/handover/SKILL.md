---
name: handover
description:
  Write a handover scratchpad, so a cold session can keep driving the plan of
  this session. Use when a session ends and the plan still holds work.
---

# Handover

Write one `SCRATCHPAD-<N>.md` at the checkout root. A cold session reads that
file, finds the originating plan, and keeps driving it.

## The rule

The handover holds no design and no schedule. The originating plan holds both.
The handover points at the plan, and it states what is left of it.

## The steps

1. Take the next free number. `SCRATCHPAD-*.md` files are gitignored, so the
   number is local to the checkout:

   ```sh
   ls SCRATCHPAD-*.md
   ```

2. Write `SCRATCHPAD-<N>.md` with these five sections, and nothing else:

   - **The plan.** The path of the originating plan, and the section of it that
     holds the ledger. Name the file, not a summary of it.
   - **What landed.** One line for each merged change, with its commit and its
     pull request.
   - **What remains.** One line for each step that is open, in the order of the
     plan. Name each step that a human must do, and say why an agent cannot.
   - **Lessons.** One line for each thing that cost this session time. State the
     cause, not the story.
   - **How to resume.** The first three commands of the next session.

3. Update the ledger of the originating plan in the same run. The handover
   repeats the state; the plan owns it.

## The bounds

- Write the file. Change no repository file, and merge nothing.
- Keep each section under ten lines. A long handover is a plan in the wrong
  place.
- A cold session must need this file and the plan alone. Cite a commit, a path
  or a run, and never a memory of this session.
