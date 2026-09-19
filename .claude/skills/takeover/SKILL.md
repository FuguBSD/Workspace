---
name: takeover
description:
  Read the newest handover scratchpad, and keep driving the plan that it names.
  Use at the start of a cold session that continues a long run.
---

# Takeover

Read the newest `SCRATCHPAD-<N>.md` at the checkout root. Take the first open
step of the plan that it names. It is the cold end of a long run.
[handover](../handover/SKILL.md) is the warm end, and it writes the five
sections that this skill reads.

## The rule

The scratchpad orients you, and the plan commands you. The handover repeats the
state, and the plan owns it. When the two disagree, the repository decides, and
you correct the ledger of the plan before you start.

## The steps

1. Take the newest file. The highest number is the newest:

   ```sh
   ls SCRATCHPAD-*.md
   ```

2. Read its five sections in order, then open the plan that "The plan" names.
   Read the ledger of the plan.

3. Prove the state before you trust it. For each row that the ledger calls
   merged, confirm the commit sits on `main`. A handover can be stale, and a
   sibling repository can have merged since.

4. Take the first open step of the plan, in the order of the plan. Stop at a
   step that "What remains" marks for a human, and report it.

5. Run "How to resume", then follow the session recipe of the plan.

## The bounds

- Do not re-plan. The plan holds the design and the order, and this skill
  changes neither.
- Do not repeat landed work. A merged commit is done.
- Read the Lessons before the first dispatch. They name what already cost the
  run time.
