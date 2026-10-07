# themql-training

Desktop-side model creation for theMQL: the `Trainer` trait,
polars-backed `Dataset`, `TrainingConfig` (incl. pruning /
sparsification), and `TchTrainer` (MLP + Adam + MSE + TorchScript
export) behind the `tch-backend` feature.

Desktop-only. Training output crosses to embedded inference only as
a validated model artifact (see `themql-artifact`). See
`specs/training.toml` in the workspace for the authoritative
specification. There is no `themql-ai` crate — do not introduce one.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
