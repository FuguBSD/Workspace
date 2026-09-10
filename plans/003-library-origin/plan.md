# 003 — The library origin lives in `.toolingrc`

## Status

Proposed. It can land now, and it depends on no other plan. FuguBench reads the
origin of the library under the key `wiki.origin` of the nearest `.toolingrc`
that holds it, per FuguBench CLI-CHECKOUT-2 and FuguBench CLI-CONFIG-2. That key
has no default, so a session in a clone under `Projects/` finds no library until
the workspace file names it.

Extends: LIB-LIBRARY. The implementation adds one rule for the key, and it lands
the rule with the code.

The swap of `worktree.pl`, `wiki.pl`, `traces.pl`, and the four hook commands to
the FuguBench shim is a later plan of this workspace. It waits on a FuguBench
release and on the org pack of Tooling that ships the shim.

## Purpose

`wiki.pl` holds the URL of the library in its source. FuguBench reads the same
fact from `.toolingrc`, the identity file of the synced tools (Tooling D-02).
Two tools with two copies of one URL drift in silence. This plan moves the URL
into `.toolingrc` and makes `wiki.pl` read it there, so one line holds the fact
for both tools.

## Scope

In scope:

- The `wiki.origin` line of `.toolingrc`.
- The reader in `wiki.pl`, and the tests of `init` in `t/ci/wiki.t`.
- The rule in `spec/library.md`.

Out of scope:

- Every other `wiki.` key of FuguBench. Each one has a default that matches this
  workspace: `Wiki`, `Projects`, and the name of the root directory.
- The swap to the shim. It is the later plan above.

## Constraints that shape the design

**A hook must never stop a session.** LIB-HOOKS and LIB-WIKI-4 hold. When the
key is absent, `init` warns and exits zero, as a failed clone does today. The
session then starts without a library, and `status` reports the absence.

**The reader stays small.** `wiki.pl` reads `<root>/.toolingrc` line by line: a
key, whitespace, a value, and a `#` comment. It takes the `wiki.origin` line and
ignores every other line. A URL without a scheme is an error that names the key.

**The root of the key is the checkout root.** `wiki.pl` finds its root as the
nearest directory that holds `.git` and the script. A worktree is such a root,
and it holds its own copy of `.toolingrc`. A session in a worktree reads the
same line.

**No test reaches the network.** Each `init` test writes a `.toolingrc` into its
fixture checkout, with a bare repository of the temporary tree as the origin.

## The interface contract

`.toolingrc` gains the line `wiki.origin https://github.com/FuguBSD/Wiki.git`.

`wiki.pl init` reads the key from `<root>/.toolingrc`. With the key, it clones
the URL into `Wiki/` when the directory is absent. Without the key, or without
the file, it warns `no wiki.origin in .toolingrc` and exits zero. Every other
subcommand changes nothing.

The new rule of LIB-LIBRARY reads: "`.toolingrc` must name the origin of the
library under `wiki.origin`. Each library tool must read the URL there, and no
tool holds it in its source." A plan names no rule number, because a number
exists after the rule lands.

## Files

| File              | Change                                               |
| ----------------- | ---------------------------------------------------- |
| `.toolingrc`      | The `wiki.origin` line                               |
| `scripts/wiki.pl` | The reader, in place of the constant                 |
| `t/ci/wiki.t`     | The `init` tests below                               |
| `spec/library.md` | The rule of LIB-LIBRARY                              |
| `spec/STATUS.md`  | The LIB-LIBRARY note names `.toolingrc` and `wiki.t` |

## Tests

`t/ci/wiki.t` builds a fixture checkout with a bare origin. It gains:

- `init` with a `.toolingrc` that names the bare origin clones it into `Wiki/`,
  and a second run changes nothing.
- `init` without the key warns with the key name and exits zero, and no `Wiki/`
  appears.
- `init` with a value that holds no scheme fails with a message that names the
  key.
- A `#` comment and a line of another tool change nothing.
- The tracked `.toolingrc` holds one `wiki.origin` line, and its value is the
  URL of `FuguBSD/Wiki`.

## Acceptance

- `make check` passes.
- `grep -c 'github.com/FuguBSD/Wiki' scripts/wiki.pl` prints 0.
- `make bootstrap` in a fresh worktree clones the library as before.
- LIB-LIBRARY stays `done`, and its note names the two files.
- The change deletes this plan.

## Open questions

None. The key name and its shape come from the FuguBench specification, which
the operator approved on 2026-09-10.
