# themql-telemetry

First-class telemetry messages for theMQL: `TelemetryMessage`
(timestamped, sequenced, schema-versioned), canonical sensor
readings (NEO-6M GPS, BME280 barometer, GY-LSM6DS3 IMU), state
estimates with covariance (`[f64; 441]`), controller/model state,
and diagnostics.

No sensor is assumed permanently valid — failure must be
detectable and the estimator must represent uncertainty. See
`specs/telemetry.toml` in the workspace for the authoritative
specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
