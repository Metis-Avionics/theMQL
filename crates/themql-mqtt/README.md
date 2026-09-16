# themql-mqtt

MQTT transport for theMQL: the `MqttTransport` / `MqttPublisher` /
`MqttSubscriber` traits, subject↔topic mapping, the JSON message
codec, `RumqttcTransport` + `RumqttcConfig` (desktop), and MQTT
topic ACLs (`MqttAcl` / `AclRule`).

MQTT is a transport for core messages, not a semantic system. See
`specs/mqtt.toml` (and `specs/auth.toml`) in the workspace for the
authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
