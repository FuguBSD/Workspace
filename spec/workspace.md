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

<a id="ws-deps"></a>

## Dependencies

- **WS-DEPS-1** — `deps/<OS>.txt` must name each external tool that the
  workspace targets need. `make deps` installs the `tool` environment and then
  the `runtime` environment from it.
- **WS-DEPS-2** — The manifest must name `gh`, because WS-CLONE-2 reads the
  project list with it. The entry must install a pinned release of the GitHub
  CLI into `~/.local/bin`.
- **WS-DEPS-3** — The manifest must not name `bun`. The operator installs it,
  because the Markdown format gate needs `bunx` before a target can run.
- **WS-DEPS-4** — The manifest must name `gitleaks` in the `tool` environment.
- **WS-DEPS-5** — CI must install gitleaks with `make deps`, so one pin serves
  the operator gate and the CI gate.
- **WS-DEPS-6** — `make deps` must verify each download before it installs the
  file. A download that fails its check must stop the install.
- **WS-DEPS-7** — `deps/SHA256.txt` must record the sha256 digest of each file
  that an entry downloads by version, for each platform that the workspace
  targets. The org pack of FuguBSD/Tooling defines the file format.
- **WS-DEPS-8** — A download of the latest release must not appear in
  `deps/SHA256.txt`, because its bytes change with each release.
- **WS-DEPS-9** — A manifest entry must not spell an operating system word or an
  architecture word.

<a id="ws-bootstrap"></a>

## Bootstrap

- **WS-BOOTSTRAP-1** — `make bootstrap` brings a checkout to a working state.
  Without `MAIN` it clones the org and the library. With `MAIN=<main checkout>`
  it materializes the gitignored paths from the main checkout.
- **WS-BOOTSTRAP-2** — `worktree.pl clone <path>...` materializes gitignored
  paths with no network and no `gh`. It clones a repository path, or a directory
  of repositories like `Projects`, locally. It sets `origin` to the upstream
  URL. It copies each `.env` in the tree, at any depth. It also copies a
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
stage skills read them. The operator rotates a key with
`scw config set --profile <name> access-key=<key> secret-key=<secret>`, and
updates the matching `~/.aws/credentials` section in the same change.

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
  rotation must update both HOME files.

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

<a id="ws-session"></a>

## The session

A session of this checkout carries its whole context for hours, and the output
of the model stays in that context. A second task in one session therefore pays
for the context of the first one. `.claude/rules/workspace.md` holds the session
rules, because the org pack of FuguBSD/Tooling owns the root `CLAUDE.md`.
`scripts/traces.pl` is the yardstick. It reads the session traces of the
operator HOME, and it prints one line for each session that holds a request. The
columns are:

- the main session: the identifier, the start time, the request count, the peak
  context and the output tokens;
- the review panel: the rounds, the main-session edits outside `scratch/` after
  the first panel launch, and the largest peak context of one panel reviewer;
- the sub-agents: the input total and the output total.

The round cap of the panel lives in the `review-panel` skill of the org pack.

- **WS-SESSION-1** — `.claude/rules/workspace.md` must hold the workspace-only
  session rules, and must carry no `paths` field, so Claude Code loads it at
  each launch (D-10).
- **WS-SESSION-2** — A session must land one deliverable, and the next
  deliverable must start in a new session (D-11).
- **WS-SESSION-3** — The main session must dispatch an `implementer` agent for
  each work package, and a `fixer` agent for each review fix. The agent files of
  the org pack hold the rules of the two agents.
- **WS-SESSION-4** — The main model must run at effort `high`, as a measured
  trial (D-12). The operator sets the effort in the user settings, outside this
  repository.
- **WS-SESSION-5** — `make traces` must run `scripts/traces.pl`. The script must
  print one line for each session that holds a request, with the columns above.
  A session with no request gets no line.
- **WS-SESSION-6** — The script must derive the checkout name from its own path,
  cut at the last `.claude/worktrees/` marker. It must read the trace directory
  of the checkout, of each worktree of it, and of each project clone in either.
  A match must take an exact name form, so a sibling checkout stays out.
- **WS-SESSION-7** — The usage of one request must count one time. One request
  writes one record for each content block, so the script must read the last
  record of the request.
- **WS-SESSION-8** — The report must meet four targets:
  - The peak context of the main session stays under 300k tokens.
  - The main session edits no repository file after the first panel launch.
  - The review panel runs three rounds or fewer.
  - The `rev-peak` column stays under 80k tokens.

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
