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

- Every other `wiki.` key of FuguBench. Each one keeps its default here. The
  later shim plan sets `wiki.project Workspace`, because `wiki.pl` names a root
  session `Workspace` today.
- The swap to the shim. It is the later plan above.

## Constraints that shape the design

**The hook keeps the session alive.** When the key is absent, `cmd_init` dies
with a message that names `wiki.origin`. `main` maps that die to exit 3, the
configuration error of FuguBench CLI-PROGRAM-5. `main` calls `cmd_init` outside
an `eval` today, so the implementation adds the mapping there. The `eval` of
`hook-start` catches the die and warns, so the session starts without a library.
`status` reports the absence, and LIB-HOOKS and LIB-WIKI-4 hold.

**The reader stays small.** `wiki.pl` reads `<root>/.toolingrc` line by line: a
key, whitespace, a value, and a `#` comment. It takes the `wiki.origin` line and
ignores every other line. A value without a scheme stops `init` the same way,
with an error that names the key.

**The root of the key is the checkout root.** `wiki.pl` finds its root as the
nearest directory that holds `.git` and the script. A worktree is such a root,
and it holds its own copy of `.toolingrc`. A session in a worktree reads the
same line.

**No test reaches the network.** Each `init` test writes a `.toolingrc` into its
fixture checkout, with a bare repository of the temporary tree as the origin.
Each fixture names that origin as a `file://` URL, so the scheme check passes.

## The interface contract

`.toolingrc` gains the line `wiki.origin https://github.com/FuguBSD/Wiki.git`.

When `Wiki/` exists, `wiki.pl init` changes nothing and reads no key. Otherwise
it reads `wiki.origin` from `<root>/.toolingrc`, then clones the URL into
`Wiki/`. Without the key, or without the file, it stops with a configuration
error and exit 3. The message names `wiki.origin`. A value without a scheme
stops the same way. Every other subcommand changes nothing.

LIB-LIBRARY gains this rule: "`.toolingrc` must name the origin of the library
under `wiki.origin`, and each library tool must read the URL there. A tool must
stop with an error that names the key when the key is absent or its value holds
no scheme." A plan names no rule number, because a number exists after the rule
lands.

## Files

| File              | Change                                                                                                                                                                        |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.toolingrc`      | The `wiki.origin` line                                                                                                                                                        |
| `scripts/wiki.pl` | The reader, in place of the constant                                                                                                                                          |
| `t/ci/wiki.t`     | The `init` tests below                                                                                                                                                        |
| `spec/library.md` | The rule of LIB-LIBRARY                                                                                                                                                       |
| `spec/STATUS.md`  | The LIB-LIBRARY note names `.toolingrc` and `wiki.t`. The `library.md` row of Code roots gains `.toolingrc`, and the intro sentence of Code roots adds it to the shared roots |

## Tests

`t/ci/wiki.t` builds a fixture checkout with a bare origin. It gains:

- `init` with a `.toolingrc` that names the bare origin as a `file://` URL
  clones it into `Wiki/`, and a second run changes nothing.
- `init` with a present `Wiki/` and no key exits 0 and changes nothing.
- `init` without the key exits 3 with a message that names the key, and no
  `Wiki/` appears.
- `init` without a `.toolingrc` exits 3 with a message that names the key.
- `init` with a value that holds no scheme exits 3 the same way.
- A `#` comment and a line of another tool change nothing.
- The tracked `.toolingrc` holds one `wiki.origin` line, and its value is the
  URL of `FuguBSD/Wiki`.

## Acceptance

- `make check` passes.
- `grep -c 'github.com/FuguBSD/Wiki' scripts/wiki.pl` prints 0.
- `make clone` in the main checkout clones the library as before.
- LIB-LIBRARY stays `done`, and its note names the two files. The `library.md`
  row of Code roots names `.toolingrc`.
- The change deletes this plan.

## Open questions

None. The key name and its shape come from the FuguBench specification, which
the operator approved on 2026-09-10.
