#!/bin/sh
# HomeRoute VPS installer PRE-ALPHA.
# Only plan/help are implemented. Apply intentionally remains blocked.

mode=${1:-plan}
AWG_CONTAINER=${AWG_CONTAINER:-amnezia-awg2}
ADGUARD_CONTAINER=${ADGUARD_CONTAINER:-adguard-home}

show_help() {
    cat <<'EOF'
Usage: install.sh [plan|apply|help]

  plan   Read-only PRE-ALPHA plan. Makes no Docker/firewall/DNS/VPN changes.
  apply  BLOCKED until inventory, apply implementation and clean-device validation are complete.
  help   Show this help.
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

case "$mode" in
    help|--help|-h)
        show_help
        exit 0
        ;;
    apply|--apply)
        printf '%s\n' '[BLOCKED] HomeRoute VPS apply-mode is not implemented or validated.'
        printf '%s\n' '[BLOCKED] Required first: reference inventory, exact Docker/image/network requirements, backup/verify/rollback implementation, and clean-device validation.'
        printf '%s\n' '[INFO] No Docker, firewall, routing, VPN, DNS, file, service, or system changes were made.'
        exit 2
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
printf '%s\n' '[INFO] This command is read-only and does not implement apply.'

printf '%s\n' '[PLAN] Reference invariants:'
printf '%s\n' '  AWG baseline: AmneziaWG 2.x'
printf '%s\n' '  VPS AWG interface: awg0'
printf '%s\n' '  DNS redirect: TCP/UDP 53 inside AWG2 container'
printf '%s\n' '  host WG443_TEST: absent'
printf '%s\n' '  duplicate router AllowedIPs: absent'

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

printf '%s\n' '[PLAN] Future transaction stages (not executed):'
printf '%s\n' '  1. preflight inventory gate'
printf '%s\n' '  2. exact Docker/image/network dependency resolution'
printf '%s\n' '  3. backup current state'
printf '%s\n' '  4. minimal idempotent apply'
printf '%s\n' '  5. doctor/functional verify'
printf '%s\n' '  6. transaction manifest'
printf '%s\n' '  7. rollback on failed verify'

printf '%s\n' '[BLOCKED] Exact resource thresholds, image/provisioning requirements and clean-VPS apply behavior remain NOT VALIDATED until reference inventory is captured.'
printf '%s\n' '[PASS] Plan completed; no system changes were made.'
exit 0
