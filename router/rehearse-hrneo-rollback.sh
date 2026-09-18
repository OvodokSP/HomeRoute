#!/bin/sh
# Controlled live rehearsal of the HRNeo automatic rollback failure path.
#
# It captures a FRESH rescue set of the current clean router state, forces a
# verification failure immediately after a same-version reinstall, requires
# automatic rollback to complete, then independently verifies that current
# package/opkg/runtime state exactly matches that fresh rescue set again.

set -eu
umask 077

MODE=${1:-plan}
ACK=${HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL_ACK:-}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PREPARE=${HOMEROUTE_HRNEO_RESCUE_PREPARE:-$SCRIPT_DIR/prepare-hrneo-rescue.sh}
CAPTURE_CONTROL=${HOMEROUTE_HRNEO_OPKG_STATE_CAPTURE:-$SCRIPT_DIR/capture-hrneo-opkg-state.sh}
CAPTURE_STATUS=${HOMEROUTE_HRNEO_OPKG_STATUS_CAPTURE:-$SCRIPT_DIR/capture-hrneo-opkg-status.sh}
VERIFY_RESCUE=${HOMEROUTE_HRNEO_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-rescue.sh}
VERIFY_CONTROL=${HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-opkg-state.sh}
VERIFY_STATUS=${HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-opkg-status.sh}
VERIFY_LIVE=${HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-live-rescue-state.sh}
VALIDATOR=${HOMEROUTE_HRNEO_REINSTALL_VALIDATOR:-$SCRIPT_DIR/validate-hrneo-reinstall.sh}
ARTIFACT_TOOL=${HOMEROUTE_HRNEO_ARTIFACT_TOOL:-$SCRIPT_DIR/hrneo-artifact.sh}
DOCTOR=${HOMEROUTE_ROUTER_DOCTOR:-$SCRIPT_DIR/doctor-router.sh}

TEST_MODE=${HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL_TEST_MODE:-0}
TMPROOT=${HOMEROUTE_HRNEO_ROLLBACK_TMPROOT:-/opt/tmp}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL %s=%s\n' "$1" "$2"
}

show_plan() {
    field schema 1
    field mode plan
    field package hrneo
    field version 3.18.3-1
    field fresh_rescue true
    field same_version_reinstall true
    field forced_postinstall_failure true
    field automatic_rollback_required true
    field independent_post_rollback_verify true
    field package_change true
    field service_restart true
    field awg_package_change false
    field result PLAN_ONLY
    printf '%s\n' '[PASS] HRNeo live rollback rehearsal plan rendered; no state changed'
}

case "$MODE" in
    plan|--plan)
        show_plan
        exit 0
        ;;
    rehearse|--rehearse)
        ;;
    help|--help|-h)
        printf '%s\n' 'Usage: rehearse-hrneo-rollback.sh [plan|rehearse]'
        exit 0
        ;;
    *)
        fail "unknown mode: $MODE"
        ;;
esac

[ "$ACK" = YES ] ||
    fail 'set HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL_ACK=YES to allow the controlled live rollback rehearsal'

for tool in     "$PREPARE" "$CAPTURE_CONTROL" "$CAPTURE_STATUS"     "$VERIFY_RESCUE" "$VERIFY_CONTROL" "$VERIFY_STATUS" "$VERIFY_LIVE"     "$VALIDATOR" "$ARTIFACT_TOOL" "$DOCTOR"
do
    [ -f "$tool" ] || fail "required rehearsal tool missing: $tool"
done

command -v opkg >/dev/null 2>&1 || fail 'opkg unavailable'
command -v cmp >/dev/null 2>&1 || fail 'cmp unavailable'
command -v mktemp >/dev/null 2>&1 || fail 'mktemp unavailable'

if [ "$TEST_MODE" = 1 ]; then
    case "$TMPROOT" in
        /tmp/homeroute-hrneo-rollback-rehearsal-test.*) ;;
        *) fail 'unsafe test temporary root' ;;
    esac
else
    [ "$TMPROOT" = /opt/tmp ] || fail 'live temporary root override is forbidden'
fi

