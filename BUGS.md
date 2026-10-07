# BUGS.md

Known bugs and unresolved issues. Empty when all known issues are resolved.
Update after every turn (see `MEMORY.md` standing rules).

## Format

One entry per bug. Use the template below. Close an entry with a `RESOLVED`
line + date + commit/PR reference when fixed.

```
### BUG-NNNN: <short title>

- Discovered: YYYY-MM-DD
- Severity: blocker | major | minor | cosmetic
- Subsystem: themql-<crate> | specs | prompts | docs | ci
- Status: open | in-progress | resolved
- Symptom: what is observed
- Expected: what the spec or correct behaviour requires
- Reproduction: minimal steps / command
- Root cause: (filled when known)
- Fix: (filled when known; include commit hash)
- Follow-up: regression test, spec clarification, etc.
```

## Open bugs

### BUG-0009: rust-toolchain.toml `miri` component breaks rustup proxy on tracking stable

- Discovered: 2026-09-14 (during crates.io publish preparation)
- Severity: minor (workaround exists)
- Subsystem: ci / toolchain
- Status: open
- Symptom: any plain `cargo`/`rustc` invocation in the repo goes
  through the rustup proxy, which reads `rust-toolchain.toml`
  (`channel = "stable"`, `components = [..., "miri"]`) and tries to
  sync stable; sync fails with "component 'miri' ... is unavailable
  for download". `cargo publish --verify` fails at `rustc -vV`
  for the same reason.
- Expected: stock `cargo` commands work in a fresh checkout.
- Reproduction: `cargo --version` (or any cargo command) in
  `/home/leo/theMQL` without a pinned toolchain on PATH.
- Root cause: `miri` is nightly-only and no longer shipped for
  stable; pinning it as a stable component plus an unpinned
  tracking `stable` channel forces a failing sync. (TETANUS still
  wants miri via `cargo +nightly miri test`, which does not need
  the stable component.)
- Fix: undecided — either drop `miri` from stable components or pin
  `channel` to a dated stable (e.g. `1.98.0`). Do not break the
  `cargo +nightly miri test` safety gate when fixing.
- Workaround: prefix PATH with the pinned toolchain —
  `PATH="$HOME/.rustup/toolchains/1.98.0-x86_64-unknown-linux-gnu/bin:$PATH"`
  (also baked into `scripts/publish_crates.sh`). Follow-up: none yet.

## Resolved bugs

### BUG-0008: flaky `themql-storage::helix_alias_works` test

- Discovered: 2026-08-20 (during Phase 3 Stages 6/7 workspace test run;
  pre-existing in the uncommitted working tree from prior Phase 2/3
  stages)
- Severity: minor
- Subsystem: themql-storage
- Status: resolved
- Symptom: `tests::helix_alias_works` panics with
  `sled temp open: ConnectionFailed` at
  `crates/themql-storage/src/lib.rs:436`.
- Expected: the test should open a temp sled database and pass.
- Reproduction: `cargo test --workspace` (intermittent; was in the
  uncommitted working tree only).
- Root cause: the `HelixStorage` alias was originally an in-memory
  `HashMap` fallback. When Phase 3 Stage 2 replaced it with a real
  sled-backed `SledStorage`, the test became stable — sled temp open
  succeeds reliably once the crate is fully wired.
- Fix: resolved 2026-08-20 (Phase 3 Stage 2 — `HelixStorage` is now
  `pub type HelixStorage = SledStorage`, backed by real sled disk
  storage). `cargo test -p themql-storage --lib` passes 31/31
  consistently, including `helix_alias_works`.
- Follow-up: none.

### BUG-0007: themql-cache / themql-storage workspace compile breakage (pre-existing)

- Discovered: 2026-08-20 (during Phase 2 Stages 6-8 turn; pre-existing
  in the working tree before the turn began, confirmed via `git stash`)
- Severity: blocker (for `cargo check --workspace` only)
- Subsystem: themql-cache, themql-storage
- Status: resolved
- Symptom: `cargo check --workspace` fails with 3 errors in
  `themql-cache/src/lib.rs` around `.await` on a non-future
  (`self.promote(key, &entry_for_promote, CacheTier::L4).await`).
