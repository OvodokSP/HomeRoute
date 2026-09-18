#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RESOLVE="$ROOT/vps/resolve-adguard-dns-target.sh"
RENDER="$ROOT/vps/render-awg-dns-rules.sh"
BASE=${TMPDIR:-/tmp}/homeroute-dns-contract-test.$$
BIN="$BASE/bin"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BIN"

cat > "$BIN/docker" <<'EOF'
#!/bin/sh
set -eu

if [ "$1" = "info" ]; then exit 0; fi
if [ "$1" = "inspect" ] && [ "$2" = "-f" ]; then
    template=$3
    name=$4
    case "$template:$name" in
        "{{.State.Running}}:amnezia-awg2"|"{{.State.Running}}:adguard-home")
            printf '%s\n' true ;;
        *NetworkID*":amnezia-awg2")
            printf '%s\n' fixture-network-id ;;
        *IPAddress*":adguard-home")
            printf '%s\n' 172.29.172.99 ;;
        *)
            exit 1 ;;
    esac
    exit 0
fi
exit 1
EOF
chmod 700 "$BIN/docker"

out=$(PATH="$BIN:$PATH" sh "$RESOLVE")
printf '%s\n' "$out" | grep -Fx 'HOMEROUTE_DNS_TARGET schema=1 result=PASS network=amnezia-dns-net adguard_ip=RESOLVED_RUNTIME' >/dev/null ||
    fail 'dynamic AdGuard target resolution contract missing'
if printf '%s\n' "$out" | grep -F '172.29.172.99' >/dev/null; then
    fail 'resolver leaked runtime AdGuard IP'
fi

rules=$(HOMEROUTE_ADGUARD_IP=172.29.172.99 HOMEROUTE_AWG_CLIENT_SUBNET=10.8.1.0/24 sh "$RENDER")
printf '%s\n' "$rules" | grep -Fx -- '-A PREROUTING -i awg0 -s 10.8.1.0/24 -p tcp --dport 53 -j DNAT --to-destination 172.29.172.99:53' >/dev/null ||
    fail 'TCP DNS DNAT rule drifted'
printf '%s\n' "$rules" | grep -Fx -- '-A PREROUTING -i awg0 -s 10.8.1.0/24 -p udp --dport 53 -j DNAT --to-destination 172.29.172.99:53' >/dev/null ||
    fail 'UDP DNS DNAT rule drifted'

printf '%s\n' '[PASS] dynamic HomeRoute AdGuard DNS redirect contract'
