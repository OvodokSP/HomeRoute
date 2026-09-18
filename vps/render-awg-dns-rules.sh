#!/bin/sh
# Render desired AWG-container DNS DNAT rules.
# Developer/helper tool; it does not execute iptables.

set -eu

ADGUARD_IP=${HOMEROUTE_ADGUARD_IP:-}
AWG_SUBNET=${HOMEROUTE_AWG_CLIENT_SUBNET:-10.8.1.0/24}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

[ -n "$ADGUARD_IP" ] || fail 'HOMEROUTE_ADGUARD_IP is required'

case "$ADGUARD_IP" in
    *[!0-9.]*|'') fail 'HOMEROUTE_ADGUARD_IP must be IPv4' ;;
esac

printf '%s\n' "-A PREROUTING -i awg0 -s $AWG_SUBNET -p tcp --dport 53 -j DNAT --to-destination $ADGUARD_IP:53"
printf '%s\n' "-A PREROUTING -i awg0 -s $AWG_SUBNET -p udp --dport 53 -j DNAT --to-destination $ADGUARD_IP:53"
