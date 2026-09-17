#!/bin/sh
# HomeRoute VPS doctor: read-only checks only.

AWG_CONTAINER=${AWG_CONTAINER:-CHANGE_ME_AWG2_CONTAINER}
ADGUARD_CONTAINER=${ADGUARD_CONTAINER:-CHANGE_ME_ADGUARD_CONTAINER}
AWG_INTERFACE=${AWG_INTERFACE:-awg0}
ROUTER_PEER_ALLOWED_IP=${ROUTER_PEER_ALLOWED_IP:-CHANGE_ME}
LEGACY_PEER_ALLOWED_IP=${LEGACY_PEER_ALLOWED_IP:-}

pass() { printf '[PASS] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '[INFO] %s\n' "$*"; }
has() { command -v "$1" >/dev/null 2>&1; }
container_running() { docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null | grep -Fxq true; }
awg_exec() {
    if has awg; then
        awg "$@"
    elif [ "$AWG_CONTAINER" != CHANGE_ME_AWG2_CONTAINER ] && container_running "$AWG_CONTAINER"; then
        docker exec "$AWG_CONTAINER" awg "$@"
    else
        return 127
    fi
}

failures=0
info "HomeRoute VPS doctor (read-only)"

if has docker && docker info >/dev/null 2>&1; then pass "Docker is working"; else fail "Docker is unavailable or not working"; fi

if [ "$AWG_CONTAINER" = CHANGE_ME_AWG2_CONTAINER ]; then
    warn "AWG_CONTAINER is not configured"
elif container_running "$AWG_CONTAINER"; then
    pass "AWG2 container $AWG_CONTAINER is running"
else
    fail "AWG2 container $AWG_CONTAINER is not running"
fi

if has ip && ip link show dev "$AWG_INTERFACE" >/dev/null 2>&1; then
    pass "AWG interface $AWG_INTERFACE exists"
elif [ "$AWG_CONTAINER" != CHANGE_ME_AWG2_CONTAINER ] && container_running "$AWG_CONTAINER" && docker exec "$AWG_CONTAINER" ip link show dev "$AWG_INTERFACE" >/dev/null 2>&1; then
    pass "AWG interface $AWG_INTERFACE exists in $AWG_CONTAINER"
else
    fail "AWG interface $AWG_INTERFACE is missing"
fi

if [ "$ROUTER_PEER_ALLOWED_IP" = CHANGE_ME ]; then
    warn "ROUTER_PEER_ALLOWED_IP is not configured; router peer checks skipped"
elif awg_exec show all allowed-ips >/dev/null 2>&1; then
    peer_count=$(awg_exec show all allowed-ips 2>/dev/null | awk -v wanted="$ROUTER_PEER_ALLOWED_IP" '$0 ~ wanted { count++ } END { print count+0 }')
    if [ "$peer_count" -eq 1 ]; then
        pass "expected router peer exists with unique AllowedIPs"
    elif [ "$peer_count" -eq 0 ]; then
        fail "expected router peer AllowedIPs were not found"
    else
        fail "duplicate router peer AllowedIPs found ($peer_count entries)"
    fi
else
    fail "awg state is unavailable for peer checks"
fi

if [ "$ADGUARD_CONTAINER" != CHANGE_ME_ADGUARD_CONTAINER ] && container_running "$ADGUARD_CONTAINER"; then
    pass "AdGuard Home container $ADGUARD_CONTAINER is running"
elif pgrep -f '[A]dGuardHome' >/dev/null 2>&1; then
    pass "AdGuard Home process is running"
else
    fail "AdGuard Home is not running (configure ADGUARD_CONTAINER if containerized)"
fi

if has iptables; then
    nat_rules=$(iptables-save -t nat 2>/dev/null || true)
    printf '%s\n' "$nat_rules" | grep -E -- '(-p tcp|--protocol tcp).*--dport 53.*(REDIRECT|DNAT)' >/dev/null && pass "DNS redirect TCP 53 is present" || fail "DNS redirect TCP 53 was not found"
    printf '%s\n' "$nat_rules" | grep -E -- '(-p udp|--protocol udp).*--dport 53.*(REDIRECT|DNAT)' >/dev/null && pass "DNS redirect UDP 53 is present" || fail "DNS redirect UDP 53 was not found"
    printf '%s\n' "$nat_rules" | grep -q 'WG443_TEST' && fail "legacy WG443_TEST rule exists" || pass "legacy WG443_TEST rule is absent"
else
    fail "iptables is unavailable for DNS and legacy checks"
fi

if [ -z "$LEGACY_PEER_ALLOWED_IP" ]; then
    warn "LEGACY_PEER_ALLOWED_IP is not configured; legacy Keenetic peer check skipped"
elif has wg && wg show all allowed-ips 2>/dev/null | grep -Fq "$LEGACY_PEER_ALLOWED_IP"; then
    fail "legacy Keenetic WireGuard peer exists"
else
    pass "legacy Keenetic WireGuard peer is absent"
fi

if [ "$failures" -gt 0 ]; then info "$failures required check(s) failed"; exit 1; fi
pass "all configured VPS checks passed"
