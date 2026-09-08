# 002 — The session rules and the trace yardstick

An audit of 72 sessions of this workspace found that the main session of a merge
carries every task of the day, edits every file itself, and holds its own output
for hours. The root `CLAUDE.md` is a synced org-pack file, so a workspace-only
rule cannot live in it. This plan adds a workspace rules file for the session
discipline, and a make target that measures the sessions, so the next change
shows its effect in numbers.

## Citations

Implements: none. The design unit does not exist yet.

This change adds one unit to [spec/workspace.md](../../spec/workspace.md) for
the session rules and the yardstick, and it sets the register row in the same
change. This plan names no new rule number, because a number exists only after
the rule lands.

## Decisions

The operator approved these on 2026-09-08. This change must not reverse one
without approval.

| #   | Decision                                                                                                                                            |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | A workspace-only rule lives in `.claude/rules/workspace.md`. The synced root `CLAUDE.md` does not change.                                           |
| 2   | One session lands one deliverable. The next deliverable starts in a new session.                                                                    |
| 3   | The main session dispatches an implementer for each work package and a fixer for each review round. The panel skill of the org pack owns that rule. |
| 4   | The main session runs at a lower effort than its agents, as a measured trial in the operator settings.                                              |
| 5   | The yardstick is `scripts/traces.pl`, with a `make traces` target.                                                                                  |

Decision 3 repeats no text of the org pack. The rules file points at the skill.

## Evidence

The audit of 2026-09-08, with three independent replications, measured each
claim below.

### One session carries several tasks

Session 3d29bae6 went from "Implement plan 004 and run the P4 campaign" to a
credential probe, a Tooling pack update, a sync to twelve repositories, and a
coherence review of the instructions, in 30 prompts. It made 351 requests and
peaked at 711k tokens. Its peak is the sum of five tasks.

### The main session holds its own output

In the four largest sessions the model's own output, thinking included, was 54
to 64 percent of the context growth, with 150k to 200k thinking tokens at effort
`xhigh`. The output stays in the context for the whole session. An agent's
output dies with the agent.

### A command without a directory reruns

The traces hold four reruns after a shell reset: "The shell cwd reset to the
workspace root, so the relative paths missed". One rerun rewrote five files of
47k characters a second time.

### The dispatcher pattern is cheap

The campaign session 6567e255 dispatched 32 agents over six hours and kept its
main context at 255k. Two implementer agents in session 3273b4ed made 115 and
123 edits while the main session held the plan.

### No tool measures a session

Every figure above came from a script in the gitignored `explore/` directory.
The next change has no number to compare against unless a tracked tool prints
one.

## Design

### The rules file

`.claude/rules/workspace.md` holds the workspace-only rules, one for each
bullet:

- One session lands one deliverable. Start a new session for the next one.
- Dispatch an implementer for each work package. Hold the plan and the ledger in
  the main session.
- Name the directory in every command, with `cd` or `make -C`. The shell resets
  between calls, and the clones sit two directories down.
- Delegate a bulk read and a whole-file write to an agent.
- Start the review stage in a new session when the context passes 300k tokens.
- Run `make check </dev/null`. A test stub drains the standard input.

Claude Code loads a rules file without a `paths` field at launch, with the
project instructions. The prose lint scans `.claude/`, so the file passes
`make check`.

### The yardstick

`scripts/traces.pl` reads the session traces of this checkout under
`~/.claude/projects/`. It derives the directory name from the checkout path. For
each session it prints the start time, the request count, the peak context, the
output tokens, the panel rounds, the main-session edits after the first panel
launch, and the sub-agent input and output totals. It reads the last record of
each request, because the first record carries a partial count. It reads the
sub-agent files under `subagents/` and `subagents/workflows/`. It uses core
modules only, `JSON::PP` included, and `use v5.36`.

`make traces` runs the script from `mk/local.mk`. The targets to hold after the
change: a peak under 300k, three panel rounds or fewer, zero main-session edits
after the first panel launch, and a reviewer under 80k tokens.

### The effort trial

The operator sets effort `high` for the main model in the user settings, and the
agent files of the org pack keep `xhigh` for the reviewer and the fixer. The
trial runs for one merge, and `make traces` records the output per request and
the peak. The quality effect is the open question, and the trial answers it with
the panel findings of that merge.

### The tests

`t/ci/traces.t` runs the script against a fixture trace directory with one
session, two requests, one panel launch, and one sub-agent file. It asserts the
peak, the round count, and the edit count.

## Work

- `.claude/rules/workspace.md`: the rules file.
- `scripts/traces.pl` and `mk/local.mk`: the yardstick and its target.
- `t/ci/traces.t`: the fixture test.
- `README.md`: the command list gains `make traces`.
- `spec/workspace.md`: the session unit.
- `spec/STATUS.md`: the row.
- Delete this plan.

## Status

### What lands now

Every item of the Work section lands now.

### What waits

The `claudeMdExcludes` trial waits for the pilot of the new panel. The setting
stops the second load of the identical project root `CLAUDE.md` in a workspace
session, and it drops the project README import with it. The pilot shows whether
the second load matters.

The effort trial is an operator step in the user settings, outside this
repository. Its record goes to the library, as a process learning.

The hooks wait for Tooling plan 005 and its pilot.

### Open questions

1. A probe must confirm that this Claude Code version loads
   `.claude/rules/workspace.md` at launch. The `/context` command lists the
   loaded files.
2. The trace directory name follows the checkout path. A worktree gets its own
   directory, so `make traces` in a worktree reports that worktree only. The
   operator confirms that this scope is the wanted one.
