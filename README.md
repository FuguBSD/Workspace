# FuguBSD workspace

The local workspace of the [FuguBSD](https://github.com/FuguBSD) organization.
It clones each project into `Projects/` and the learning library into `Wiki/`.
Each clone is its own repository, and this repository tracks the workspace-level
files only.

Do the project work inside a project directory. A commit here changes the
workspace itself. The project list comes from `gh`, and the operator
authenticates it once with `gh auth login`. The specification in
[spec/](spec/index.md) states the contract of the workspace and the library.

## Commands

```sh
make deps                      # install gh and gitleaks into ~/.local/bin
make bootstrap                 # bring this checkout to a working state
make clone                     # clone every org project that is absent
make pull                      # fast-forward every clone
make list                      # list the org projects
make worktree NAME=<n>         # create and bootstrap a worktree
make worktree-remove NAME=<n>  # remove a worktree, after a manual decision
make worktree-list             # list each worktree with its age and state
make rule-candidates           # report each undelivered rule candidate
make check                     # run every gate; run it before each commit
```

## Commit scopes

`worktree`, `wiki`, `mk`, `spec`, `agents`.
