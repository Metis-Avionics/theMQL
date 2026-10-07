# SECURITY.md

Security policy and threat model for theMQL. Update after every turn (see
`MEMORY.md` standing rules).

## Reporting

Security issues should be reported via the GitHub issue tracker at
https://github.com/Metis-Avionics/theMQL/issues for now. A dedicated
security-contact channel will be added before v0.2.

Do not file public issues for vulnerabilities that are exploitable in
deployed systems; contact the maintainers privately first.

## Scope

theMQL spans two execution domains with very different security profiles:

- **Desktop** (`themql-desktop` binary) — development, analysis, training,
  telemetry, operations. Runs on developer machines and operations
  infrastructure. Networked. Uses tokio, async-graphql, dioxus, polars,
  tch, helix-db, valkey.
- **Embedded** (`themql-embedded` binary) — vehicle-facing. Runs on
  constrained hardware via embassy. Uses MQTT, sensor inputs, GNC, state
  estimation, ML inference.

A vulnerability in the desktop domain is a research/ops problem. A
vulnerability in the embedded domain can be a safety-of-flight problem.
Treat embedded-domain findings as safety issues, not just security issues.

## Threat model

### Safety-critical (embedded)

- **ML control authority bypass** — any code path where ML silently becomes
  the authoritative flight-control path. Spec-forbidden
  (`SPEC.toml: [ml.authority] ml_control_authority = "forbidden"`). The GNC
  authority hierarchy in `prompts/ARCHITECT.md` is the control.
- **Unvalidated model activation** — activating an embedded model without
  version/schema/compatibility/integrity validation. Spec-forbidden
  (`specs/inference.toml`, `specs/model_artifact.toml`).
- **Euler-angle canonical state** — using Euler angles as the internal
  attitude representation. Spec-forbidden (`specs/gnc.toml`,
  `specs/state_estimation.toml`). Gimbal lock is a safety issue, not a
  style issue.
- **tch in control loop** — coupling the deterministic control path to
  the ML runtime. Spec-forbidden (`specs/gnc.toml:
  tch_rs_in_control_loop = false`).
- **Sensor failure undetected** — any estimator/controller that assumes a
  sensor is permanently valid. Spec-forbidden (`SPEC.toml [safety]`).
- **Online adaptation without budget/rollback** — unconstrained online
  learning. Spec-forbidden (`specs/inference.toml`,
  `prompts/ARCHITECT.md`).
- **Deterministic fallback removed** — any change that makes the
  deterministic GNC/EKF path dependent on ML. Spec-forbidden.

### Security (desktop and transport)

- **Transport business logic leakage** — business logic in MQTT/GraphQL/SSE
  adapters. Spec-forbidden (`SPEC.toml [architecture.forbidden]`). Such
  code is also a maintenance security risk because it bypasses review
  boundaries.
- **Transport-specific domain models** — defining Message/Query/Response
  types inside a transport adapter. Spec-forbidden. Also a deserialization
  attack surface.
- **Implicit cache invalidation** — hidden or implicit cache invalidation
  can cause stale data to be served as authoritative. Spec-forbidden
  (`specs/cache.toml`).
- **Collapsed error codes** — reporting an authorization denial as
  `ResolverError` makes a revoked grant indistinguishable from a domain
  failure or an outage; reporting it as `CacheMiss` invites a retry that the
  authoritative store then answers on the caller's behalf. `ErrorCode` carries
  `NotFound`, `AuthorizationError` and `Conflict` as distinct variants
  precisely so these cannot be collapsed, and
  `specs/core.toml [types.ErrorCode.separation_rule]` makes
  `AuthorizationError` the fail-closed match target that MUST NOT fall through
  to the authority. A transport projection that maps two codes onto one wire
  string silently reinstates the collapse at the edge, so
  `crates/themql-core/tests/error_code_wire_contract.rs` asserts the
  variant→wire-string map is injective. Collapsing these is an authorization
  bypass, not a cosmetic change.
