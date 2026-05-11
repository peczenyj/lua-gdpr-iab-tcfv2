# Development Guide

This document covers the technical setup, tooling, and configuration for developing `lua-gdpr-iab-tcfv2`.

## Prerequisites

Ensure you have the following installed on your system:

1.  **Lua (5.1, 5.2, 5.3, 5.4, 5.5, or LuaJIT)**:
    - Ubuntu: `sudo apt install lua5.4`
    - macOS: `brew install lua`
2.  **LuaRocks**:
    - Ubuntu: `sudo apt install luarocks`
    - macOS: `brew install luarocks`
3.  **StyLua** (Code Formatter):
    - **Rust/Cargo**: `cargo install stylua`
    - **macOS**: `brew install stylua`
    - **Linux (Manual)**: Download from [StyLua Releases](https://github.com/JohnnyMorganz/StyLua/releases).

## Local Setup

Initialize the local dependencies folder (`.rocks/`):
```bash
make setup
```
This installs `busted`, `luacheck`, and `luacov` locally. The `Makefile` automatically detects and uses this folder.

## Test Classes

The project uses three distinct classes of tests:

1.  **Unit Tests (`make test`)**: Fast, deterministic tests for individual modules (plumbing, core logic). These are the primary target for code coverage.
2.  **Reference Tests (`make test-reference`)**: Full scan of the 1,024-line Golden Corpus to verify validator-decision parity with the Perl reference implementation across the configured scenarios.
3.  **Fuzz Tests (`make test-fuzz`)**: Randomized sampling of the corpus and robustness testing with random bitstreams to catch crashes.

## Environment Variables

The test suite behavior can be customized using the following environment variables:

| Variable | Description | Default |
| :--- | :--- | :--- |
| `TCF_VERBOSE` | Set to `1` to enable detailed output and real-time Golden Corpus progress. | `0` |
| `TCF_CONTINUE_ON_FAILURE` | Set to `1` to collect all corpus mismatches and report them at the end. | `0` |
| `TCF_QUICK` | Set to `1` to limit the Reference scan to 128 entries. | `0` |
| `LUA_VERSION` | Manually specify the Lua version (e.g., `5.1`, `5.4`). | *Auto-detected* |
| `LUA_BIN` | Path to the Lua executable. | `lua` |

## Makefile Targets

- `make setup`: Initialize local LuaRocks dependencies into `./.rocks/`.
- `make test`: Run the unit-test suite (`test/units/`).
- `make test-reference`: Run the full Golden Corpus reference suite (`test/reference/`).
- `make test-fuzz`: Run the fuzz-test suite (`test/fuzz/`).
- `make lint`: Lint sources and tests with `luacheck`.
- `make format`: Apply `stylua` formatting in place.
- `make check-format`: Verify formatting without modifying files (used by CI).
- `make coverage`: Run unit tests with `luacov` enabled and print a summary.
- `make report-coverage`: Upload coverage data to Coveralls.
- `make bench`: Run the local benchmark suite (`bench/runner.lua`).
- `make changelog`: Regenerate `CHANGELOG.md` from git history via `git-cliff`.
- `make dist`: Package the source tarball for release.
- `make pack`: Package the LuaRocks source rock (`.src.rock`) for offline installs.
- `make install`: Install the library to the system Lua path (consider `luarocks install` instead).
- `make clean`: Remove build artifacts and the local `.rocks/` tree.
- `make ci`: Full CI orchestration (`check-format` → `lint` → `test` → `test-reference` → `test-fuzz`). **Must pass locally before any commit or push.**
- `make task`: Local development loop (`format` → `lint` → `test`).

## Golden Corpus Management

To keep the repository size manageable, the Golden Corpus is partially optimized by stripping large `to_json` data from lines 129 onwards. You can verify the integrity of the file using the provided script:

```bash
./scripts/optimize_golden.sh <original_full_corpus.jsonl> test/corpus/golden.jsonl
```

If the optimization was performed correctly, `git status` should show no changes to the file.
