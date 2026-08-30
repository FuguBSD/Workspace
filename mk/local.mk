# mk/local.mk: the consumer hook of this repository (MK-LOCAL).
# sync never touches this file. The workspace targets live here.
#
# Keep the recipes in the portable make subset: no $(shell), no !=
# assignments (Apple ships GNU make 3.81, which lacks !=). REPOS
# holds a command, not its output; recipes run it themselves.

ORG	= FuguBSD
DIR	= Projects
WIKI	= Wiki
REPOS	= gh repo list $(ORG) --limit 1000 --json name --jq '.[].name'

# Bring this checkout to a working state. In a fresh worktree,
# worktree.pl create runs `make bootstrap MAIN=<main checkout>`, and
# the clone subcommand materializes the gitignored paths locally from
# there (no network). Without MAIN this is the main checkout: clone
# the org and the library. Credentials live in the HOME profiles
# (WS-PROFILES), so bootstrap writes no settings file.
#
# Wiki goes to clone beside .env and Projects (WS-BOOTSTRAP-5). Each
# checkout gets its own clone of the library, so two parallel sessions
# never contend on one git index.
bootstrap:
	@if test -n "$(MAIN)"; then \
		perl scripts/worktree.pl -C "$(MAIN)" clone .env $(DIR) $(WIKI); \
	else \
		$(MAKE) clone; \
	fi

clone:
	@mkdir -p $(DIR)
	@$(REPOS) | while read -r r; do \
		test -d $(DIR)/$$r || gh repo clone $(ORG)/$$r $(DIR)/$$r; \
	done
	@perl scripts/wiki.pl init

pull:
	@for d in $(DIR)/*/; do \
		echo "==> $$d"; \
		git -C $$d pull --ff-only || true; \
	done

list:
	@$(REPOS)

worktree:
	@test -n "$(NAME)" || { echo "usage: make worktree NAME=<name>" >&2; exit 1; }
	@perl scripts/worktree.pl create "$(NAME)"

# No hook removes a worktree (D-06). This target is the manual path,
# and it refuses a worktree that holds work at risk. FORCE=1 overrides
# the refusal.
worktree-remove:
	@test -n "$(NAME)" || { echo "usage: make worktree-remove NAME=<name> [FORCE=1]" >&2; exit 1; }
	@if test -n "$(FORCE)"; then \
		perl scripts/worktree.pl remove --force "$(NAME)"; \
	else \
		perl scripts/worktree.pl remove "$(NAME)"; \
	fi

worktree-list:
	@perl scripts/worktree.pl list

# LIB-CANDIDATE: report each undelivered rule candidate with its age.
# It exits zero without a library clone, so a checkout that has not
# bootstrapped still passes make check.
rule-candidates:
	@perl scripts/wiki.pl candidates

.PHONY: bootstrap clone pull list worktree worktree-remove
.PHONY: worktree-list rule-candidates
