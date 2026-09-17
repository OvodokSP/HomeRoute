#!/bin/sh
# HomeRoute router doctor: read-only checks only.

ROUTER_AWG_INTERFACE=${ROUTER_AWG_INTERFACE:-opkgtun0}
LAN_INTERFACE=${LAN_INTERFACE:-br0}
ROUTING_MARK=${ROUTING_MARK:-0x3001}
ROUTING_TABLE=${ROUTING_TABLE:-301}

passes=0
warnings=0
failures=0

pass() { passes=$((passes + 1)); printf '[PASS] %s\n' "$*"; }
warn() { warnings=$((warnings + 1)); printf '[WARN] %s\n' "$*"; }
fail() { failures=$((failures + 1)); printf '[FAIL] %s\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
has() { command -v "$1" >/dev/null 2>&1; }
doctor_summary() {
    result=PASS
    [ "$failures" -gt 0 ] && result=FAIL
    printf 'HOMEROUTE_DOCTOR schema=1 type=router pass=%s warn=%s fail=%s result=%s\n' \
        "$passes" "$warnings" "$failures" "$result"
}
forward_rule_present() {
    awk -v lan="$LAN_INTERFACE" -v awg="$ROUTER_AWG_INTERFACE" '
        $1 == "-A" && $2 == "FORWARD" {
            input_ok=0
            output_ok=0
            for (i=3; i<=NF; i++) {
                if ($i == "-i" && (i+1) <= NF && $(i+1) == lan) input_ok=1
                if ($i == "-o" && (i+1) <= NF && $(i+1) == awg) output_ok=1
            }
            if (input_ok && output_ok) found=1
        }
        END { exit(found ? 0 : 1) }
    '
}

info "HomeRoute router doctor (read-only)"

if has ip && ip link show dev "$ROUTER_AWG_INTERFACE" >/dev/null 2>&1; then
    pass "AWG interface $ROUTER_AWG_INTERFACE exists"
    if ip -4 address show dev "$ROUTER_AWG_INTERFACE" | grep -q 'inet '; then
        pass "$ROUTER_AWG_INTERFACE has an IPv4 address"
    else
        fail "$ROUTER_AWG_INTERFACE has no IPv4 address"
    fi
else
    fail "AWG interface $ROUTER_AWG_INTERFACE is missing"
fi

if has awg; then
    pass "awg command is available"
    if awg show "$ROUTER_AWG_INTERFACE" >/dev/null 2>&1; then
        pass "AWG reports state for $ROUTER_AWG_INTERFACE"
        if awg show "$ROUTER_AWG_INTERFACE" latest-handshakes 2>/dev/null | awk '$2 > 0 { found=1 } END { exit !found }'; then
            pass "AWG has a recorded latest handshake"
        else
            fail "AWG has no recorded latest handshake"
        fi
    else
        fail "AWG state for $ROUTER_AWG_INTERFACE is unavailable"
    fi
else
    fail "awg command is missing"
fi

if ps 2>/dev/null | grep -i '[h]rneo' >/dev/null; then
    pass "HRNeo process is running"
else
    fail "HRNeo process was not found"
fi

if grep -q '^[[:space:]]*PolicyOrder=opkgtun0[[:space:]]*$' /opt/etc/HydraRoute/hrneo.conf 2>/dev/null; then
    pass "PolicyOrder=opkgtun0 is present"
else
    fail "PolicyOrder=opkgtun0 was not found in /opt/etc/HydraRoute/hrneo.conf"
fi

if has ipset && ipset list -n 2>/dev/null | grep -Fxq "$ROUTER_AWG_INTERFACE"; then
    pass "ipset $ROUTER_AWG_INTERFACE exists"
else
    fail "ipset $ROUTER_AWG_INTERFACE is missing"
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

if has ip && ip route show table "$ROUTING_TABLE" 2>/dev/null | grep -Eq "^default([[:space:]].*)? dev $ROUTER_AWG_INTERFACE([[:space:]]|$)"; then
    pass "table $ROUTING_TABLE has default dev $ROUTER_AWG_INTERFACE"
else
    fail "default dev $ROUTER_AWG_INTERFACE is missing from table $ROUTING_TABLE"
fi

if has iptables && iptables-save -t filter 2>/dev/null | forward_rule_present; then
    pass "FORWARD $LAN_INTERFACE to $ROUTER_AWG_INTERFACE is present"
else
    fail "FORWARD $LAN_INTERFACE to $ROUTER_AWG_INTERFACE was not found"
fi

if has iptables && iptables-save -t nat 2>/dev/null | grep '^-A POSTROUTING ' | grep -q -- "-o $ROUTER_AWG_INTERFACE .*MASQUERADE"; then
    pass "MASQUERADE through $ROUTER_AWG_INTERFACE is present"
else
    fail "MASQUERADE through $ROUTER_AWG_INTERFACE was not found"
fi

for hook in \
    /opt/etc/init.d/S98telegram-awg \
    /opt/etc/init.d/S99hrneo \
    /opt/etc/ndm/netfilter.d/014-telegram-awg.sh \
    /opt/etc/ndm/netfilter.d/015-hrneo.sh \
    /opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh \
    /opt/etc/ndm/ifstatechanged.d/015-hrneo.sh
do
    if [ -f "$hook" ]; then pass "required persistence hook exists: $hook"; else fail "required persistence hook is missing: $hook"; fi
done

ps 2>/dev/null | grep -q '[n]fqws' && pass "nfqws optional component is running" || warn "nfqws optional component is not running"
ps 2>/dev/null | grep -q '[t]g-ws-proxy' && pass "tg-ws-proxy reserve component is running" || warn "tg-ws-proxy reserve component is not running"

if has ip && ip link show dev nwg0 >/dev/null 2>&1; then fail "legacy interface nwg0 exists"; else pass "legacy interface nwg0 is absent"; fi
if has ip && { ip rule show 2>/dev/null | grep -Eq '(lookup|table)[[:space:]]+4098([[:space:]]|$)' || ip route show table 4098 2>/dev/null | grep -q .; }; then fail "legacy routing table 4098 is in use"; else pass "legacy routing table 4098 is absent"; fi
if { has ip && ip rule show 2>/dev/null | grep -qi '0xffffaab'; } || { has iptables && iptables-save 2>/dev/null | grep -qi '0xffffaab'; }; then fail "legacy mark 0xffffaab exists"; else pass "legacy mark 0xffffaab is absent"; fi
if has ipset && ipset list -n 2>/dev/null | grep -Ei '^HydraRoute'; then fail "legacy HydraRoute ipset exists"; else pass "legacy HydraRoute ipsets are absent"; fi

if [ "$failures" -gt 0 ]; then
    info "$failures required check(s) failed"
    doctor_summary
    exit 1
fi
pass "all required router checks passed"
doctor_summary
