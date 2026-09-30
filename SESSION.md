# SESSION.md

Current session state. Update at the end of every turn (see `MEMORY.md`
standing rules). When a session ends, fold the in-flight items into
`HANDOVER.md`.

## Current session

- Date: 2026-08-20
- Mode: build
- Agent: opencode (glm-5.2:cloud)
- Branch: `feat/phase-7-13-comprehensive` (off main, post PR #8 merge)

## Just-completed turn

Phase 9 — core runtime closures:

- **9.1 `DefaultQueryExecutor` orchestrator** in `themql-query`:
  `DefaultQueryExecutor<C: QueryCache>` wraps `Arc<dyn Resolver>`,
  checks `Context.cancellation.is_cancelled()`, checks
  `Context.deadline.is_expired(now)`, optional cache read via
  `QueryCache` trait (new, minimal — `get`/`put`), optional cache
  write-through on miss. `QueryCache` is a new trait that avoids a
  circular dep on `themql-cache`. `DefaultCacheKeyer` used for key
  derivation. +5 tests (invoke on miss, timeout on cancelled,
  write-through, bypass skips read, disabled skips read+write).
- **9.2 Real `EmbassyRuntime::sleep`** in `themql-runtime`:
  replaced `std::future::pending()` with
  `embassy_time::Timer::after(embassy_time::Duration::from_micros(...))`.
  Added `embassy-time` to the `embedded` feature in Cargo.toml.
- **9.3 `StubThedafAdapter`** in `themql-analysis`: concrete impl of
  `ThedafAdapter` returning `AnalysisError::ThedafError("thedaf
  adapter not configured")` for both `fetch_legacy` and
  `list_legacy_datasets`. Gives consumers a type to compose against.
- **9.4 MQTT retained messages** in `themql-mqtt`: added
  `publish_retained` method to `MqttPublisher` trait. The
  `RumqttcTransport` impl passes `retain=true` to the rumqttc
  `publish()` call. Per `specs/mqtt.toml [topics] retained`.
- **9.5 Apalis queue stub** in `themql-desktop`: added `apalis` dep,
  `JobQueue` trait (`enqueue`/`pending_count`), `InMemoryJobQueue`
  stub impl (`Mutex<Vec>`). Real apalis integration (persistent
  storage, workers, retries) is future work.
- 402 tests pass workspace-wide (was 397; +5 from QueryExecutor
  tests). Full validation green.

## State of the repository

- Phase 1 complete (spec + 20 crates implemented).
- Phase 2 Stages 1-12 complete.
- Phase 3 Stages 1-11 complete.
- Phase 3 followups complete (PR #5 merged).
- Phase 4 complete (PR #6 merged): MQTT-to-SSE bridge, better-auth,
  embassy embedded main.
- Phase 5 complete: no_std gnc/estimation, real EKF+controller in
  embedded binary, GraphQL authz guards + MQTT topic ACLs.
- Phase 6 complete: per-request authz + dep audit + real sensors +
  embedded MQTT (PR #8 merged).
- Phase 7 complete: doc + spec-deviation cleanup.
- 365 tests pass workspace-wide (default features). 20 crates, 21 specs.
- Full validation green.
- `tch-backend` feature compiles clean (tests not run: libtorch OOM).
- Embedded binary cross-compiles for thumbv7em-none-eabihf with real
  EKF + HybridController + sensor drivers + minimq MQTT payload
  formatting.
- No open bugs.

## In-flight work

Phase 7 of a 7-phase sweep (Phases 7-13) on
`feat/phase-7-13-comprehensive`. Phases 8-13 pending: testing
infrastructure, core runtime closures, safety-critical mechanisms,
embedded networking, training pipeline completeness, desktop dioxus UI +
pnpm toolchain.

## Next plausible actions (suggestions, not commitments)

1. Phase 8: integration tests in `crates/<crate>/tests/`, property tests
   via `proptest`, benchmarks via `criterion`.
2. Phase 9: `QueryExecutor` orchestrator, real `EmbassyRuntime::sleep`,
   `ThedafAdapter` stub, MQTT retained messages, apalis queue stub.
3. Phase 10: controller/estimator/ML failure detection + ML-degrade-to-
   EKF-only fallback.
4. Phase 11: `embassy-net` TCP transport + embedded MQTT publish +
   command subscribe.
5. Phase 12: TrainerKind dispatch + pruning + sparsification + online
   adaptation trait method (compile-only, tch-backend tests deferred).
6. Phase 13: dioxus 0.7 fullstack UI + pnpm/Tailwind/Playwright
   toolchain + SPEC.toml amendment for pnpm carve-out.

## Open questions / blockers

None.

## 2026-08-20 — themql-sse real implementation (Stage 8)

Rewrote `crates/themql-sse/src/lib.rs` to flow real `SseEvent`s through
the broadcast channel and added an `axum`-backed `serve_sse` HTTP
server with `Last-Event-ID` replay. 17 tests pass; clippy pedantic +
`#![deny(warnings)]` + fmt clean. Added `futures-util` workspace dep.
Workspace `cargo check` green. No issues.

### Open questions / blockers
None.

## Phase 6 (2026-08-20): Per-request authz + dep audit + sensors + MQTT

4 commits on branch `feat/phase-6-authz-sensors-mqtt`, single PR #8.

1. **Per-request GraphQL role extraction**: Custom axum handler in
   `themql-desktop` extracts `better-auth` session → `AuthRole` →
   injects per-request via `BatchRequest::data()`. When auth off,
   guards reject all requests (no global role). `AuthRole: FromStr`.
2. **Dependabot remediation**: All 6 GitHub alerts are non-exploitable
   (rustls-webpki CRL/X.509 paths not activated, jsonwebtoken type
   confusion on JWT path not used, lru IterMut Stacked-Borrows only).
   `lru` 0.12→0.18 dedup. 6 advisories ignored in `deny.toml`.
3. **Real sensor drivers**: BME280 (I2C, full compensation math),
   LSM6DS3 (I2C IMU), NEO-6M (UART NMEA parser). Generic over
   `embedded-hal` 1.0. `SensorDriver` trait now `async fn read`.
4. **Embedded MQTT**: `minimq 0.13` added. Spec amended. Telemetry
   task formats JSON payloads via hand-formatted `write_f64`/`write_u32`.

365 tests pass. Full validation green: fmt, check, test, clippy, deny,
TOML sanity, metadata, cross-compile (thumbv7em-none-eabihf).

---

## Current session

- Date: 2026-09-30
- Mode: maintain
- Agent: opencode (space-bunny-free)
- Branch: `fix/advisories-webpki-jwt` (off main)
- Toolchain: Rust 1.98.1

## Just-completed turn

Advisory remediation across the workspace.

- **Fixed** `RUSTSEC-2026-0285`: `rustls 0.23.43` -> `0.23.45` (TLS 1.3
  encryption-level boundary confusion). This was a hard `cargo deny check`
  failure; it is now cleared. Also `chacha20 0.10.1` -> `0.10.2` (yanked).
- **Investigated, not waived vaguely**, the 4 `rustls-webpki` advisories.
  Root cause is an upstream pin, not our config: every `rumqttc` release
  through 0.25.1 requires `rustls-webpki "^0.102"`, and the 0.102 line has no
  patched release (0.102.8 is the last), so `cargo update` cannot converge and
  `[patch.crates-io]` is semver-rejected.
- **Investigated** the `jsonwebtoken` authorization-bypass advisory.
  `better-auth 0.10.0` requires `jsonwebtoken "^9"`, so the patched 10.3.0 is
  unreachable without a semver-major bump. Confirmed the code path is not
  reachable (email/password plugin only, opaque session tokens, auth opt-in).
- Replaced prose waivers with blocks carrying a proof, a blocker, and a
  machine-checked unblock condition. Removed the stale `lru` waiver
  (`RUSTSEC-2026-0002`; `lru` is 0.18.2, already patched).
- Fixed the `auth_secret` help text, which wrongly called itself a JWT signing
  key and would have led a maintainer to make the ignored advisory reachable.
- Added `scripts/check-advisory-rationales.sh` and checks 5 + 6 in
  `scripts/ci_guard.py`.

## Verification

- `cargo deny check` — 0 errors (was 1 `error[vulnerability]`). Remaining
  output is warnings only: pre-existing duplicate-version and wildcard
  dependency notices.
- `python3 scripts/ci_guard.py` — 5/5 OK, including the 2 new checks.
- **Negative-tested both new guards** by injection: registering a JWT plugin,
  bumping `jsonwebtoken` to major 10, and removing `rustls-webpki 0.102.x` from
  the lock each make `ci_guard.py` exit non-zero with a specific message. Tree
  restored green afterwards. A guard never observed failing is decoration.

## Environment note

A concurrent `cargo check -p degoyle` from `/tmp/opencode/wt-readiness`
exhausted this 6 GB box and OOM-killed a `themql-desktop` test link even at
`-j 2`; the peak is one link process, not the job count. The desktop static
assertions were moved out of a Rust test and into the Python guard, which
needs no linking at all. Recorded as a standing rule in `MEMORY.md`.

- Branch: `chore/pin-toolchain-1.98.1-edition-2024` (off main)
- Toolchain: Rust 1.98.1 (pinned by this branch, previously floating `stable`)

## Just-completed turn

Pin the toolchain, migrate to edition 2024, and fix the embedded target.

- `rust-toolchain.toml`: `stable` -> `1.98.1`. All seven CI jobs pinned to the
  same version, keeping their original components/targets. Fixed three duplicate
  `with:` YAML keys introduced while doing it (caught by a strict duplicate-key
  parse, not by eye).
- Edition 2021 -> 2024 across all 19 crates. 22 `collapsible_if` sites became
  let-chains via `clippy --fix` scoped to that lint; 28 sites reformatted by
  rustfmt's new style edition.
- New `ci_guard.py` check 4: the pin and every CI job must agree, and a
  floating channel in either is rejected.
- **Found and fixed a pre-existing red CI job**: `embedded-check` did not
  compile on `main`. `no_std` production code in `themql-estimation` and
  `themql-gnc` used `format!` and `f64::sqrt` without the `alloc` imports they
  need, and `themql-gnc` lacked the `num-traits` dependency entirely.
  Reproduced on stashed `main` first, so the attribution is proven rather than
  assumed.

## Verification

- `cargo check --workspace` — clean on edition 2024, first attempt
- `cargo clippy --workspace --all-targets -- -D warnings` — 0 warnings
- `cargo fmt --all -- --check` — clean
- `cargo check -p themql-embedded --target thumbv7em-none-eabihf` — **green**
  (was red on `main`)
- `python3 scripts/ci_guard.py` — 4/4 OK
- Tests on the crates with semantic changes: themql-storage 36,
  themql-query 21, themql-cache 36, themql-mqtt 39 — all pass
- `check_toolchain_pin` negative-tested x5, including a drift in the *last*
  CI job, which the first (regex-based) implementation missed entirely

## Caveats

- **Full workspace test suite not run locally.** `themql-desktop` pulls polars
  and tch; linking its test binary OOM-killed this 6 GB box at `-j 2`, and a
  concurrent build was competing for the same memory. CI runs it.
- `cargo deny check` still fails on this branch for `RUSTSEC-2026-0285`. That is
  pre-existing on `main` and is fixed by PR #12; this branch does not include
  that lock bump.
- `cargo machete`/`deny` duplicate-version and wildcard warnings are untouched
  pre-existing debt.
