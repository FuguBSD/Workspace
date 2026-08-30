---
name: corpus
description:
  Build or sync the training data of one project. Use for the corpus stage of a
  campaign. Takes the absolute project path.
---

# Stage — corpus

This stage builds or syncs the data that a campaign trains on. Each project
names it differently, so the runbook holds the map.

1. Read `<project path>/train/RUNBOOK.md` for the verb of this stage.
2. Read `<project path>/train/config.env` for the campaign pins and the shared
   names.
3. Run the verb on one command line:

   ```sh
   set -a; . <project path>/.env; set +a; make -C <project path> <verb>
   ```

Report the counts the run printed: the document count, the token count, and each
split size. The operator contract holds the common rules.
