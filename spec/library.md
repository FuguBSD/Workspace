# The learning library

One set of agents and skills operates every campaign of FuguSTX, FuguCTX and
FuguTTX. A shared git repository holds the learnings. The set lives in this
workspace checkout, because it operates a project from outside that project
(D-08).

Two records split the work. The library holds every observation and every
admitted claim. A project ledger holds one delivered batch for each campaign
(D-09).

<a id="lib-library"></a>

## The library repository

- **LIB-LIBRARY-1** — The library must be the git repository `FuguBSD/Wiki`,
  cloned at `Wiki/` in each checkout, a sibling of `Projects/` (D-07).
- **LIB-LIBRARY-2** — The library must consume the `org` pack of
  FuguBSD/Tooling, so CI runs `ste-lint` and `gitleaks` on each push.
- **LIB-LIBRARY-3** — A CI failure must report only. It must not block a push,
  because capture stays cheap and the gate stays advisory.
- **LIB-LIBRARY-4** — A ruleset must forbid a force push, so the library stays
  append-only by rule. A ruleset needs a public repository on the Free plan of
  the org (Repositories SET-RULESETS-3).

<a id="lib-pages"></a>

## Pages

- **LIB-PAGES-1** — Pages must stay flat. The page name carries the structure,
  and no subdirectory holds a page.
- **LIB-PAGES-2** — The page names are `Library-<project>-<component>`,
  `Session-<project>-<date>-<n>`, `Rule-candidates` and `Process`.
- **LIB-PAGES-3** — A page name must not start with `SCRATCHPAD`, because the
  `ste-lint` file walk skips that prefix.
- **LIB-PAGES-4** — One session can drive several runs. So a run identifier
  lives inside a session page, and never in a page name.
- **LIB-PAGES-5** — The `Process` page holds the process learnings, and the
  `Rule-candidates` page holds each candidate rule with its date.

<a id="lib-content"></a>

## The content rule

The library is public, so its content needs a rule. The `gitleaks` gate catches
a key pattern, and it catches no identifier.

- **LIB-CONTENT-1** — A page must not hold a credential, a bucket suffix, a
  Scaleway Project identifier, or an IAM application name.
- **LIB-CONTENT-2** — A page can hold a price, a quota state, an error string
  and a run identifier.

<a id="lib-entry"></a>

## The two stores

- **LIB-ENTRY-1** — The session scratchpad page must take every raw observation,
  live, with no gate.
- **LIB-ENTRY-2** — A library page must take a claim after the verifier passes
  it. A claim that LIB-VERIFY-1 puts out of scope enters at once.
- **LIB-ENTRY-3** — An entry must hold a bold claim, the evidence, a `Scope:`
  sentence, and a `Maps to:` list of FuguTTX units.
- **LIB-ENTRY-4** — The consolidator writes the library at the end of a session.
- **LIB-ENTRY-5** — A migrated entry must keep its date and its run identifier.
  A migration must not state a claim that the source entry does not make.

<a id="lib-wiki"></a>

## `scripts/wiki.pl`

One Perl program operates the library, as `scripts/worktree.pl` operates a
worktree. It uses core modules only and `use v5.34`. The `-C <checkout>` option
names the checkout that holds the clone.

| Subcommand                 | Action                                               |
| -------------------------- | ---------------------------------------------------- |
| `init`                     | Clone `FuguBSD/Wiki` into `Wiki/` when it is absent. |
| `open <project> <session>` | Start the session page, commit, then push.           |
| `note <page> <file>`       | Append one observation, commit, then push.           |
| `admit <page> <file>`      | Append an admitted claim, commit, then push.         |
| `close <session>`          | Commit a remainder, mark the page closed, then push. |
| `status`                   | Report the open sessions and the unpushed commits.   |
| `candidates`               | Report each undelivered rule candidate with its age. |
| `hook-start`, `hook-end`   | Do the work of one session hook, from a payload.     |

- **LIB-WIKI-1** — Each capture subcommand must commit, and then push. The
  commit carries durability, and the push carries visibility.
- **LIB-WIKI-2** — A failed push must not stop a capture. The subcommand must
  warn and exit zero, so a network failure loses no observation.
- **LIB-WIKI-3** — On a rejected push, wiki.pl must fetch, rebase and retry. It
  must never force a push, because LIB-LIBRARY-4 forbids one.
