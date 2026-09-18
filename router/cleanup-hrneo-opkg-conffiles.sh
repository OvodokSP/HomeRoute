#!/bin/sh
# Capture and remove only the three expected HRNeo conffile alternates created
# by a successful same-version opkg reinstall. No service or network changes.

set -eu
umask 077

MODE=${1:-plan}
RESCUE=${2:-}
ACK=${HOMEROUTE_HRNEO_CONFFILE_CLEANUP_ACK:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DOCTOR=${HOMEROUTE_ROUTER_DOCTOR:-$SCRIPT_DIR/doctor-router.sh}
LIVE_ROOT=${HOMEROUTE_HRNEO_LIVE_ROOT:-}
TEST_MODE=${HOMEROUTE_HRNEO_CONFFILE_CLEANUP_TEST_MODE:-0}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_HRNEO_CONFFILE_CLEANUP %s=%s\n' "$1" "$2"
}

show_plan() {
    field schema 1
    field mode plan
    field expected_artifacts 3
    field capture_before_remove true
    field service_restart false
    field package_change false
    field network_change false
    field result PLAN_ONLY
    printf '%s\n' '[PASS] HRNeo conffile cleanup plan rendered; no state changed'
}

case "$MODE" in
    plan|--plan)
        show_plan
        exit 0
        ;;
    clean|--clean)
        ;;
    help|--help|-h)
        printf '%s\n' 'Usage: cleanup-hrneo-opkg-conffiles.sh [plan|clean <rescue-dir>]'
        exit 0
        ;;
    *)
        fail "unknown mode: $MODE"
        ;;
esac

[ -n "$RESCUE" ] || fail 'rescue directory is required'
[ "$ACK" = YES ] || fail 'set HOMEROUTE_HRNEO_CONFFILE_CLEANUP_ACK=YES to capture and remove generated conffile alternates'
[ -d "$RESCUE" ] || fail "rescue directory missing: $RESCUE"
[ -f "$RESCUE/FILES.sha256" ] || fail 'rescue FILES.sha256 missing'
[ -f "$DOCTOR" ] || fail "router doctor missing: $DOCTOR"
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum unavailable'
command -v cp >/dev/null 2>&1 || fail 'cp unavailable'
command -v rm >/dev/null 2>&1 || fail 'rm unavailable'

if [ "$TEST_MODE" = 1 ]; then
    case "$RESCUE" in
        /tmp/homeroute-hrneo-rescue-test.*/*) ;;
        *) fail 'unsafe test rescue path' ;;
    esac
    case "$LIVE_ROOT" in
        /tmp/homeroute-hrneo-live-test.*) ;;
        *) fail 'unsafe test live root' ;;
    esac
else
    case "$RESCUE" in
        /opt/homeroute-backups/hrneo-rescue-*) ;;
        *) fail 'invalid live rescue path' ;;
    esac
    [ -z "$LIVE_ROOT" ] || fail 'live root override is forbidden'
fi

base="$LIVE_ROOT/opt/etc/HydraRoute"
[ -d "$base" ] || fail "HydraRoute config directory missing: $base"

names='hrneo.conf domain.conf ip.list'
evidence="$RESCUE/reinstall-conffile-alternates"
manifest="$evidence/FILES.sha256"

# Refuse unexpected *-opkg objects in the managed config directory.
unexpected=0
for path in "$base"/*-opkg; do
    [ -e "$path" ] || continue
    name=$(basename "$path")
    case "$name" in
        hrneo.conf-opkg|domain.conf-opkg|ip.list-opkg) ;;
        *)
            printf '[FAIL] unexpected opkg conffile artifact: %s\n' "$path" >&2
            unexpected=1
            ;;
    esac
done
[ "$unexpected" -eq 0 ] || exit 2

existing=0
for name in $names; do
    alt="$base/$name-opkg"
    [ -f "$alt" ] && existing=$((existing + 1))
done

if [ "$existing" -eq 0 ]; then
    [ -f "$manifest" ] || fail 'expected alternates are absent but no cleanup evidence exists'
    (
        cd "$evidence"
        sha256sum -c FILES.sha256 >/dev/null
    ) || fail 'existing cleanup evidence failed checksum verification'

    doctor_out=$(sh "$DOCTOR" 2>&1) || {
        printf '%s\n' "$doctor_out" >&2
        fail 'router doctor failed on already-clean state'
    }
    printf '%s\n' "$doctor_out" | grep -F 'result=PASS' >/dev/null ||
        fail 'router doctor PASS marker missing on already-clean state'

    field schema 1
    field mode clean
    field expected_artifacts 3
    field captured_artifacts 3
    field removed_artifacts 0
    field already_clean true
    field doctor PASS
    field service_restart false
    field package_change false
    field network_change false
    field result PASS
    printf '%s\n' '[PASS] HRNeo conffile cleanup already complete; evidence re-verified'
    exit 0
fi

[ "$existing" -eq 3 ] || fail "partial conffile-artifact state detected: expected 3, found $existing"
[ ! -e "$evidence" ] || fail 'cleanup evidence directory already exists before first cleanup'

# Verify current live conffiles still match the pre-reinstall rescue snapshot.
for name in $names; do
    rel="opt/etc/HydraRoute/$name"
    live="$LIVE_ROOT/$rel"
    expected=$(awk -v rel="$rel" '$2==rel {print $1; exit}' "$RESCUE/FILES.sha256")
    [ -n "$expected" ] || fail "rescue manifest does not contain live conffile: $rel"
    [ -f "$live" ] || fail "live conffile missing: $live"
    actual=$(sha256sum "$live" | awk '{print $1}')
    [ "$actual" = "$expected" ] || fail "live conffile drifted from rescue snapshot: $name"
done

mkdir -p "$evidence"
chmod 700 "$evidence"
: > "$manifest"

captured=0
bytes=0
for name in $names; do
    alt="$base/$name-opkg"
    [ -f "$alt" ] || fail "expected generated conffile missing: $alt"
    cp -a "$alt" "$evidence/$name-opkg"
    hash=$(sha256sum "$evidence/$name-opkg" | awk '{print $1}')
    size=$(wc -c < "$evidence/$name-opkg" | tr -d '[:space:]')
    printf '%s  %s\n' "$hash" "$name-opkg" >> "$manifest"
    captured=$((captured + 1))
    bytes=$((bytes + size))
done
chmod 600 "$manifest" "$evidence"/*-opkg

(
    cd "$evidence"
    sha256sum -c FILES.sha256 >/dev/null
) || fail 'captured conffile-alternate evidence failed verification'

removed=0
for name in $names; do
    alt="$base/$name-opkg"
    rm -f "$alt"
    [ ! -e "$alt" ] || fail "failed to remove generated conffile: $alt"
    removed=$((removed + 1))
done

doctor_out=$(sh "$DOCTOR" 2>&1) || {
    printf '%s\n' "$doctor_out" >&2
    fail 'router doctor failed after conffile cleanup'
}
printf '%s\n' "$doctor_out" | grep -F 'result=PASS' >/dev/null ||
    fail 'router doctor PASS marker missing after conffile cleanup'

field schema 1
field mode clean
field expected_artifacts 3
field captured_artifacts "$captured"
field captured_bytes "$bytes"
field removed_artifacts "$removed"
field already_clean false
field doctor PASS
field service_restart false
field package_change false
field network_change false
field result PASS
printf '%s\n' '[PASS] HRNeo opkg-generated conffile alternates captured and removed; live conffiles were preserved'
