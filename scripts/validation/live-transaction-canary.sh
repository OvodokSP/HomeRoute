#!/bin/sh
# Live filesystem canary for HomeRoute transaction validation.
# It mutates only a dedicated temporary directory and never touches
# networking, packages, Docker, VPN, firewall, or existing HomeRoute files.

set -eu

CANARY_TARGET=${1:-}
ACK=${HOMEROUTE_LIVE_CANARY_ACK:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TX_LIB=${HOMEROUTE_TRANSACTION_LIB:-$SCRIPT_DIR/../installer/file-transaction.sh}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

[ "$ACK" = "YES" ] || fail 'set HOMEROUTE_LIVE_CANARY_ACK=YES to run the dedicated canary'

case "$CANARY_TARGET" in
    router)
        BASE=/opt/tmp/homeroute-live-canary
        ;;
    vps)
        BASE=/var/tmp/homeroute-live-canary
        ;;
    *)
        fail 'usage: live-transaction-canary.sh <router|vps>'
        ;;
esac

if [ "${HOMEROUTE_CANARY_TEST_MODE:-0}" = "1" ]; then
    test_root=${HOMEROUTE_CANARY_TEST_ROOT:-}
    [ -n "$test_root" ] || fail 'HOMEROUTE_CANARY_TEST_ROOT is required in test mode'
    case "$test_root" in
        /tmp/homeroute-live-canary-test.*) BASE=$test_root ;;
        *) fail 'unsafe test canary root' ;;
    esac
fi

[ -f "$TX_LIB" ] || fail "transaction library not found: $TX_LIB"
[ ! -e "$BASE" ] || fail "canary directory already exists; inspect and remove it manually first: $BASE"

cleanup() {
    case "$BASE" in
        /opt/tmp/homeroute-live-canary|/var/tmp/homeroute-live-canary|/tmp/homeroute-live-canary-test.*)
            rm -rf "$BASE"
            ;;
    esac
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$BASE/etc/homeroute"
: > "$BASE/.homeroute-sandbox"
printf '%s\n' 'ORIGINAL=1' > "$BASE/etc/homeroute/existing.conf"
printf '%s\n' 'UNRELATED=1' > "$BASE/etc/homeroute/unrelated.conf"
printf '%s\n' 'DESIRED=1' > "$BASE/desired.conf"

export HOMEROUTE_SANDBOX_ROOT="$BASE"
export HOMEROUTE_TX_ID="live-canary-$$"

# shellcheck source=../installer/file-transaction.sh
. "$TX_LIB"

tx_begin
tx_apply_file 'etc/homeroute/existing.conf' "$BASE/desired.conf"
tx_apply_file 'etc/homeroute/generated.conf' "$BASE/desired.conf"

tx_verify_file 'etc/homeroute/existing.conf' "$BASE/desired.conf" ||
    fail 'canary verify failed for existing file'
tx_verify_file 'etc/homeroute/generated.conf' "$BASE/desired.conf" ||
    fail 'canary verify failed for generated file'

tx_rollback

grep -Fx 'ORIGINAL=1' "$BASE/etc/homeroute/existing.conf" >/dev/null ||
    fail 'rollback did not restore existing file'
[ ! -e "$BASE/etc/homeroute/generated.conf" ] ||
    fail 'rollback did not remove transaction-created file'
grep -Fx 'UNRELATED=1' "$BASE/etc/homeroute/unrelated.conf" >/dev/null ||
    fail 'unrelated file changed'

printf 'HOMEROUTE_LIVE_CANARY schema=1 target=%s result=PASS scope=dedicated_filesystem_only\n' "$target"
printf '%s\n' '[PASS] live filesystem transaction canary; dedicated directory will be removed'