- **Unbounded channels / uncontrolled backpressure** — DoS vector.
  Spec-discouraged (`specs/runtime.toml`).
- **Blocking work on async executor** — can stall the runtime. Spec-forbidden
  (`specs/runtime.toml`).
- **Python ABI / runtime dependency** — not a deliberate attack vector but
  a supply-chain and attack-surface expansion. Spec-forbidden
  (`SPEC.toml [architecture.forbidden]`).
- **Unvalidated model artifact import** — a malicious or corrupt artifact
  could execute arbitrary tensor operations. The
  `specs/model_artifact.toml` validation gate is the control. As of
  Phase 3 Stage 7, `themql-inference::TchInferenceEngine::load()`
  (behind `tch-backend`) runs `themql_artifact::HashValidator::new()
  .validate(&artifact)` and rejects on any `report.errors`, rejects
  empty bytes on every load (not just the first), and only then
  deserialises the bytes into a `tch::CModule`. The placeholder
  behaviour that skipped validation after the first load is gone.
- **HelixDB / Valkey access** — L4 (helix-db) is authoritative; L3 (valkey)
  is distributed ephemeral. Treat credential handling and access boundaries
  as security-relevant from Phase 1 onward.

### Supply chain

- `[workspace.dependencies]` versions are resolved against crates.io
  (2026-08-19). `valkey` is alpha (`0.0.0-alpha5`); `cachelito` is a
  proc-macro for function caching — both may need reassessment. Audit
  transitive deps before production use.
- `deny.toml` enforces license allowlist (MIT, Apache-2.0, BSD, ISC,
  Zlib, CC0), bans Python ABI crates (pyo3, cpython, python3-sys) and
  custom database engines (rusqlite), and restricts sources to crates.io.
  Run `cargo deny check` to verify.
- No `unsafe` is permitted without written justification
  (`SPEC.toml [quality] unsafe_requires_justification = true`). `Miri`
  (`cargo +nightly miri test`) is required for any crate containing
  `unsafe` blocks (see `TETANUS.md` Rule 10).

## Security-relevant specs to consult

- `SPEC.toml` — `[architecture.forbidden]`, `[ml.authority]`, `[safety]`,
  `[quality]`.
- `specs/gnc.toml` — control authority, `tch_rs_in_control_loop = false`.
- `specs/state_estimation.toml` — `ml_failure_must_not_disable_ekf = true`,
  `sensor_failure_detection = true`.
- `specs/inference.toml` — `unvalidated_model_activation = false`,
  `validation_bypass = false`, `rollback_without_retained_previous = false`.
- `specs/model_artifact.toml` — `validation_bypass = false`,
  `schema_bypass = false`, `arbitrary_model_activation = false`.
- `specs/cache.toml` — `implicit_invalidation = false`, `hidden_cache =
  false`.
- `specs/runtime.toml` — `blocking_work_on_async_executor = false`,
  `unbounded_channels_by_default = false`.
- `specs/transport.toml` — `business_logic_in_transport = false`,
  `transport_specific_domain_model = false`.
- `specs/storage.toml` — `business_logic_in_storage = false`,
  `storage_specific_domain_model = false`, `implicit_retry = false`.
- `specs/core.toml` — `no_transport_specific_error_type = true`,
  `response_contains_value_or_error_never_both = true`.

## Security review checklist (per change)

Before a change touches anything in `themql-embedded`, `themql-inference`,
`themql-gnc`, `themql-estimation`, or `themql-telemetry`:

- Does it preserve the deterministic fallback path?
- Does it preserve sensor-failure detection?
- Does it preserve quaternion canonical attitude?
- Does it keep `tch` out of the control loop?
- Does it require ML for basic flight stability? (must not)
- Does it activate a model without the full validation gate? (must not)
- Does it introduce `unsafe`? If yes, is it justified in writing?

Before a change touches anything in `themql-transport`, `themql-graphql`,
`themql-mqtt`, `themql-sse`, `themql-cache`, `themql-storage`:

- Does it add business logic to a transport adapter? (must not)
- Does it define transport-specific domain types that escape the adapter?
  (must not)
