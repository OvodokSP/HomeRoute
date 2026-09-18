#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RENDER="$ROOT/vps/render-dns-persistence-plan.sh"
OUT=${TMPDIR:-/tmp}/homeroute-dns-persistence-plan.$$
trap 'rm -f "$OUT"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

sh "$RENDER" >"$OUT" || fail 'DNS persistence plan renderer returned non-zero'

for expected in \
  'HOMEROUTE_DNS_DESIRED schema=1' \
  'HOMEROUTE_DNS_DESIRED mode=render_only' \
  'HOMEROUTE_DNS_DESIRED timer=awg-adguard-dns.timer' \
  'HOMEROUTE_DNS_DESIRED service=awg-adguard-dns.service' \
  'HOMEROUTE_DNS_DESIRED schedule_kind=monotonic' \
  'HOMEROUTE_DNS_DESIRED on_boot_sec=30' \
  'HOMEROUTE_DNS_DESIRED on_unit_active_sec=60' \
  'HOMEROUTE_DNS_DESIRED persistent=true' \
  'HOMEROUTE_DNS_DESIRED accuracy_sec=10' \
  'HOMEROUTE_DNS_DESIRED randomized_delay_sec=0' \
  'HOMEROUTE_DNS_DESIRED helper_path=/usr/local/sbin/awg-adguard-dns.sh' \
  'HOMEROUTE_DNS_DESIRED target_resolution=docker_inspect_runtime_ipv4' \
  'HOMEROUTE_DNS_DESIRED network=amnezia-dns-net' \
  'HOMEROUTE_DNS_DESIRED adguard_container=adguard-home' \
  'HOMEROUTE_DNS_DESIRED awg_container=amnezia-awg2' \
  'HOMEROUTE_DNS_DESIRED runtime_ip_logging=false' \
  'HOMEROUTE_DNS_DESIRED rule_scope=inside_awg_container' \
  'HOMEROUTE_DNS_DESIRED table=nat' \
  'HOMEROUTE_DNS_DESIRED chain=PREROUTING' \
  'HOMEROUTE_DNS_DESIRED protocols=tcp,udp' \
  'HOMEROUTE_DNS_DESIRED destination_port=53' \
  'HOMEROUTE_DNS_DESIRED check_before_insert=true' \
  'HOMEROUTE_DNS_DESIRED insert_operation=-I' \
  'HOMEROUTE_DNS_DESIRED broad_flush_allowed=false' \
  'HOMEROUTE_DNS_DESIRED container_restart_allowed=false' \
  'HOMEROUTE_DNS_DESIRED container_remove_allowed=false' \
  'HOMEROUTE_DNS_DESIRED reboot_allowed=false' \
  'HOMEROUTE_DNS_DESIRED live_apply=false' \
  'HOMEROUTE_DNS_DESIRED helper_source_identity=NOT_ADOPTED_PENDING_SCHEMA2_LIVE_CAPTURE' \
  'HOMEROUTE_DNS_DESIRED result=PASS'
do
    grep -Fx "$expected" "$OUT" >/dev/null || fail "missing DNS desired-state field: $expected"
done

for forbidden in 'docker inspect' 'docker exec' 'iptables -t' 'systemctl' '/proc/' '/etc/systemd/'
do
    if grep -F "$forbidden" "$OUT" >/dev/null; then
        fail "renderer unexpectedly exposed executable command text: $forbidden"
    fi
done

printf '%s\n' '[PASS] DNS persistence desired-state renderer contract'
