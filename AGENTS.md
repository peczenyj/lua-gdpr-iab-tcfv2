# AGENTS.md

This file provides guidance to coding agents working on `lua-gdpr-iab-tcfv2`.

## Project Goals
Implement a complete, version-agnostic Lua parser for IAB TCF v2.x consent strings.
Optimized for high-performance middleware environments like **OpenResty** and **HAProxy**.

## Operational Boundaries (Gitflow)
1. **Branching Strategy**:
   - `main`: **OFF LIMITS**. No direct commits or pushes. Only includes tagged releases via `gitflow release`.
   - `devel`: Main development branch. **NEVER** commit directly without explicit permission for very specific tasks. All feature branches (`feat/*`) must merge here.
   - **Feature Workflow**: Always create a branch, work, commit, push, create a Pull Request, and assign it to the project owner (@peczenyj).
2. **Release Process**: Releases are made from `devel` to `main` via a `release/X.Y.Z` branch. Tags (`v*`) trigger automated release artifacts (.tar.gz, .src.rock) and LuaRocks upload. See [RELEASING.md](RELEASING.md) for the full procedure.
3. **Commit Messages**: Follow Conventional Commits: `type(scope): short description`.
   - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.
4. **CI/CD**: GitHub Actions on Linux (Matrix: 5.1, 5.2, 5.3, 5.4, 5.5, LuaJIT, OpenResty) and macOS (5.4, LuaJIT) must pass.

## Technical Rules & Conventions
1. **Lua Compatibility**: Compatible with Lua 5.1, 5.2, 5.3, 5.4, 5.5, and LuaJIT.
   - **Package Structure**: Source files are in `src/gdpr/iab/tcfv2/` mapping to the `gdpr.iab.tcfv2` module.
   - **Zero-dependency**: No external libraries allowed in `src/`. Use internal bridges for bitwise and Base64.
2. **Architecture**: **Lazy/On-demand decoding** with caching via metatables.
3. **Error Handling**: 
   - Return `nil, err` for parsing failures.
   - **Lenient Mode**: (Default) Collect non-fatal structural issues in a `parser.warnings` table and continue.
   - **Strict Mode**: Fail-fast; return `nil, err` on the first spec or structural violation.
4. **Optimization**: Support `targetVendors` in the constructor for $O(1)$ single-pass decoding of specific IDs in RangeSections.
5. **Data Representation**: 
   - Use **CamelCase** for all TCF fields (matching GVL/JSON).
   - Prefer raw tables and primitives for JIT-friendliness.
   - Dates as integers (Deciseconds since epoch).
6. **Separation of Concerns**: Keep the `Parser` (data extraction) separate from the `Validator` (policy enforcement).

## Build & Test
- Use `Makefile` for all common tasks (`make test`, `make lint`, `make format`, `make dist`).
- **Mandatory CI Check**: Agents **MUST** run `make ci` and ensure it passes locally before making any commit or push. This ensures that formatting, linting, and tests are verified as they will be in GitHub Actions.
- Tests MUST verify against the Perl Golden File corpus for logical parity.
- The Golden Corpus is stored uncompressed in `test/corpus/golden.jsonl` to avoid C-binding dependencies (gzip) during testing.

## Interaction Rules
1. **Hard Stop Mandate**: If a user message contains a question mark (`?`), it **MUST** be treated as a circuit-breaker. The agent is **STRICTLY FORBIDDEN** from using any modification tools (`replace`, `write_file`, etc.) in the same turn. The agent must provide a comprehensive text-based answer and wait for a separate directive before initiating any implementation.
2. **Clarification First**: When presented with architectural choices or ambiguous requirements, explain the options and wait for a decision.
