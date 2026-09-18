#!/bin/sh
# Read-only resolver for the HomeRoute AdGuard target inside amnezia-dns-net.
# It never prints the resolved IP; it reports only validation state.

set -eu

AWG_CONTAINER=${AWG_CONTAINER:-amnezia-awg2}
ADGUARD_CONTAINER=${ADGUARD_CONTAINER:-adguard-home}
NETWORK=${HOMEROUTE_DNS_NETWORK:-amnezia-dns-net}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

command -v docker >/dev/null 2>&1 || fail 'docker command is unavailable'
docker info >/dev/null 2>&1 || fail 'docker daemon is unavailable'

is_running() {
    docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null | grep -Fxq true
}

is_running "$AWG_CONTAINER" || fail "AWG container is not running: $AWG_CONTAINER"
is_running "$ADGUARD_CONTAINER" || fail "AdGuard container is not running: $ADGUARD_CONTAINER"

awg_attached=$(docker inspect -f "{{with index .NetworkSettings.Networks \"$NETWORK\"}}{{.NetworkID}}{{end}}" "$AWG_CONTAINER" 2>/dev/null || true)
adg_ip=$(docker inspect -f "{{with index .NetworkSettings.Networks \"$NETWORK\"}}{{.IPAddress}}{{end}}" "$ADGUARD_CONTAINER" 2>/dev/null || true)

[ -n "$awg_attached" ] || fail "AWG container is not attached to $NETWORK"
[ -n "$adg_ip" ] || fail "AdGuard has no IPv4 address on $NETWORK"

case "$adg_ip" in
    *[!0-9.]*|'') fail 'resolved AdGuard address is not IPv4' ;;
esac

old_ifs=$IFS
IFS=.
set -- $adg_ip
IFS=$old_ifs
[ "$#" -eq 4 ] || fail 'resolved AdGuard address is not four-octet IPv4'
for octet in "$@"; do
    case "$octet" in ''|*[!0-9]*) fail 'resolved AdGuard IPv4 contains invalid octet' ;; esac
    [ "$octet" -ge 0 ] 2>/dev/null && [ "$octet" -le 255 ] 2>/dev/null ||
        fail 'resolved AdGuard IPv4 octet is out of range'
done

printf '%s\n' 'HOMEROUTE_DNS_TARGET schema=1 result=PASS network=amnezia-dns-net adguard_ip=RESOLVED_RUNTIME'
printf '%s\n' '[PASS] AdGuard runtime target resolved without printing its IP'
