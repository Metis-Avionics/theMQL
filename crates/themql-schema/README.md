# themql-schema

Canonical shared schema types for theMQL: `FeatureSchema`,
`NormalizationSpec`, `ModelFormat`, `TrainedModel`,
`ValidationMetrics`, and related types.

`themql-artifact`, `themql-training`, and `themql-inference`
re-export from here instead of defining their own copies. See
`specs/schema.toml` in the workspace for the authoritative
specification. Pure type definitions — no I/O, no network, no
`unsafe`.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
