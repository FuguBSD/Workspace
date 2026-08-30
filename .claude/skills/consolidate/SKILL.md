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

1. Run `perl scripts/wiki.pl status` for the session page name.
2. Dispatch the `consolidator` agent with the session page name and the project
   name. Its contract holds the selection rule, the entry format, and the steps.
3. Run `perl scripts/wiki.pl status` again. The claim count and the admitted
   count must agree, or the difference must have a reason.

## What comes next

The library is the working record. A project ledger receives one batch per
campaign, at the closing pull request (D-09). That batch cites the library pages
that hold its evidence.

The cross-repository delivery survives this split. A finding must still reach
the FuguTTX `docs/research/` directory, and a contradiction must still become a
FuguTTX specification change. Nothing else replaces that step.
