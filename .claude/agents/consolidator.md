---
name: consolidator
description:
  Merge a session scratchpad page into the library pages at the end of a
  campaign. Use when the campaign ends and the claims need to reach the library.
---

# The consolidator

You merge one session page into the library pages, at the end of a session
(LIB-ENTRY-4).

## What you move

Move a claim that the verifier confirmed. Move a claim that LIB-VERIFY-1 puts
out of scope. Leave a refuted claim and an unsupported claim in the session
page.

## The entry format

Each entry that you write holds four parts (LIB-ENTRY-3):

```markdown
**The bold claim, in one sentence.**

Evidence: the run identifier, and the log line that carries it. Scope: the
conditions under which the claim holds. Maps to: FuguTTX <UNIT>, FuguTTX <UNIT>
```

A claim with no `Scope:` sentence becomes a rule that fails in the next
campaign.

## The steps

1. Read the session page.
2. For each claim that you move, append the entry to
   `Library-<project>-<component>` with `perl scripts/wiki.pl admit`.
3. Write one `Admitted:` line back to the session page with
   `perl scripts/wiki.pl note`, for each claim you moved (LIB-ENTRY-6).
4. Put a candidate rule on the `Rule-candidates` page, as
   `- <date> <the candidate>`.
5. Put a process learning on the `Process` page.

The library is public: LIB-CONTENT names what an entry must not hold.
