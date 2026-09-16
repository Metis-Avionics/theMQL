# themql-message

Message serialisation for theMQL: the `Serializer` trait plus
`JsonSerializer` and `MessageError`.

Subordinate to `themql-core` (canonical Message type lives there);
this crate handles routing and serialisation specialisation only.
See `specs/message.toml` in the workspace for the authoritative
specification (subject grammar, serializer contract).

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
