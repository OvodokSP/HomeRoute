#!/bin/sh
# HomeRoute router installer PRE-ALPHA.
# plan/help are read-only. Live apply intentionally remains blocked.
# sandbox-apply is repository-only transaction testing and cannot target live paths.

mode=${1:-plan}
CORE_INSTALL_ROOTS=${CORE_INSTALL_ROOTS:-chur-amneziawg,hrneo}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TX_LIB=${HOMEROUTE_TRANSACTION_LIB:-$SCRIPT_DIR/../scripts/installer/file-transaction.sh}
FEED_TOOL=${HOMEROUTE_FEED_TOOL:-$SCRIPT_DIR/feed-config.sh}

show_help() {
    cat <<'EOF'
Usage: install.sh [plan|apply|sandbox-apply|help]

  plan           Read-only PRE-ALPHA plan. Makes no system changes.
  apply          BLOCKED until live backup/verify/rollback and clean-device validation are complete.
  sandbox-apply  Developer-only transaction test inside HOMEROUTE_SANDBOX_ROOT.
  help           Show this help.
EOF
}

presence() {
    name=$1
    if command -v "$name" >/dev/null 2>&1; then
        printf '[PLAN] component %-16s PRESENT (%s)\n' "$name" "$(command -v "$name")"
    else
        printf '[PLAN] component %-16s NOT VALIDATED / NOT FOUND\n' "$name"
    fi
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
    [ -f "$FEED_TOOL" ] || {
        printf '[FAIL] router feed renderer not found: %s\n' "$FEED_TOOL" >&2
        return 2
    }

    arch=${HOMEROUTE_ENTWARE_ARCH:-}
    [ -n "$arch" ] || {
        printf '%s\n' '[FAIL] HOMEROUTE_ENTWARE_ARCH is required for sandbox-apply' >&2
        return 2
    }

    # shellcheck source=../scripts/installer/file-transaction.sh
    . "$TX_LIB"

    desired="${TMPDIR:-/tmp}/homeroute-router-desired.$"
    desired_feed="${TMPDIR:-/tmp}/homeroute-chur-feed.$"
    trap 'rm -f "$desired" "$desired_feed"' EXIT HUP INT TERM

    if ! sh "$FEED_TOOL" render-chur "$arch" > "$desired_feed"; then
        printf '[FAIL] cannot render Chur feed for architecture: %s\n' "$arch" >&2
        rm -f "$desired" "$desired_feed"
        trap - EXIT HUP INT TERM
        return 2
    fi

    cat > "$desired" <<EOF
AWG_BASELINE=AmneziaWG_2.x
AWG_INTERFACE=opkgtun0
ROUTING_MARK=0x3001
ROUTING_TABLE=301
ORCHESTRATOR=HRNeo
CORE_INSTALL_ROOTS=$CORE_INSTALL_ROOTS
ENTWARE_ARCH=$arch
EOF

    tx_begin
    tx_apply_file 'etc/homeroute/router-state.env' "$desired"
    tx_apply_file 'opt/etc/opkg/chur.conf' "$desired_feed"

    if [ "${HOMEROUTE_SANDBOX_FORCE_VERIFY_FAIL:-0}" = "1" ]; then
        printf '%s\n' '[VERIFY] forced failure requested by sandbox test'
        tx_rollback
        rm -f "$desired" "$desired_feed"
        trap - EXIT HUP INT TERM
        return 3
    fi

    if ! tx_verify_file 'etc/homeroute/router-state.env' "$desired" ||
       ! tx_verify_file 'opt/etc/opkg/chur.conf' "$desired_feed"; then
        printf '%s\n' '[FAIL] sandbox router verification failed'
        tx_rollback
        rm -f "$desired" "$desired_feed"
        trap - EXIT HUP INT TERM
        return 3
    fi

    printf '%s\n' '[VERIFY] router sandbox desired state and Chur feed match'
    tx_commit
    printf 'HOMEROUTE_SANDBOX target=router result=PASS live_apply=false entware_arch=%s\n' "$arch"

    rm -f "$desired" "$desired_feed"
    trap - EXIT HUP INT TERM
    return 0
}

