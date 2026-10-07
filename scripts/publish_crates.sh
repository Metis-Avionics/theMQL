#!/usr/bin/env bash
# scripts/publish_crates.sh — publish theMQL workspace crates to crates.io
# at FIXED intervals to stay under the crates.io new-crate rate limit.
#
# Background / unattended use:
#   nohup bash scripts/publish_crates.sh all > /tmp/opencode/publish-fixed.log 2>&1 &
#
# Cron use (publishes at most one crate per run — the schedule IS the interval):
#   */15 * * * * /home/leo/theMQL/scripts/publish_crates.sh next >> /tmp/opencode/publish-cron.log 2>&1
#
# Usage:
#   scripts/publish_crates.sh all   # publish every remaining crate, one per interval
#   scripts/publish_crates.sh next  # publish only the next unpublished crate, then exit
#
# Env:
#   PUBLISH_INTERVAL  seconds between successful publishes (default 720 = 12 min).
#                     crates.io 429-rate-limits bursts of new crates; a fixed
#                     12-minute cadence keeps us safely under the observed limit.
#   DRY_RUN=1         run `cargo publish --dry-run` instead of uploading.
set -u

INTERVAL="${PUBLISH_INTERVAL:-720}"
MODE="${1:-all}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Dependency order: leaves first, binaries last. The script skips crates
# already at this version on crates.io, so re-running is always safe.
CRATES="themql-core themql-schema themql-runtime themql-message themql-query themql-artifact themql-storage themql-telemetry themql-sse themql-mqtt themql-gnc themql-estimation themql-transport themql-cache themql-graphql themql-analysis themql-inference themql-training themql-desktop themql-embedded"

# The repo's rust-toolchain.toml requests the `miri` component on the
# tracking `stable` channel, which currently breaks rustup-proxy sync
# (`rustc -vV` fails inside `cargo publish --verify`). Bypass the proxy by
# putting a pinned toolchain's binaries first on PATH.
PINNED="$HOME/.rustup/toolchains/1.98.0-x86_64-unknown-linux-gnu/bin"
if [ -d "$PINNED" ]; then
    export PATH="$PINNED:$PATH"
fi

VERSION="$(grep '^version' "$REPO_ROOT/Cargo.toml" | head -n 1 | cut -d'"' -f2)"

is_published() {
    # 200 from the version endpoint means this exact version is live.
    # NOTE: crates.io returns 403 to requests without an explicit
    # User-Agent, so one is required here (verified 2026-09-14).
    curl -sf -A "theMQL-publish-script/0.1.0" -o /dev/null "https://crates.io/api/v1/crates/$1/$VERSION" 2>/dev/null
}

publish_one() {
    local crate="$1"
    local extra_args="${DRY_RUN:+--dry-run}"
    # Repo policy: never commit implicitly, so publish from the dirty tree.
    # shellcheck disable=SC2086
    cargo publish -p "$crate" --allow-dirty $extra_args 2>&1
}

wait_for_rate_limit() {
    # $1 = full cargo output containing the 429 retry hint.
    local retry
    retry=$(echo "$1" | grep -oP 'try again after \K[^.]*(?= and)' | head -n 1)
    if [ -z "$retry" ]; then
        return 1
    fi
    local now target sleep_for
    now=$(date -u +%s)
    target=$(date -u -d "$retry" +%s)
    sleep_for=$((target - now + 60))
    [ "$sleep_for" -lt 60 ] && sleep_for=60
    echo "rate-limited; fixed backoff: sleeping ${sleep_for}s (retry-after $retry + 60s buffer)"
    sleep "$sleep_for"
    return 0
}

publish_next() {
    # Publish the first unpublished crate in dependency order. Returns:
    # 0 = published (or dry-run ok), 1 = fatal error, 2 = nothing left to do.
    local crate out
    for crate in $CRATES; do
        if is_published "$crate"; then
            echo "skip: $crate $VERSION already on crates.io"
            continue
        fi
        echo "=== publishing $crate $VERSION at $(date -u) ==="
        out=$(publish_one "$crate")
        echo "$out" | tail -n 5
        if echo "$out" | grep -q "Published $crate"; then
            echo "=== $crate SUCCESS ==="
            return 0
        fi
        if echo "$out" | grep -q "already exists\|already uploaded"; then
            echo "=== $crate already exists (race), treating as done ==="
            return 0
        fi
        if echo "$out" | grep -q "429 Too Many Requests"; then
            echo "$out" > /tmp/opencode/publish-last-429.log
            echo "=== $crate rate-limited (see /tmp/opencode/publish-last-429.log) ==="
            return 3
        fi
        echo "=== $crate FATAL ==="
        echo "$out" | tail -n 20
        return 1
    done
    echo "all crates at $VERSION already published — nothing to do"
    return 2
}

cd "$REPO_ROOT" || exit 1

case "$MODE" in
    next)
        publish_next
        exit $?
        ;;
    all)
        while true; do
            publish_next
            rc=$?
            case $rc in
                2) exit 0 ;;                    # done
                1) echo "fatal error, stopping"; exit 1 ;;
                3)                              # rate-limited: wait, then retry same crate
                    if wait_for_rate_limit "$(cat /tmp/opencode/publish-last-429.log)"; then
                        continue
                    fi
                    echo "could not parse retry-after, sleeping $INTERVAL"
                    sleep "$INTERVAL"
                    ;;
                0)                              # success: fixed interval before next crate
                    echo "fixed interval: sleeping ${INTERVAL}s before next crate"
                    sleep "$INTERVAL"
                    ;;
            esac
        done
        ;;
    *)
        echo "usage: $0 [all|next]" >&2
        exit 2
        ;;
esac
