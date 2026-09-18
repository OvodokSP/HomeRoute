#!/bin/sh
# HomeRoute VPS installer PRE-ALPHA.
# plan/help are read-only. Live apply intentionally remains blocked.
# sandbox-apply is repository-only transaction testing and cannot target live paths.

mode=${1:-plan}
AWG_CONTAINER=${AWG_CONTAINER:-amnezia-awg2}
ADGUARD_CONTAINER=${ADGUARD_CONTAINER:-adguard-home}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TX_LIB=${HOMEROUTE_TRANSACTION_LIB:-$SCRIPT_DIR/../scripts/installer/file-transaction.sh}

show_help() {
    cat <<'EOF'
Usage: install.sh [plan|apply|sandbox-apply|help]

  plan           Read-only PRE-ALPHA plan. Makes no Docker/firewall/DNS/VPN changes.
  apply          BLOCKED until live backup/verify/rollback and clean-device validation are complete.
  sandbox-apply  Developer-only transaction test inside HOMEROUTE_SANDBOX_ROOT.
  help           Show this help.
EOF
}

container_status() {
    name=$1
    if ! command -v docker >/dev/null 2>&1; then
        printf 'NOT VALIDATED / docker unavailable'
        return
    fi
    docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || printf 'absent'
}

plan_field() {
    key=$1
    value=$2
    printf 'HOMEROUTE_PLAN %s=%s\n' "$key" "$value"
}

sandbox_apply() {
    [ -f "$TX_LIB" ] || {
        printf '[FAIL] sandbox transaction library not found: %s\n' "$TX_LIB" >&2
        return 2
    }

    # shellcheck source=../scripts/installer/file-transaction.sh
    . "$TX_LIB"

    desired="${TMPDIR:-/tmp}/homeroute-vps-desired.$$"
    trap 'rm -f "$desired"' EXIT HUP INT TERM

    cat > "$desired" <<EOF
AWG_BASELINE=AmneziaWG_2.x
AWG_CONTAINER=$AWG_CONTAINER
ADGUARD_CONTAINER=$ADGUARD_CONTAINER
AWG_INTERFACE=awg0
DNS_REDIRECT=TCP_UDP_53
WG443_TEST=absent
EOF

    tx_begin
    tx_apply_file 'etc/homeroute/vps-state.env' "$desired"

    if [ "${HOMEROUTE_SANDBOX_FORCE_VERIFY_FAIL:-0}" = "1" ]; then
        printf '%s\n' '[VERIFY] forced failure requested by sandbox test'
        tx_rollback
        rm -f "$desired"
        trap - EXIT HUP INT TERM
        return 3
    fi

    if ! tx_verify_file 'etc/homeroute/vps-state.env' "$desired"; then
        printf '%s\n' '[FAIL] sandbox VPS verification failed'
        tx_rollback
        rm -f "$desired"
        trap - EXIT HUP INT TERM
        return 3
    fi

    printf '%s\n' '[VERIFY] VPS sandbox desired state matches'
    tx_commit
    printf '%s\n' 'HOMEROUTE_SANDBOX target=vps result=PASS live_apply=false'

    rm -f "$desired"
    trap - EXIT HUP INT TERM
    return 0
}

case "$mode" in
    help|--help|-h)
        show_help
        exit 0
        ;;
    apply|--apply)
        printf '%s\n' '[BLOCKED] HomeRoute VPS live apply-mode is not implemented or validated.'
        printf '%s\n' '[BLOCKED] Required first: exact image/network provisioning, live backup/verify/rollback validation, and clean-device validation.'
        printf '%s\n' '[INFO] No Docker, firewall, routing, VPN, DNS, file, service, or system changes were made.'
        exit 2
        ;;
    sandbox-apply|--sandbox-apply)
        printf '%s\n' '[INFO] Developer sandbox apply; live infrastructure is not permitted.'
        sandbox_apply
        exit $?
        ;;
    plan|--plan)
        ;;
    *)
        printf '[FAIL] unknown mode: %s\n' "$mode" >&2
        show_help >&2
        exit 2
        ;;
esac

