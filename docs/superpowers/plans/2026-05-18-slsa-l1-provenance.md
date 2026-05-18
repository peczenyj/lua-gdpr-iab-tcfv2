# SLSA Build L1 Provenance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate, verify, and document SLSA provenance for GitHub Release artifacts so the project satisfies SLSA Build Level 1.

**Architecture:** Add two steps to the existing `publish` job in `.github/workflows/release.yml` — one that generates signed SLSA provenance for the release artifacts via `actions/attest-build-provenance`, and one that verifies it with `gh attestation verify` before any artifact is uploaded. Document the claim and consumer verification in `SECURITY.md` and `RELEASING.md`.

**Tech Stack:** GitHub Actions, `actions/attest-build-provenance@v2`, GitHub CLI (`gh attestation`), Markdown docs.

---

## Context for the implementer

This repository is a pure-Lua library. There is no application code to change here — the entire change is GitHub Actions workflow YAML and Markdown documentation. There is no unit-test harness for workflows, so the usual TDD loop does not apply. Verification is: YAML syntax linting, and a careful manual diff review against the snippets in this plan. The workflow's real end-to-end test is the next tagged release; the embedded `gh attestation verify` step makes that release fail closed if provenance is broken.

The design spec this plan implements: `docs/superpowers/specs/2026-05-18-slsa-l1-provenance-design.md`.

Work happens on branch `feat/slsa-l1-provenance` (already created and checked out; the design spec is already committed there).

## File Structure

- **Modify** `.github/workflows/release.yml` — move `permissions` to the `publish` job, add provenance generation + verification steps.
- **Modify** `SECURITY.md` — add a "Verifying release artifacts" section.
- **Modify** `RELEASING.md` — describe provenance in the `release.yml` step list and the post-release checklist.

No new files. No source code changes.

---

## Task 1: Add provenance generation and verification to `release.yml`

**Files:**
- Modify: `.github/workflows/release.yml`

The current file (for reference — verify it matches before editing):

```yaml
name: Release

on:
  push:
    tags: [ "v*" ]

# Needed so softprops/action-gh-release@v2 can attach assets to the
# auto-created release for this tag.
permissions:
  contents: write

jobs:
  # Reuse the full ci.yml matrix as the release gate. If any cell
  # fails, `publish` is skipped. `secrets: inherit` lets the called
  # workflow see COVERALLS_REPO_TOKEN (and anything else CI consumes).
  test:
    uses: ./.github/workflows/ci.yml
    secrets: inherit

  publish:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Lua
        uses: hishamhm/gh-actions-lua@master
        with:
          luaVersion: "5.4"
      - name: Setup LuaRocks
        uses: hishamhm/gh-actions-luarocks@master
        with:
          luaRocksVersion: "3.13.0"
      - name: Build dist artifacts
        run: |
          make dist
          make pack
      - name: Upload GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            lua-gdpr-iab-tcfv2-*.tar.gz
            lua-gdpr-iab-tcfv2-*.src.rock
            *.rockspec
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: Publish to LuaRocks
        run: luarocks upload *.rockspec --api-key=${{ secrets.LUAROCKS_APIKEY }}
```

- [ ] **Step 1: Move `permissions` from workflow level to the `publish` job**

Delete the workflow-level `permissions` block and its comment:

```yaml
# Needed so softprops/action-gh-release@v2 can attach assets to the
# auto-created release for this tag.
permissions:
  contents: write

jobs:
```

Replace with just:

```yaml
jobs:
```

Then add a job-scoped `permissions` block to the `publish` job. Change:

```yaml
  publish:
    needs: test
    runs-on: ubuntu-latest
    steps:
```

to:

```yaml
  publish:
    needs: test
    runs-on: ubuntu-latest
    # contents: write  -> create the release and upload assets
    # id-token: write  -> OIDC token for keyless signing of provenance
    # attestations: write -> store the attestation in GitHub's API
    permissions:
      contents: write
      id-token: write
      attestations: write
    steps:
```

- [ ] **Step 2: Insert provenance generation and verification steps**

Insert two new steps between the `Build dist artifacts` step and the `Upload GitHub Release` step. After the change, that region of the file reads:

