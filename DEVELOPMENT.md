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

## Environment Variables

The test suite behavior can be customized using the following environment variables:

| Variable | Description | Default |
| :--- | :--- | :--- |
| `TCF_QUICK` | Set to `1` to run only a subset of the Golden Corpus (128 entries). | `0` |
| `TCF_VERBOSE` | Set to `1` to enable verbose output (`-o gtest`) and show real-time Golden Corpus progress. | `0` |
| `TCF_FULL_CORPUS` | Controls whether the entire Golden Corpus is scanned. Set to `0` to disable. | `1` |
| `TCF_FUZZ` | Set to `1` to enable randomized vendor sampling during the Golden Corpus scan. | `0` |
| `TCF_CONTINUE_ON_FAILURE` | Set to `1` to collect all corpus mismatches and report them at the end. | `0` |
| `TCF_DEEP_LIMIT` | Number of entries at the start of the file to deep-compare. | `16` |
| `TCF_SCAN_LIMIT` | Total number of lines to read in quick mode. | `128` |
| `LUA_VERSION` | Manually specify the Lua version (e.g., `5.1`, `5.4`). | *Auto-detected* |
| `LUA_BIN` | Path to the Lua executable. | `lua` |

### Examples

**Run standard deterministic tests (Full Corpus):**
```bash
make test
```

**Run quick deterministic tests (128 entries):**
```bash
make test-quick
```

**Run randomized probabilistic tests (Fuzzing):**
```bash
make fuzz
```

**Perform an exhaustive deep scan of the entire corpus, reporting all errors:**
```bash
TCF_CONTINUE_ON_FAILURE=1 make test
```

## Makefile Targets

- `make setup`: Initialize local LuaRocks dependencies.
- `make task`: Development loop (Format + Lint + Test-Quick).
- `make ci`: CI verification (Verify Format + Lint + Test).
- `make test`: Run the full test suite (Deterministic Full Golden Corpus scan).
- `make test-quick`: Run a fast subset of tests (128 entries).
- `make fuzz`: Run full test suite with randomized vendor sampling enabled.
- `make lint`: Run the linter (Luacheck).
- `make format`: Apply code formatting (StyLua).
- `make check-format`: Verify formatting without changing files.
- `make coverage`: Generate a coverage report (Luacov).
