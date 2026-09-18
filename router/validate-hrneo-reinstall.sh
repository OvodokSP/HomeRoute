#!/bin/sh
# Controlled same-version reinstall validation for pinned HRNeo.
#
# Live behavior:
# - requires a fully verified rescue set;
# - requires current managed state to still match that rescue set;
# - reinstalls the exact local pinned IPK with --force-reinstall --nodeps;
# - validates package metadata, managed files, side effects and router doctor;
# - on any failure after transaction start, restores files, hrneo.* opkg info,
#   global opkg status, rc.unslung and /opt/bin/neo from the rescue set,
#   then restarts HRNeo and runs doctor again.

set -eu
umask 077

MODE=${1:-plan}
RESCUE=${2:-}
ACK=${HOMEROUTE_HRNEO_REINSTALL_ACK:-}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERIFY_RESCUE=${HOMEROUTE_HRNEO_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-rescue.sh}
VERIFY_CONTROL=${HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-opkg-state.sh}
VERIFY_STATUS=${HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-opkg-status.sh}
ARTIFACT_TOOL=${HOMEROUTE_HRNEO_ARTIFACT_TOOL:-$SCRIPT_DIR/hrneo-artifact.sh}
DOCTOR=${HOMEROUTE_ROUTER_DOCTOR:-$SCRIPT_DIR/doctor-router.sh}

INFO_DIR=${HOMEROUTE_OPKG_INFO_DIR:-/opt/lib/opkg/info}
STATUS_FILE=${HOMEROUTE_OPKG_STATUS_FILE:-/opt/lib/opkg/status}
LIVE_ROOT=${HOMEROUTE_HRNEO_LIVE_ROOT:-}
TEST_MODE=${HOMEROUTE_HRNEO_REINSTALL_TEST_MODE:-0}
FORCE_VERIFY_FAIL=${HOMEROUTE_HRNEO_REINSTALL_FORCE_VERIFY_FAIL:-0}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_HRNEO_REINSTALL %s=%s\n' "$1" "$2"
}

show_plan() {
    field schema 1
    field mode plan
    field package hrneo
    field version 3.18.3-1
    field exact_local_ipk true
    field force_reinstall true
    field nodeps true
    field postinst_expected_stop_start true
    field rollback_files true
    field rollback_opkg_info true
    field rollback_opkg_status true
    field rollback_side_effects true
    field requires_explicit_ack true
    field result PLAN_ONLY
    printf '%s\n' '[PASS] controlled HRNeo same-version reinstall plan rendered; no state changed'
}

case "$MODE" in
    plan|--plan)
        show_plan
        exit 0
        ;;
    validate|--validate)
        ;;
    help|--help|-h)
        printf '%s\n' 'Usage: validate-hrneo-reinstall.sh [plan|validate <rescue-dir>]'
        exit 0
        ;;
    *)
        fail "unknown mode: $MODE"
        ;;
esac

[ -n "$RESCUE" ] || fail 'rescue directory is required'
[ "$ACK" = YES ] || fail 'set HOMEROUTE_HRNEO_REINSTALL_ACK=YES to allow the controlled package reinstall'

command -v opkg >/dev/null 2>&1 || fail 'opkg unavailable'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum unavailable'
command -v cp >/dev/null 2>&1 || fail 'cp unavailable'
command -v cmp >/dev/null 2>&1 || fail 'cmp unavailable'
command -v readlink >/dev/null 2>&1 || fail 'readlink unavailable'

for tool in "$VERIFY_RESCUE" "$VERIFY_CONTROL" "$VERIFY_STATUS" "$ARTIFACT_TOOL" "$DOCTOR"; do
    [ -f "$tool" ] || fail "required verifier/tool missing: $tool"
done

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
    fail 'base HRNeo rescue set did not verify'
sh "$VERIFY_CONTROL" "$RESCUE" >/dev/null ||
    fail 'HRNeo opkg/control rescue extension did not verify'
sh "$VERIFY_STATUS" "$RESCUE" >/dev/null ||
    fail 'HRNeo global opkg status rescue extension did not verify'

meta() {
    key=$1
    sed -n "s/^${key}=//p" "$RESCUE/metadata.txt" | sed -n '1p'
}

arch=$(meta arch)
filename=$(meta artifact_filename)
[ -n "$arch" ] && [ -n "$filename" ] || fail 'rescue artifact metadata incomplete'
artifact="$RESCUE/$filename"
[ -f "$artifact" ] || fail "pinned rescue artifact missing: $artifact"
sh "$ARTIFACT_TOOL" verify-file "$arch" "$artifact" >/dev/null ||
    fail 'pinned rescue artifact identity verification failed'

help=$(opkg --help 2>&1 || true)
printf '%s\n' "$help" | grep -F -- '--force-reinstall' >/dev/null ||
    fail 'installed opkg does not advertise --force-reinstall'