printf '%s\n' '[INFO] HomeRoute VPS installer — PRE-ALPHA plan-only mode'
printf '%s\n' '[INFO] This command is read-only and does not implement live apply.'

printf '%s\n' '[PLAN] Reference invariants:'
printf '%s\n' '  AWG baseline: AmneziaWG 2.x'
printf '%s\n' '  VPS AWG interface: awg0'
printf '%s\n' '  DNS redirect: TCP/UDP 53 inside AWG2 container'
printf '%s\n' '  host WG443_TEST: absent'
printf '%s\n' '  duplicate router AllowedIPs: absent'

printf '%s\n' '[PLAN] Machine-readable contract:'
plan_field schema 1
plan_field target vps
plan_field mode plan
plan_field apply_available false
plan_field sandbox_apply_available true
plan_field awg_baseline 'AmneziaWG_2.x'
plan_field awg_interface awg0
plan_field resource_thresholds SUPPORTED_FLOOR_DEFINED
plan_field runtime_manifest REFERENCE_RUNTIME_CAPTURED
plan_field runtime_capture AVAILABLE_READ_ONLY
plan_field container_shape_capture REFERENCE_CAPTURED
plan_field provisioning_template DEFINED_LOCAL_PARAMETERS_REQUIRED
plan_field awg_upstream_recipe PINNED_SOURCE_BASE_IMAGE_FLOATING
plan_field awg_state_backup LIVE_BACKUP_VERIFIED
plan_field awg_restore SANDBOX_RESTORE_ROLLBACK_TESTED_LIVE_BLOCKED
plan_field exact_image_rescue LIVE_EXPORT_VERIFIED
plan_field adguard_state_backup LIVE_BACKUP_VERIFIED
plan_field adguard_restore SANDBOX_RESTORE_ROLLBACK_TESTED_LIVE_BLOCKED
plan_field rescue_set ARTIFACTS_CAPTURED_COMBINED_VERIFIER_READY
plan_field dns_network UPSTREAM_PINNED
plan_field adguard_dns_target DYNAMIC_RUNTIME_RESOLUTION
plan_field dns_redirect RENDERER_TESTED_LIVE_TIMER_IDENTITY_CAPTURED
plan_field dns_persistence TIMER_ACTIVE_ENABLED_HELPER_HASH_CAPTURED
plan_field dns_helper_analysis READY_FOR_LIVE_SANITIZED_FINGERPRINT
plan_field container_provisioning NOT_VALIDATED
plan_field backup_restore SANDBOX_TRANSACTION_TESTED
plan_field clean_device_validation NOT_VALIDATED

if command -v docker >/dev/null 2>&1; then
    printf '[PLAN] Docker PRESENT (%s)\n' "$(command -v docker)"
    docker --version 2>/dev/null | sed -n '1p' || true
else
    printf '%s\n' '[PLAN] Docker NOT VALIDATED / NOT FOUND'
fi
printf '[PLAN] AWG2 container %s status=%s\n' "$AWG_CONTAINER" "$(container_status "$AWG_CONTAINER")"
printf '[PLAN] AdGuard container %s status=%s\n' "$ADGUARD_CONTAINER" "$(container_status "$ADGUARD_CONTAINER")"

if command -v df >/dev/null 2>&1; then
    printf '%s\n' '[PLAN] root filesystem capacity:'
    df -h / 2>/dev/null || printf '%s\n' '[PLAN] root filesystem capacity NOT VALIDATED'
fi

printf '%s\n' '[PLAN] Future live transaction stages (not executed):'
printf '%s\n' '  1. preflight inventory gate'
printf '%s\n' '  2. exact Docker/image/network dependency resolution'
printf '%s\n' '  3. backup current state'
printf '%s\n' '  4. minimal idempotent apply'
printf '%s\n' '  5. doctor/functional verify'
printf '%s\n' '  6. transaction manifest'
printf '%s\n' '  7. rollback on failed verify'

printf '%s\n' '[BLOCKED] Live apply remains disabled until exact provisioning, live backup/rollback, and clean-device validation are complete.'
printf '%s\n' '[PASS] Plan completed; no system changes were made.'
exit 0
