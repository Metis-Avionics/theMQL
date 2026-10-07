# themql-desktop

Desktop operations binary for theMQL: clap CLI (`serve`, `analyze`,
`train`, `validate`, `telemetry`, `tui`), the axum serve router
(GraphQL + SSE + MQTT bridge, optional better-auth sessions),
polars analysis, `tch` training (behind `tch-backend`),
artifact validation, and the ratatui TUI dashboard.

The primary development, analysis, training, telemetry, and
operational environment. Training lives in `themql-training` and is
desktop-only. See `specs/desktop.toml` in the workspace for the
authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
