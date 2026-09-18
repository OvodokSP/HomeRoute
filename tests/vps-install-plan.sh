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
grep -F '[BLOCKED] Live apply remains disabled' "$OUT" >/dev/null || fail 'live apply gate missing'

for expected in \
    'HOMEROUTE_PLAN schema=1' \
    'HOMEROUTE_PLAN target=vps' \
    'HOMEROUTE_PLAN mode=plan' \
    'HOMEROUTE_PLAN apply_available=false' \
    'HOMEROUTE_PLAN sandbox_apply_available=true' \
    'HOMEROUTE_PLAN awg_baseline=AmneziaWG_2.x' \
    'HOMEROUTE_PLAN awg_interface=awg0' \
    'HOMEROUTE_PLAN resource_thresholds=SUPPORTED_FLOOR_DEFINED' \
    'HOMEROUTE_PLAN runtime_manifest=REFERENCE_RUNTIME_CAPTURED' \
    'HOMEROUTE_PLAN runtime_capture=AVAILABLE_READ_ONLY' \
    'HOMEROUTE_PLAN container_shape_capture=REFERENCE_CAPTURED' \
    'HOMEROUTE_PLAN provisioning_template=DEFINED_LOCAL_PARAMETERS_REQUIRED' \
    'HOMEROUTE_PLAN awg_upstream_recipe=PINNED_SOURCE_BASE_IMAGE_FLOATING' \
    'HOMEROUTE_PLAN awg_state_backup=LIVE_BACKUP_VERIFIED' \
    'HOMEROUTE_PLAN awg_restore=SANDBOX_RESTORE_ROLLBACK_TESTED_LIVE_BLOCKED' \
    'HOMEROUTE_PLAN exact_image_rescue=LIVE_EXPORT_VERIFIED' \
    'HOMEROUTE_PLAN adguard_state_backup=LIVE_BACKUP_VERIFIED' \
    'HOMEROUTE_PLAN adguard_restore=SANDBOX_RESTORE_ROLLBACK_TESTED_LIVE_BLOCKED' \
    'HOMEROUTE_PLAN rescue_set=ARTIFACTS_CAPTURED_COMBINED_VERIFIER_READY' \
    'HOMEROUTE_PLAN dns_network=UPSTREAM_PINNED' \
    'HOMEROUTE_PLAN adguard_dns_target=DYNAMIC_RUNTIME_RESOLUTION' \
    'HOMEROUTE_PLAN dns_redirect=RENDERER_TESTED_LIVE_TIMER_MONOTONIC_CAPTURED' \
    'HOMEROUTE_PLAN dns_persistence=DESIRED_STATE_PLAN_TESTED_LIVE_TIMER_VERIFIED' \
    'HOMEROUTE_PLAN dns_helper_analysis=SCHEMA2_LIVE_PARTIAL_TARGET_SOURCE_NOT_VALIDATED' \
    'HOMEROUTE_PLAN container_provisioning=NOT_VALIDATED' \
    'HOMEROUTE_PLAN restore_readiness=READ_ONLY_GATE_AVAILABLE' \
    'HOMEROUTE_PLAN backup_restore=SANDBOX_TRANSACTION_TESTED' \
    'HOMEROUTE_PLAN clean_device_validation=NOT_VALIDATED'
do
    grep -Fx "$expected" "$OUT" >/dev/null || fail "missing VPS plan contract field: $expected"
done

if sh "$INSTALLER" apply >"$OUT" 2>"$ERR"; then
    fail 'apply mode unexpectedly succeeded'
fi
grep -F '[BLOCKED] HomeRoute VPS live apply-mode is not implemented or validated.' "$OUT" >/dev/null || fail 'apply block marker missing'

if sh "$INSTALLER" definitely-not-a-mode >"$OUT" 2>"$ERR"; then
    fail 'unknown mode unexpectedly succeeded'
fi
grep -F '[FAIL] unknown mode:' "$ERR" >/dev/null || fail 'unknown-mode failure marker missing'

printf '%s\n' '[PASS] VPS installer plan/live-gate contract'