work=$(mktemp -d "$TMPROOT/homeroute-hrneo-rollback-rehearsal.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

capture_out=$(
    HOMEROUTE_HRNEO_RESCUE_ACK=YES     HOMEROUTE_HRNEO_ARTIFACT_TOOL="$ARTIFACT_TOOL"     HOMEROUTE_ROUTER_DOCTOR="$DOCTOR"         sh "$PREPARE" capture
)

rescue=$(
    printf '%s\n' "$capture_out" |
    sed -n 's/^HOMEROUTE_HRNEO_RESCUE rescue_dir=//p' |
    sed -n '1p'
)
[ -n "$rescue" ] || fail 'fresh rescue capture did not return rescue_dir'
[ -d "$rescue" ] || fail "fresh rescue directory missing: $rescue"
printf '%s\n' "$capture_out" | grep -F 'HOMEROUTE_HRNEO_RESCUE result=PASS' >/dev/null ||
    fail 'fresh package-file rescue capture did not pass'

control_out=$(
    HOMEROUTE_HRNEO_OPKG_RESCUE_ACK=YES     HOMEROUTE_HRNEO_RESCUE_VERIFIER="$VERIFY_RESCUE"     HOMEROUTE_HRNEO_ARTIFACT_TOOL="$ARTIFACT_TOOL"         sh "$CAPTURE_CONTROL" capture "$rescue"
)
printf '%s\n' "$control_out" | grep -F 'HOMEROUTE_HRNEO_OPKG_RESCUE result=PASS' >/dev/null ||
    fail 'fresh opkg/control rescue capture did not pass'

status_out=$(
    HOMEROUTE_HRNEO_STATUS_RESCUE_ACK=YES     HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$VERIFY_CONTROL"         sh "$CAPTURE_STATUS" capture "$rescue"
)
printf '%s\n' "$status_out" | grep -F 'HOMEROUTE_HRNEO_STATUS_RESCUE result=PASS' >/dev/null ||
    fail 'fresh global opkg status rescue capture did not pass'

HOMEROUTE_HRNEO_RESCUE_VERIFIER="$VERIFY_RESCUE" HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$VERIFY_CONTROL" HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER="$VERIFY_STATUS" HOMEROUTE_HRNEO_ARTIFACT_TOOL="$ARTIFACT_TOOL" HOMEROUTE_ROUTER_DOCTOR="$DOCTOR"     sh "$VERIFY_LIVE" "$rescue" > "$work/live-before.out"

grep -F 'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY result=PASS' "$work/live-before.out" >/dev/null ||
    fail 'fresh live-vs-rescue verification did not pass before rehearsal'

opkg list-installed | LC_ALL=C sort > "$work/packages.before"

start_epoch=$(date +%s)

set +e
HOMEROUTE_HRNEO_REINSTALL_ACK=YES HOMEROUTE_HRNEO_REINSTALL_FORCE_VERIFY_FAIL=1 HOMEROUTE_HRNEO_RESCUE_VERIFIER="$VERIFY_RESCUE" HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$VERIFY_CONTROL" HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER="$VERIFY_STATUS" HOMEROUTE_HRNEO_ARTIFACT_TOOL="$ARTIFACT_TOOL" HOMEROUTE_ROUTER_DOCTOR="$DOCTOR"     sh "$VALIDATOR" validate "$rescue" > "$work/validator.out" 2> "$work/validator.err"
validator_rc=$?
set -e

cp "$work/validator.out" "$rescue/rollback-rehearsal-validator.out"
cp "$work/validator.err" "$rescue/rollback-rehearsal-validator.err"
chmod 600 \
    "$rescue/rollback-rehearsal-validator.out" \
    "$rescue/rollback-rehearsal-validator.err"

show_validator_diagnostics() {
    printf '%s\n' '===== VALIDATOR STDOUT =====' >&2
    cat "$work/validator.out" >&2 || true
    printf '%s\n' '===== VALIDATOR STDERR =====' >&2
    cat "$work/validator.err" >&2 || true
    printf 'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL validator_rc=%s\n' "$validator_rc" >&2
}

[ "$validator_rc" -ne 0 ] || {
    show_validator_diagnostics
    fail 'forced post-install failure unexpectedly returned success'
}

if ! grep -F '[FAIL] forced post-install verification failure requested' "$work/validator.err" >/dev/null; then
    show_validator_diagnostics
    fail 'validator did not reach the intended forced-failure point'
fi

if ! grep -F '[PASS] automatic HRNeo rollback completed' "$work/validator.err" >/dev/null; then
    show_validator_diagnostics
    fail 'automatic rollback PASS marker missing'
fi

if grep -F '[FAIL] automatic HRNeo rollback failed' "$work/validator.err" >/dev/null; then
    show_validator_diagnostics
    fail 'automatic rollback reported failure'
fi

HOMEROUTE_HRNEO_RESCUE_VERIFIER="$VERIFY_RESCUE" HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$VERIFY_CONTROL" HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER="$VERIFY_STATUS" HOMEROUTE_HRNEO_ARTIFACT_TOOL="$ARTIFACT_TOOL" HOMEROUTE_ROUTER_DOCTOR="$DOCTOR"     sh "$VERIFY_LIVE" "$rescue" > "$work/live-after.out"

grep -F 'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY result=PASS' "$work/live-after.out" >/dev/null ||
    fail 'live state does not match fresh rescue after automatic rollback'

opkg list-installed | LC_ALL=C sort > "$work/packages.after"
cmp -s "$work/packages.before" "$work/packages.after" ||
    fail 'installed package set changed across rollback rehearsal'

end_epoch=$(date +%s)
window=$((end_epoch - start_epoch))

cat > "$rescue/rollback-rehearsal-evidence.txt" <<EOF
schema=1
package=hrneo
version=3.18.3-1
forced_postinstall_failure=true
automatic_rollback=PASS
live_state_matches_fresh_rescue=true
installed_package_set_unchanged=true
conffile_residue=none
doctor=PASS
validation_window_seconds=$window
EOF
chmod 600 "$rescue/rollback-rehearsal-evidence.txt"

field schema 1
field mode rehearse
field package hrneo
field version 3.18.3-1
field fresh_rescue PASS
field forced_postinstall_failure true
field automatic_rollback PASS
field live_state_matches_fresh_rescue true
field installed_package_set_unchanged true
field conffile_residue none
field doctor PASS
field validation_window_seconds "$window"
field rescue_dir "$rescue"
field live_rollback_validated true
field result PASS
printf '%s\n' '[PASS] controlled HRNeo live rollback failure-path rehearsal completed'
