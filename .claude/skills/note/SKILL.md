---
name: note
description:
  Append one observation to the session page of the library, and commit it. Use
  at the moment you see something worth keeping, never at the end of a run.
---

# note

This skill writes one observation to the session page. It commits at capture
time, so a crash loses nothing.

`SessionEnd` does not run after an abnormal stop. A test confirms it — a
`SIGKILL` loses the hook, and `SIGTERM` keeps it (LIB-HOOKS-6). So an
observation that waits for the end of a session is an observation that a crash
loses.

## The steps

1. Write the observation to a file under `explore/`, which is gitignored:

   ```sh
   cat > explore/note.md <<'END'
   Claim: the offer probe returns three zones for the H100 type.
   Evidence: run 42, the log line that starts "offer".
   END
   ```

2. Append it, and commit it:

   ```sh
   perl scripts/wiki.pl note <session page> explore/note.md
   ```

   The page name comes from the `SessionStart` hook. Run
   `perl scripts/wiki.pl status` when you do not have it.

## The format

- Start a claim line with `Claim:`. The consolidator moves those lines, and
  `wiki.pl status` counts them.
- Start an admission line with `Admitted:`. The consolidator writes one for each
  claim it moves, and the difference is the work that is left.
- Write everything else as plain prose. A raw observation needs no gate
  (LIB-ENTRY-1).

## The content rule

The library is public. A note must not hold a credential, a bucket suffix, a
Scaleway Project identifier, or an IAM application name. It can hold a price, a
quota state, an error string and a run identifier (LIB-CONTENT).
