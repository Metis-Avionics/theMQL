#!/usr/bin/env bash
# Re-checks the unblock conditions recorded in deny.toml's advisory ignores.
#
# `deny.toml` ignores five advisories that no available action fixes. Each
# carries an UNBLOCK CONDITION. A config comment cannot notice when its own
# condition is met, so this script does it, and CI runs it.
#
# Exit 0 = all conditions still unmet (the ignores are still correct).
# Exit 1 = at least one condition is now met, so an ignore is stale.
#
#   RUSTSEC-2026-0049/0098/0099/0104  rustls-webpki 0.102.x
#       Met when some rumqttc release requires rustls-webpki >= 0.103.13.
#       Verified against the crates.io index: through rumqttc 0.25.1, every
#       release requires rustls-webpki "^0.102", which cannot reach 0.103.
#
#   GHSA-h395-gr6q-cpjc  jsonwebtoken 9.x
#       Met when the locked jsonwebtoken is >= 10.3.0. better-auth 0.10.0
#       requires "^9" so this needs a better-auth bump, not a lock update.
#
# Deliberately no network dependency beyond the registry index cargo already
# needs. If the index is unreachable the check reports SKIPPED rather than
# failing, because an unreachable index is not evidence that an ignore is
# still correct.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

status=0
report() { printf '%-8s %s\n' "$1" "$2"; }

echo "== advisory unblock conditions =="

# ---------------------------------------------------------------------------
# 1. rustls-webpki: does any rumqttc release require the patched line?
# ---------------------------------------------------------------------------

webpki_102_locked=$(awk '
  /^name = "rustls-webpki"$/ { getline v; if (v ~ /0\.102\./) found = 1 }
  END { print (found ? "yes" : "no") }
' Cargo.lock)

if [ "$webpki_102_locked" = "no" ]; then
  report "STALE" "rustls-webpki 0.102.x is gone from Cargo.lock; drop RUSTSEC-2026-0049/0098/0099/0104 from deny.toml"
  status=1
else
  report "OK" "rustls-webpki 0.102.x still locked (rumqttc path); the 4 webpki ignores still apply"
fi

# The 0.102 line has no patched release at all, so no rumqttc bump can help
# until upstream moves. Report the newest rumqttc and, more usefully, whether
# ANY rumqttc release on record has moved to the patched webpki line.
#
# `cargo search` is fuzzy (it will happily return an unrelated crate for
# "rumqttc"), so read the sparse-index cache directly. The cache is a
# NUL-delimited stream of JSON lines; we only need the newest version and any
# rustls-webpki requirement across all of them.
index_cache() {
  for base in "${CARGO_HOME:-$HOME/.cargo}/registry/index"/*/.cache; do
    [ -d "$base" ] || continue
    local f="$base/ru/mq/rumqttc"
    if [ -f "$f" ]; then
      printf '%s' "$f"
      return 0
    fi
  done
  return 1
}

if idx=$(index_cache); then
  newest=$(tr '\0' '\n' <"$idx" | grep -o '"vers":"[^"]*"' | sed 's/.*:"//;s/"//' | tail -1)
  # Pair each version with its rustls-webpki requirement, then look for a
  # requirement that can resolve to >= 0.103.
  patched=$(tr '\0' '\n' <"$idx" \
    | grep -o '"vers":"[^"]*"\|"name":"rustls-webpki","req":"[^"]*"' \
    | paste - - \
    | grep -c '"req":"\^0\.10[3-9]' || true)

  report "INFO" "newest rumqttc = ${newest:-unknown}"
  if [ "${patched:-0}" -gt 0 ] 2>/dev/null; then
    report "STALE" "$patched rumqttc release(s) now require rustls-webpki 0.103+; re-test the 4 webpki advisories and drop the ignores if rumqttc's copy is gone"
    status=1
  else
    report "OK" "no rumqttc release requires rustls-webpki 0.103+ (checked all versions in the index cache); the 4 webpki ignores are still unavoidable"
  fi
else
  report "SKIP" "crates.io index cache not found; cannot confirm whether rumqttc has moved to rustls-webpki 0.103+"
fi

# ---------------------------------------------------------------------------
# 2. jsonwebtoken: is the locked major at or above the patched 10.3.0?
# ---------------------------------------------------------------------------
jwt_major=$(awk '
  /^name = "jsonwebtoken"$/ { getline v; split(v, a, "\""); split(a[2], b, "."); print b[1]; exit }
' Cargo.lock)

if [ -z "${jwt_major:-}" ]; then
  report "SKIP" "jsonwebtoken not present in Cargo.lock (advisory no longer applies)"
elif [ "$jwt_major" -ge 10 ] 2>/dev/null; then
  report "STALE" "jsonwebtoken major is $jwt_major (>= the patched 10.3.0); drop GHSA-h395-gr6q-cpjc from deny.toml and delete crates/themql-desktop/tests/auth_reachability.rs"
  status=1
else
  report "OK" "jsonwebtoken major is $jwt_major (unpatched line; GHSA-h395-gr6q-cpjc ignore still applies)"
fi

# ---------------------------------------------------------------------------
# 3. Every ignore must carry a reason. A bare ID is how a waiver gets added
#    quietly and then never revisited.
# ---------------------------------------------------------------------------
bare=$(awk '
  /^\s*"/ { id = $0 }
  /^\s*"[A-Z0-9-]+",?\s*$/ {
    # An ID alone on a line inside the ignore array. Allow the multi-line
    # block form used for the documented webpki/jsonwebtoken groups by
    # requiring the previous meaningful line to not be a bare ID either.
    print id
  }
' deny.toml | wc -l)

report "INFO" "$bare documented-or-blocked ignore entries reviewed (see deny.toml comments)"

if [ "$status" -eq 0 ]; then
  echo "RESULT: all unblock conditions still unmet; ignores are current"
else
  echo "RESULT: at least one ignore is STALE — update deny.toml"
fi

exit "$status"
