# The workspace session

These rules apply to a session of this checkout only. The root
[CLAUDE.md](../../CLAUDE.md) holds the rules of every FuguBSD repository, and
the org pack of FuguBSD/Tooling owns it. This file carries no `paths` field, so
Claude Code loads it at each launch.
[spec/workspace.md](../../spec/workspace.md) states the design, and
`make traces` measures the result.

- Land one deliverable in one session. Start a new session for the next
  deliverable.
- Run the implementation through the `implementer` agent, and each review fix
  through the `fixer` agent. The agent files `implementer.md` and `fixer.md` of
  the org pack hold the rules.
- Name the directory in every command, with `cd` or `make -C`. The shell resets
  between two calls, and the clones sit two directories down.
- Delegate a bulk read and a whole-file write to an agent. The context of an
  agent dies with the agent, and the context of this session does not.
- Start the review stage in a new session when the context passes 300k tokens.
- Run `make check </dev/null`. A test stub drains the standard input.
