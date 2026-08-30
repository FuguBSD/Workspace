# Implementation register

This register is the one record of implementation state. One row exists for each
unit of the specification. A unit is one design element of one specification
document. The [conventions](index.md#conventions) define the unit IDs. Each row
describes the current state only. A row must not carry a plan name or a
reference to an earlier state. A note can carry the date of a recorded fact.

## States

| State   | Meaning                                                              |
| ------- | -------------------------------------------------------------------- |
| open    | No code implements the unit.                                         |
| partial | Code implements a part of the unit. The note names each absent part. |
| done    | Code implements the full unit. The note links the code or the tests. |
| n-a     | No code can implement the unit. It exists for citation only.         |

The "Done by" column names a phase of the [roadmap](ROADMAP.md), or "—" when no
phase applies.

## Units

| Unit                                      | State   | Done by | Note                                                                                                              |
| ----------------------------------------- | ------- | ------- | ----------------------------------------------------------------------------------------------------------------- |
| [WS-LAYOUT](workspace.md#ws-layout)       | partial | —       | [.gitignore](../.gitignore), [.toolingrc](../.toolingrc). Absent: the remote and the CI of WS-LAYOUT-1.           |
| [WS-CLONE](workspace.md#ws-clone)         | done    | —       | [local.mk](../mk/local.mk)                                                                                        |
| [WS-BOOTSTRAP](workspace.md#ws-bootstrap) | done    | —       | [local.mk](../mk/local.mk), [worktree.pl](../scripts/worktree.pl)                                                 |
| [WS-ENVSYNC](workspace.md#ws-envsync)     | done    | —       | [worktree.pl](../scripts/worktree.pl), [envsync.t](../t/ci/envsync.t)                                             |
| [WS-WORKTREE](workspace.md#ws-worktree)   | done    | —       | [worktree.pl](../scripts/worktree.pl), [worktree.t](../t/ci/worktree.t)                                           |
| [WS-HOOKS](workspace.md#ws-hooks)         | done    | —       | [settings.json](../.claude/settings.json)                                                                         |
| [LIB-LIBRARY](library.md#lib-library)     | open    | —       | The repository `FuguBSD/Wiki` is not created yet.                                                                 |
| [LIB-PAGES](library.md#lib-pages)         | done    | —       | [wiki.pl](../scripts/wiki.pl), [wiki.t](../t/ci/wiki.t)                                                           |
| [LIB-CONTENT](library.md#lib-content)     | n-a     | —       | A prose rule for an author. The `gitleaks` gate of LIB-LIBRARY-2 catches a key pattern only.                      |
| [LIB-ENTRY](library.md#lib-entry)         | partial | —       | [consolidate](../.claude/skills/consolidate/SKILL.md). Absent: LIB-ENTRY-5, the migration of the FuguSTX entries. |
| [LIB-WIKI](library.md#lib-wiki)           | done    | —       | [wiki.pl](../scripts/wiki.pl), [wiki.t](../t/ci/wiki.t)                                                           |
| [LIB-HOOKS](library.md#lib-hooks)         | done    | —       | [settings.json](../.claude/settings.json)                                                                         |
| [LIB-OBSERVER](library.md#lib-observer)   | done    | —       | [observer.md](../.claude/agents/observer.md)                                                                      |
| [LIB-VERIFY](library.md#lib-verify)       | done    | —       | [verifier.md](../.claude/agents/verifier.md), [verify](../.claude/skills/verify/SKILL.md)                         |
| [LIB-SKILLS](library.md#lib-skills)       | done    | —       | [.claude/skills](../.claude/skills)                                                                               |
| [LIB-RUNBOOK](library.md#lib-runbook)     | partial | —       | The three runbooks exist. Absent: LIB-RUNBOOK-3, the runbook gate that each project owns.                         |
| [LIB-CANDIDATE](library.md#lib-candidate) | done    | —       | [local.mk](../mk/local.mk)                                                                                        |

## Update protocol

1. The change that implements a unit, or a part of a unit, sets the state of the
   unit in this register, in the same change.
2. A `partial` note names each absent rule or part.
3. A `done` note holds at least one relative link to code or to tests.

## Code roots

The drift gate maps each document to the code that implements it. Two documents
share the `scripts`, `mk` and `.claude/settings.json` roots, so each row names
the paths that its document owns.

| Document     | Roots                                                                                                                 |
| ------------ | --------------------------------------------------------------------------------------------------------------------- |
| workspace.md | `scripts/worktree.pl`, `mk`, `.claude/settings.json`, `.gitignore`, `.toolingrc`, `t/ci/envsync.t`, `t/ci/worktree.t` |
| library.md   | `scripts/wiki.pl`, `mk`, `.claude/settings.json`, `.claude/agents`, `.claude/skills`, `t/ci/wiki.t`                   |

## Retired IDs

| ID  |
| --- |
