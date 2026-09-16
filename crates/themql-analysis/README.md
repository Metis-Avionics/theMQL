# themql-analysis

Desktop-side telemetry analysis for theMQL: the `AnalysisPipeline`
trait, `PolarsDatasetBuilder` / `PolarsAnalysisResult` (polars),
`RayonAnalysisPipeline` (parallel), `StorageAnalysisPipeline`, and
the theDAF legacy-data adapter surface.

Desktop-only: must not pull in embedded concerns. theDAF is
integration-only (legacy access / migration reference), never a core
dependency. See `specs/analysis.toml` in the workspace for the
authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
