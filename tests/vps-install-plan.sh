#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALLER="$ROOT/vps/install.sh"
TMPDIR_BASE=${TMPDIR:-/tmp}
OUT="$TMPDIR_BASE/homeroute-vps-plan-test.$$"
ERR="$TMPDIR_BASE/homeroute-vps-plan-test-err.$$"
trap 'rm -f "$OUT" "$ERR"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

sh "$INSTALLER" plan >"$OUT" 2>"$ERR" || fail 'plan mode returned non-zero'
grep -F '[PASS] Plan completed; no system changes were made.' "$OUT" >/dev/null || fail 'plan success marker missing'
grep -F '[BLOCKED] Exact resource thresholds' "$OUT" >/dev/null || fail 'plan must preserve inventory dependency gate'

if sh "$INSTALLER" apply >"$OUT" 2>"$ERR"; then
    fail 'apply mode unexpectedly succeeded'
fi
grep -F '[BLOCKED] HomeRoute VPS apply-mode is not implemented or validated.' "$OUT" >/dev/null || fail 'apply block marker missing'

if sh "$INSTALLER" definitely-not-a-mode >"$OUT" 2>"$ERR"; then
    fail 'unknown mode unexpectedly succeeded'
fi
grep -F '[FAIL] unknown mode:' "$ERR" >/dev/null || fail 'unknown-mode failure marker missing'

printf '%s\n' '[PASS] VPS installer plan-only contract'
