#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/vps/analyze-dns-helper.sh"
BASE=${TMPDIR:-/tmp}/homeroute-dns-helper-test.$$
HELPER="$BASE/helper.sh"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BASE"

cat > "$HELPER" <<'EOF'
#!/bin/sh
set -eu
ADG=$(docker inspect -f '{{with index .NetworkSettings.Networks "amnezia-dns-net"}}{{.IPAddress}}{{end}}' adguard-home)
docker exec amnezia-awg2 iptables -t nat -C PREROUTING -p tcp --dport 53 -j DNAT --to-destination "$ADG:53" ||
docker exec amnezia-awg2 iptables -t nat -A PREROUTING -p tcp --dport 53 -j DNAT --to-destination "$ADG:53"
docker exec amnezia-awg2 iptables -t nat -C PREROUTING -p udp --dport 53 -j DNAT --to-destination "$ADG:53" ||
docker exec amnezia-awg2 iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination "$ADG:53"
EOF

sha=$(sha256sum "$HELPER" | awk '{print $1}')
out=$(HOMEROUTE_DNS_HELPER="$HELPER" HOMEROUTE_DNS_HELPER_EXPECTED_SHA256="$sha" sh "$SCRIPT")

for expected in \
  'HOMEROUTE_DNS_HELPER schema=1' \
  "HOMEROUTE_DNS_HELPER helper_path=$HELPER" \
  "HOMEROUTE_DNS_HELPER helper_sha256=$sha" \
  'HOMEROUTE_DNS_HELPER expected_sha_match=true' \
  'HOMEROUTE_DNS_HELPER shell_syntax=valid' \
  'HOMEROUTE_DNS_HELPER pattern_docker=true' \
  'HOMEROUTE_DNS_HELPER pattern_docker_inspect=true' \
  'HOMEROUTE_DNS_HELPER pattern_adguard_name=true' \
  'HOMEROUTE_DNS_HELPER pattern_awg_name=true' \
  'HOMEROUTE_DNS_HELPER pattern_dns_network=true' \
  'HOMEROUTE_DNS_HELPER pattern_docker_exec=true' \
  'HOMEROUTE_DNS_HELPER pattern_iptables=true' \
  'HOMEROUTE_DNS_HELPER pattern_nat_table=true' \
  'HOMEROUTE_DNS_HELPER pattern_prerouting=true' \
  'HOMEROUTE_DNS_HELPER pattern_tcp=true' \
  'HOMEROUTE_DNS_HELPER pattern_udp=true' \
  'HOMEROUTE_DNS_HELPER pattern_dport_53=true' \
  'HOMEROUTE_DNS_HELPER pattern_dnat=true' \
  'HOMEROUTE_DNS_HELPER pattern_to_destination=true' \
  'HOMEROUTE_DNS_HELPER pattern_rule_check=true' \
  'HOMEROUTE_DNS_HELPER pattern_rule_append=true' \
  'HOMEROUTE_DNS_HELPER pattern_rule_flush=false' \
  'HOMEROUTE_DNS_HELPER pattern_docker_restart=false' \
  'HOMEROUTE_DNS_HELPER pattern_docker_rm=false' \
  'HOMEROUTE_DNS_HELPER pattern_system_reboot=false' \
  'HOMEROUTE_DNS_HELPER pattern_rm_command=false'
do
    printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null ||
        fail "missing helper semantic field: $expected"
done

if printf '%s\n' "$out" | grep -F 'NetworkSettings.Networks' >/dev/null; then
    fail 'semantic analyzer leaked helper contents'
fi

if HOMEROUTE_DNS_HELPER="$HELPER" HOMEROUTE_DNS_HELPER_EXPECTED_SHA256=deadbeef sh "$SCRIPT" >/dev/null 2>&1; then
    fail 'semantic analyzer unexpectedly accepted wrong helper SHA'
fi

printf '%s\n' '[PASS] DNS helper semantic fingerprint contract'
