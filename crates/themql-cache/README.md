# themql-cache

Tiered cache for theMQL: the `Cache` trait plus L1 (`lru`), L2
(`moka`), L3 (`redis`), and L4 (`themql-storage`), orchestrated by
`TieredCache` with promotion on hit, write-through puts, and a
key→subject index for pattern invalidation.

L4 is authoritative. Cache keys are deterministic; TTL and
invalidation policies are explicit (no hidden invalidation). See
`specs/cache.toml` in the workspace for the authoritative
specification. Composes the listed cache dependencies — no custom
cache engine.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