case "$mode" in
    help|--help|-h)
        show_help
        exit 0
        ;;
    apply|--apply)
        printf '%s\n' '[BLOCKED] HomeRoute router live apply-mode is not implemented or validated.'
        printf '%s\n' '[BLOCKED] Package roots and a pinned HRNeo artifact are validated; remaining live gates are package transaction/rollback, live-safe backup/verify/rollback, and clean-device validation.'
        printf '%s\n' '[INFO] No opkg, firewall, routing, VPN, file, service, or system changes were made.'
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

printf '%s\n' '[INFO] HomeRoute router installer — PRE-ALPHA plan-only mode'
printf '%s\n' '[INFO] This command is read-only and does not implement live apply.'

printf '%s\n' '[PLAN] Golden State invariants:'
printf '%s\n' '  AWG baseline: AmneziaWG 2.x'
printf '%s\n' '  router interface: opkgtun0'
printf '%s\n' '  routing mark: 0x3001'
printf '%s\n' '  routing table: 301'
printf '%s\n' '  policy orchestrator: HRNeo'
printf '[PLAN] validated core install roots: %s\n' "$CORE_INSTALL_ROOTS"

printf '%s\n' '[PLAN] Machine-readable contract:'
plan_field schema 1
plan_field target router
plan_field mode plan
plan_field apply_available false
plan_field sandbox_apply_available true
plan_field awg_baseline 'AmneziaWG_2.x'
plan_field awg_interface opkgtun0
plan_field routing_mark 0x3001
plan_field routing_table 301
plan_field orchestrator HRNeo
plan_field dependency_state VALIDATED_REFERENCE_MANIFEST
plan_field core_install_roots "$CORE_INSTALL_ROOTS"
plan_field resource_thresholds SUPPORTED_FLOOR_DEFINED
plan_field feed_provisioning CHUR_SANDBOX_TESTED_HRNEO_PINNED_ARTIFACT
plan_field hrneo_artifact PINNED_3.18.3-1_SHA256_VERIFIED
plan_field hrneo_rescue FULL_LIVE_RESCUE_SET_PASS
plan_field backup_restore FULL_HRNEO_PACKAGE_ROLLBACK_SET_PASS
plan_field hrneo_reinstall LIVE_PASS_CLEAN
plan_field hrneo_conffile_cleanup LIVE_PASS
plan_field hrneo_rollback LIVE_PASS
plan_field clean_device_validation NOT_VALIDATED

printf '%s\n' '[PLAN] Observed component availability:'
for component in opkg awg awg-quick amneziawg-go hrneo nfqws tg-ws-proxy; do
    presence "$component"
done

if command -v df >/dev/null 2>&1 && [ -d /opt ]; then
    printf '%s\n' '[PLAN] /opt filesystem is present; current capacity:'
    df -h /opt 2>/dev/null || printf '%s\n' '[PLAN] /opt capacity NOT VALIDATED'
else
    printf '%s\n' '[PLAN] /opt filesystem NOT VALIDATED / NOT FOUND'
fi

printf '%s\n' '[PLAN] Future live transaction stages (not executed):'
printf '%s\n' '  1. preflight inventory gate'
printf '%s\n' '  2. deterministic package/feed provisioning'
printf '%s\n' '  3. install validated package roots only'
printf '%s\n' '  4. backup current managed state'
printf '%s\n' '  5. minimal idempotent configuration apply'
printf '%s\n' '  6. doctor/functional verify'
printf '%s\n' '  7. transaction manifest / rollback on failed verify'

printf '%s\n' '[BLOCKED] Live apply remains disabled until a clean-device reproduction is recorded.'
printf '%s\n' '[PASS] Plan completed; no system changes were made.'
exit 0