printf '%s\n' "$help" | grep -F -- '--nodeps' >/dev/null ||
    fail 'installed opkg does not advertise --nodeps'

for dep in libc ipset iptables ip-full; do
    dep_status=$(opkg status "$dep" 2>/dev/null || true)
    printf '%s\n' "$dep_status" | grep -Fx "Package: $dep" >/dev/null ||
        fail "required dependency is not installed: $dep"
    printf '%s\n' "$dep_status" | grep -E '^Status: .* installed$' >/dev/null ||
        fail "required dependency is not marked installed: $dep"
done

installed=$(opkg status hrneo 2>/dev/null || true)
printf '%s\n' "$installed" | grep -Fx 'Package: hrneo' >/dev/null ||
    fail 'HRNeo package missing before reinstall'
printf '%s\n' "$installed" | grep -Fx 'Version: 3.18.3-1' >/dev/null ||
    fail 'HRNeo version drifted before reinstall'
printf '%s\n' "$installed" | grep -E '^Status: .* installed$' >/dev/null ||
    fail 'HRNeo is not marked installed before reinstall'

if ps 2>/dev/null | grep '[o]pkg ' >/dev/null 2>&1; then
    fail 'another opkg process appears to be running'
fi

live_path() {
    printf '%s/%s\n' "$LIVE_ROOT" "$1"
}

verify_live_managed_state() {
    while read -r hash rel; do
        [ -n "$hash" ] && [ -n "$rel" ] || continue
        path=$(live_path "$rel")
        [ -f "$path" ] || return 1
        actual=$(sha256sum "$path" | awk '{print $1}')
        [ "$actual" = "$hash" ] || return 1
    done < "$RESCUE/FILES.sha256"

    tab=$(printf '\t')
    while IFS="$tab" read -r rel target; do
        [ -n "$rel" ] || continue
        path=$(live_path "$rel")
        [ -L "$path" ] || return 1
        [ "$(readlink "$path")" = "$target" ] || return 1
    done < "$RESCUE/SYMLINKS.tsv"

    while read -r hash name; do
        [ -n "$hash" ] && [ -n "$name" ] || continue
        path="$INFO_DIR/$name"
        [ -f "$path" ] || return 1
        actual=$(sha256sum "$path" | awk '{print $1}')
        [ "$actual" = "$hash" ] || return 1
    done < "$RESCUE/OPKG_INFO.sha256"

    while IFS="$tab" read -r name target; do
        [ -n "$name" ] || continue
        path="$INFO_DIR/$name"
        [ -L "$path" ] || return 1
        [ "$(readlink "$path")" = "$target" ] || return 1
    done < "$RESCUE/OPKG_INFO_SYMLINKS.tsv"

    rc="$LIVE_ROOT/opt/etc/init.d/rc.unslung"
    neo="$LIVE_ROOT/opt/bin/neo"
    [ -f "$rc" ] || return 1
    rc_expected=$(awk '$2=="rc.unslung" {print $1}' "$RESCUE/SIDE_EFFECTS.sha256")
    [ -n "$rc_expected" ] || return 1
    [ "$(sha256sum "$rc" | awk '{print $1}')" = "$rc_expected" ] || return 1
    [ -L "$neo" ] || return 1
    [ "$(readlink "$neo")" = /opt/etc/init.d/S99hrneo ] || return 1

    return 0
}

verify_live_against_rescue() {
    verify_live_managed_state || return 1
    status_expected=$(sed -n 's/^status_database_sha256=//p' "$RESCUE/opkg-status-rescue-metadata.txt" | sed -n '1p')
    [ -n "$status_expected" ] || return 1
    [ "$(sha256sum "$STATUS_FILE" | awk '{print $1}')" = "$status_expected" ] || return 1
    return 0
}

verify_live_against_rescue ||
    fail 'current HRNeo/opkg state drifted from rescue set; refusing package transaction'

doctor_before=$(sh "$DOCTOR" 2>&1) || {
    printf '%s\n' "$doctor_before" >&2
    fail 'router doctor failed immediately before package transaction'
}
printf '%s\n' "$doctor_before" | grep -F 'result=PASS' >/dev/null ||
    fail 'router doctor PASS marker missing before package transaction'

work="$RESCUE/reinstall-work"
[ ! -e "$work" ] || fail 'reinstall-work already exists in rescue set'
mkdir -p "$work"
chmod 700 "$work"

opkg list-installed | LC_ALL=C sort > "$work/packages.before"
status_before_sha=$(sha256sum "$STATUS_FILE" | awk '{print $1}')

transaction_started=0
success=0
rollback_result=NOT_NEEDED