- Expected: `cargo check --workspace` passes for all 20 crates.
- Reproduction: `cargo check --workspace`.
- Root cause: uncommitted changes in `themql-cache/Cargo.toml`,
  `themql-cache/src/lib.rs`, `themql-storage/Cargo.toml`,
  `themql-storage/src/lib.rs` (1939 lines added across 5 files) that were
  in the working tree before the Phase 2 Stages 6-8 turn. NOT introduced
  by Stages 6-8 (which only touch themql-runtime, themql-desktop,
  themql-embedded).
- Fix: resolved 2026-08-20 (Phase 2 Stages 2-9 turn). The cache/storage
  changes were completed and integrated; `cargo check --workspace`,
  `cargo clippy --workspace --all-targets -- -D warnings`, and
  `cargo test --workspace` all pass clean (240 tests).
- Follow-up: none.

## Known limitations (not bugs, but tracked alongside)

These are spec-acknowledged gaps / v0.1 placeholders, not bugs. As of
Phase 7 (2026-08-20), all 20 crates have real `src/` content,
cache/storage/transport backends (L1 lru, L2 moka, L3 redis, L4 sled),
runtime impls + desktop/embedded binary wiring, analysis/training/
inference heavy-dep wiring, cross-crate type reconciliation, real
sensor drivers (BME280/LSM6DS3/NEO-6M), embedded MQTT payload
formatting (minimq 0.13), per-request GraphQL authz + MQTT ACLs, and
safety-critical tooling installed. 365 tests pass workspace-wide
(default features). Full validation green.

### Safety-critical placeholders (MUST address before deployment)

- (none remaining — the EKF now uses real Jacobian-based Kalman gain
  with Joseph-form covariance update; the HashValidator now uses real
  BLAKE3; the TchInferenceEngine now runs real model load + forward
  pass + rollback behind `tch-backend`. All four safety-critical
  crates are TETANUS-compliant. Spec deviations in `RollbackHandle`,
  `InferenceError`, and `TrainingError` were fixed in Phase 7 to match
  `specs/inference.toml` and `specs/training.toml` exactly.)

### Environment constraints (not bugs)

- **`tch-backend` feature tests not run** — `themql-training` and
  `themql-inference` define `tch-backend` features wiring `tch` with
  `download-libtorch`. The feature compiles clean, but tests
  (`TchTrainer`, `TchInferenceEngine`) are not run in this environment
  due to libtorch download size + RAM constraints (7.8GB RAM, no swap;
  polars-core alone OOM-kills rustc without `CARGO_PROFILE_DEV_DEBUG=0`).
  The default-feature tests pass. Tracked as a limitation.

### Cross-cutting follow-ups (not bugs)

- **CacheKey duplication — RESOLVED** — `CacheKey` is now re-exported
  from `themql-query` in `themql-cache` per `specs/cache.toml`. The
  `themql-query` version was enriched with `Serialize`/`Deserialize`
  derives + `hash_of()` method.
- **Local type stubs — RESOLVED** — `themql-training` and
  `themql-artifact` now re-export shared schema types from
  `themql-schema` (20th crate). No more local duplicate definitions of
  `FeatureSchema`/`ModelFormat`/`ValidationMetrics`/`TrainedModel`.
- **`serde-big-array` dependency** — added to workspace.dependencies for
  serializing the 21x21 covariance `[f64; 441]` in themql-telemetry.
  Reassess if a more idiomatic serde path emerges.

### Remaining spec-implementation gaps (Phase 8-13 scope)

These are spec-required features not yet implemented, grouped by the
phase that will address them:

- **Testing infrastructure (Phase 8)** — no integration tests (all 365
  are in-crate unit tests; `SPEC.toml [quality] integration_tests_required
  = true`); no property tests (`property_tests_required = true`; no
  proptest/quickcheck dep); no benchmarks (`benchmark_hot_paths = true`;
  no `benches/` dirs, no criterion dep).
- **Core runtime closures (Phase 9)** — `QueryExecutor` orchestrator
  not implemented (`specs/query.toml:50`, trait exists at
  `themql-core/src/lib.rs:1449`, no impl); `EmbassyRuntime::sleep` is a
  stub (`themql-runtime/src/lib.rs:404`, returns `std::future::pending`);
  `ThedafAdapter` trait declared but no impl (`themql-analysis/src/lib.rs:178`);
  MQTT retained messages not supported (`specs/mqtt.toml:34`, no
  `retain: bool` in publish path); apalis queue not wired
  (`specs/runtime.toml:111-119`, `apalis = "0.6"` in workspace deps
  but no crate uses it).
