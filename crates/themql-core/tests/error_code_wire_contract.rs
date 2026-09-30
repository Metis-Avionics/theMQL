//! Wire-contract tests for [`ErrorCode`].
//!
//! Covers `SPEC.toml [quality] property_tests_required = true` and the
//! separation rule in `specs/core.toml` `[types.ErrorCode.separation_rule]`.
//!
//! The property that matters is **distinguishability**. A transport adapter
//! projects an `ErrorCode` into a GraphQL error, an MQTT topic, or an SSE
//! frame. If two codes serialise to the same string, the receiving side
//! cannot tell a denial from a miss, and a fail-closed decision becomes an
//! indistinguishable one. So the assertions here are about the *set* of wire
//! strings, not about any one of them.

#![allow(clippy::unwrap_used, clippy::expect_used)]

use std::collections::HashSet;

use proptest::prelude::*;
use themql_core::{Error, ErrorCode};

/// The declared contract: variant -> wire string. If a variant is added
/// without a wire string, or renamed without updating this table, the
/// round-trip tests below fail rather than shipping a silent rename.
const CONTRACT: &[(ErrorCode, &str)] = &[
    (ErrorCode::TransportError, "transport_error"),
    (ErrorCode::ResolverError, "resolver_error"),
    (ErrorCode::CacheMiss, "cache_miss"),
    (ErrorCode::NotFound, "not_found"),
    (ErrorCode::ValidationError, "validation_error"),
    (ErrorCode::AuthorizationError, "authorization_error"),
    (ErrorCode::Timeout, "timeout"),
    (ErrorCode::Conflict, "conflict"),
    (ErrorCode::InternalError, "internal_error"),
];

fn all_codes() -> Vec<ErrorCode> {
    CONTRACT.iter().map(|(code, _)| *code).collect()
}

#[test]
fn every_code_renders_its_declared_wire_string() {
    for (code, expected) in CONTRACT {
        assert_eq!(
            code.to_string(),
            *expected,
            "{code:?} must render as {expected}; a rename here is a wire break"
        );
    }
}

#[test]
fn every_code_serde_round_trips_through_its_wire_string() {
    for (code, wire) in CONTRACT {
        let json = serde_json::to_string(code).expect("ErrorCode serializes");
        assert_eq!(
            json,
            format!("\"{wire}\""),
            "{code:?} must serialise to its declared wire string"
        );
        let back: ErrorCode = serde_json::from_str(&json).expect("ErrorCode deserializes");
        assert_eq!(back, *code, "{code:?} must survive a serde round trip");
    }
}

/// The load-bearing property: no two codes may share a wire string.
#[test]
fn wire_strings_are_injective_across_every_code() {
    let mut seen: HashSet<&str> = HashSet::new();
    for (code, wire) in CONTRACT {
        assert!(
            seen.insert(wire),
            "{code:?} reuses the wire string {wire:?}; the receiving side could \
             not tell the two outcomes apart"
        );
    }
    assert_eq!(seen.len(), CONTRACT.len());
}

/// A denial must not be observable as anything else. This is the concrete
/// fail-closed property: a caller matching on `AuthorizationError` cannot be
/// fooled by a miss, a resolver failure, or a not-found.
#[test]
fn authorization_denial_is_distinct_from_every_other_code() {
    let denial = Error::authorization_error("grant revoked");
    assert_eq!(denial.code, ErrorCode::AuthorizationError);

    for other in all_codes() {
        if other == ErrorCode::AuthorizationError {
            continue;
        }
        assert_ne!(
            denial.code, other,
            "an authorization denial must not be reportable as {other:?}"
        );
    }

    // And it must not degrade to a retryable miss on the wire.
    assert_ne!(denial.code, ErrorCode::CacheMiss);
    assert_ne!(denial.code, ErrorCode::NotFound);
}

/// `NotFound` (a fact about the data) and `CacheMiss` (a fact about the
/// lookup) drive opposite caller behaviour: one retries against the
/// authority, the other does not. They must stay separate.
#[test]
fn not_found_and_cache_miss_drive_opposite_behaviour_and_stay_separate() {
    assert_ne!(
        Error::not_found("no such asset").code,
        Error::cache_miss("no resolver").code
    );
}

/// A lost CAS race is retryable; a malformed input is not. Same reasoning,
/// different pair.
#[test]
fn conflict_is_distinct_from_validation_error() {
    assert_ne!(
        Error::conflict("cas lost").code,
        Error::validation_error("malformed").code
    );
}

#[test]
fn constructors_set_their_own_code_and_preserve_the_message() {
    let cases = [
        (Error::not_found("m"), ErrorCode::NotFound),
        (
            Error::authorization_error("m"),
            ErrorCode::AuthorizationError,
        ),
        (Error::conflict("m"), ErrorCode::Conflict),
    ];
    for (err, expected) in cases {
        assert_eq!(err.code, expected);
        assert_eq!(err.message, "m", "the message must survive construction");
    }
}

/// The builders must chain without dropping the code, since a real error is
/// almost always built and then decorated with a subject and correlation id.
#[test]
fn builders_preserve_the_authorization_code() {
    let err =
        Error::authorization_error("denied").with_details(serde_json::json!({"role": "viewer"}));
    assert_eq!(err.code, ErrorCode::AuthorizationError);
    assert!(err.details.is_some(), "details must be retained");
}

proptest! {
    /// Whatever the input, the rendered wire string must be a lowercase
    /// snake_case token with no whitespace — adapters key routing and
    /// filtering off it.
    #[test]
    fn wire_string_is_always_lowercase_snake_case(code in prop::sample::select(
        all_codes()
    )) {
        let rendered = code.to_string();
        prop_assert!(!rendered.is_empty());
        prop_assert!(rendered.chars().all(|c| c.is_ascii_lowercase() || c == '_'));
        prop_assert!(rendered.chars().next().is_some_and(|c| c.is_ascii_lowercase()));
    }

    /// Round-tripping through JSON must be lossless for every code, so a
    /// projection into any transport format is reversible.
    #[test]
    fn every_code_json_round_trips(code in prop::sample::select(all_codes())) {
        let json = serde_json::to_string(&code).expect("ErrorCode serializes");
        let back: ErrorCode = serde_json::from_str(&json).expect("ErrorCode deserializes");
        prop_assert_eq!(back, code);
    }
}
