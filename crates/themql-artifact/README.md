# themql-artifact

Model-artifact boundary between training and inference: versioned,
hashed artifacts with `ArtifactValidator` / `ArtifactLoader` /
`ArtifactWriter`, real BLAKE3 integrity hashing
(`HashValidator`), file loading, and bincode writing.

No model activates on the embedded target without version, schema,
compatibility, and integrity validation; the previous valid model
is retained and failed activation reverts. Safety-critical:
TETANUS-compliant (`TETANUS.md`). See `specs/model_artifact.toml`
in the workspace for the authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
