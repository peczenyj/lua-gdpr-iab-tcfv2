# lua-gdpr-iab-tcfv2 Comprehensive Plan

## 1. Project Vision
A zero-dependency, JIT-optimized Lua parser for IAB TCF v2.x.
- **Goal**: High-throughput middleware (OpenResty/HAProxy).
- **Architecture**: Lazy decoding (only parse what you access).
- **Source of Truth**: Perl project's `golden.jsonl` (identical logical output).

## 2. Operational Foundation
- **Branching**: Gitflow (`devel` / `main`).
- **Commits**: Conventional Commits (`feat:`, `fix:`, etc.).
- **Changelog**: Automated via `git-cliff` (Keep a Changelog style).
- **License**: MIT.
- **Identity**: Tiago Peczenyj <tiago.peczenyj+lua@gmail.com>.

## 3. Development Phases

### Phase 0: Setup & Social
- [ ] Create `LICENSE` (MIT), `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`.
- [ ] Create `Makefile` with targets: `test`, `lint`, `format`, `coverage`, `changelog`, `dist`.
- [ ] Create `cliff.toml` (adapted from Perl).
- [ ] Create `.luacheckrc` and `.stylua.toml`.
- [ ] Finalize GitHub Actions (Linux matrix: 5.1, 5.2, 5.3, 5.4, LuaJIT, OpenResty).
- [ ] Add `.rockspec` template for Luarocks.

### Phase 1: Foundation (Plumbing)
- [x] Implement `src/base64.lua` (zero-dependency).
- [x] Implement `src/bit.lua` (version-agnostic bridge).
- [x] Implement `src/bitstream.lua` (high-performance reader).
- [x] **Golden Harness**: Setup `test/corpus/` with Perl's `golden.jsonl` and a minimal JSON reader for verification.

### Phase 2: Core Segment & Lazy Infrastructure
- [ ] Implement `src/core.lua` with metatable-based lazy decoding.
- [ ] Implement BitField and RangeSection decoders with internal caching.
- [ ] Implement `src/constants/` (Purpose, SpecialFeature, RestrictionType) as bi-directional tables.
- [ ] Implement `strict` vs `lenient` mode and `targetVendors` optimization.
- [ ] Map all fields to **CamelCase** (matching GVL/JSON).

### Phase 3: Multi-Segment Router
- [ ] Implement `src/router.lua` to handle `.` splitting.
- [ ] Route Type 1 (Disclosed), Type 2 (Allowed), Type 3 (Pub TC).

### Phase 4: Validator & Documentation
- [ ] Implement `src/validator.lua` as a separate policy engine.
- [ ] Finalize `src/init.lua` public API.
- [ ] Complete LDoc annotations for all public tables and methods.
- [ ] Create `README.md` with Middleware Recipes (OpenResty/HAProxy).

### Phase 5: Verification & Performance
- [ ] Run full Golden Corpus suite (Verify MD5 consistency).
- [ ] Implement `bench/` suite (Throughput, Latency, Memory churn).
- [ ] JIT profiling in LuaJIT.

## 4. Open Questions / Technical Decisions
1. **JSON for Tests**: I will use a minimal, single-file JSON library in `test/vendor/` strictly for reading the Golden File. Production code remains zero-dependency.
2. **Bitwise Fallback**: For Lua 5.1 (non-JIT), we will use a pure-Lua math-based fallback. It's slower but ensures the library works everywhere.
3. **Vendor IDs**: Lua tables are 1-indexed. We will store vendor permissions in a table where `vendorConsents[284] = true` for direct O(1) lookups.
4. **Dates**: We will return integers (Deciseconds since epoch) to match the spec and the Perl Golden File exactly.
