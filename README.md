# FuguBSD workspace

The workspace for the [FuguBSD](https://github.com/FuguBSD) organization. Each
project is cloned into `Projects/`, and the learning library is cloned into
`Wiki/`. Each clone is its own repository. This repository tracks the
workspace-level files only. `Projects/`, `Wiki/`, `.env` files, and
`.claude/worktrees/` are gitignored.

Do the project work inside a project directory, not here. A commit, a branch, or
a pull request of a project belongs to that project. A commit here changes the
workspace itself.

## Commands

    make bootstrap                 # bring this checkout to a working state
    make clone                     # clone every org project that is absent
    make pull                      # fast-forward every clone
    make list                      # list the org projects
    make worktree NAME=<n>         # create and bootstrap a worktree
    make worktree-remove NAME=<n>  # remove a worktree, after a manual decision
    make worktree-list             # list each worktree with its age and state
    make rule-candidates           # report each undelivered rule candidate
    make check                     # lint + format + test + spec-check + ste-lint + gitleaks

The project list comes from `gh repo list FuguBSD`, so it reflects the org at
all times. `gh` is authenticated with admin permissions, and private projects
are included.

`make check` runs the Markdown format gate, and prettier runs through bunx. The
operator installs bun and gitleaks, for example from Homebrew. No deps manifest
provides them.

## Worktrees

Git worktrees live under `.claude/worktrees/` (gitignored). The hooks in
`.claude/settings.json` replace the built-in worktree handling of Claude Code,
per [WS-HOOKS](spec/workspace.md#ws-hooks): create bootstraps the gitignored
paths locally, and no hook removes a worktree (D-06). `make worktree-remove` is
the manual removal path, and `make worktree-list` shows which worktree is safe
to remove.

## The learning library

A shared git repository holds the campaign learnings of FuguSTX, FuguCTX and
FuguTTX. It is cloned at `Wiki/`, a sibling of `Projects/`, and
`scripts/wiki.pl` operates it from the `SessionStart` and `SessionEnd` hooks.
The agents in `.claude/agents/` and the skills in `.claude/skills/` run a
campaign against it. The specification in [spec/](spec/index.md) states the full
contract.

## Shared tooling

This repository consumes the `org` and the `infra` packs of FuguBSD/Tooling, as
each other repository in the org does. `.toolingrc` selects the packs. Run the
sync from this directory:

    perl Projects/Tooling/scripts/sync           # copy the shared files in
    perl Projects/Tooling/scripts/sync --check   # report drift, change nothing

## Projects

- `.github` — the GitHub organization profile, rendered on the org page.
- `Fugu` — generic OpenBSD-style daemon utilities for Perl.
- `FuguCTX` — a configuration repair model for OpenBSD daemons.
- `FuguOracle` — a blind PIN oracle service, designed after OpenBSD principles.
- `FuguPass` — a password manager for any secret, built on proven seed-phrase
  standards and air-gapped custody patterns.
- `FuguSTX` — an embeddable English linguistic analysis engine for prose
  linters.
- `FuguTTX` — a small language model and agent for OpenBSD system
  administration.
- `FuguVM` — install and manage OpenBSD virtual machines under QEMU, by hand or
  by agent.
- `FuguWeb` — build a documentation website for a Perl project.
- `Repositories` — declarative settings for all repositories in the
  organization.
- `Tooling` — shared build, dist, release and agent tooling for the
  repositories.
- `Website` — the main website of the organization, at www.fugubsd.org.

## Scaleway

The org shares one Scaleway Organization, and each project gets its own Scaleway
Project inside it. The naming standard lives in the Repositories specification
(Repositories SET-NAMING). The shared infrastructure rules live in
[infra/CLAUDE.md](infra/CLAUDE.md), and the canonical infrastructure document is
`Projects/FuguTTX/spec/infrastructure.md`.

The operator HOME holds one credential profile for each project key, per
[WS-PROFILES](spec/workspace.md#ws-profiles). The profiles today are `fugubsd`,
`fugustx`, `fuguctx`, and `fuguttx`. Each lives in `~/.config/scw/config.yaml`,
with a matching `~/.aws/credentials` section for the S3 tools. No profile is
active by default. Name the identity on each command: `scw --profile fugustx`,
`SCW_PROFILE=fugustx`, or `AWS_PROFILE=fugustx`. Rotate a key with
`scw config set --profile <name> access-key=<key> secret-key=<secret>`. Update
the matching `~/.aws/credentials` section in the same change. The specification
states the environment rule.

## Commit scopes

`worktree`, `wiki`, `mk`, `spec`, `agents`.

## License

ISC. See [LICENSE](LICENSE).
