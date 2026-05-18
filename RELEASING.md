# Releasing

How to cut a new release of `lua-gdpr-iab-tcfv2`. Releases follow Gitflow: a short-lived `release/X.Y.Z` branch from `devel`, merged into `main`, tagged from `main`, and merged back into `devel`. The `v*` tag triggers `.github/workflows/release.yml`, which runs the full CI gate, builds artifacts, creates the GitHub release, and uploads to LuaRocks.

## Version policy

The project is pre-1.0; semantic versioning applies under the 0.x.y convention:

- **`0.X.0` (minor)**: new features, or any behavior change that could break consumers (error message wording, validator semantics, parser strictness).
- **`0.x.Y` (patch)**: bug fixes and internal changes that preserve observable behavior.

When in doubt, prefer a minor bump; pre-1.0 consumers should expect minor bumps to carry breaking changes.

## Pre-release checklist

Before opening a release branch, confirm on `devel`:

- [ ] All target PRs are merged.
- [ ] `make ci` passes locally.
- [ ] `git status` is clean (in particular, `test/corpus/golden.jsonl` is not dirty).
- [ ] The version number is chosen per the policy above.

## Release procedure

The steps below assume version `X.Y.Z`. Use real digits in every command.

### 1. Create the release branch

```bash
git checkout devel
git pull --ff-only
git checkout -b release/X.Y.Z
```

### 2. Bump the version

Three edits, all required:

- **`Makefile`** — update the `VERSION` constant:
  ```make
  VERSION = X.Y.Z
  ```
- **Rockspec** — rename the file and update the two version-bound fields:
  ```bash
  git mv lua-gdpr-iab-tcfv2-<prev>-1.rockspec lua-gdpr-iab-tcfv2-X.Y.Z-1.rockspec
  ```
  Inside the renamed file:
  ```lua
  version = "X.Y.Z-1"
  source = { ..., tag = "vX.Y.Z" }
  ```
- **Parity wording** — if the release changes the parity guarantee, update the matching prose in `README.md` (Features section) and the rockspec `description.detailed` block. Skip if unchanged.

### 3. Verify locally

```bash
make ci
```

This must pass. The same workflow gates the tag-triggered publish, so a failure here means the release would fail in CI anyway.

### 4. Regenerate the changelog

`make changelog` runs `git-cliff -o CHANGELOG.md` without a tag argument, so unreleased commits land under an `[unreleased]` heading. To label them with the new version, invoke `git-cliff` directly:

```bash
git-cliff --tag vX.Y.Z -o CHANGELOG.md
```

Review the diff. `cliff.toml` skips `chore`, `style`, `test`, and merge commits, so a release dominated by chores will produce a thin section — that is expected.

### 5. Commit and push

```bash
git add Makefile lua-gdpr-iab-tcfv2-X.Y.Z-1.rockspec lua-gdpr-iab-tcfv2-<prev>-1.rockspec README.md CHANGELOG.md
git commit -m "chore(release): X.Y.Z"
git push -u origin release/X.Y.Z
```

### 6. Open the PR and merge

Open a pull request from `release/X.Y.Z` into `main`. Title: `chore(release): X.Y.Z`. After review, merge with a **merge commit** (not squash) so `main`'s history records the release point cleanly.

### 7. Tag from main

```bash
git checkout main
git pull --ff-only
git tag -a vX.Y.Z -m "Tagged for release. vX.Y.Z"
git push origin vX.Y.Z
```

Pushing the tag triggers `release.yml`:

1. Reuses `ci.yml` as the test gate across the full matrix.
2. On a clean pass, runs `make dist` (source tarball) and `make pack` (`.src.rock`).
3. Generates SLSA build provenance for the `*.tar.gz` and `*.src.rock`, then verifies it with `gh attestation verify`. A verification failure fails the job before any artifact is uploaded.
4. Creates the GitHub release with `*.tar.gz`, `*.src.rock`, and `*.rockspec` attached.
5. Publishes to LuaRocks via `luarocks upload`.

### 8. Sync devel back

```bash
git checkout devel
git merge --no-ff main
git push origin devel
```

## Post-release verification

- [ ] `release.yml` finished green on the tag.
- [ ] The release appears at `https://github.com/peczenyj/lua-gdpr-iab-tcfv2/releases/tag/vX.Y.Z` with all three asset types attached.
- [ ] The build provenance is listed at `https://github.com/peczenyj/lua-gdpr-iab-tcfv2/attestations`, and `gh attestation verify <downloaded-asset> --repo peczenyj/lua-gdpr-iab-tcfv2` succeeds.
- [ ] The version is listed on `https://luarocks.org/modules/peczenyj/lua-gdpr-iab-tcfv2`.
- [ ] `git log main --oneline` shows the merge commit followed by the tag.

## If the release fails partway through

- **CI fails on the tag** — the tag exists but no artifacts were published. Fix the underlying problem on `devel`, cherry-pick or merge into a fresh `release/X.Y.Z+1` branch, and start over with a new tag. Do not delete and recreate the failed tag; downstream consumers may already have fetched it.
- **LuaRocks upload fails after GitHub release succeeded** — re-run the publish job manually, or upload the rockspec locally with `luarocks upload lua-gdpr-iab-tcfv2-X.Y.Z-1.rockspec --api-key=...`.
- **Wrong content tagged** — issue a patch release (`X.Y.Z+1`) with the correction; never force-push or move a published tag.