- Does it introduce implicit cache invalidation? (must not)
- Does it introduce unbounded channels or blocking work on the async
  executor? (must not)

## Known limitations (as of v0.1, 2026-08-20, Phase 7 complete)

**Release note (2026-09-14, crates.io publish in progress):** v0.1.0
is being published to the public crates.io registry (9/20 live at
last update; remainder via detached fixed-interval publisher — see
HANDOVER.md). Publishing makes the crate sources world-readable;
no secrets are in the tree (registry token lives in
`~/.cargo/credentials.toml`, outside the repo — never commit it).
No code changed for the release beyond packaging metadata
(description + version requirements in Cargo.tomls), so the
safety-critical posture below is unaffected.

All 20 crates now have real `src/` content (traits + types + error types +
unit tests). The four safety-critical crates (themql-gnc, themql-estimation,
themql-inference, themql-artifact) comply with TETANUS.md (Power of Ten
rules): `#![forbid(unsafe_code)]`, `#![deny(warnings)]`, `clippy::pedantic`,
no recursion, fixed loop bounds, no heap alloc after init where required,
functions <= 60 lines, >= 2 assertions per public function as
`if !invariant { return Err }`, no unwrap()/expect() in non-test code.

- **BLAKE3 hash in themql-artifact (real, as of Phase 3 Stage 1)** —
  `HashValidator` uses `blake3::hash` for the 32-byte integrity
  digest (the v0.1 placeholder fold hash was replaced). Model artifacts
  are hash-verified before activation. `TchInferenceEngine::load()`
  (Phase 3 Stage 7) runs the full `HashValidator` validation pipeline
  and rejects on any errors.
- **Real EKF in themql-estimation (as of Phase 3 Stage 4)** — the `Ekf`
  uses real Jacobian-based Kalman gain with Joseph-form covariance
  update (`K = PHᵀ(HPHᵀ+R)⁻¹`, `P = (I-KH)P(I-KH)ᵀ + KRKᵀ`),
  `SensorModel<M>` trait, `GpsModel`, `BaroModel`, and
  `BayesianEstimator`. The v0.1 simplified identity-gain placeholder
  is gone. State estimation correctness is now backed by real
  quaternion dynamics + Jacobian linearisation.
- **21-dim EKF state (fixed, no dynamic allocation)** — `EstimatorState`
  is a fixed 21-dimensional nalgebra `SVector<f64, 21>` with a fixed
  `SMatrix<f64, 21, 21>` covariance. No heap allocation after `new()`. This
  is a safety property (predictable memory, no allocator failure in the
  control loop) and a TETANUS compliance point.
- **TETANUS compliance of gnc/estimation/inference/artifact** — all four
  safety-critical crates carry `#![forbid(unsafe_code)]` and pass the Power
  of Ten rules. No `unsafe` exists anywhere in the workspace.
- **Real tch-backed InferenceEngine (as of Phase 3 Stage 7)** —
  themql-inference has a concrete `TchInferenceEngine` behind the
  `tch-backend` feature that loads a `tch::CModule` (after hash +
  schema validation), runs `forward_ts`, checks the
  `inference_deadline_ms` budget, and supports `rollback()`. ML
  remains augmentative only (never the authoritative flight-control
  path).
- **Real tch-backed Trainer (as of Phase 3 Stage 6)** — themql-training
  has a concrete `TchTrainer` behind `tch-backend` that builds an MLP,
  trains with Adam + MSE, and exports to TorchScript bytes via
  `CModule::create_by_tracing`.
- **EmbassyRuntime sleep stub** — themql-runtime's `EmbassyRuntime` sleep
  is a stub; embassy 0.10 `Spawner` is not `Send`/`Sync` so the
  `EmbeddedRuntime` trait was relaxed from the spec. Confirm before
  relying on the embedded runtime in flight.
- No fuzzing harness.
- No dependency audit pipeline beyond `cargo deny check` (installed and
  passing). `cargo machete` clean. `cargo bloat` passes.