- **Safety-critical mechanisms (Phase 10)** — controller failure not
  detectable (`SPEC.toml:244`, `specs/gnc.toml:227`); estimator failure
  not detectable (`SPEC.toml:243`); ML failure graceful degradation to
  EKF-only not implemented (`SPEC.toml:242`, `specs/inference.toml:144`);
  sensor failure partially detectable (`SensorError` variants exist but
  estimator doesn't consume them for degraded-mode flagging).
- **Embedded networking (Phase 11)** — embedded MQTT does not publish
  over the network (`themql-embedded/src/main.rs:558`, `embassy-net` TCP
  transport not wired; telemetry task formats payloads but
  `publish_count += 1` is a placeholder); command task does not subscribe
  to MQTT (`themql-embedded/src/main.rs:594`, "waits indefinitely").
- **Training pipeline completeness (Phase 12)** — `TrainerKind` variants
  Pinn/GradientBoosting/FineTuning declared but `train_dense` ignores
  `kind` and always runs MLP+Adam+MSE; `PruningConfig`/`SparsificationConfig`
  types exist but `train_dense` never reads `config.pruning`/`config.
  sparsification`; online adaptation method missing from
  `InferenceEngine` trait (`specs/inference.toml:42-44`). All behind
  `tch-backend` feature; compile-only verification (tests can't run
  here).
- **Desktop dioxus UI (Phase 13)** — `specs/desktop.toml [ui]
  framework = "dioxus"` and `[api.DesktopRoot]` not implemented
  (only ratatui TUI exists). `dioxus = "0.5"` in workspace deps but no
  crate uses it. Spec amendment + pnpm toolchain carve-out required
  (`SPEC.toml [architecture.forbidden] typescript_runtime = true`
  vs. pnpm/Playwright dev tooling).
- **Other spec-implementation gaps** — `mqtt_graphql_bridge` not
  implemented (`SPEC.toml:162`, only `mqtt_sse_bridge` exists);
  `HelixStorage` is `pub type HelixStorage = SledStorage` (sled-backed,
  not real helix-db; `SPEC.toml:61 l4_cache = "helixdb"`); no `ImuModel`
  in estimation (IMU is consumed directly in `predict`, which is
  architecturally correct for an EKF, but no `SensorModel` impl exists
  for IMU measurement updates).

### Infrastructure-dependent backends (not bugs)

- L3 (redis) requires a running `redis-server` for live operation;
  degrades gracefully to `TierUnavailable` when absent (unit tests
  handle this).
- L4 (sled) is disk-backed and works without external infrastructure.
- MQTT integration tests need a running broker (unit tests use
  config-only tests).
- `tch-backend` feature tests need libtorch + more RAM than this
  environment provides (feature compiles clean, tests not run).

### Tooling / CI (not bugs)

- `cargo-deny`, `cargo-machete`, `cargo-bloat` installed and passing.
  `cargo deny check` passes (BSL-1.0 + CDLA-Permissive-2.0 added to
  allowed licenses, 6 RUSTSEC advisory ignores for non-exploitable
  transitive deps). `cargo machete --with-metadata` clean. `cargo bloat`
  passes on desktop binary.
- `opencode.json` written with `$schema`, `instructions: ["AGENTS.md"]`,
  permission rules, and `validate` + `safety-gate` custom commands.
- `scripts/ci_guard.py` checks TOML parse + crate-name-vs-workspace
  invariant. All checks pass.
- CI: 9 jobs (fmt, check, clippy, test, toml-sanity, ci-guard, deny,
  machete, embedded-check). Missing: `cargo bloat` job, `cargo miri`
  job (no unsafe exists, so miri is dormant), clippy/deny/machete on
  the embedded no_std cross-build.
- `mold`, `sccache` not installed. Config files (`.cargo/config.toml`)
  are ready for when they are. Install: `apt install mold`,
  `cargo install sccache`. Then uncomment the relevant lines.
- No fuzzing harness, no dependency-audit pipeline, no secret-management
  policy. Tracked in `SECURITY.md` known limitations.

### Supply chain (not bugs)

- `[workspace.dependencies]` versions are resolved against crates.io
  (2026-08-19), but `valkey` is alpha (`0.0.0-alpha5`) and `cachelito` is a
  proc-macro for function caching — both may need reassessment for the
  L1/L3 use cases. (Phase 3 replaced valkey with `redis` for L3 and
  cachelito with `lru` for L1; `valkey` and `cachelito` are no longer in
  the cache crate's Cargo.toml.)

## Phase 6 known issues (2026-08-20)

- **WS subscription role extraction**: The authed GraphQL WS upgrade
  handler currently defaults to `Observer` role at upgrade time without
  resolving the session from the cookie (the `resolve_role_from_headers`
  call is present but the session may not be available at WS upgrade
  time). Refining to per-connection session resolution is a follow-up.
- **Embedded MQTT transport**: `minimq` is wired and payload formatting
  is live, but the actual TCP transport (`embassy-net`) is not yet
  connected. The telemetry task formats payloads but does not publish
  them over the network. Requires a specific MCU HAL commit.
- **GitHub dependabot alerts**: 6 alerts remain open in the GitHub UI.
  They are ignored in `deny.toml` with non-exploitability rationale
  (see `SECURITY.md`), but dependabot does not read `deny.toml`. Manual
  dismissal in the GitHub Security tab is required.
- **lru duplicate-version warning**: Resolved by bumping themql-cache
  from lru 0.12.5 to 0.18.2 (deduped with ratatui's transitive 0.18.2).

### BUG-0002: 4 rustls-webpki advisories unfixable behind rumqttc

- Severity: High (four advisories, no available fix)
- Status: OPEN — blocked upstream
- Detail: `RUSTSEC-2026-0049` (CRL Distribution Point matching),
  `RUSTSEC-2026-0098` (URI name constraints), `RUSTSEC-2026-0099` (wildcard
  name constraints) and `RUSTSEC-2026-0104` (CRL BIT STRING panic / DoS) all
  affect `rustls-webpki 0.102.8`, which enters the lock through `rumqttc`.
  All four are fixed only in `>= 0.103.10/12/13`, and the 0.102 line received
  no patch at all — 0.102.8 is its final release, so there is nothing to bump
  to within the line.
- Root cause: `rumqttc` pins `rustls-webpki "^0.102"`. Verified against the
  crates.io index: newest is 0.25.1, and every release from 0.19 onward carries
  the same `^0.102` requirement. No rumqttc release requires 0.103, so
  `cargo update` cannot converge, and `[patch.crates-io]` to 0.103.x is
  rejected as semver-incompatible. This is an upstream pin, not a
  misconfiguration on our side.
- Mitigating: the lock carries both lines. `rustls 0.23.45` (better-auth)
  already resolves to the patched `rustls-webpki 0.103.14`; only rumqttc's own
  TLS paths reach the vulnerable copy. rumqttc is used by `themql-mqtt` for
  broker connections.
- Detection: `scripts/check-advisory-rationales.sh` (CI guard check 6) fails
  the build as soon as a rumqttc release moves to `rustls-webpki >= 0.103.13`,
  so this cannot quietly outlive its own justification.
- Filed 2026-09-30 while remediating Dependabot alerts.

### BUG-0003: jsonwebtoken authorization-bypass advisory blocked behind better-auth

- Severity: High (authorization bypass) / Low (reachability)
- Status: OPEN — blocked upstream, not reachable in current configuration
- Detail: `GHSA-h395-gr6q-cpjc` — `jsonwebtoken` type confusion in `nbf`/`exp`
  validation that can lead to an authorization bypass. Locked at 9.3.1;
  fixed in 10.3.0.
- Root cause: `better-auth 0.10.0` requires `jsonwebtoken "^9"`, which cannot
  resolve to 10.x. This is a semver-major bump, so no lock update reaches it.
  `better-auth 1.0.0-alpha.3` requires `jsonwebtoken "^11"` (patched) but is a
  pre-release, and taking an alpha dependency on a 0.x crate is a deliberate
  decision rather than a side effect of a security bump.
- Why it is not reachable: the only plugin registered on the `BetterAuth`
  builder is `EmailPasswordPlugin`; no JWT-issuing plugin exists. Sessions are
  opaque `session_` tokens (`SessionManager::extract_session_token` is
  mirrored, not reimplemented as JWT validation). GraphQL session auth is
  opt-in — `enable_auth` defaults to `false`.
- Latent hazard found and fixed: the `auth_secret` CLI help described itself
  as an "Auth secret for JWT session signing", which is inaccurate and would
  have led the next maintainer to register a JWT plugin and make the advisory
  reachable without realizing it. Help text corrected.
- Detection: `scripts/ci_guard.py` check 5 fails if a JWT marker appears in
  the auth builder, if the plugin count is no longer exactly one, if
  `enable_auth` stops defaulting to false, or if the locked `jsonwebtoken`
  reaches major 10 (at which point the ignore is stale and must be dropped).
- Filed 2026-09-30 while remediating Dependabot alerts.

### BUG-0004: `embedded-check` CI job was red — no_std targets did not compile

- Severity: High (the embedded binary did not build; the gate that should have
  caught it was failing and nobody attributed it)
- Status: RESOLVED 2026-09-30 — branch `chore/pin-toolchain-1.98.1-edition-2024`
- Detail: `cargo check -p themql-embedded --target thumbv7em-none-eabihf` failed
  on `main`. Three causes, all in `no_std` **production** code rather than
  tests, so the embedded artifact could not be produced at all:
  1. `themql-estimation` and `themql-gnc` call `format!` while importing only
     `String` / `ToString` / `Vec` from `alloc`. `format!` is not in the
     `no_std` prelude and needs its own `use alloc::format;`.
  2. `themql-gnc::health_check` calls `.sqrt()` on an `f64`, which has no
     inherent `no_std` implementation and needs `num_traits::real::Real` in
     scope.
  3. `themql-gnc` did not depend on `num-traits` at all, so (2) could not be
     fixed by an import. Added with the `libm` feature, mirroring
     `themql-estimation`, which already hit the identical constraint and
     already had the dependency.
- Detection: this was the `embedded-check` CI job, which was **failing and
  unexamined**. The last four consecutive `main` runs were red.
- Resolution: imports added and the dependency declared. `embedded-check` is
  green. Recorded in `MEMORY.md` so the `no_std` import rules are written down
  rather than rediscovered by the next agent.

### BUG-0005: CI was red on main for an unexamined reason

- Severity: Medium (process)
- Status: OPEN
- Detail: the last four consecutive `main` CI runs failed. At least two
  independent causes: this `embedded-check` breakage (BUG-0004, now fixed) and
  `RUSTSEC-2026-0285` in the `deny` job (fixed in PR #12). A red gate that
  nobody attributes accumulates, because each new run looks like the same
  known-red and gets the same non-attention.
- Follow-up: worth deciding whether a red `main` should block merges. Today it
  does not, and both this and BUG-0004 were found by accident rather than by
  process.

### BUG-0001: `ErrorCode` could not express an authorization denial

- Severity: High (fail-closed correctness)
- Status: RESOLVED 2026-09-30 — branch `feat/error-code-authz-notfound-conflict`
- Detail: `ErrorCode` had 6 variants and no `AuthorizationError`, so a policy
  denial could only be reported as `ResolverError` — making a revoked grant
  indistinguishable from a domain failure — or as `CacheMiss`, which invites a
  retry that the authority would then answer on the caller's behalf. Discovered
  downstream while ruling the DeGoyle risk-control calculus boundary: the
  `degoyle_mql_core` reconstruction already carried 9 variants, so upstream was
  behind the consumer it was meant to replace.
- Also fixed in the same change: `NotFound` (a fact about the data) had no code
  distinct from `CacheMiss` (a fact about the lookup path), and `Conflict` (a
  lost CAS race) had none distinct from `ValidationError` (a malformed input).
- Resolution: 3 variants + 3 constructors added, `specs/core.toml` updated in
  the same change with a `[types.ErrorCode.separation_rule]`, and an
  injectivity test over the wire-string map so the collapse cannot reappear at a
  transport projection. Workspace moved to `0.2.0` (breaking for exhaustive
  `match`).
