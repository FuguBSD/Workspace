# Workspace specification

The workspace holds a local clone of every FuguBSD project under `Projects/`,
and the learning library at `Wiki/`. It manages git worktrees for parallel
agents. This repository tracks the workspace-level files only.

This document is the entry point of the specification. It holds the plan
contract, the ID conventions, and the document tables.

## Plan contract

- Read [DECISIONS.md](DECISIONS.md) before you make a plan.
- A plan must cite each unit that it implements, for example
  `Implements: WS-WORKTREE`.
- A plan can exclude a rule from a cited unit with `without`, for example
  `Implements: WS-WORKTREE without WS-WORKTREE-4`.
- A plan must cite each unit that it touches but defers, for example
  `Defers: WS-CLONE`.
- The change that implements a unit, or a part of a unit, must set the state of
  the unit in [STATUS.md](STATUS.md) in the same change.

<a id="conventions"></a>

## Conventions

The ID overlay lives in [spec/CLAUDE.md](CLAUDE.md): the unit anchors, the rule
shape, the append-only numbers, the retire procedure, and the citation forms.

## Specification documents

Each document specifies one area of work. The code of a document prefixes the
IDs of its units.

| Code | Document                     | Area                                      |
| ---- | ---------------------------- | ----------------------------------------- |
| WS   | [workspace.md](workspace.md) | Clones, worktrees, and bootstraps         |
| LIB  | [library.md](library.md)     | The learning library and the observer set |

## Governance documents

These documents carry no units.

| Document                     | Role                                                  |
| ---------------------------- | ----------------------------------------------------- |
| [DECISIONS.md](DECISIONS.md) | The decisions. A plan must not go against a decision. |
| [ROADMAP.md](ROADMAP.md)     | The schedule of the work.                             |
| [STATUS.md](STATUS.md)       | The implementation register.                          |