- **LIB-WIKI-4** — A second run of `init` or `open` must cause no change.
- **LIB-WIKI-5** — `status` must report each open session, each unadmitted
  claim, and each unpushed commit. It must not count an empty page as an open
  session.
- **LIB-WIKI-6** — `wiki.pl` must write only inside the `Wiki/` clone of the
  checkout that `-C` names.

<a id="lib-hooks"></a>

## The session hooks

- **LIB-HOOKS-1** — `SessionStart` must run `init`, and then `open`.
  `SessionEnd` must run `close`.
- **LIB-HOOKS-2** — Each hook must derive the checkout root from the session
  path, because a session can start in a worktree. It must cut at the last
  `.claude/worktrees/` marker (WS-HOOKS-4).
- **LIB-HOOKS-3** — A hook must exit at once when the payload holds `agent_id`.
  That payload is a sub-agent, and an observer dispatches many. Without this
  test, each operator and each verifier opens its own page.
- **LIB-HOOKS-4** — The `SessionEnd` hook must set an explicit `timeout`.
  `SessionEnd` hooks share a 1.5-second budget, and a commit with a push does
  not fit it. A longer per-hook timeout raises the budget.
- **LIB-HOOKS-5** — `SessionStart` fires for every session, and a session can
  run no campaign. So `open` must stay cheap and idempotent.
- **LIB-HOOKS-6** — `SessionEnd` does not fire on an abnormal stop. So every
  observation must reach a commit at capture time, through `note`. `close` adds
  no durability of its own.

<a id="lib-observer"></a>

## The observer set

The contract lives in `.claude/agents/observer.md`, and the main session adopts
it.

| Agent          | Role                                          |
| -------------- | --------------------------------------------- |
| `observer`     | Dispatches, watches and captures.             |
| `operator`     | Runs one campaign step. Full tools.           |
| `verifier`     | Checks one claim against the run logs.        |
| `consolidator` | Merges a session scratchpad into the library. |

- **LIB-OBSERVER-1** — The observer must dispatch, watch and write. It must not
  edit code.
- **LIB-OBSERVER-2** — The observer must dispatch an operator when a step fails.
- **LIB-OBSERVER-3** — The observer must dispatch a verifier for each claim that
  LIB-VERIFY-1 puts in scope.

<a id="lib-verify"></a>

## Verification

- **LIB-VERIFY-1** — The verifier must check a claim that names a number, a
  cause, or a platform behavior. Any other claim enters the library with no
  check.
- **LIB-VERIFY-2** — The verifier must check a claim against the run logs. It
  must not re-run a campaign step.

<a id="lib-skills"></a>

## The skills

The skills live in `.claude/skills/` of this checkout. One skill serves each
pipeline stage, and `watch`, `note`, `verify` and `consolidate` serve the
observer. The procedure lives in the skill, not in the context of the observer.

- **LIB-SKILLS-1** — A skill must take the project path as an argument.
- **LIB-SKILLS-2** — A skill must use an absolute path.
- **LIB-SKILLS-3** — A skill must state which clone and which project it read.
- **LIB-SKILLS-4** — A skill must export the project `.env` into the child
  environment. The `env` block of the checkout shadows each project key (D-05),
  so a bare command bills the wrong Scaleway Project.
- **LIB-SKILLS-5** — A step skill must take its name from the pipeline stage,
  never from the verb of one project. No campaign verb set contains the others,
  so a name from one project cramps the other two.

<a id="lib-runbook"></a>

## The runbook contract

Each project-unique instruction lives in `Projects/<name>/train/RUNBOOK.md`,
which the project repository tracks. A skill reads the runbook of the project it
operates.

- **LIB-RUNBOOK-1** — A runbook must map each shared stage name to the verb of
  its project, and it must name each stage that the project omits.
- **LIB-RUNBOOK-2** — A runbook must hold a map, not a design. It must point at
  `train/config.env`, at `infra/persistent/RUNBOOK.md` and at `spec/`, and it
  must not restate them.
- **LIB-RUNBOOK-3** — Each project owns its runbook gate. A workspace gate
  cannot read a runbook, because `Projects/` is gitignored and each clone is an
  independent repository.

<a id="lib-candidate"></a>

## The machine check

- **LIB-CANDIDATE-1** — `make rule-candidates` must read the `Rule-candidates`
  page and report each undelivered candidate with its age in days.
- **LIB-CANDIDATE-2** — The target must exit zero when the clone is absent, so a
  checkout without a library still passes `make check`.
