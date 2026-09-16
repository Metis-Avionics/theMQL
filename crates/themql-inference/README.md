# themql-inference

Embedded-side model execution for theMQL: the `InferenceEngine`
trait, `TchInferenceEngine` (model load + forward pass behind the
`tch-backend` feature), `ResourceBudget` (bounded online
adaptation), and `RollbackHandle` (failed activation reverts to the
previous model).

Embedded-capable; must not depend on desktop infrastructure. ML is
augmentative only — it must never become the authoritative
flight-control path, and no model activates without version, schema,
compatibility, and integrity validation. Safety-critical:
TETANUS-compliant (`TETANUS.md`). See `specs/inference.toml` in the
workspace for the authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
