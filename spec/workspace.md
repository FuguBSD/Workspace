# The workspace

The workspace gives each agent and each human one place with every FuguBSD
project in it. It clones the org into `Projects/`, and it clones the learning
library into `Wiki/`. It makes git worktrees of itself for parallel work.
`scripts/worktree.pl` implements the worktree lifecycle, and `mk/local.mk` holds
the make targets. [library.md](library.md) specifies the library and the
observer set.

<a id="ws-layout"></a>

## Layout

- **WS-LAYOUT-1** — The workspace repository must be public, at the remote
  `FuguBSD/Workspace`. CI must run the `check` target on each push and on each
  pull request.
- **WS-LAYOUT-2** — The repository tracks the workspace-level files only.
  `Projects/`, `Wiki/`, each `.env` file, and `.claude/worktrees/` are
  gitignored, and each clone under `Projects/` and at `Wiki/` is its own
  independent repository.
- **WS-LAYOUT-3** — The workspace must consume the `org` and the `infra` packs
  of FuguBSD/Tooling. `.toolingrc` selects the packs, and
  `Projects/Tooling/scripts/sync` copies them in.

<a id="ws-clone"></a>

## Clone management

- **WS-CLONE-1** — `make clone` must clone each org project that is absent from
  `Projects/`, and must keep each project that is present.
- **WS-CLONE-2** — The project list must come from `gh repo list FuguBSD`, so
  the list reflects the org at all times, private projects included.
- **WS-CLONE-3** — `make pull` fast-forwards each clone, and a failure in one
  clone must not stop the others.

<a id="ws-bootstrap"></a>

## Bootstrap

- **WS-BOOTSTRAP-1** — `make bootstrap` brings a checkout to a working state.
  Without `MAIN` it clones the org and the library. With `MAIN=<main checkout>`
  it materializes the gitignored paths from the main checkout.
- **WS-BOOTSTRAP-2** — `worktree.pl clone <path>...` materializes gitignored
  paths with no network and no `gh`. It clones a repository path, or a directory
  of repositories like `Projects`, locally; it sets `origin` to the upstream
  URL; it copies each `.env` in the tree, at any depth; and it copies a
  plain-file path, like `.env`.
- **WS-BOOTSTRAP-3** — Clone must keep a destination that exists, so a second
  `make bootstrap MAIN=<main>` repairs a partial bootstrap and keeps local
  changes.
- **WS-BOOTSTRAP-4** — Clone must write only inside the current directory.
- **WS-BOOTSTRAP-5** — The bootstrap must materialize `Wiki` beside `.env` and
  `Projects`, so each checkout holds its own clone of the library. Without
  `MAIN`, `make clone` must clone `FuguBSD/Wiki` into `Wiki/` when it is absent.

<a id="ws-profiles"></a>

## Credential profiles

The operator HOME holds one credential profile per Scaleway Project (D-05).
`~/.config/scw/config.yaml` serves `scw` and the tofu provider. A matching
section of `~/.aws/credentials` serves the S3 tools. The environment beats a
profile in every Scaleway tool, so an ambient credential silently replaces a
named profile. The per-project `.env` files are the CI-parity copies, and the
stage skills read them.

- **WS-PROFILES-1** — A profile must carry the short name of its Scaleway
  Project, for example `fugustx`.
- **WS-PROFILES-2** — A file must not set an active or a default profile. A
  command must name its identity: `--profile`, `SCW_PROFILE`, `AWS_PROFILE`, or
  one project `.env` export on its own command line.
- **WS-PROFILES-3** — A checkout settings file must not hold a credential, and a
  workspace tool must not write one there.
- **WS-PROFILES-4** — A command that reaches Scaleway must run without ambient
  `SCW_*` and `AWS_*` variables, except the variables it sets itself.
- **WS-PROFILES-5** — Only the operator makes or rotates a profile, and a
  rotation must update both HOME files. The README holds the procedure.

<a id="ws-worktree"></a>

## Worktrees

- **WS-WORKTREE-1** — A worktree lives at `.claude/worktrees/<name>`, on a new
  branch `<name>` that starts at the local HEAD.
- **WS-WORKTREE-2** — `worktree.pl create <name>` bootstraps the worktree with
  the `bootstrap` make target and `MAIN=<main checkout>`, and writes the
  worktree path to stdout as the only line.
- **WS-WORKTREE-3** — After a failure, or after SIGINT or SIGTERM, create
  removes all that it made: a failed run leaves no worktree and no branch.
- **WS-WORKTREE-4** — `worktree.pl remove <name>` removes the worktree and
  deletes its branch. Only an operator runs it. It removes a locked worktree,
  debris from a killed create, and a worktree that a user deleted by hand. A
  second run causes no change.
- **WS-WORKTREE-5** — Create and remove must confine their changes to
  `.claude/worktrees/`, and the commands must stay safe under parallel runs.
- **WS-WORKTREE-6** — Remove must refuse a worktree that holds work at risk, and
  the message must name each cause. The causes are an uncommitted change in the
  worktree or in a clone inside it, and a commit that no remote holds. The
  `--force` option must override the refusal.
- **WS-WORKTREE-7** — `worktree.pl list` must report each worktree with its age
  in days and its state. The state names an uncommitted change and an unpushed
  commit, so an operator can see which worktree is safe to remove.

<a id="ws-hooks"></a>

## Claude Code hooks

- **WS-HOOKS-1** — The `WorktreeCreate` and `WorktreeRemove` hooks in
  `.claude/settings.json` fully replace the built-in worktree creation and
  removal of Claude Code. The create hook calls `worktree.pl`. The remove hook
  must remove nothing: it reports the worktree path and the manual command, and
  it exits zero (D-06).
- **WS-HOOKS-2** — The create hook must write the worktree path to stdout.
- **WS-HOOKS-3** — `worktree.baseRef` must stay `"head"`, because a worktree
  starts at the local HEAD (WS-WORKTREE-1). Without the hooks, the built-in
  creation branches from `origin/main` instead, and it skips the bootstrap.
- **WS-HOOKS-4** — A hook that derives the checkout root from a worktree path
  must cut at the last `.claude/worktrees/` marker, not the first. A nested
  checkout holds the marker more than one time, and a cut at the first marker
  names the wrong checkout.
- **WS-HOOKS-5** — The `SessionStart` and `SessionEnd` hooks operate the
  library, per LIB-HOOKS.
