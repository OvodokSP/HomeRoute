#!/bin/sh
# HomeRoute VPS doctor: read-only checks only.

AWG_CONTAINER=${AWG_CONTAINER:-CHANGE_ME_AWG2_CONTAINER}
ADGUARD_CONTAINER=${ADGUARD_CONTAINER:-CHANGE_ME_ADGUARD_CONTAINER}
VPS_AWG_INTERFACE=${VPS_AWG_INTERFACE:-awg0}
ROUTER_PEER_ALLOWED_IP=${ROUTER_PEER_ALLOWED_IP:-CHANGE_ME}
LEGACY_WG_CONTAINER=${LEGACY_WG_CONTAINER:-}
LEGACY_PEER_ALLOWED_IP=${LEGACY_PEER_ALLOWED_IP:-}

pass() { printf '[PASS] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '[INFO] %s\n' "$*"; }
has() { command -v "$1" >/dev/null 2>&1; }
container_running() { docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null | grep -Fxq true; }
awg_exec() {
    if [ "$AWG_CONTAINER" != CHANGE_ME_AWG2_CONTAINER ] && container_running "$AWG_CONTAINER"; then
        docker exec "$AWG_CONTAINER" awg "$@"
    elif has awg; then
        awg "$@"
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

if [ "$AWG_CONTAINER" != CHANGE_ME_AWG2_CONTAINER ] && container_running "$AWG_CONTAINER" && docker exec "$AWG_CONTAINER" ip link show dev "$VPS_AWG_INTERFACE" >/dev/null 2>&1; then
    pass "AWG interface $VPS_AWG_INTERFACE exists in $AWG_CONTAINER"
elif has ip && ip link show dev "$VPS_AWG_INTERFACE" >/dev/null 2>&1; then
    warn "using host AWG interface fallback for a non-reference architecture"
    pass "AWG interface $VPS_AWG_INTERFACE exists on host"
else
    fail "AWG interface $VPS_AWG_INTERFACE is missing"
fi

if [ "$ROUTER_PEER_ALLOWED_IP" = CHANGE_ME ]; then
    warn "ROUTER_PEER_ALLOWED_IP is not configured; router peer checks skipped"
elif awg_exec show all allowed-ips >/dev/null 2>&1; then
    peer_count=$(awg_exec show all allowed-ips 2>/dev/null | awk -v wanted="$ROUTER_PEER_ALLOWED_IP" '$NF == wanted { count++ } END { print count+0 }')
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

nat_source_available=0
if [ "$AWG_CONTAINER" != CHANGE_ME_AWG2_CONTAINER ] && container_running "$AWG_CONTAINER"; then
    if nat_rules=$(docker exec "$AWG_CONTAINER" iptables-save -t nat 2>/dev/null); then
        nat_source_available=1
        info "checking DNS redirect in AWG2 container $AWG_CONTAINER"
    else
        fail "cannot read NAT rules from AWG2 container $AWG_CONTAINER"
    fi
elif has iptables; then
    warn "using host iptables fallback for a non-reference architecture"
    if nat_rules=$(iptables-save -t nat 2>/dev/null); then
        nat_source_available=1
    else
        fail "cannot read host NAT rules"
    fi
else
    nat_rules=
    fail "NAT rule source is unavailable"
fi
if [ "$nat_source_available" -eq 1 ]; then
    printf '%s\n' "$nat_rules" | grep -E -- '(-p tcp|--protocol tcp).*--dport 53.*(REDIRECT|DNAT)' >/dev/null && pass "DNS redirect TCP 53 is present" || fail "DNS redirect TCP 53 was not found"
    printf '%s\n' "$nat_rules" | grep -E -- '(-p udp|--protocol udp).*--dport 53.*(REDIRECT|DNAT)' >/dev/null && pass "DNS redirect UDP 53 is present" || fail "DNS redirect UDP 53 was not found"
    printf '%s\n' "$nat_rules" | grep -q 'WG443_TEST' && fail "legacy WG443_TEST rule exists" || pass "legacy WG443_TEST rule is absent"
fi

if [ -z "$LEGACY_WG_CONTAINER" ]; then
    warn "LEGACY_WG_CONTAINER is not configured; legacy Keenetic peer check skipped"
elif ! container_running "$LEGACY_WG_CONTAINER"; then
    fail "configured legacy WireGuard container $LEGACY_WG_CONTAINER is not running"
elif [ -z "$LEGACY_PEER_ALLOWED_IP" ]; then
    warn "LEGACY_PEER_ALLOWED_IP is not configured; legacy Keenetic peer cannot be identified"
else
    if legacy_allowed_ips=$(docker exec "$LEGACY_WG_CONTAINER" wg show all allowed-ips 2>/dev/null); then
        if printf '%s\n' "$legacy_allowed_ips" | awk -v wanted="$LEGACY_PEER_ALLOWED_IP" '$NF == wanted { found=1 } END { exit !found }'; then
            fail "legacy Keenetic WireGuard peer exists in $LEGACY_WG_CONTAINER"
        else
            pass "legacy Keenetic WireGuard peer is absent from $LEGACY_WG_CONTAINER"
        fi
    else
        fail "cannot inspect peers in legacy WireGuard container $LEGACY_WG_CONTAINER"
    fi
fi

if [ "$failures" -gt 0 ]; then info "$failures required check(s) failed"; exit 1; fi
pass "all configured VPS checks passed"
