# themql-runtime

Execution runtimes for theMQL, as two separate traits (no shared
trait, per spec): `DesktopRuntime` on tokio and `EmbeddedRuntime`
on embassy.

Features: `desktop` (tokio time/sync), `embedded`
(`embassy-sync`, `embassy-executor`, `embassy-time`). See
`specs/runtime.toml` in the workspace for the authoritative
specification (async I/O, Rayon for CPU-bound work, bounded
channels, explicit backpressure).

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
