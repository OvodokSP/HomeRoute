#!/bin/sh
# Extend an existing HRNeo rescue set with the global opkg status database.
# Read-only with respect to package/runtime state.

set -eu
umask 077

MODE=${1:-plan}
RESCUE=${2:-}
ACK=${HOMEROUTE_HRNEO_STATUS_RESCUE_ACK:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERIFY_CONTROL=${HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-opkg-state.sh}
STATUS_FILE=${HOMEROUTE_OPKG_STATUS_FILE:-/opt/lib/opkg/status}
TEST_MODE=${HOMEROUTE_HRNEO_STATUS_RESCUE_TEST_MODE:-0}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_HRNEO_STATUS_RESCUE %s=%s\n' "$1" "$2"
}

show_plan() {
    field schema 1
    field mode plan
    field package hrneo
    field status_database_capture true
    field package_change false
    field service_restart false
    field network_change false
    field result PLAN_ONLY
    printf '%s\n' '[PASS] HRNeo opkg status-database rescue plan rendered; no state changed'
}

case "$MODE" in
    plan|--plan)
        show_plan
        exit 0
        ;;
    capture|--capture)
        ;;
    help|--help|-h)
        printf '%s\n' 'Usage: capture-hrneo-opkg-status.sh [plan|capture <rescue-dir>]'
        exit 0
        ;;
    *)
        fail "unknown mode: $MODE"
        ;;
esac

[ -n "$RESCUE" ] || fail 'rescue directory is required'
[ "$ACK" = YES ] || fail 'set HOMEROUTE_HRNEO_STATUS_RESCUE_ACK=YES to capture the opkg status database'
[ -d "$RESCUE" ] || fail "rescue directory missing: $RESCUE"
[ -f "$VERIFY_CONTROL" ] || fail "opkg/control rescue verifier missing: $VERIFY_CONTROL"
[ -f "$STATUS_FILE" ] || fail "opkg status database missing: $STATUS_FILE"
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum unavailable'
command -v opkg >/dev/null 2>&1 || fail 'opkg unavailable'

if [ "$TEST_MODE" = 1 ]; then
    case "$RESCUE" in
        /tmp/homeroute-hrneo-rescue-test.*/*) ;;
        *) fail 'unsafe test rescue directory' ;;
    esac
    case "$STATUS_FILE" in
        /tmp/homeroute-opkg-status-test.*) ;;
        *) fail 'unsafe test status-file path' ;;
    esac
else
    case "$RESCUE" in
        /opt/homeroute-backups/hrneo-rescue-*) ;;
        *) fail 'live rescue directory must be under /opt/homeroute-backups/hrneo-rescue-*' ;;
    esac
    [ "$STATUS_FILE" = /opt/lib/opkg/status ] || fail 'live opkg status-file override is forbidden'
fi

sh "$VERIFY_CONTROL" "$RESCUE" >/dev/null ||
    fail 'HRNeo opkg/control rescue extension did not verify before status capture'

installed=$(opkg status hrneo 2>/dev/null || true)
printf '%s\n' "$installed" | grep -Fx 'Package: hrneo' >/dev/null ||
    fail 'opkg status hrneo did not report the package'
printf '%s\n' "$installed" | grep -Fx 'Version: 3.18.3-1' >/dev/null ||
    fail 'installed HRNeo version is not 3.18.3-1'
printf '%s\n' "$installed" | grep -E '^Status: .* installed$' >/dev/null ||
    fail 'HRNeo is not marked installed in opkg status'

db_dir="$RESCUE/package-database"
[ ! -e "$db_dir" ] || fail 'package-database rescue directory already exists'
mkdir -p "$db_dir"
chmod 700 "$db_dir"

cp -a "$STATUS_FILE" "$db_dir/opkg-status"
printf '%s\n' "$installed" > "$db_dir/hrneo-status-stanza.txt"

db_sha=$(sha256sum "$db_dir/opkg-status" | awk '{print $1}')
stanza_sha=$(sha256sum "$db_dir/hrneo-status-stanza.txt" | awk '{print $1}')
db_bytes=$(wc -c < "$db_dir/opkg-status" | tr -d '[:space:]')

cat > "$RESCUE/opkg-status-rescue-metadata.txt" <<EOF
schema=1
package=hrneo
version=3.18.3-1
status_database_sha256=$db_sha
status_database_bytes=$db_bytes
hrneo_status_stanza_sha256=$stanza_sha
package_change=false
service_restart=false
network_change=false
EOF

chmod 600 "$db_dir/opkg-status" "$db_dir/hrneo-status-stanza.txt" "$RESCUE/opkg-status-rescue-metadata.txt"

field schema 1
field mode capture
field package hrneo
field version 3.18.3-1
field status_database_sha256 "$db_sha"
field status_database_bytes "$db_bytes"
field hrneo_status_stanza_sha256 "$stanza_sha"
field package_change false
field service_restart false
field network_change false
field result PASS
printf '%s\n' '[PASS] global opkg status database captured; live package/runtime state was not changed'
