# themql-query

Query resolution for theMQL: `CacheKey` / `CacheKeyer` (deterministic
BLAKE3 keys), the `QueryExecutor` trait (incl. the
`DefaultQueryExecutor` orchestrator with cancellation, deadline, and
cache write-through), `Batcher`, and `QueryError`.

Subordinate to `themql-core`; queries are side-effect-free and
transport-independent. See `specs/query.toml` in the workspace for
the authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
