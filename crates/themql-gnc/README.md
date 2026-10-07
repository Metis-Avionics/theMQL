# themql-gnc

Deterministic flight control for theMQL: the `Controller` trait with
PID, LQRI, and hybrid LQRI-PID controllers over a 21-dimensional
`GncState`. Quaternion attitude is canonical (Euler angles only for
UI/logging — never as control state).

Basic flight stability works without ML: deterministic GNC outranks
every ML path, and `tch` is forbidden in the control loop
(`tch_rs_in_control_loop = false`). `no_std` + `alloc` capable
(`--no-default-features`). Safety-critical: TETANUS-compliant
(`TETANUS.md`). See `specs/gnc.toml` in the workspace for the
authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
