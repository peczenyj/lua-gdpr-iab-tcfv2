# Design — SLSA Build provenance for releases

**Date:** 2026-05-18
**Status:** Approved
**Target:** SLSA Build Level 1 (provenance exists and is distributed to consumers)

## Problem

`lua-gdpr-iab-tcfv2` releases ship a source tarball, a `.src.rock`, and a
`.rockspec` as GitHub Release assets, plus a LuaRocks publish. The build is
already fully scripted (`make dist`, `make pack`) and runs on a GitHub-hosted
runner via `.github/workflows/release.yml` — not a developer workstation.

The one gap against SLSA Build L1 is **provenance**: the release does not
generate or distribute a signed statement describing how each artifact was
produced.

## Goal

Add provenance generation to the release pipeline so that SLSA Build L1 is
satisfied, document the claim and consumer-side verification, and gate the
release on successful provenance verification.

## Chosen approach

`actions/attest-build-provenance` — the GitHub-native attestation action.

It generates SLSA v1.0 provenance for the named artifacts, signs it with a
short-lived OIDC certificate (keyless), records it in a public transparency
log, and stores it in the repository's attestation API. Because the build runs
on a GitHub-hosted, isolated runner, the result clears Build **L2** in
practice — comfortably past the L1 target — with no extra effort.

Rejected alternatives:

- **`slsa-framework/slsa-github-generator`** — aimed at Build L3; requires
  restructuring `release.yml` around a reusable build workflow. Overkill for an
  L1 goal and harder to reconcile with the existing `make dist`/`make pack` +
  `softprops/action-gh-release` flow.
- **Hand-rolled in-toto provenance** — reinvents the chosen action without
  signing or a transparency-log entry unless those are also built by hand.

## Scope

Provenance covers the two genuinely built artifacts:

- `lua-gdpr-iab-tcfv2-*.tar.gz` (from `make dist`)
- `lua-gdpr-iab-tcfv2-*.src.rock` (from `make pack`)

The `.rockspec` is a hand-edited file committed to the repository, not a build
output, and is excluded.

## Changes

### 1. `.github/workflows/release.yml`

**Permissions.** The workflow-level `permissions: contents: write` block moves
to a job-scoped block on the `publish` job (least privilege — the `test` job
does not need write access), extended with the two scopes the attestation
action requires:

```yaml
  publish:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: write       # create release + upload assets
      id-token: write       # OIDC token for keyless signing
      attestations: write   # store attestation in GitHub's API
```

**New steps**, inserted between "Build dist artifacts" and "Upload GitHub
Release":

```yaml
- name: Generate SLSA provenance
  uses: actions/attest-build-provenance@v2
  with:
    subject-path: |
      lua-gdpr-iab-tcfv2-*.tar.gz
      lua-gdpr-iab-tcfv2-*.src.rock

- name: Verify provenance
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    for f in lua-gdpr-iab-tcfv2-*.tar.gz lua-gdpr-iab-tcfv2-*.src.rock; do
      gh attestation verify "$f" --repo "${{ github.repository }}"
    done
```

Action versions follow the repository's existing convention (tags such as
`@v4`/`@v2`, not SHA-pinned).

### 2. Data flow and gating

```
make dist / make pack  →  attest  →  verify  →  upload GitHub release  →  publish LuaRocks
```

Verification runs *before* the upload steps. If `attest` or `verify` fails, the
job fails, the release assets are never uploaded, and the LuaRocks publish never
runs — a broken-provenance release produces no artifacts at all. This matches
the existing "CI fails on the tag" recovery path in `RELEASING.md`: the tag
exists, no artifacts shipped, fix forward with the next patch tag.

### 3. Documentation

- **`SECURITY.md`** — add a "Verifying release artifacts" section with the
  consumer command:
  `gh attestation verify <file> --repo peczenyj/lua-gdpr-iab-tcfv2`
- **`RELEASING.md`** — update the step-7 `release.yml` description to list
  provenance generation and verification, and add a post-release checklist item
  to confirm the attestation is listed under the repository's attestations.

## Known limitation

`luarocks upload` builds and uploads its own artifact to luarocks.org
server-side. The provenance covers the **GitHub Release** `.tar.gz` and
`.src.rock` only. Consumers who `luarocks install` from luarocks.org cannot
verify provenance; only those downloading the GitHub Release assets can.
`SECURITY.md` will state this plainly rather than imply broader coverage.

## Testing

Workflow changes are not exercised by `make ci`. Verification is:

1. Lint / review the workflow YAML for syntax.
2. The embedded `gh attestation verify` step is self-checking — the first real
   tagged release proves the whole chain end to end or fails closed.

No artifacts ship on failure, so there is no unsafe outcome to guard against
beyond a release that produces nothing.

## Out of scope

- SHA-pinning all GitHub Actions (a reasonable supply-chain hardening
  follow-up, but not required for L1).
- Provenance for the luarocks.org distribution channel.
- Higher SLSA build levels (L3) via an isolated reusable build workflow.
