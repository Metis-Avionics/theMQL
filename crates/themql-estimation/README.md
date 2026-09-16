# themql-estimation

State estimation for theMQL: the `Estimator` trait, a Jacobian-based
extended Kalman filter with Joseph-form covariance update over a
fixed 21-dimensional state, `SensorModel` impls (GPS, barometer),
and Bayesian uncertainty propagation/sampling.

Primary estimation is the EKF — ML may only augment the estimate,
never replace it. Sensor failure must be detectable; uncertainty is
always represented. `no_std` + `alloc` capable
(`--no-default-features`). Safety-critical: TETANUS-compliant
(`TETANUS.md`). See `specs/state_estimation.toml` in the workspace
for the authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
