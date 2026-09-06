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
[WS-DEPS](../../spec/workspace.md#ws-deps) with the new rules, and sets the
register row in the same change. This plan lives here, and not in Tooling,
because the workspace covers every project of the organization.

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

## Evidence

A cold session must not repeat this research.

### The fetcher accepts an error page

`scripts/ftp` runs `curl -L -o` on Darwin, with no `-f` option. A measured 404
exits 0 and writes a 9-byte body that holds the text `Not Found`. `scripts/deps`
then sets mode 755 on that file in `~/.local/bin`. The Linux branch runs
`wget -O`, which exits 8 and leaves an empty file. The Darwin branch needs `-f`
before any other work starts.

### Two hardcoded platform words exist today

The alias problem covers the operating system word and the architecture word.

| Manifest                       | Hardcoded word                    | Cause                                 |
| ------------------------------ | --------------------------------- | ------------------------------------- |
| `Repositories/deps/Darwin.txt` | `gh_2.97.0_macOS_{arch}.zip`      | The `{os}` expansion gives `darwin`.  |
| `Workspace/deps/Linux.txt`     | `gitleaks_8.30.1_{os}_x64.tar.gz` | The `{arch}` expansion gives `amd64`. |

The gitleaks release assets confirm the second cause. Each
`gitleaks_<version>_linux_amd64.tar.gz` answers 404, and each
`gitleaks_<version>_linux_x64.tar.gz` answers 200.

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

### The organization already holds the signify pattern

`Fugu/lib/Fugu/Signify.pm` verifies a signify signature over a SHA256 manifest,
and then each named file against its digest. The manifest format is
`SHA256 (filename) = hexdigest`, the format that decision 3 names.
`FuguVM/lib/App/FuguVM/Mirror.pm` consumes that module. It resolves a key
through an explicit directory, then `/etc/signify`, then a share tree, and it
names each key by serial. The module accepts a key set in trust order: the
current key first, and the next key second.

`Fugu::Signify` holds no private key, and it cannot sign.

### One release workflow covers every distribution

`Tooling/.github/workflows/perl-release.yml` builds and publishes every Perl
distribution of the organization. It already copies the versioned tarball to a
stable name, and a comment names the deps manifests as the consumer of that
name. It already binds an `environment: release` that holds secrets. One change
there reaches Fugu, FuguVM, FuguWeb and FuguTTX.

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

## Design

### The tool environment

The environment words become `tool`, `runtime`, `test` and `develop`.
`mk/org.mk` installs `tool` first in each deps target. A repeated target chain,
such as `deps-test` over `deps`, must install `tool` one time only.

A `tool` entry must not use the signify tier, because that tier needs
`signify(1)`. A project whose platform lacks the command adds a `tool` entry for
it, as `tool pkg signify-openbsd` on Linux and `tool pkg signify-osx` on Darwin.
The workspace needs such an entry.

The rule MK-VERBS-4 of Tooling keeps the three target names. The `setup-perl`
action computes names from its `dependencies` input, so the implementation
checks that action for the new word.

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

### The digest manifest

`deps/SHA256.txt` holds one line for each downloaded file, in BSD format. One
file serves every operating system and every architecture, because the asset
names differ already.

    SHA256 (gh_2.97.0_linux_amd64.tar.gz) = 30a1...
    SHA256 (gitleaks_8.30.1_linux_x64.tar.gz) = 551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb

### The key file

`deps/KEYS.txt` declares each signify public key by URL. The org pack owns the
file, and sync copies it to each consumer. A consumer adds a third-party key to
`deps/KEYS.local.txt`, which sync must not touch. That split copies the rule
MK-LOCAL-1 of Tooling.

    fugubsd-1 https://www.fugubsd.org/signify/fugubsd-1.pub 9f86d081...

Each line holds a name, a URL and the sha256 digest of the key file. The line
order is the trust order, so the current key comes first. The digest is the
trust anchor, and the website is the publication point. A rotation adds a
serial, and it must not change a published URL.

The file sits in `deps/` and not in a manifest, because a key does not depend on
the operating system. A manifest entry needs the same three lines in each per-OS
file.

### The verification tiers

For each `bin` entry and each `dist` entry, `scripts/deps` runs this order.

1. A `deps/SHA256.txt` entry for the resolved file name gives the digest. The
   script downloads the file and compares the digest.
2. With no such entry, the script derives `SHA256` and `SHA256.sig` from the
   directory part of the download URL. It downloads the pair, verifies the
   signature against the keys of `deps/KEYS.txt`, and then verifies the file
   against the signed manifest.
3. With neither one, the script stops with an error.

A missing `signify(1)` gives an error that names the command.

### The maintenance command

`scripts/deps --update-sums` tries the alias candidates over the network, and it
writes the entries into `deps/SHA256.txt`. The operator runs it. The install
path never runs it.

## Work by repository

### Phase 1 — FuguBSD/Tooling

- `scripts/ftp`: add `-f` to the Darwin curl branch.
- `scripts/deps`: add the `tool` word, the alias table, the digest tier, the
  signify tier and `--update-sums`.
- `mk/org.mk`: install `tool` first in each deps target.
- `org/sync/deps/KEYS.txt`: add the file, with the FuguBSD keys.
- `.github/workflows/perl-release.yml`: build `SHA256`, sign it, and attach both
  files to the release.
- `spec/make.md` and `spec/sync.md`: add the units, and amend MK-VERBS-4 and
  MK-GITLEAKS-4.
- `perl/t/deps.t`: cover the alias table, both tiers and each error path.
- A plan in `Tooling/plans/` lands first, and the implementation deletes it.

### Phase 2 — FuguBSD/Website

- `deps/Linux.txt`: add the file, with `tool pkg signify-openbsd`.
- Publish the public key under a stable URL.
- Add the rotation workflow. It generates the key pair, stores the secret,
  commits the public key, and opens a pull request against Tooling that adds the
  new serial to `org/sync/deps/KEYS.txt`.

The pull request step is a requirement, not an option. A rotation without it
breaks `make deps` in each consumer as soon as a release carries the new
signature.

### Phase 3 — the consumers

Each repository takes the synced files, and then adds its digests.

| Repository   | Work                                                              |
| ------------ | ----------------------------------------------------------------- |
| Fugu         | sync; no bin entry, so the digest file stays empty                |
| FuguCTX      | sync; digests for scw                                             |
| FuguSTX      | sync; digests for scw and tofu                                    |
| FuguTTX      | sync; digests for scw; signify tier for the Fugu dist             |
| FuguVM       | sync; signify tier for the Fugu dist                              |
| FuguWeb      | sync; signify tier for the Fugu dist                              |
| Repositories | sync; digests for scw, gh and tofu; remove the `macOS` workaround |
| Workspace    | sync; digests for gh and gitleaks; remove the `x64` workaround    |

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
2. FuguOracle, FuguPass and Website hold no `deps/` directory. The operator
   confirms which one needs a manifest.
3. The digest file needs one entry for each operating system and architecture
   pair that the organization supports. Some pairs run on no machine here. The
   implementation records the digest from the published asset.