```yaml
      - name: Build dist artifacts
        run: |
          make dist
          make pack
      - name: Generate SLSA provenance
        uses: actions/attest-build-provenance@v2
        with:
          subject-path: |
            lua-gdpr-iab-tcfv2-*.tar.gz
            lua-gdpr-iab-tcfv2-*.src.rock
      - name: Verify provenance
        # Runs before the upload steps: a verification failure fails the
        # job, so no release assets are uploaded and LuaRocks is not
        # published. A broken-provenance release produces no artifacts.
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          for f in lua-gdpr-iab-tcfv2-*.tar.gz lua-gdpr-iab-tcfv2-*.src.rock; do
            gh attestation verify "$f" --repo "${{ github.repository }}"
          done
      - name: Upload GitHub Release
        uses: softprops/action-gh-release@v2
```

(The `Upload GitHub Release` and `Publish to LuaRocks` steps are unchanged.)

- [ ] **Step 3: Lint the workflow YAML**

Run: `actionlint .github/workflows/release.yml`
Expected: no output, exit code 0.

If `actionlint` is not installed, instead run:
`python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/release.yml')); print('YAML OK')"`
Expected: `YAML OK`

Then visually diff the file against the snippets above:
Run: `git diff .github/workflows/release.yml`
Expected: only the `permissions` move and the two inserted steps appear; no other lines changed.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci(slsa): generate and verify SLSA provenance on release

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Document release verification in `SECURITY.md`

**Files:**
- Modify: `SECURITY.md`

The current file in full:

```markdown
# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability within this project, please send an e-mail to **tiago.peczenyj+lua@gmail.com**.

All security vulnerabilities will be promptly addressed. We request that you do not report security-related issues through public GitHub issues.
```

- [ ] **Step 1: Append the "Verifying release artifacts" section**

Add the following section to the end of `SECURITY.md`:

```markdown

## Verifying release artifacts

Release artifacts published on the project's GitHub Releases page carry SLSA
build provenance (SLSA Build Level 1). The provenance is a signed statement,
generated by GitHub Actions during the release, describing exactly which
workflow, commit, and build produced each artifact.

Provenance is generated for the source tarball (`*.tar.gz`) and the source
rock (`*.src.rock`). To verify a downloaded artifact, use the GitHub CLI:

​```bash
gh attestation verify lua-gdpr-iab-tcfv2-X.Y.Z.tar.gz \
  --repo peczenyj/lua-gdpr-iab-tcfv2
​```

A successful run confirms the artifact was built by this repository's release
workflow and has not been altered since.

**Scope:** Provenance covers the artifacts attached to a GitHub Release only.
Packages installed from luarocks.org are built and uploaded by LuaRocks itself
and are not covered by this provenance; verify against the GitHub Release
asset if you need the provenance guarantee.
```

