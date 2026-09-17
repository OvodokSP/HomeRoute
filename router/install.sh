#!/bin/sh
# HomeRoute router installer PRE-ALPHA.
# Only plan/help are implemented. Apply intentionally remains blocked.

mode=${1:-plan}

show_help() {
    cat <<'EOF'
Usage: install.sh [plan|apply|help]

  plan   Read-only PRE-ALPHA plan. Makes no system changes.
  apply  BLOCKED until inventory, apply implementation and clean-device validation are complete.
  help   Show this help.
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

case "$mode" in
    help|--help|-h)
        show_help
        exit 0
        ;;
    apply|--apply)
        printf '%s\n' '[BLOCKED] HomeRoute router apply-mode is not implemented or validated.'
        printf '%s\n' '[BLOCKED] Required first: reference inventory, exact dependency mapping, backup/verify/rollback implementation, and clean-device validation.'
        printf '%s\n' '[INFO] No opkg, firewall, routing, VPN, file, service, or system changes were made.'
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

printf '%s\n' '[INFO] HomeRoute router installer — PRE-ALPHA plan-only mode'
printf '%s\n' '[INFO] This command is read-only and does not implement apply.'

printf '%s\n' '[PLAN] Golden State invariants:'
printf '%s\n' '  AWG baseline: AmneziaWG 2.x'
printf '%s\n' '  router interface: opkgtun0'
printf '%s\n' '  routing mark: 0x3001'
printf '%s\n' '  routing table: 301'
printf '%s\n' '  policy orchestrator: HRNeo'

printf '%s\n' '[PLAN] Machine-readable contract:'
plan_field schema 1
plan_field target router
plan_field mode plan
plan_field apply_available false
plan_field awg_baseline 'AmneziaWG_2.x'
plan_field awg_interface opkgtun0
plan_field routing_mark 0x3001
plan_field routing_table 301
plan_field orchestrator HRNeo
plan_field dependency_state NOT_VALIDATED
plan_field resource_thresholds NOT_VALIDATED
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

printf '%s\n' '[PLAN] Future transaction stages (not executed):'
printf '%s\n' '  1. preflight inventory gate'
printf '%s\n' '  2. exact dependency resolution'
printf '%s\n' '  3. backup current state'
printf '%s\n' '  4. minimal idempotent apply'
printf '%s\n' '  5. doctor/functional verify'
printf '%s\n' '  6. transaction manifest'
printf '%s\n' '  7. rollback on failed verify'

printf '%s\n' '[BLOCKED] Exact package names, resource thresholds and clean-device target paths remain NOT VALIDATED until reference inventory is captured.'
printf '%s\n' '[PASS] Plan completed; no system changes were made.'
exit 0
