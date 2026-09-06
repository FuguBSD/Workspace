# 001 — Verified dependency installs across the organization

`scripts/deps` downloads a binary and installs it without a check of the bytes.
It also expands one architecture word and one operating system word, so a
release asset with a different spelling needs a hardcoded workaround. This plan
adds two guarantees. Each downloaded file must match a recorded sha256 digest,
or a signify signature. Each download URL must resolve through an alias table,
so no manifest holds a hardcoded platform word.

The work starts in FuguBSD/Tooling, because the org pack owns `scripts/deps`,
`scripts/ftp` and `mk/org.mk`. The rollout then reaches every consumer.

## Citations

Implements: none. The design units do not exist yet.

The implementation adds the units to the Tooling specification, in
`spec/make.md` and `spec/sync.md`. It then extends the workspace unit
[WS-DEPS](../../spec/workspace.md#ws-deps) with three rules, and sets the
register row in the same change. The rules cover the digest file, the key files,
and the `tool` entry that installs signify. This plan names no rule number,
because a number exists only after the rule lands.

This plan is the record of the organization. [plans/CLAUDE.md](../CLAUDE.md)
states that a plan lives in the repository that implements it, and describes the
work of that repository only. The workspace covers every project, so the
operator keeps the design here. Each implementing repository takes its own plan
from this one, and the Tooling plan lands first. Open question 5 records the
tension with the rule.

## Decisions

The operator made these decisions. An implementation must not reverse one
without approval.

| #   | Decision                                                                                                                 |
| --- | ------------------------------------------------------------------------------------------------------------------------ |
| 1   | Alias resolution reads the digest manifest. The install path must not probe the network. An ambiguous match is an error. |
| 2   | Each entry that downloads a URL must carry a sha256 digest, or a signify signature. Neither one present is an error.     |
| 3   | The digests live in `deps/SHA256.txt`, in BSD format, keyed by file name.                                                |
| 4   | A new `tool` environment installs before every other environment. A `tool` entry must not use the signify tier.          |
| 5   | `scripts/deps` derives the signature URLs from the download URL base, so the signify tier stays generic.                 |
| 6   | The release key lives online, as a GitHub organization secret. A workflow of the Website repository rotates it.          |
| 7   | The rule MK-GITLEAKS-4 of Tooling changes, so a manifest can provide gitleaks.                                           |
| 8   | `deps/KEYS.txt` declares each signify public key by URL. `deps/KEYS.local.txt` holds a consumer key.                     |

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

### Tooling already pins the gitleaks digest

The `setup-gitleaks` action of Tooling installs
`gitleaks_8.30.1_linux_x64.tar.gz` and checks it against the sha256 default
`551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb`
(WFL-GITLEAKS-1 of Tooling). The workspace entry in `deps/SHA256.txt` must hold
the same digest, as WS-DEPS-4 holds the same version. Two pins name one binary.

### The setup-perl action fixes the environment words

The `setup-perl` action of Tooling accepts `runtime`, `test` or `develop` as its
`dependencies` input, and rejects every other word. It maps `runtime` to
`make deps`, and the other two to `make deps-<name>`. The decision D-08 of
Tooling fixes the three target names. A `tool` environment therefore cannot get
a target of its own. It must run inside `make deps`.

### The organization already holds the signify pattern

`Fugu/lib/Fugu/Signify.pm` verifies a signify signature over a SHA256 manifest,
and then each named file against its digest. The manifest format is
`SHA256 (filename) = hexdigest`, the format that decision 3 names. The module
verifies the signature before it digests any file, and it rejects an empty
manifest, a bad line, and a duplicate name. The module accepts a key set in
trust order: the current key first, and the next key second.

`FuguVM/lib/App/FuguVM/Mirror.pm` consumes that module. It names each key file
after the OpenBSD release, for example `openbsd-78-base.pub`, and resolves it
through an explicit directory, then `/etc/signify`, then a share tree. It passes
one key to the module.

`Fugu::Signify` holds no private key, and it cannot sign.

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
OpenBSD holds the command in base. The workspace needs the Linux entry.

### Alias resolution

`scripts/deps` holds a table of aliases for the operating system word and for
the architecture word. The candidate set is the cross product of the two lists.

- The architecture `x86_64` gives `amd64`, `x64` and `x86_64`.
- The architecture `aarch64` and `arm64` give `arm64` and `aarch64`.
- The operating system `Darwin` gives `darwin`, `macOS`, `macos` and `osx`.
- The operating system `Linux` gives `linux`, and `OpenBSD` gives `openbsd`.

The script forms one file name for each candidate. It then selects the candidate
that `deps/SHA256.txt` names. No match is an error, and two matches are an
error. The install path makes no request to find the URL.

One selected pair expands both the URL and the member path of an entry. The
member path of the gh entry holds the same words as the asset name, and the two
must agree.

An entry with a placeholder needs a digest entry, because the resolution reads
the digest file. The signify tier therefore serves an entry without a
placeholder only. Today that set is the `dist` lines. The specification must
state this limit.

### The digest manifest

`deps/SHA256.txt` holds one line for each downloaded file, in BSD format. One
file serves every operating system and every architecture, because the asset
names differ already. The parser copies the rules of `Fugu::Signify`: a bad
line, a digest that is not 64 hexadecimal characters, and a duplicate name are
each an error.

    SHA256 (gh_2.97.0_linux_amd64.tar.gz) = 30a1...
    SHA256 (gitleaks_8.30.1_linux_x64.tar.gz) = 551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb

A stable-name asset, such as `releases/latest/download/Fugu.tar.gz`, must not
appear in the file. Its bytes change with each release, and a recorded digest
breaks at the next release. Such an asset uses the signify tier.

### The key file

`deps/KEYS.txt` declares each signify public key by URL. The org pack owns the
file, and sync copies it to each consumer. A consumer adds a third-party key to
`deps/KEYS.local.txt`, which sync must not touch. That split copies the rule
MK-LOCAL-1 of Tooling.

    # The org pack of FuguBSD/Tooling owns this file. ...
    fugubsd-1 https://www.fugubsd.org/signify/fugubsd-1.pub 9f86d081...

Each line holds a name, a URL and the sha256 digest of the key file. A line that
starts with `#` is a comment, so the file can carry the sync marker. The line
order is the trust order, so the current key comes first. The digest is the
trust anchor, and the website is the publication point. A rotation adds a
serial, and it must not change a published URL.

The install path fetches each key into a temporary directory, and compares its
digest against the line. A mismatch is an error that names the key.

The file sits in `deps/` and not in a manifest, because a key does not depend on
the operating system. A manifest entry needs the same three lines in each per-OS
file.

### The rotation procedure

A consumer verifies a signature against its synced copy of `deps/KEYS.txt`. A
release that a new key signs fails in each consumer that holds the old copy. The
rotation therefore runs in two steps, and the trust order carries the gap.

1. The rotation workflow generates the next key pair. It publishes the public
   key, stores the private key as a second secret, and opens the pull request
   against Tooling that adds the next key as the second line. Releases still
   sign with the current key.
2. After the Tooling change merges, and after each consumer syncs it, the
   operator switches the release secret to the next key, and moves its line to
   the top. The old key stays as the second line until no consumer needs it.

The pull request step is a requirement, not an option. A rotation without it
breaks `make deps` in each consumer as soon as a release carries the new
signature.

### The verification tiers

For each `bin` entry and each `dist` entry, `scripts/deps` runs this order.

1. A `deps/SHA256.txt` entry for the resolved file name gives the digest. The
   script downloads the file and compares the digest.
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
- `perl/t/deps.t`: cover the alias table, both tiers and each error path, with
  the stub `ftp` sibling that the evidence describes.
- A plan in `Tooling/plans/` lands first, and the implementation deletes it.

### Phase 2 — FuguBSD/Website

- `deps/Linux.txt`: add the file, with `tool pkg signify-openbsd`.
- Publish the public key under a stable URL.
- Add the rotation workflow, per the rotation procedure. It generates the key
  pair with `signify -G -n`, stores the secret, commits the public key, and
  opens a pull request against Tooling that adds the new serial to
  `org/sync/deps/KEYS.txt`.

### Phase 3 — the consumers

Each repository takes the synced files, and then adds its digests. Each
repository removes the workaround comments that name the old expansion.

| Repository   | Work                                                                                       |
| ------------ | ------------------------------------------------------------------------------------------ |
| Fugu         | sync; no bin entry, so the digest file stays empty                                         |
| FuguCTX      | sync; digests for scw                                                                      |
| FuguSTX      | sync; digests for scw and tofu                                                             |
| FuguTTX      | sync; digests for scw; signify tier for the Fugu dist                                      |
| FuguVM       | sync; signify tier for the Fugu dist                                                       |
| FuguWeb      | sync; signify tier for the Fugu dist                                                       |
| Repositories | sync; digests for scw, gh and tofu; remove the `macOS` workaround                          |
| Workspace    | sync; `tool pkg signify-openbsd`; digests for gh and gitleaks; remove the `x64` workaround |

The Workspace change also extends WS-DEPS, sets the register row, and deletes
this plan. The gitleaks digest must equal the `setup-gitleaks` default of
Tooling, and the workspace test proves it against the checkout of Tooling that
the sync job holds.

## Status

### What lands now

This plan lands now. It records the decisions, the evidence and the design.

### What waits

Phase 1 waits on nothing. It starts as soon as this plan merges.

Phase 2 waits on Phase 1, because the rotation workflow needs the key file
format and the `tool` environment.

Phase 3 waits on Phase 1 for each repository. The three repositories with a
`dist` line also wait on Phase 2, and on one signed Fugu release. Their
`make deps` fails until a signature exists, and that failure is the design.

### Open questions

1. The tofu version differs between two repositories. Repositories pins 1.10.6,
   and FuguSTX pins 1.12.6. The operator picks one version, or keeps both.
2. FuguOracle and FuguPass hold no `deps/` directory. Phase 2 gives Website a
   manifest. The operator confirms which of the other two needs one.
3. The digest file needs one entry for each operating system and architecture
   pair that the organization supports. Some pairs run on no machine here. The
   implementation records the digest from the upstream checksum file.
4. A signify public key is one base64 line of 56 characters. `deps/KEYS.txt`
   could hold the key body in place of the URL and the digest. The install path
   then needs no request to the website, and a website outage cannot stop
   `make deps`. Decision 8 names the URL, so the operator decides.
5. [plans/CLAUDE.md](../CLAUDE.md) states that a plan must not describe work
   that another repository implements. This plan describes the work of eleven
   repositories. The operator confirms the location, or moves the Tooling design
   into the Tooling plan and keeps the rollout table here.
