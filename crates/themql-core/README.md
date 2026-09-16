# themql-core

Semantic owner of theMQL — the canonical Message, Query, Response,
Error, Context, and Resource types plus the `Resolver`,
`MessageHandler`, and `QueryExecutor` traits.

All transport layers (GraphQL, MQTT, SSE) are projections of these
types; they never redefine them. See `specs/core.toml` in the
workspace for the authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace (native Rust message-query runtime for desktop,
distributed, telemetry, analysis, AI, GNC, and embedded systems).
License: MIT.
