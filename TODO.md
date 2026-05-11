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

### Phase 0: Setup & Social [DONE]
- [x] Create `LICENSE` (MIT), `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`.
- [x] Create `Makefile` with targets: `test`, `lint`, `format`, `coverage`, `changelog`, `dist`.
- [x] Create `cliff.toml` (adapted from Perl).
- [x] Create `.luacheckrc` and `.stylua.toml`.
- [x] Finalize GitHub Actions (Linux matrix: 5.1, 5.2, 5.3, 5.4).
- [x] Add `.rockspec` template for Luarocks.

### Phase 1: Foundation (Plumbing) [DONE]
- [x] Implement `src/gdpr/iab/tcfv2/base64.lua` (zero-dependency).
- [x] Implement `src/gdpr/iab/tcfv2/bit.lua` (version-agnostic bridge).
- [x] Implement `src/gdpr/iab/tcfv2/bitstream.lua` (high-performance reader).
- [x] **Golden Harness**: Setup `test/corpus/` with Perl's `golden.jsonl` (uncompressed) and a minimal JSON reader for verification.

### Phase 2: Core Segment & Lazy Infrastructure [DONE]
- [x] Implement `src/gdpr/iab/tcfv2/core.lua` with metatable-based lazy decoding.
- [x] Implement BitField and RangeSection decoders with internal caching.
- [x] Implement `src/gdpr/iab/tcfv2/constants/` (Purpose, SpecialFeature, RestrictionType) as bi-directional tables.
- [x] Implement `strict` vs `lenient` mode and `targetVendors` optimization.
- [x] Map all fields to **CamelCase** (matching GVL/JSON).

### Phase 3: Multi-Segment Router [DONE]
- [x] Implement `src/gdpr/iab/tcfv2/router.lua` to handle `.` splitting.
- [x] Route Type 1 (Disclosed), Type 2 (Allowed), Type 3 (Pub TC).


### Phase 4: Validator & Documentation [DONE]
- [x] Implement `src/gdpr/iab/tcfv2/validator.lua` as a separate policy engine.
- [x] Finalize `src/gdpr/iab/tcfv2/init.lua` public API.
- [x] Complete LDoc annotations for all public tables and methods.
- [x] Create `README.md` with Middleware Recipes (OpenResty/HAProxy).


### Phase 5: Exhaustive Verification [DONE]
- [x] Run full Golden Corpus suite (Verify MD5 consistency).
- [x] Implement `TCF_CONTINUE_ON_FAILURE` for bulk error reporting.
- [x] Configure CI for Full Scan on stable/high-performance versions (5.5, LuaJIT).


### Phase 6: Performance & Platform [DONE]
- [x] Implement `bench/` suite (Throughput, Latency, Memory churn).
- [x] JIT profiling in LuaJIT and optimization hot-fixes.
- [x] **Cross-platform verification**: Add macOS to CI matrix.
- [ ] **Fuzz Data Optimization**: Support keeping only a logical subset of `to_json` data (e.g., under a `tests.fuzz` key).


### Phase 7: Advanced Optimizations
- [ ] **Strict Linkage**: Ensure `strict_legal_basis` in Validator triggers `strict` mode in Parser.
- [ ] **Vendor Prefetch**: Use `targetVendors` optimization automatically in Validator to pre-fetch the required `vendor_id`.

## 4. Open Questions / Technical Decisions
1. **JSON for Tests**: I will use a minimal, single-file JSON library in `test/vendor/` strictly for reading the Golden File. Production code remains zero-dependency.
2. **Bitwise Fallback**: For Lua 5.1 (non-JIT), we will use a pure-Lua math-based fallback. It's slower but ensures the library works everywhere.
3. **Vendor IDs**: Lua tables are 1-indexed. We will store vendor permissions in a table where `vendorConsents[284] = true` for direct O(1) lookups.
4. **Dates**: We will return integers (Deciseconds since epoch) to match the spec and the Perl Golden File exactly.
5. **Corpus Size**: Use partially optimized `golden.jsonl` (keeping `to_json` only for first 128 lines) to balance depth and repository weight.
