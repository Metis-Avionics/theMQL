# themql-graphql

GraphQL projection of theMQL: the `GraphqlSchema` /
`GraphqlResolverBridge` traits, `QueryRoot` / `MutationRoot` /
`SubscriptionRoot`, the resolver/dispatch bridge impls, per-request
role guards (`RoleGuard`, via better-auth sessions), and
`serve_graphql` (axum HTTP + WebSocket).

GraphQL is a projection of the core model, not an independent
semantic system. Composes `async-graphql` — no custom GraphQL
engine. See `specs/graphql.toml` (and `specs/auth.toml`) in the
workspace for the authoritative specification.

Part of the [theMQL](https://github.com/Metis-Avionics/theMQL)
workspace. License: MIT.
