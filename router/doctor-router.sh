#!/bin/sh
# HomeRoute router doctor: read-only checks only.

AWG_INTERFACE=${AWG_INTERFACE:-opkgtun0}
LAN_INTERFACE=${LAN_INTERFACE:-br0}
ROUTING_MARK=${ROUTING_MARK:-0x3001}
ROUTING_TABLE=${ROUTING_TABLE:-301}

pass() { printf '[PASS] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '[INFO] %s\n' "$*"; }
has() { command -v "$1" >/dev/null 2>&1; }

failures=0
info "HomeRoute router doctor (read-only)"

if has ip && ip link show dev "$AWG_INTERFACE" >/dev/null 2>&1; then
    pass "AWG interface $AWG_INTERFACE exists"
    if ip -4 address show dev "$AWG_INTERFACE" | grep -q 'inet '; then
        pass "$AWG_INTERFACE has an IPv4 address"
    else
        fail "$AWG_INTERFACE has no IPv4 address"
    fi
else
    fail "AWG interface $AWG_INTERFACE is missing"
fi

if has awg; then
    pass "awg command is available"
    if awg show "$AWG_INTERFACE" >/dev/null 2>&1; then
        pass "AWG reports state for $AWG_INTERFACE"
        if awg show "$AWG_INTERFACE" latest-handshakes 2>/dev/null | awk '$2 > 0 { found=1 } END { exit !found }'; then
            pass "AWG has a recorded latest handshake"
        else
            fail "AWG has no recorded latest handshake"
        fi
    else
        fail "AWG state for $AWG_INTERFACE is unavailable"
    fi
else
    fail "awg command is missing"
fi

if ps 2>/dev/null | grep -i '[h]rneo' >/dev/null; then
    pass "HRNeo process is running"
else
    fail "HRNeo process was not found"
fi

if grep -R -s -q 'PolicyOrder[[:space:]]*=[[:space:]]*opkgtun0' /opt/etc 2>/dev/null; then
    pass "PolicyOrder=opkgtun0 is present"
else
    fail "PolicyOrder=opkgtun0 was not found under /opt/etc"
fi

if has ipset && ipset list -n 2>/dev/null | grep -Fxq "$AWG_INTERFACE"; then
    pass "ipset $AWG_INTERFACE exists"
else
    fail "ipset $AWG_INTERFACE is missing"
fi

if has iptables && iptables-save -t mangle 2>/dev/null | grep -qi -- "$ROUTING_MARK"; then
    pass "routing mark $ROUTING_MARK is present"
else
    fail "routing mark $ROUTING_MARK was not found"
fi

if has ip && ip rule show 2>/dev/null | grep -Eq "(lookup|table)[[:space:]]+$ROUTING_TABLE([[:space:]]|$)"; then
    pass "ip rule selects table $ROUTING_TABLE"
else
    fail "ip rule for table $ROUTING_TABLE was not found"
fi

if has ip && ip route show table "$ROUTING_TABLE" 2>/dev/null | grep -Eq "^default([[:space:]].*)? dev $AWG_INTERFACE([[:space:]]|$)"; then
    pass "table $ROUTING_TABLE has default dev $AWG_INTERFACE"
else
    fail "default dev $AWG_INTERFACE is missing from table $ROUTING_TABLE"
fi

if has iptables && iptables-save -t filter 2>/dev/null | grep '^-A FORWARD ' | grep -q -- "-i $LAN_INTERFACE .* -o $AWG_INTERFACE\|-o $AWG_INTERFACE .* -i $LAN_INTERFACE"; then
    pass "FORWARD $LAN_INTERFACE to $AWG_INTERFACE is present"
else
    fail "FORWARD $LAN_INTERFACE to $AWG_INTERFACE was not found"
fi

if has iptables && iptables-save -t nat 2>/dev/null | grep '^-A POSTROUTING ' | grep -q -- "-o $AWG_INTERFACE .*MASQUERADE"; then
    pass "MASQUERADE through $AWG_INTERFACE is present"
else
    fail "MASQUERADE through $AWG_INTERFACE was not found"
fi

if find /opt/etc/init.d /opt/etc/ndm -type f 2>/dev/null | grep -q .; then
    pass "persistence hook locations contain files"
else
    warn "persistence hooks were not found in known locations"
fi

ps 2>/dev/null | grep -q '[n]fqws' && pass "nfqws optional component is running" || warn "nfqws optional component is not running"
ps 2>/dev/null | grep -q '[t]g-ws-proxy' && pass "tg-ws-proxy reserve component is running" || warn "tg-ws-proxy reserve component is not running"

if has ip && ip link show dev nwg0 >/dev/null 2>&1; then fail "legacy interface nwg0 exists"; else pass "legacy interface nwg0 is absent"; fi
if has ip && { ip rule show 2>/dev/null; ip route show table 4098 2>/dev/null; } | grep -Eq '(lookup|table)[[:space:]]+4098|^default'; then fail "legacy routing table 4098 is in use"; else pass "legacy routing table 4098 is absent"; fi
if has iptables && iptables-save 2>/dev/null | grep -qi '0xffffaab'; then fail "legacy mark 0xffffaab exists"; else pass "legacy mark 0xffffaab is absent"; fi
if has ipset && ipset list -n 2>/dev/null | grep -Ei '^HydraRoute'; then fail "legacy HydraRoute ipset exists"; else pass "legacy HydraRoute ipsets are absent"; fi

if [ "$failures" -gt 0 ]; then
    info "$failures required check(s) failed"
    exit 1
fi
pass "all required router checks passed"
