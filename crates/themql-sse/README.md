# themql-sse

Server-sent-events projection of theMQL: the `SseStream` /
`SsePublisher` traits, the `SseEvent` wire format,
`TokioSsePublisher` (broadcast + bounded replay log), and
`serve_sse` (axum, with `Last-Event-ID` replay).

SSE is a projection of the core message model. See `specs/sse.toml`
in the workspace for the authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
