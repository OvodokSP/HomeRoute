#!/bin/sh
# Read-only verification that immutable HRNeo/opkg/runtime state matches
# a previously captured rescue set. User conffiles are mutable protected state:
# they must exist, but their bytes are not pinned to an older rescue snapshot.

set -eu

RESCUE=${1:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

VERIFY_RESCUE=${HOMEROUTE_HRNEO_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-rescue.sh}
VERIFY_CONTROL=${HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-opkg-state.sh}
VERIFY_STATUS=${HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-opkg-status.sh}
ARTIFACT_TOOL=${HOMEROUTE_HRNEO_ARTIFACT_TOOL:-$SCRIPT_DIR/hrneo-artifact.sh}
DOCTOR=${HOMEROUTE_ROUTER_DOCTOR:-$SCRIPT_DIR/doctor-router.sh}

INFO_DIR=${HOMEROUTE_OPKG_INFO_DIR:-/opt/lib/opkg/info}
STATUS_FILE=${HOMEROUTE_OPKG_STATUS_FILE:-/opt/lib/opkg/status}
LIVE_ROOT=${HOMEROUTE_HRNEO_LIVE_ROOT:-}
TEST_MODE=${HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY_TEST_MODE:-0}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY %s=%s\n' "$1" "$2"
}

[ -n "$RESCUE" ] || fail 'usage: verify-hrneo-live-rescue-state.sh <rescue-dir>'
[ -d "$RESCUE" ] || fail "rescue directory missing: $RESCUE"

for tool in "$VERIFY_RESCUE" "$VERIFY_CONTROL" "$VERIFY_STATUS" "$ARTIFACT_TOOL" "$DOCTOR"; do
    [ -f "$tool" ] || fail "required verifier/tool missing: $tool"
done

command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum unavailable'
command -v readlink >/dev/null 2>&1 || fail 'readlink unavailable'
command -v opkg >/dev/null 2>&1 || fail 'opkg unavailable'

