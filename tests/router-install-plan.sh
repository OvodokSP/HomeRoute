#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALLER="$ROOT/router/install.sh"
TMPDIR_BASE=${TMPDIR:-/tmp}
OUT="$TMPDIR_BASE/homeroute-router-plan-test.$$"
ERR="$TMPDIR_BASE/homeroute-router-plan-test-err.$$"
trap 'rm -f "$OUT" "$ERR"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

sh "$INSTALLER" plan >"$OUT" 2>"$ERR" || fail 'plan mode returned non-zero'
grep -F '[PASS] Plan completed; no system changes were made.' "$OUT" >/dev/null || fail 'plan success marker missing'
grep -F '[BLOCKED] Live apply remains disabled' "$OUT" >/dev/null || fail 'live apply gate missing'

for expected in \
    'HOMEROUTE_PLAN schema=1' \
    'HOMEROUTE_PLAN target=router' \
    'HOMEROUTE_PLAN mode=plan' \
    'HOMEROUTE_PLAN apply_available=false' \
    'HOMEROUTE_PLAN sandbox_apply_available=true' \
    'HOMEROUTE_PLAN awg_baseline=AmneziaWG_2.x' \
    'HOMEROUTE_PLAN awg_interface=opkgtun0' \
    'HOMEROUTE_PLAN routing_mark=0x3001' \
    'HOMEROUTE_PLAN routing_table=301' \
    'HOMEROUTE_PLAN orchestrator=HRNeo' \
    'HOMEROUTE_PLAN dependency_state=VALIDATED_REFERENCE_MANIFEST' \
    'HOMEROUTE_PLAN core_install_roots=chur-amneziawg,hrneo' \
    'HOMEROUTE_PLAN resource_thresholds=SUPPORTED_FLOOR_DEFINED' \
    'HOMEROUTE_PLAN feed_provisioning=CHUR_SANDBOX_TESTED_HRNEO_PINNED_ARTIFACT' \
    'HOMEROUTE_PLAN hrneo_artifact=PINNED_3.18.3-1_SHA256_VERIFIED' \
    'HOMEROUTE_PLAN hrneo_rescue=FULL_LIVE_RESCUE_SET_PASS' \
    'HOMEROUTE_PLAN backup_restore=FULL_HRNEO_PACKAGE_ROLLBACK_SET_PASS' \
    'HOMEROUTE_PLAN hrneo_reinstall=CONTROLLED_SAME_VERSION_VALIDATOR_READY_LIVE_PENDING' \
    'HOMEROUTE_PLAN clean_device_validation=NOT_VALIDATED'
do
    grep -Fx "$expected" "$OUT" >/dev/null || fail "missing plan contract field: $expected"
done

if sh "$INSTALLER" apply >"$OUT" 2>"$ERR"; then
    fail 'apply mode unexpectedly succeeded'
fi
grep -F '[BLOCKED] HomeRoute router live apply-mode is not implemented or validated.' "$OUT" >/dev/null || fail 'apply block marker missing'

if sh "$INSTALLER" definitely-not-a-mode >"$OUT" 2>"$ERR"; then
    fail 'unknown mode unexpectedly succeeded'
fi
grep -F '[FAIL] unknown mode:' "$ERR" >/dev/null || fail 'unknown-mode failure marker missing'

printf '%s\n' '[PASS] router installer plan/live-gate contract'