Note: the three backtick lines inside the snippet above are shown with a
zero-width marker (`​`) so this plan renders correctly. When editing
`SECURITY.md`, write plain triple backticks (` ``` `) with no marker.

- [ ] **Step 2: Verify the file renders sensibly**

Run: `cat SECURITY.md`
Expected: the new section appears at the end, the `gh attestation verify`
command is inside a fenced code block, and there are no stray `​` characters.

- [ ] **Step 3: Commit**

```bash
git add SECURITY.md
git commit -m "docs(security): document SLSA provenance verification for releases

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Document provenance in the release process (`RELEASING.md`)

**Files:**
- Modify: `RELEASING.md`

Two edits: the `release.yml` step list (around lines 93-98) and the
post-release verification checklist (around lines 109-113).

- [ ] **Step 1: Update the `release.yml` numbered step list**

Find this block in `RELEASING.md` (under "### 7. Tag from main"):

```markdown
Pushing the tag triggers `release.yml`:

1. Reuses `ci.yml` as the test gate across the full matrix.
2. On a clean pass, runs `make dist` (source tarball) and `make pack` (`.src.rock`).
3. Creates the GitHub release with `*.tar.gz`, `*.src.rock`, and `*.rockspec` attached.
4. Publishes to LuaRocks via `luarocks upload`.
```

Replace it with:

```markdown
Pushing the tag triggers `release.yml`:

1. Reuses `ci.yml` as the test gate across the full matrix.
2. On a clean pass, runs `make dist` (source tarball) and `make pack` (`.src.rock`).
3. Generates SLSA build provenance for the `*.tar.gz` and `*.src.rock`, then verifies it with `gh attestation verify`. A verification failure fails the job before any artifact is uploaded.
4. Creates the GitHub release with `*.tar.gz`, `*.src.rock`, and `*.rockspec` attached.
5. Publishes to LuaRocks via `luarocks upload`.
```

- [ ] **Step 2: Add a post-release checklist item**

Find the "## Post-release verification" checklist:

```markdown
## Post-release verification

- [ ] `release.yml` finished green on the tag.
- [ ] The release appears at `https://github.com/peczenyj/lua-gdpr-iab-tcfv2/releases/tag/vX.Y.Z` with all three asset types attached.
- [ ] The version is listed on `https://luarocks.org/modules/peczenyj/lua-gdpr-iab-tcfv2`.
- [ ] `git log main --oneline` shows the merge commit followed by the tag.
```

Replace it with:

```markdown
## Post-release verification

- [ ] `release.yml` finished green on the tag.
- [ ] The release appears at `https://github.com/peczenyj/lua-gdpr-iab-tcfv2/releases/tag/vX.Y.Z` with all three asset types attached.
- [ ] The build provenance is listed at `https://github.com/peczenyj/lua-gdpr-iab-tcfv2/attestations`, and `gh attestation verify <downloaded-asset> --repo peczenyj/lua-gdpr-iab-tcfv2` succeeds.
- [ ] The version is listed on `https://luarocks.org/modules/peczenyj/lua-gdpr-iab-tcfv2`.
- [ ] `git log main --oneline` shows the merge commit followed by the tag.
```

- [ ] **Step 3: Verify the edits**

Run: `git diff RELEASING.md`
Expected: only the step list (now 5 items) and the checklist (now 5 items)
changed; no other lines touched.

- [ ] **Step 4: Commit**

```bash
git add RELEASING.md
git commit -m "docs(release): document SLSA provenance in the release procedure

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Final review and push

**Files:** none modified.

- [ ] **Step 1: Confirm the branch contents**

Run: `git log --oneline main..HEAD`
Expected: four commits — the design spec, the `release.yml` change, the
`SECURITY.md` change, and the `RELEASING.md` change.

- [ ] **Step 2: Run the local CI gate**

Run: `make ci`
Expected: `CI check passed successfully.` (This change touches no Lua source,
so `make ci` should pass exactly as it did before — confirm it still does.)

- [ ] **Step 3: Push the branch**

```bash
git push -u origin feat/slsa-l1-provenance
```

- [ ] **Step 4: Open the pull request**

Open a PR from `feat/slsa-l1-provenance` into `devel`, assigned to
`@peczenyj`, per the project's Gitflow rules.

Run:
```bash
gh pr create --base devel --head feat/slsa-l1-provenance \
  --assignee peczenyj \
  --title "ci(slsa): SLSA Build L1 provenance for releases" \
  --body "Implements SLSA Build Level 1: generates and verifies signed SLSA provenance for release artifacts, and documents verification for consumers. See docs/superpowers/specs/2026-05-18-slsa-l1-provenance-design.md."
```
Expected: the PR URL is printed.

---

## Self-review notes

- **Spec coverage:** provenance generation (Task 1, Step 2), least-privilege permissions move (Task 1, Step 1), gating verification before upload (Task 1, Step 2), `SECURITY.md` consumer docs incl. the documented luarocks.org limitation (Task 2), `RELEASING.md` updates (Task 3). All design sections map to a task.
- **Placeholder scan:** no TBD/TODO; every edit shows full before/after content.
- **Consistency:** artifact globs (`lua-gdpr-iab-tcfv2-*.tar.gz`, `lua-gdpr-iab-tcfv2-*.src.rock`), the action `actions/attest-build-provenance@v2`, and the `gh attestation verify ... --repo peczenyj/lua-gdpr-iab-tcfv2` command are identical across the workflow and both docs.
