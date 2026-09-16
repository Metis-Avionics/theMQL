# themql-storage

Authoritative storage (L4) for theMQL: the
`Storage`/`StorageReader`/`StorageWriter` traits,
`StorageKey`/`StorageValue`/`StorageQuery`/`StorageResultSet`
types, `SledStorage` (disk-backed sled), and the `HelixStorage`
alias.

Storage holds no business logic — it is a projection target of the
core message/query model. See `specs/storage.toml` in the workspace
for the authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
