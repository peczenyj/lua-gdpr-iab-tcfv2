# AGENTS.md

This file provides guidance to coding agents working on `lua-gdpr-iab-tcfv2`.

## Project Goals
Implement a complete, version-agnostic Lua parser for IAB TCF v2.x consent strings.
Optimized for high-performance middleware environments like **OpenResty** and **HAProxy**.

## Operational Boundaries (Gitflow)
1. **Branching Strategy**:
   - `devel`: Main development branch. All feature branches (`feat/*`) must merge here.
   - `main`: Production/Release branch. Only includes tagged releases.
2. **Release Process**: Releases are made from `devel` to `main` via `gitflow release` or equivalent workflow.
3. **Commit Messages**: Follow Conventional Commits: `type(scope): short description`.
   - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.
4. **CI/CD**: GitHub Actions on Linux (and other suggested OS) must pass for all PRs.

## Technical Rules & Conventions
1. **Lua Compatibility**: Compatible with Lua 5.1, 5.2, 5.3, 5.4, and LuaJIT.
   - Zero-dependency: Use internal bridges for bitwise and Base64.
2. **Architecture**: Lazy/On-demand decoding with caching.
3. **Error Handling**: Return `nil, err` for parsing failures.
4. **Data Representation**: Simple tables/numbers (JIT-friendly).

## Build & Test
- Run tests using the local Lua interpreter (if available) or via CI.

