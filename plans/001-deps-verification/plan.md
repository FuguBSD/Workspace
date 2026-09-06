# 001 — Verified dependency installs across the organization

`scripts/deps` downloads a binary and installs it without a check of the bytes.
It also expands one architecture word and one operating system word, so a
release asset with a different spelling needs a hardcoded workaround. This plan
adds two guarantees. Each downloaded file must match a recorded sha256 digest,
or a signify signature. Each download URL must resolve through an alias table,
so no manifest holds a hardcoded platform word. One install path then serves the
operator and CI. The `setup-gitleaks` action of Tooling retires, and each check
workflow installs gitleaks with `make deps`, as the operator does.

The work starts in FuguBSD/Tooling, because the org pack owns `scripts/deps`,
`scripts/ftp` and `mk/org.mk`. The rollout then reaches every consumer.

## Citations

Implements: WS-DEPS without WS-DEPS-7 and WS-DEPS-8

The workspace unit [WS-DEPS](../../spec/workspace.md#ws-deps) states the target
design. WS-DEPS-7 and WS-DEPS-8 landed with the digest file. The key files and
the verification tiers belong to the specification of FuguBSD/Tooling, which
owns `scripts/deps`. The register holds the unit as `partial`, and it names each
absent part.

This plan is the record of the organization. [plans/CLAUDE.md](../CLAUDE.md)
states that a plan lives in the repository that implements it, and describes the
work of that repository only. The workspace covers every project, so the
operator keeps the design here. Each implementing repository takes its own plan
from this one, and the Tooling plan lands first. Open question 4 records the
tension with the rule.

## Decisions

The operator made these decisions. An implementation must not reverse one
without approval.

| #   | Decision                                                                                                                                                               |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Alias resolution reads the digest manifest. The install path must not probe the network. An ambiguous match is an error.                                               |
| 2   | Each entry that downloads a URL must carry a sha256 digest, or a signify signature. Neither one present is an error.                                                   |
| 3   | The digests live in `deps/SHA256.txt`, in BSD format, keyed by download URL. The operator approved this reversal of the file-name key on 2026-09-06.                   |
| 4   | A new `tool` environment installs before every other environment. A `tool` entry must not use the signify tier.                                                        |
| 5   | `scripts/deps` derives the signature URLs from the download URL base, so the signify tier stays generic.                                                               |
| 6   | The release key lives online, as a GitHub organization secret. A workflow of the Website repository rotates it.                                                        |
| 7   | The rule MK-GITLEAKS-4 of Tooling changes, so a manifest can provide gitleaks.                                                                                         |
| 8   | `deps/KEYS.txt` declares each signify public key, as the key body or as a URL and sha256 pair. `deps/KEYS.local.txt` holds a consumer key.                             |
| 9   | The `setup-gitleaks` action retires. Each check workflow installs gitleaks with `make deps`, from the manifest.                                                        |
| 10  | The keys publish under `https://www.fugubsd.org/keys/`. FuguWeb generates the key directory, the Apache `KEYS` file, and the well-known URLs from a description block. |
| 11  | The generic parts of the key directory live in Fugu modules. FuguWeb holds the site wiring only.                                                                       |

Decision 6 puts the private key in CI. The signature then proves that the asset
store holds the bytes that CI built. It does not prove that CI is honest. The
rotation workflow also needs an organization-admin token, the strongest
credential of the organization. The operator accepts both costs.

Decision 6 has one more consequence. CI cannot answer a passphrase prompt, so
the key pair must come from `signify -G -n`, with no passphrase. The secret is
the whole protection of the private key.

## Evidence

A cold session must not repeat this research. This session checked each claim
below against the repositories on 2026-09-06.

### The fetcher accepts an error page

`scripts/ftp` runs `curl -L -o` on Darwin, with no `-f` option. A measured 404
exits 0 and writes a 9-byte body that holds the text `Not Found`. `scripts/deps`
then sets mode 755 on that file in `~/.local/bin`. The Linux branch runs
`wget -O`, which exits 8 and leaves an empty file. The Darwin branch needs `-f`
before any other work starts.

`scripts/deps` also downloads a plain `bin` entry straight into
`~/.local/bin/<name>`. A failed download therefore replaces a working binary
with a broken file. An archive entry downloads into a temporary directory first.

### Two hardcoded platform words exist today

The alias problem covers the operating system word and the architecture word.

| Manifest                       | Hardcoded word                    | Cause                                 |
| ------------------------------ | --------------------------------- | ------------------------------------- |
| `Repositories/deps/Darwin.txt` | `gh_2.97.0_macOS_{arch}.zip`      | The `{os}` expansion gives `darwin`.  |
| `Workspace/deps/Linux.txt`     | `gitleaks_8.30.1_{os}_x64.tar.gz` | The `{arch}` expansion gives `amd64`. |

The release assets confirm both causes. `gitleaks_8.30.1_linux_amd64.tar.gz`
answers 404, and `gitleaks_8.30.1_linux_x64.tar.gz` answers 200.
`gh_2.97.0_darwin_arm64.zip` answers 404, and `gh_2.97.0_macOS_arm64.zip`
answers 200.

### The entries that download a URL

Only a `bin` entry and a `dist` entry download a URL. A `pkg` entry and a `cpan`
entry pass the name to apt, brew, pkg_add or cpanm, and those tools own their
own integrity check.

| Tool     | Version         | Repositories that name it                       |
| -------- | --------------- | ----------------------------------------------- |
| scw      | 2.61.0          | FuguCTX, FuguSTX, FuguTTX, Repositories         |
| gh       | 2.97.0          | Repositories, Workspace                         |
| tofu     | 1.10.6 / 1.12.6 | Repositories holds 1.10.6, FuguSTX holds 1.12.6 |
| gitleaks | 8.30.1          | Workspace                                       |
| Fugu     | latest          | FuguTTX, FuguVM, FuguWeb, over 7 dist lines     |

The scw entry names a plain binary, with no archive and no member.

The `deps/SHA256.txt` of the workspace records the Linux digests of gh, and the
`linux_x64` digest of gitleaks. The `linux_arm64` digest of gitleaks 8.30.1 is
`e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080`, per the
upstream checksum file. It joins the file with the `{arch}` placeholder.

### Each upstream publishes a checksum file

Each pinned tool publishes a sha256 list beside its release assets. The operator
compares a recorded digest against that list, so the first download is not the
only source of trust.

| Tool     | Checksum asset                  |
| -------- | ------------------------------- |
| gh       | `gh_2.97.0_checksums.txt`       |
| gitleaks | `gitleaks_8.30.1_checksums.txt` |
| tofu     | `tofu_1.10.6_SHA256SUMS`        |
| scw      | `SHA256SUMS`                    |

### The setup-gitleaks action is the second install path

The `setup-gitleaks` action of Tooling installs
`gitleaks_8.30.1_linux_x64.tar.gz` and checks it against the sha256 default
`551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb`
(WFL-GITLEAKS-1 of Tooling). That digest seeds the first `deps/SHA256.txt`
entry. After decision 9 lands, the manifest is the one pin.

These places name the action today. Each one changes or goes.

| Place                                       | Reference                                                          |
| ------------------------------------------- | ------------------------------------------------------------------ |
| `Tooling/actions/setup-gitleaks/`           | The action itself.                                                 |
| `Tooling/perl/t/setup-gitleaks.t`           | The test of WFL-GITLEAKS-1. It skips when the action is gone.      |
| `Tooling/spec/workflows.md`                 | The unit WFL-GITLEAKS, rules 1 to 3.                               |
| `Tooling/spec/make.md`                      | MK-GITLEAKS-4 names the action as the CI install.                  |
| `Tooling/.github/workflows/check.yml`       | The `gitleaks` job runs the action before `make gitleaks`.         |
| `org/sync/t/ci/workflows.t`                 | Pins the action path in each use. A workflow without a use passes. |
| Each consumer `.github/workflows/check.yml` | A `Setup gitleaks` step before `make check`.                       |
| `Workspace/README.md`                       | The deps paragraph names the action.                               |

The synced `t/ci/workflows.t` checks the action path only where a workflow uses
it, so a consumer can drop the step before Tooling deletes the action. The
reverse order breaks CI: a consumer that still uses a deleted action fails at
the step.

The same synced test fails a workflow line that runs `make deps`, with the
message "runs no deps target of its own". The rule assumes that the setup-perl
action owns every install. A check workflow without that action, as in the
workspace, therefore cannot take the `make deps` step of decision 9 before
Tooling changes the test. Phase 1 changes the test with the script.

The action appends `$HOME/.local/bin` to `GITHUB_PATH`. `scripts/deps` installs
into the same directory and appends nothing. The default PATH of the Ubuntu
runner holds `/home/runner/.local/bin`, and the implementation confirms this
before it drops the append.

### The setup-perl action fixes the environment words

The `setup-perl` action of Tooling accepts `runtime`, `test` or `develop` as its
`dependencies` input, and rejects every other word. It maps `runtime` to
`make deps`, and the other two to `make deps-<name>`. The decision D-08 of
Tooling fixes the three target names. A `tool` environment therefore cannot get
a target of its own. It must run inside `make deps`.

### The organization already holds the signify pattern

`Fugu/lib/Fugu/Signify.pm` verifies a signify signature over a SHA256 manifest,
and then each named file against its digest. The manifest format is
`SHA256 (key) = hexdigest`, the format that decision 3 names. The parser takes
any key, so a URL key reads as a file-name key does. The module verifies the
signature before it digests any file, and it rejects an empty manifest, a bad
line, and a duplicate key. The module accepts a key set in trust order: the
current key first, and the next key second.

`FuguVM/lib/App/FuguVM/Mirror.pm` consumes that module. It names each key file
after the OpenBSD release, for example `openbsd-78-base.pub`, and resolves it
through an explicit directory, then `/etc/signify`, then a share tree. It passes
one key to the module.

`Fugu::Signify` holds no private key, and it cannot sign. Its manifest parser is
a private method, and the module has no writer for the manifest form. Fugu holds
no OpenPGP module and no base32 module.

FuguWeb depends on Fugu and on core Perl only, and the publish workflow installs
the two release tarballs together. A Fugu module is therefore available to every
site build, and to FuguVM and FuguTTX as well.

### A signify public key is one line

A signify public key file holds two lines. The first line starts with
`untrusted comment: `, and signify(1) rejects a file without that prefix. The
second line is the key body: 42 bytes in base64, 56 characters, and the first
two bytes spell `Ed`. The comment carries no trust. A key file is therefore
reproducible from its body and any comment, and a text file can hold the body as
one word.

### One release workflow covers every distribution

`Tooling/.github/workflows/perl-release.yml` builds and publishes every Perl
distribution of the organization. It already copies the versioned tarball to a
stable name, and a comment names the deps manifests as the consumer of that
name. It already binds an `environment: release` that holds secrets. One change
there reaches Fugu, FuguVM, FuguWeb and FuguTTX. The runner is Ubuntu, and
`signify-openbsd` is an apt package.

### The sync mechanism carries a new pack file with no change

`Tooling/scripts/sync` walks the whole pack tree and copies each file to the
same path in the consumer. A new `org/sync/deps/KEYS.txt` therefore reaches each
consumer with no change to the script. Each synced file must start with a marker
comment (SYNC-MARKER-1 of Tooling), so the key file starts with `#` lines, and
the parser must skip them.

### The website publishes through fuguweb on GitHub Pages

The Website repository publishes at `www.fugubsd.org` (SITE-BUILD-3 of Website),
and the Repositories project holds the Pages settings. The shared
`web-publish.yml` workflow of Tooling installs fuguweb from the latest release
tarballs of Fugu and FuguWeb, never from a checkout. A Website build therefore
takes a FuguWeb feature only after a FuguWeb release.

fuguweb copies an asset only when the file sits directly in `web/`, and it skips
every dot file (`App::FuguWeb::Site`, ASSETS). A `web/keys/` directory and a
`.well-known/` directory both stay out of the build today.

GitHub Pages sits under the same GitHub organization as the release assets and
the CI secret. The website is not an independent trust domain. The DNS record of
`fugubsd.org` is the part outside GitHub.

### The publication conventions

RFC 8615 reserves `.well-known/` for registered names. Two registered names
serve a GPG key. `openpgpkey` is the Web Key Directory, and `gpg --locate-keys`
reads it from an email address. Its direct method serves the key in binary form
at `https://<domain>/.well-known/openpgpkey/hu/<hash>?l=<local>`, with a
`policy` file beside `hu/`. The hash is the z-base-32 form of the SHA-1 of the
local part in lower case. The domain is the email domain itself, so a key for
`@fugubsd.org` lives under `fugubsd.org`, not under `www.fugubsd.org`.
`security.txt` (RFC 9116) holds `Contact`, `Expires` and `Encryption` fields,
and the last one points at a key. Signify has no registered name.

The Apache projects publish one `KEYS` file with every GPG public key of a
project, and `gpg --import` reads it. OpenBSD names a key
`openbsd-<release>-<purpose>.pub`, and its untrusted comment names the key in
words.

### The workspace change conflicts with an organization rule

The rule MK-GITLEAKS-4 of `Tooling/spec/make.md` states that no deps manifest
provides gitleaks. The current [deps/Linux.txt](../../deps/Linux.txt) of the
workspace holds a gitleaks entry. Decision 7 resolves the conflict in favor of
the manifest.

### The bootstrap constraint holds

The rule SYNC-BOOTSTRAP-1 of Tooling limits the synced scripts to core modules
and `use v5.34`. `scripts/deps` also runs before any dependency exists, and Fugu
arrives through a `dist` line. Therefore `scripts/deps` must not load
`Fugu::Signify`. It runs `signify(1)` as a command, and it computes a digest
with the core module `Digest::SHA`. The duplication is deliberate, and the
specification must record the reason.

### The deps test runs without the network

`Tooling/perl/t/deps.t` runs the script under `--dry-run` and `--os` against
fixture manifests. It never fetches a file. The new tiers verify bytes, so a dry
run cannot cover them. `scripts/deps` finds `ftp` as an executable sibling
(SYNC-BOOTSTRAP-2 of Tooling), so a test can place a stub `ftp` beside a copy of
the script. The stub copies a fixture file, and the test then drives each tier
and each error path.

## Design

### The tool environment

The environment words become `tool`, `runtime`, `test` and `develop`. The `deps`
target of `mk/org.mk` runs `$(DEPS) tool` and then `$(DEPS) runtime`.
`deps-test` and `deps-develop` chain over `deps`, as they do today, so `tool`
installs one time in each chain. No `deps-tool` target exists, because
MK-VERBS-4 and D-08 of Tooling fix the three target names. The `setup-perl`
action needs no change, because `make deps` covers `tool`.

A `tool` entry must not use the signify tier, because that tier needs
`signify(1)`. A project whose platform lacks the command adds a `tool` entry for
it, as `tool pkg signify-openbsd` on Linux and `tool pkg signify-osx` on Darwin.
OpenBSD holds the command in base. Only a repository with a signify-tier entry
needs the `tool` entry. The workspace has none today.

### One install path for gitleaks

Each repository names gitleaks in the `tool` environment of each manifest, in
`deps/Linux.txt` and in `deps/Darwin.txt`, through the digest tier. The `tool`
environment fits, because gitleaks is a tool of the gates and not a dependency
of the software, and because every deps chain installs `tool`. The operator then
installs gitleaks with `make deps`, and the Homebrew install ends.

CI takes the same path. A check job that runs the `setup-perl` action already
runs `make deps-test`, which chains over `deps`, so gitleaks arrives with the
CPAN tree. A check job without that action, as in the workspace, adds one step
that runs `make deps`. The `gitleaks` job of the Tooling check workflow does the
same. No check workflow uses the `setup-gitleaks` action after its consumer
change.

The action goes last, after each consumer change, per the evidence. Its deletion
retires WFL-GITLEAKS-1, and the number is never reused. WFL-GITLEAKS-2 and
WFL-GITLEAKS-3 stay, because the full checkout rule does not depend on the
install path. MK-GITLEAKS-4 changes to state that the manifest provides gitleaks
in the `tool` environment, and that CI installs it with `make deps`. The synced
`t/ci/workflows.t` drops the action pin.

### Alias resolution

`scripts/deps` holds a table of aliases for the operating system word and for
the architecture word. The candidate set is the cross product of the two lists.

- The architecture `x86_64` gives `amd64`, `x64` and `x86_64`.
- The architecture `aarch64` and `arm64` give `arm64` and `aarch64`.
- The operating system `Darwin` gives `darwin`, `macOS`, `macos` and `osx`.
- The operating system `Linux` gives `linux`, and `OpenBSD` gives `openbsd`.

The script forms one URL for each candidate. It then selects the candidate that
`deps/SHA256.txt` names. No match is an error, and two matches are an error. The
install path makes no request to find the URL.

One selected pair expands both the URL and the member path of an entry. The
member path of the gh entry holds the same words as the asset name, and the two
must agree.

An entry with a placeholder needs a digest entry, because the resolution reads
the digest file. The signify tier therefore serves an entry without a
placeholder only. Today that set is the `dist` lines. The specification must
state this limit.

### The digest manifest

`deps/SHA256.txt` holds one line for each download, in BSD format, and the key
is the download URL. One file serves every operating system and every
architecture. The URL key also keeps two upstreams apart when both publish one
file name. The parser copies the rules of `Fugu::Signify`: a bad line, a digest
that is not 64 hexadecimal characters, and a duplicate URL are each an error.

    SHA256 (https://github.com/cli/cli/releases/download/v2.97.0/gh_2.97.0_linux_amd64.tar.gz) = 30a1...
    SHA256 (https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz) = 551f...

A stable-name asset, such as `releases/latest/download/Fugu.tar.gz`, must not
appear in the file. Its bytes change with each release, and a recorded digest
breaks at the next release. Such an asset uses the signify tier.

### The key file

`deps/KEYS.txt` declares each signify public key. The org pack owns the file,
and sync copies it to each consumer. A consumer adds a third-party key to
`deps/KEYS.local.txt`, which sync must not touch. That split copies the rule
MK-LOCAL-1 of Tooling.

A line holds a name and then one of two forms. The body form gives the key body
as one word. The URL form gives the URL of the key file and the sha256 digest of
that file. Both forms are valid in both files, and one file can mix them.

    # The org pack of FuguBSD/Tooling owns this file. ...
    fugubsd-1-release https://www.fugubsd.org/keys/fugubsd-1-release.pub 9f86d081...
    fugubsd-2-release https://www.fugubsd.org/keys/fugubsd-2-release.pub 2c26b46b...

The field count selects the form. Two fields give the body form, and the body
must be 56 base64 characters that decode to 42 bytes with the prefix `Ed`. Three
fields give the URL form, and the digest must be 64 hexadecimal characters. Any
other count, or a word of the wrong shape, is an error that names the line. A
line that starts with `#` is a comment, so the file can carry the sync marker.
The line order is the trust order, so the current key comes first.

The URL form fetches the key file into a temporary directory, and compares its
digest against the line. A mismatch is an error that names the key. The digest
is the trust anchor, and a rotation must not change a published URL.

The FuguBSD keys use the URL form. Each `make deps` then fetches the published
key and verifies a release signature with it, so every install is a test of the
publication. A key that the website serves wrong, or not at all, or a release
that the published key did not sign, fails at the first consumer install. The
cost is that an outage of the website stops the signify tier. The operator
accepts it, because the release chain must not work while its public record is
broken.

The body form needs no request. The install path writes the body into a key file
in a temporary directory, with an `untrusted comment: ` line that names the key,
and gives that file to signify(1). The form serves a key with no publication
point, or a third-party key that a consumer pins in `deps/KEYS.local.txt`.

The file sits in `deps/` and not in a manifest, because a key does not depend on
the operating system. A manifest entry needs the same lines in each per-OS file.

### The key names

A key file is `<org>-<serial>-<purpose>.<ext>`, for example
`fugubsd-1-release.pub`.

- The organization word is `fugubsd`.
- The serial is an integer with no padding. It starts at 1 for each purpose, and
  each rotation of that purpose adds one. A reader sorts it as a number.
- The purpose names what the key signs. `release` signs the release assets. A
  new purpose starts at serial 1, and a compromise of one purpose leaves the
  others in force.
- The extension names the type. `.pub` is a signify key, and `.asc` is an
  armored GPG key.

The stem, such as `fugubsd-1-release`, is the key name in `deps/KEYS.txt` and in
the site description. The untrusted comment of a signify key is
`<stem> public key`. The name of a key never changes, and a retired key stays
published at its URL, so a release that it signed still verifies.

### The publication

Every key lives under `https://www.fugubsd.org/keys/`. One prefix holds each key
type, and no subdomain exists, because a subdomain needs a second Pages site and
buys nothing.

| Path                                 | Content                                                                               |
| ------------------------------------ | ------------------------------------------------------------------------------------- |
| `keys/<stem>.pub`, `keys/<stem>.asc` | Each key file, byte for byte.                                                         |
| `keys/KEYS`                          | Every GPG key of the site, current keys first, in the Apache form.                    |
| `keys/SHA256`, `keys/SHA256.sig`     | The digest of every key file, signed with the current signify release key.            |
| `keys/index.html`                    | The human page: serial, purpose, type, fingerprint, status and dates of each key.     |
| `.well-known/openpgpkey/`            | The `hu/<hash>` file of each GPG key with an email, and the `policy` file.            |
| `.well-known/security.txt`           | The contact, an expiry, and an `Encryption` field that points at the current GPG key. |

The Web Key Directory reads the apex domain. The implementation confirms that
`fugubsd.org` serves the path, or redirects it to `www` in a form that gpg
follows. Without either, the advanced method needs a CNAME
`openpgpkey.fugubsd.org`, which the Repositories project holds.

### The FuguWeb key directory

FuguWeb owns the key directory, so every FuguBSD site publishes keys the same
way. A `keys` block in `.fuguwebrc` names the source directory under `web/` and
the organization word. One `key` block per key holds the status, the dates, and
for a GPG key the email and the fingerprint. The type comes from the extension,
and the serial and the purpose come from the name.

    keys "keys" {
    	org     = fugubsd
    	contact = mailto:security@fugubsd.org
    }

    key "fugubsd-1-release" {
    	status = current
    	since  = 2026-09-06
    }

The status is `current`, `next` or `retired`. Each purpose holds one `current`
key and at most one `next` key.

The generic parts live in Fugu, per decision 11, so a site build, FuguVM, and a
future tool share one tested implementation. FuguWeb reads the description
blocks, calls the modules, writes the output tree, and runs the checks. Nothing
else lives in FuguWeb.

- A key directory module holds the name pattern, the type from the extension,
  the status vocabulary, the order of a key set, and the text of `KEYS`, of the
  index data, and of `security.txt`.
- An OpenPGP module decodes an armored key to its binary form, computes the v4
  fingerprint from the public key packet, and computes the Web Key Directory
  hash with `Digest::SHA` and a z-base-32 encoder.
- `Fugu::Signify` exposes the manifest parser as a public method, and gains a
  writer for the `SHA256 (key) = digest` form, so the rotation workflow and the
  check share one implementation of the manifest.

Each module reads and writes bytes and text. No module runs gpg or signify, so
the build needs neither command. The bootstrap rule of Tooling does not reach
these modules, because only the synced scripts must stay core-only.

`fuguweb build` copies each key file, and it copies `SHA256` and `SHA256.sig` as
they are. It generates `KEYS`, `index.html`, the `openpgpkey` tree, and
`security.txt` when the block names a contact, through the Fugu modules.

`fuguweb check` holds the directory to the design. Each key file has a block,
and each block has a file. Each name matches the pattern. Each purpose holds one
`current` key. `SHA256` names every key file with its digest. The declared
fingerprint of a GPG key equals the computed one. A signature verification is
the work of the consumer install, because the site build cannot sign.

The site build cannot sign, so `SHA256` and `SHA256.sig` are source files. The
rotation workflow writes them with the Fugu manifest writer, and the check
verifies the digests. The implementation adds a unit to the FuguWeb
specification for the wiring, and one unit to the Fugu specification for each
module. The web pack of Tooling documents the block.

### The rotation procedure

A consumer verifies a signature against its synced copy of `deps/KEYS.txt`. A
release that a new key signs fails in each consumer that holds the old copy. The
rotation therefore runs in two steps, and the trust order carries the gap.

1. The rotation workflow takes the highest serial of the purpose and adds one.
   It generates the pair with `signify -G -n`, writes the public key to
   `web/keys/<stem>.pub` with a `key` block of status `next`, and stores the
   private key as a second secret. It rewrites `keys/SHA256` to name every key
   file, and signs it with the current key, so the current key vouches for the
   next one. It commits, and it opens the pull request against Tooling that adds
   the next key as the second line, with its URL and its digest. Releases still
   sign with the current key.
2. After the Tooling change merges, and after each consumer syncs it, the
   operator switches the release secret to the next key. The workflow sets the
   next key to `current` and the old key to `retired`, signs `keys/SHA256` with
   the new current key, and moves its line to the top of `deps/KEYS.txt`.

A routine rotation keeps the retired key as the second line of `deps/KEYS.txt`
until every release that it signed has a successor. A compromise removes the
line at once. The retired key file stays published in both cases.

The first run of the workflow finds no current key. It sets the new key to
`current` at once, and the key signs its own manifest.

The pull request step is a requirement, not an option. A rotation without it
breaks `make deps` in each consumer as soon as a release carries the new
signature.

### The verification tiers

For each `bin` entry and each `dist` entry, `scripts/deps` runs this order.

1. A `deps/SHA256.txt` entry for the resolved URL gives the digest. The script
   downloads the file and compares the digest.
2. With no such entry, the script derives `SHA256` and `SHA256.sig` from the
   directory part of the download URL. It downloads the pair, verifies the
   signature against the keys of `deps/KEYS.txt`, and then verifies the file
   against the signed manifest. The manifest must name the resolved file name.
   The script verifies the signature before it downloads the file, as
   `Fugu::Signify` does.
3. With neither one, the script stops with an error.

Every download lands in a temporary directory. The script verifies the bytes
before it extracts an archive, and before any file reaches `~/.local/bin`. A
failure removes the temporary directory and leaves the install directory as it
was. A missing `signify(1)` gives an error that names the command.

### The maintenance command

`scripts/deps --update-sums` tries the alias candidates over the network, and it
writes the entries into `deps/SHA256.txt`. The operator runs it. The install
path never runs it.

The table order is the preference order. The command records the first candidate
that answers, and it reports each other candidate that also answers, so the
operator sees a name that the install path rejects as ambiguous.

The command records the digest of the bytes that one download returned. That
step trusts the first download. The operator compares the new entries against
the upstream checksum file that the evidence names, before the commit.

## Work by repository

### Phase 1 — FuguBSD/Tooling

- `scripts/ftp`: add `-f` to the Darwin curl branch.
- `scripts/deps`: add the `tool` word, the alias table, the digest tier, the
  signify tier, the temporary-directory download, and `--update-sums`.
- `mk/org.mk`: run `tool` before `runtime` in the `deps` target.
- `org/sync/deps/KEYS.txt`: add the file, with the FuguBSD keys and the sync
  marker.
- `.github/workflows/perl-release.yml`: install `signify-openbsd`, build a
  `SHA256` manifest that names the versioned tarball and the stable tarball,
  sign it with the release secret, and attach `SHA256` and `SHA256.sig` to the
  release beside the two tarballs.
- `spec/make.md` and `spec/sync.md`: add the units, and amend MK-VERBS-4 and
  MK-GITLEAKS-4.
- `deps/Linux.txt` and `deps/SHA256.txt`: add gitleaks in the `tool`
  environment, with the digest that the action holds today.
- `.github/workflows/check.yml`: the `gitleaks` job runs `make deps` in place of
  the action.
- `org/sync/t/ci/workflows.t`: permit a `make deps` step in a check workflow
  without the setup-perl action. A consumer then installs gitleaks from its
  manifest.
- The action, its test, and WFL-GITLEAKS-1 stay until Phase 5.
- `perl/t/deps.t`: cover the alias table, both key forms, both tiers and each
  error path, with the stub `ftp` sibling that the evidence describes.
- A plan in `Tooling/plans/` lands first, and the implementation deletes it.

### Phase 2 — FuguBSD/Fugu, then FuguBSD/FuguWeb

Fugu lands first, and FuguWeb builds on its release.

- Fugu: add the key directory module and the OpenPGP module, expose the manifest
  parser of `Fugu::Signify`, and add the manifest writer. The tests cover the
  name pattern, each status rule, the armor decoder, the fingerprint and the Web
  Key Directory hash against known vectors, and both manifest directions. Add
  the units to the Fugu specification, and release Fugu.
- FuguWeb, `.fuguwebrc`: add the `keys` block and the `key` block, per the key
  directory design.
- FuguWeb, `App::FuguWeb::Site`: copy the key files and the manifest pair, and
  generate `KEYS`, `index.html`, the `openpgpkey` tree and `security.txt`
  through the Fugu modules.
- FuguWeb, `fuguweb check`: hold the directory to the design.
- FuguWeb, `spec/web.md`: add the unit, and set the register row.
- The FuguWeb tests cover each generated file and each check, against the Fugu
  release.
- Release FuguWeb, because the publish workflow installs the latest release.
- A plan in `Fugu/plans/` and a plan in `FuguWeb/plans/` land first, and each
  implementation deletes its plan.

### Phase 3 — FuguBSD/Website

- `deps/Linux.txt`: add the file, with `tool pkg signify-openbsd`.
- `.fuguwebrc` and `web/keys/`: add the `keys` block, and the first key through
  the rotation workflow.
- Add the rotation workflow, per the rotation procedure.
- Confirm the apex behavior for the Web Key Directory, and set the CNAME in
  Repositories when the apex cannot serve the path.
- The web pack of Tooling documents the `keys` block in `web/CLAUDE.md`.

### Phase 4 — the consumers

Each repository takes the synced files, adds gitleaks to the `tool` environment
of each manifest, and adds its digests. Each repository removes the workaround
comments that name the old expansion. Each check workflow drops the
`Setup gitleaks` step, and a workflow without the `setup-perl` action adds a
`make deps` step.

| Repository   | Work beyond the shared steps                                                   |
| ------------ | ------------------------------------------------------------------------------ |
| .github      | the check workflow only, if one exists                                         |
| Fugu         | no other bin entry                                                             |
| FuguCTX      | digests for scw                                                                |
| FuguSTX      | digests for scw and tofu                                                       |
| FuguTTX      | digests for scw; signify tier for the Fugu dist                                |
| FuguVM       | signify tier for the Fugu dist                                                 |
| FuguWeb      | signify tier for the Fugu dist                                                 |
| Repositories | digests for scw, gh and tofu; remove the `macOS` workaround                    |
| Website      | the manifest from Phase 3                                                      |
| Workspace    | move gitleaks to `tool`; replace `x64` with `{arch}`, and add the arm64 digest |

The Workspace change also rewrites the README paragraph, so it does not name the
action. It sets the register row to `done`. It deletes this plan.

### Phase 5 — FuguBSD/Tooling, the removal

- `actions/setup-gitleaks/`: delete the action.
- `perl/t/setup-gitleaks.t`: delete the test.
- `spec/workflows.md`: retire WFL-GITLEAKS-1, and keep WFL-GITLEAKS-2 and
  WFL-GITLEAKS-3.
- `org/sync/t/ci/workflows.t`: drop the action pin, and sync the test to each
  consumer.
- `spec/STATUS.md`: set the WFL-GITLEAKS row.

## Status

### What lands now

Phase 1 and Phase 2 wait on nothing. Each starts now, and the two run in
parallel.

The Workspace holds the parts of its change that the current synced
`scripts/deps` accepts. `deps/SHA256.txt` records the Linux digests of gh and of
gitleaks, `t/ci/deps.t` keeps it in step with the manifest, and WS-DEPS states
the target design. The register holds the unit as `partial`.

### What waits

Phase 3 waits on Phase 1, because the rotation workflow needs the key file
format and the `tool` environment. It waits on a Fugu release and a FuguWeb
release with Phase 2, because the publish workflow installs the latest release
of each.

Phase 4 waits on Phase 1 for each repository. The three repositories with a
`dist` line also wait on Phase 3, and on one signed Fugu release. Their
`make deps` fails until a signature exists, and that failure is the design.

The rest of the Workspace change waits on Phase 1. That Phase must ship the
`tool` word, the alias table, and the change to `t/ci/workflows.t`. The
workspace then takes the `tool` environment and the `{arch}` placeholder of the
gitleaks entry. It also takes the `make deps` step of the check workflow, the
README paragraph, and the `done` register row. The deletion of this plan lands
with them.

Phase 5 waits on every check workflow of Phase 4. A consumer that still uses the
action fails at the step when the action is gone.

### Open questions

1. The tofu version differs between two repositories. Repositories pins 1.10.6,
   and FuguSTX pins 1.12.6. The operator picks one version, or keeps both.
2. FuguOracle and FuguPass hold no `deps/` directory. Phase 3 gives Website a
   manifest. The operator confirms which of the other two needs one.
3. The digest file needs one entry for each operating system and architecture
   pair that the organization supports. Some pairs run on no machine here. The
   implementation records the digest from the upstream checksum file.
4. [plans/CLAUDE.md](../CLAUDE.md) states that a plan must not describe work
   that another repository implements. This plan describes the work of eleven
   repositories. The operator confirms the location, or moves the Tooling design
   into the Tooling plan and keeps the rollout table here.
5. The Workspace holds `deps/Linux.txt` only, and the operator works on Darwin.
   The design names gitleaks in `deps/Darwin.txt` as well, so `make deps`
   replaces the Homebrew install. The operator confirms whether the Workspace
   gets a Darwin manifest.
