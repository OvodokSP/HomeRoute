#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CANARY="$ROOT/scripts/validation/live-transaction-canary.sh"
TX="$ROOT/scripts/installer/file-transaction.sh"
FEEDS="$ROOT/router/preflight-feeds.sh"
TMPDIR_BASE=${TMPDIR:-/tmp}
BASE="$TMPDIR_BASE/homeroute-live-validation-test.$$"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

# Canary must refuse to run without explicit acknowledgement.
if HOMEROUTE_CANARY_TEST_MODE=1 HOMEROUTE_CANARY_TEST_ROOT="/tmp/homeroute-live-canary-test.noack.$$"    HOMEROUTE_TRANSACTION_LIB="$TX" sh "$CANARY" router >/dev/null 2>&1; then
    fail 'live canary unexpectedly ran without acknowledgement'
fi

# CI test-mode canary uses only an explicitly allowed /tmp prefix.
TEST_ROOT="/tmp/homeroute-live-canary-test.$$"
out=$(HOMEROUTE_LIVE_CANARY_ACK=YES       HOMEROUTE_CANARY_TEST_MODE=1       HOMEROUTE_CANARY_TEST_ROOT="$TEST_ROOT"       HOMEROUTE_TRANSACTION_LIB="$TX"       sh "$CANARY" router)
printf '%s\n' "$out" | grep -F 'HOMEROUTE_LIVE_CANARY schema=1 target=router result=PASS' >/dev/null ||
    fail 'router live-canary contract did not pass'
[ ! -e "$TEST_ROOT" ] || fail 'canary test root was not cleaned up'

# Feed inventory fixture.
mkdir -p "$BASE/opkg"
cat > "$BASE/opkg/public.conf" <<'EOF'
src/gz chur https://ward-sentry.github.io/chur-keenetic/latest/mips-3.4
src hrneo https://example.invalid/packages
EOF
printf 'src/gz private https://%s:%s@example.invalid/feed\n' 'fixture-user' 'fixture-pass' > "$BASE/opkg/private.conf"

feed_out=$(HOMEROUTE_OPKG_DIR="$BASE/opkg" sh "$FEEDS")
printf '%s\n' "$feed_out" | grep -F 'name=chur url=https://ward-sentry.github.io/chur-keenetic/latest/mips-3.4' >/dev/null ||
    fail 'public feed missing from inventory'
printf '%s\n' "$feed_out" | grep -F 'name=private url=[REDACTED_URL_WITH_USERINFO]' >/dev/null ||
    fail 'credential-bearing feed URL was not redacted'
if printf '%s\n' "$feed_out" | grep -F 'fixture-user:fixture-pass' >/dev/null; then
    fail 'credential-bearing URL leaked'
fi

printf '%s\n' '[PASS] live-canary and feed-inventory safety contracts'
