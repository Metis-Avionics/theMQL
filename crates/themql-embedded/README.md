# themql-embedded

Embedded vehicle binary for theMQL (embassy): sensor acquisition
(BME280 barometer, LSM6DS3 IMU, NEO-6M GPS via `embedded-hal`),
EKF estimation, hybrid LQRI-PID control, constrained model
inference, and MQTT v5 telemetry (`minimq`).

Runs the real EKF + `HybridController` pipeline in embassy tasks
with a fixed-heap allocator. Cross-compiles for
`thumbv7em-none-eabihf`. Must not depend on dioxus, polars,
helix-db, valkey, theDAF, or desktop training infrastructure. See
`specs/embedded.toml` in the workspace for the authoritative
specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