- No secret-management policy for HelixDB / Valkey credentials.
- **Transport-layer authn/authz (as of Phase 4/5/6)** — GraphQL
  per-request role extraction via `better-auth` sessions is implemented
  (`RoleGuard` sees the actual caller role, not a global default).
  MQTT topic ACLs via `MqttAcl` / `AclRule` (pattern matching) are
  implemented. Auth-off mode rejects all GraphQL requests and uses
  anonymous MQTT credentials. WS subscription role extraction defaults
  to Observer at upgrade time; per-connection session resolution is a
  follow-up. See `specs/auth.toml`.
- `themql-cache` has concrete backends wired (L1 lru, L2 moka, L3 redis,
  L4 sled via themql-storage), with a key→subject index for pattern
  invalidation. L3 requires a running `redis-server` (degrades to
  `TierUnavailable` when absent). The trait boundary is where access
  control, credential handling, and input validation must be enforced
  when real valkey/redis L3 and helix-db L4 land.
- `tch` is wired behind a `tch-backend` feature gate in
  themql-training/themql-inference. The feature compiles clean but tests
  are not run in this environment (libtorch + RAM). The ML attack surface
  is real: model bytes are hash-validated + schema-validated before
  deserialisation into a `tch::CModule`, and inference checks the
  `inference_deadline_ms` budget. ML remains augmentative only (never
  the authoritative flight-control path).
- `polars` + `rayon` are wired into themql-analysis. No live analysis
  attack surface yet (RayonAnalysisPipeline runs a trivial parallel
  null-count; StorageAnalysisPipeline queries themql-storage).
- `themql-schema` is a pure type-definition crate with no I/O, no
  network, no unsafe code. No attack surface.

These limitations are tracked; they are not open invitations to land
insecure defaults when the corresponding code is written.

## Dependabot Alert Dismissal Rationale (2026-08-20)

GitHub Dependabot reported 6 alerts on the default branch. All 6 are
**not exploitable in our usage** and are ignored in `deny.toml
[advisories].ignore`. The rationale for each:

| Alert | Crate | Severity | Path in our tree | Not-exploitable because |
|---|---|---|---|---|
| RUSTSEC-2026-0104 | rustls-webpki 0.102/0.103 | High (DoS panic on malformed CRL BIT STRING) | rustls → reqwest/rumqttc → desktop | We never pass CRL data to webpki; reqwest/rumqttc use default trust store, no CRL revocation. Panic requires attacker-controlled CRL input. |
| GHSA-h395-gr6q-cpjc | jsonwebtoken 9.3.1 | Moderate (type confusion in nbf/exp validation) | better-auth-core → desktop | better-auth's MemoryDatabaseAdapter session flow uses opaque `session_`-prefixed tokens (session.rs:223), not JWT issuance. `jsonwebtoken` is only referenced in an error enum (error.rs:71). We never call encode/decode on attacker-controlled JWTs. |
| RUSTSEC-2026-0049 | rustls-webpki 0.103 | Moderate (CRL Distribution Point matching) | same as above | No CRL revocation enabled. |
| RUSTSEC-2026-0002 | lru 0.12.5 | Low (Stacked Borrows violation in IterMut) | themql-cache direct dep | We do not use `IterMut` under Miri/Stacked Borrows. **Fixed by deduping lru to 0.18.2** (patched version); advisory kept in ignore list for audit traceability. |
| RUSTSEC-2026-0099 | rustls-webpki 0.103 | Low (wildcard name constraints) | same as above | No name-constrained CA using wildcards in use. |
| RUSTSEC-2026-0098 | rustls-webpki 0.103 | Low (URI name constraints) | same as above | No URI name-constrained CA in use. |

**Action taken:** `lru` bumped from 0.12.5 → 0.18.2 in `themql-cache`
(deduplicates the transitive 0.18.2 from ratatui, fixes
RUSTSEC-2026-0002 and RUSTSEC-2026-0253). The remaining 5 alerts are
transitive deps we cannot remove without upstream changes (better-auth
pins `jsonwebtoken = "9"`; rustls-webpki is pulled by reqwest/rumqttc).
All 6 are ignored in `deny.toml` with precise reasons.

