---
name: consolidate
description:
  Merge the session page into the library pages at the end of a campaign. Use
  once, when the campaign ends, before the batch pull request.
---

# consolidate

This skill dispatches the consolidator. It runs one time, at the end of a
session (LIB-ENTRY-4).

## The steps

1. Read the session page. Run `perl scripts/wiki.pl status` for its name.
2. Dispatch the `consolidator` agent with the session page name and the project
   name.
3. The consolidator moves each confirmed claim, and each claim that LIB-VERIFY-1
   puts out of scope, into `Library-<project>-<component>`:

   ```sh
   perl scripts/wiki.pl admit Library-<project>-<component> explore/entry.md
   ```

4. It writes one `Admitted:` line back to the session page for each claim it
   moved, with the `note` skill.
5. It puts a candidate rule on the `Rule-candidates` page, as
   `- <date> <the candidate>`.
6. It puts a process learning on the `Process` page.
7. Run `perl scripts/wiki.pl status` again. The claim count and the admitted
   count must agree, or the difference must have a reason.

## The entry format

Each entry holds four parts (LIB-ENTRY-3):

```markdown
**The bold claim, in one sentence.**

Evidence: the run identifier, and the log line that carries it. Scope: the
conditions under which the claim holds. Maps to: FuguTTX <UNIT>, FuguTTX <UNIT>
```

## What comes next

The library is the working record. A project ledger receives one batch per
campaign, at the closing pull request (D-09). That batch cites the library pages
that hold its evidence.

The cross-repository delivery survives this split. A finding must still reach
the FuguTTX `docs/research/` directory, and a contradiction must still become a
FuguTTX specification change. Nothing else replaces that step.