if [ "$TEST_MODE" = 1 ]; then
    case "$RESCUE" in /tmp/homeroute-hrneo-rescue-test.*/*) ;; *) fail 'unsafe test rescue path' ;; esac
    case "$INFO_DIR" in /tmp/homeroute-hrneo-opkg-info-test.*) ;; *) fail 'unsafe test opkg info path' ;; esac
    case "$STATUS_FILE" in /tmp/homeroute-opkg-status-test.*) ;; *) fail 'unsafe test opkg status path' ;; esac
    case "$LIVE_ROOT" in /tmp/homeroute-hrneo-live-test.*) ;; *) fail 'unsafe test live root' ;; esac
else
    case "$RESCUE" in /opt/homeroute-backups/hrneo-rescue-*) ;; *) fail 'invalid live rescue path' ;; esac
    [ "$INFO_DIR" = /opt/lib/opkg/info ] || fail 'live opkg info override is forbidden'
    [ "$STATUS_FILE" = /opt/lib/opkg/status ] || fail 'live opkg status override is forbidden'
    [ -z "$LIVE_ROOT" ] || fail 'live root override is forbidden'
fi

HOMEROUTE_HRNEO_ARTIFACT_TOOL="$ARTIFACT_TOOL" sh "$VERIFY_RESCUE" "$RESCUE" >/dev/null ||
    fail 'base rescue set integrity failed'
sh "$VERIFY_CONTROL" "$RESCUE" >/dev/null ||
    fail 'opkg/control rescue integrity failed'
sh "$VERIFY_STATUS" "$RESCUE" >/dev/null ||
    fail 'global opkg status rescue integrity failed'

is_mutable_conffile_rel() {
    case "$1" in
        opt/etc/HydraRoute/hrneo.conf|opt/etc/HydraRoute/domain.conf|opt/etc/HydraRoute/ip.list)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

mutable_conffiles_present=0
while read -r hash rel; do
    [ -n "$hash" ] && [ -n "$rel" ] || continue
    path="$LIVE_ROOT/$rel"
    if is_mutable_conffile_rel "$rel"; then
        [ -f "$path" ] || fail "mutable HRNeo conffile missing: $rel"
        mutable_conffiles_present=$((mutable_conffiles_present + 1))
        continue
    fi
    [ -f "$path" ] || fail "live immutable package file missing: $rel"
    actual=$(sha256sum "$path" | awk '{print $1}')
    [ "$actual" = "$hash" ] || fail "live immutable package file differs from rescue: $rel"
done < "$RESCUE/FILES.sha256"

[ "$mutable_conffiles_present" -eq 3 ] ||
    fail "expected 3 mutable HRNeo conffiles in package snapshot, found: $mutable_conffiles_present"

tab=$(printf '\t')
while IFS="$tab" read -r rel target; do
    [ -n "$rel" ] || continue
    path="$LIVE_ROOT/$rel"
    [ -L "$path" ] || fail "live package symlink missing: $rel"
    [ "$(readlink "$path")" = "$target" ] ||
        fail "live package symlink target differs: $rel"
done < "$RESCUE/SYMLINKS.tsv"

while read -r hash name; do
    [ -n "$hash" ] && [ -n "$name" ] || continue
    path="$INFO_DIR/$name"
    [ -f "$path" ] || fail "live opkg info file missing: $name"
    actual=$(sha256sum "$path" | awk '{print $1}')
    [ "$actual" = "$hash" ] || fail "live opkg info differs from rescue: $name"
done < "$RESCUE/OPKG_INFO.sha256"

while IFS="$tab" read -r name target; do
    [ -n "$name" ] || continue
    path="$INFO_DIR/$name"
    [ -L "$path" ] || fail "live opkg info symlink missing: $name"
    [ "$(readlink "$path")" = "$target" ] ||
        fail "live opkg info symlink target differs: $name"
done < "$RESCUE/OPKG_INFO_SYMLINKS.tsv"

rc="$LIVE_ROOT/opt/etc/init.d/rc.unslung"
neo="$LIVE_ROOT/opt/bin/neo"
[ -f "$rc" ] || fail 'live rc.unslung missing'
rc_expected=$(awk '$2=="rc.unslung" {print $1; exit}' "$RESCUE/SIDE_EFFECTS.sha256")
[ -n "$rc_expected" ] || fail 'rescue rc.unslung checksum missing'
[ "$(sha256sum "$rc" | awk '{print $1}')" = "$rc_expected" ] ||
    fail 'live rc.unslung differs from rescue'
[ -L "$neo" ] || fail 'live /opt/bin/neo is not a symlink'
[ "$(readlink "$neo")" = /opt/etc/init.d/S99hrneo ] ||
    fail 'live /opt/bin/neo target differs from rescue contract'

status_expected=$(sed -n 's/^status_database_sha256=//p' "$RESCUE/opkg-status-rescue-metadata.txt" | sed -n '1p')
[ -n "$status_expected" ] || fail 'rescue global status checksum missing'
status_actual=$(sha256sum "$STATUS_FILE" | awk '{print $1}')
[ "$status_actual" = "$status_expected" ] ||
    fail 'live global opkg status differs from rescue'

base="$LIVE_ROOT/opt/etc/HydraRoute"
[ -d "$base" ] || fail 'live HydraRoute config directory missing'
for path in "$base"/*-opkg; do
    [ -e "$path" ] || continue
    fail "generated opkg conffile residue remains: $path"
done

installed=$(opkg status hrneo 2>/dev/null || true)
printf '%s\n' "$installed" | grep -Fx 'Package: hrneo' >/dev/null ||
    fail 'HRNeo package missing from opkg status'
printf '%s\n' "$installed" | grep -Fx 'Version: 3.18.3-1' >/dev/null ||
    fail 'HRNeo version mismatch'
printf '%s\n' "$installed" | grep -E '^Status: .* installed$' >/dev/null ||
    fail 'HRNeo not marked installed'

doctor_out=$(sh "$DOCTOR" 2>&1) || {
    printf '%s\n' "$doctor_out" >&2
    fail 'router doctor failed'
}
printf '%s\n' "$doctor_out" | grep -F 'result=PASS' >/dev/null ||
    fail 'router doctor PASS marker missing'

field schema 1
field package hrneo
field version 3.18.3-1
field immutable_package_files PASS
field mutable_conffiles present_not_pinned
field opkg_info PASS
field side_effect_state PASS
field status_database PASS
field conffile_residue none
field doctor PASS
field result PASS
printf '%s\n' '[PASS] current immutable HRNeo/opkg/router state matches rescue; mutable conffiles are present but intentionally not pinned to the old snapshot'
