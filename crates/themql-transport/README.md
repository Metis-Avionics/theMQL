# themql-transport

Cross-cutting transport abstraction for theMQL: the `Bridge` trait,
`BridgeRoute`, and `TransportKind` (MQTT, GraphQL, SSE sub-kinds),
plus the MQTT↔SSE bridge direction.

Transport adapters contain no business logic — they project the
core message/query model onto the wire. Transport-specific types
must not escape their adapter crate. See `specs/transport.toml`
(plus `mqtt.toml`, `graphql.toml`, `sse.toml`) in the workspace for
the authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