restore_from_rescue() {
    rollback_result=FAILED
    init="$LIVE_ROOT/opt/etc/init.d/S99hrneo"

    if [ -x "$init" ] || [ -f "$init" ]; then
        sh "$init" stop >/dev/null 2>&1 || true
    fi

    cp -a "$RESCUE/files/." "$LIVE_ROOT/" || return 1

    for path in "$INFO_DIR"/hrneo.*; do
        [ -e "$path" ] || [ -L "$path" ] || continue
        rm -f "$path" || return 1
    done
    cp -a "$RESCUE/opkg-info/." "$INFO_DIR/" || return 1

    tmp_status="$STATUS_FILE.homeroute-rollback.$$"
    cp -a "$RESCUE/package-database/opkg-status" "$tmp_status" || return 1
    mv -f "$tmp_status" "$STATUS_FILE" || return 1

    cp -a "$RESCUE/package-side-effects/rc.unslung" "$LIVE_ROOT/opt/etc/init.d/rc.unslung" || return 1
    rm -f "$LIVE_ROOT/opt/bin/neo" || return 1
    cp -a "$RESCUE/package-side-effects/neo" "$LIVE_ROOT/opt/bin/neo" || return 1

    init="$LIVE_ROOT/opt/etc/init.d/S99hrneo"
    sh "$init" start >/dev/null 2>&1 || return 1

    verify_live_against_rescue || return 1

    rollback_doctor=$(sh "$DOCTOR" 2>&1) || {
        printf '%s\n' "$rollback_doctor" >&2
        return 1
    }
    printf '%s\n' "$rollback_doctor" | grep -F 'result=PASS' >/dev/null || return 1

    rollback_result=PASS
    return 0
}

cleanup() {
    rc=$?
    trap - EXIT HUP INT TERM

    if [ "$success" -ne 1 ] && [ "$transaction_started" -eq 1 ]; then
        printf '%s\n' '[INFO] package validation failed; restoring HRNeo rescue set' >&2
        if ! restore_from_rescue; then
            printf '%s\n' '[FAIL] automatic HRNeo rollback failed; rescue set retained' >&2
        else
            printf '%s\n' '[PASS] automatic HRNeo rollback completed' >&2
        fi
    fi

    if [ "$success" -eq 1 ]; then
        rm -rf "$work"
    else
        printf '[INFO] rescue set retained at %s\n' "$RESCUE" >&2
    fi
    exit "$rc"
}
trap cleanup EXIT HUP INT TERM

start_epoch=$(date +%s)
transaction_started=1

opkg --force-reinstall --nodeps install "$artifact"

if [ "$FORCE_VERIFY_FAIL" = 1 ]; then
    fail 'forced post-install verification failure requested'
fi

after=$(opkg status hrneo 2>/dev/null || true)
printf '%s\n' "$after" | grep -Fx 'Package: hrneo' >/dev/null ||
    fail 'HRNeo missing from opkg status after reinstall'
printf '%s\n' "$after" | grep -Fx 'Version: 3.18.3-1' >/dev/null ||
    fail 'HRNeo version mismatch after reinstall'
printf '%s\n' "$after" | grep -E '^Status: .* installed$' >/dev/null ||
    fail 'HRNeo not marked installed after reinstall'

opkg list-installed | LC_ALL=C sort > "$work/packages.after"
cmp -s "$work/packages.before" "$work/packages.after" ||
    fail 'installed package set changed during HRNeo same-version reinstall'

# The same-version artifact should reproduce the same managed package/control files
# and idempotent postinst side effects. The global status DB itself may be rewritten.
status_after_sha=$(sha256sum "$STATUS_FILE" | awk '{print $1}')

verify_live_managed_state ||
    fail 'managed HRNeo/opkg state differs from expected same-version result'

doctor_after=$(sh "$DOCTOR" 2>&1) || {
    printf '%s\n' "$doctor_after" >&2
    fail 'router doctor failed after HRNeo reinstall'
}
printf '%s\n' "$doctor_after" | grep -F 'result=PASS' >/dev/null ||
    fail 'router doctor PASS marker missing after HRNeo reinstall'

end_epoch=$(date +%s)
window=$((end_epoch - start_epoch))

status_identical=false
[ "$status_before_sha" = "$status_after_sha" ] && status_identical=true

field schema 1
field mode validate
field package hrneo
field version 3.18.3-1
field arch "$arch"
field force_reinstall true
field nodeps true
field installed_package_set_unchanged true
field managed_files_match_rescue true
field opkg_info_match_rescue true
field side_effect_state_idempotent true
field status_database_byte_identical "$status_identical"
field doctor PASS
field validation_window_seconds "$window"
field rollback "$rollback_result"
field live_package_transaction_validated true
field result PASS

success=1
printf '%s\n' '[PASS] controlled HRNeo same-version package reinstall validation completed'