**GitHub UI dismissal:** Dependabot does not read `deny.toml`; the 6
alerts must be manually dismissed in the GitHub Security tab using
"Dismiss alert → Tolerable risk" with the rationale above.

## Advisory posture (2026-09-30)

`cargo deny check` no longer fails: `RUSTSEC-2026-0285` (`rustls` 0.23.43 TLS
1.3 encryption-level confusion) was fixed by moving to 0.23.45, and the
yanked `chacha20 0.10.1` to 0.10.2.

Five advisories remain under `deny.toml` waiver. None is a reachability shrug;
each is either provably unreachable or provably unfixable today, and each
carries an unblock condition that CI re-checks.

| Advisory | Crate | Status | Unblock |
|---|---|---|---|
| RUSTSEC-2026-0049 / 0098 / 0099 / 0104 | `rustls-webpki` 0.102.8 | **Unfixable** — no patched 0.102.x exists; every `rumqttc` release through 0.25.1 pins `^0.102` | a rumqttc release requiring `rustls-webpki >= 0.103.13` |
| GHSA-h395-gr6q-cpjc | `jsonwebtoken` 9.3.1 | **Unreachable** — no JWT plugin registered; sessions are opaque; auth is opt-in | `better-auth >= 1.0.0-alpha.3` (`jsonwebtoken ^11`) |

**Waivers in this repo must be machine-checked.** A waiver that rests on
reachability is asserting an invariant, so the invariant gets a guard rather
than a comment. `scripts/ci_guard.py`:

- **check 5** — the `jsonwebtoken` authorization-bypass advisory stays
  unreachable. Fails if the auth builder references a JWT marker, if the
  registered plugin count is no longer exactly one, if `enable_auth` stops
  defaulting to `false`, if the waiver and the guard disagree, or if the
  locked `jsonwebtoken` reaches the patched major. This exists because the
  `auth_secret` help text once described itself as a JWT signing key, which
  would have walked the next maintainer into making the ignored advisory
  reachable.
- **check 6** — re-checks each waiver's unblock condition
  (`scripts/check-advisory-rationales.sh`) and fails the build once one is
  met, so a waiver cannot outlive its own justification.

`rumqttc` reaches the vulnerable `rustls-webpki` only on its own broker TLS
paths (`themql-mqtt`). The `better-auth` path in `themql-desktop` already
resolves to the patched `rustls-webpki 0.103.14` via `rustls 0.23.45`.

## Toolchain and edition posture (2026-09-30)

The workspace is pinned to **Rust 1.98.1** and on **edition 2024**.

Pinning is a supply-chain control, not a convenience. A floating `stable` in CI
means a new compiler release can change build and lint behaviour with no change
in the repository — so a reviewer sees a red pipeline with an empty diff, and
the change that caused it is not attributable to any commit. `ci_guard.py`
check 4 asserts the pin in `rust-toolchain.toml` and every CI job name the same
exact version, and rejects a floating channel in either, because a pin only one
of the two knows about is not a pin.

The edition 2024 migration was checked for unsafe-surface exposure before it
started: no `no_mangle` / `export_name` / `link_section`, no file-scope
`static mut`, no bare `gen` identifier, no `unsafe fn`, and no `extern "C"`
across ~18k lines. There was therefore no FFI shim or unsafe block to rework,
and the only semantic change was `collapsible_if` becoming a let-chain.

The embedded `no_std` target (`thumbv7em-none-eabihf`) is a safety-relevant
build for vehicle-facing code. It had stopped compiling — see `BUGS.md`
BUG-0004 — because `format!` and `f64::sqrt` need explicit `alloc` imports and a
trait in scope under `no_std`, and `themql-gnc` was missing the `num-traits`
dependency outright. Those are production `health_check` paths, so the artifact
could not be produced. The rules are now written down in `MEMORY.md`.
