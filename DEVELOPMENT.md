# Development Guide

This document covers the technical setup, tooling, and configuration for developing `lua-gdpr-iab-tcfv2`.

## Prerequisites

Ensure you have the following installed on your system:

1.  **Lua (5.1, 5.2, 5.3, 5.4, or LuaJIT)**:
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
2.  **Reference Tests (`make test-reference`)**: Full scan of the 1024-line Golden Corpus to ensure 100% logical parity with the Perl reference implementation.
3.  **Fuzz Tests (`make test-fuzz`)**: Randomized sampling of the corpus and robustness testing with random bitstreams to catch crashes.

## Environment Variables

The test suite behavior can be customized using the following environment variables:

| Variable | Description | Default |
| :--- | :--- | :--- |
| `TCF_VERBOSE` | Set to `1` to enable detailed output and real-time Golden Corpus progress. | `0` |
| `TCF_CONTINUE_ON_FAILURE` | Set to `1` to collect all corpus mismatches and report them at the end. | `0` |
| `TCF_QUICK` | Set to `1` to limit the Reference scan to 128 entries. | `0` |
| `TCF_DEEP_LIMIT` | Number of entries to deep-compare in Reference tests. | `16` |
| `LUA_VERSION` | Manually specify the Lua version (e.g., `5.1`, `5.4`). | *Auto-detected* |
| `LUA_BIN` | Path to the Lua executable. | `lua` |

## Makefile Targets

- `make setup`: Initialize local LuaRocks dependencies.
- `make task`: Development loop (Format + Lint + Unit Tests).
- `make ci`: Full verification (Verify Format + Lint + Unit + Reference + Fuzz).
- `make test`: Run **Unit Tests** only.
- `make test-reference`: Run the **Full Golden Corpus scan**.
- `make test-fuzz`: Run **Randomized Fuzz tests**.
- `make coverage`: Run Unit Tests and print coverage summary to stdout.
- `make lint`: Run the linter.
- `make format`: Apply code formatting.
