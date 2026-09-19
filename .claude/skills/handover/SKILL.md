---
name: handover
description:
  Write a handover scratchpad, so a cold session can keep driving the plan of
  this session. Use when a session ends and the plan still holds work.
---

# Handover

Write one `SCRATCHPAD-<N>.md` at the checkout root. It is the warm end of a long
run. [takeover](../takeover/SKILL.md) is the cold end, and it reads what this
skill writes.

## The rule

The handover holds no design and no schedule. The originating plan holds both.
The handover points at the plan, and it states what is left of it. The plan owns
the state, so update the ledger of the plan as well.

## The steps

1. Take the next free number. A `SCRATCHPAD-*.md` file is gitignored, so the
   number is local to the checkout:

   ```sh
   ls SCRATCHPAD-*.md
   ```

2. Write `SCRATCHPAD-<N>.md` with these five sections, in this order, and
   nothing else:

   - **The plan.** The path of the originating plan, and the section of it that
     holds the ledger. Name the file, not a summary of it.
   - **What landed.** One line for each merged change, with its commit and its
     pull request.
   - **What remains.** One line for each open step, in the order of the plan.
     Name each step that a human must do, and say why an agent cannot.
   - **Lessons.** One line for each thing that cost this session time. State the
     cause, not the story.
   - **How to resume.** The first three commands of the next session.

3. Update the ledger of the originating plan in the same run.

## The bounds

- Write the one file, and update the one ledger. Merge nothing.
- Keep each section under ten lines. A long handover is a plan in the wrong
  place.
- Cite a commit, a path or a run. Never cite a memory of this session.
