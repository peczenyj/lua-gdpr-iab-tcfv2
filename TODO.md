# TODO: lua-gdpr-iab-tcfv2 Roadmap

This roadmap outlines the development of the Lua IAB TCF v2.x parser.

## Phase 0: Project Setup
- [x] Initialize Gitflow branches (`main`, `devel`).
- [ ] Set up GitHub Actions CI for Linux.
- [ ] Add basic `README.md`.
- [ ] Define `LICENSE` (likely MIT or Apache).

## Phase 1: Foundation (The "Plumbing")
- [ ] Implement `src/base64.lua`: Zero-dependency Base64url decoder.
- [ ] Implement `src/bit.lua`: Version-agnostic bitwise operator bridge (5.1-5.4).
- [ ] Implement `src/bitstream.lua`: Lazy-capable bit stream reader.
- [ ] Add basic unit tests for plumbing components.

## Phase 2: Core Segment & Lazy Infrastructure
- [ ] Implement `core.lua` with lazy-lookup logic for fixed fields.
- [ ] Implement BitField decoder (caching results).
- [ ] Implement RangeSection decoder (caching results).
- [ ] Implement Publisher Restrictions decoder.

## Phase 3: Multi-Segment Router
- [ ] Implement segment splitter (`.` separator handling).
- [ ] Implement routing for Disclosed Vendors, Allowed Vendors, and Publisher TC.

## Phase 4: Public API & Integration
- [ ] Finalize the `src/init.lua` entry point.
- [ ] Implement validation / compliance predicates (e.g., `is_v22_plus`).

## Phase 5: Verification & Performance
- [ ] Comprehensive test suite using IAB golden test vectors.
- [ ] Performance profiling in OpenResty/LuaJIT environment.
