#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/router/capture-reference-semantics.sh"

BASE=${TMPDIR:-/tmp}/homeroute-router-reference-capture-test.$$
ROOTFS="$BASE/root"
BIN="$BASE/bin"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p \
  "$ROOTFS/opt/etc/init.d" \
  "$ROOTFS/opt/etc/ndm/netfilter.d" \
  "$ROOTFS/opt/etc/ndm/ifstatechanged.d" \
  "$ROOTFS/opt/etc/HydraRoute" \
  "$BIN"

cat > "$ROOTFS/opt/etc/init.d/S98telegram-awg" <<'EOF'
#!/bin/sh
ip rule add fwmark 0x3001 table 301 2>/dev/null || true
ip route replace default dev opkgtun0 table 301
iptables -t filter -C FORWARD -i br0 -o opkgtun0 -j ACCEPT 2>/dev/null ||
iptables -t filter -I FORWARD -i br0 -o opkgtun0 -j ACCEPT
iptables -t nat -C POSTROUTING -o opkgtun0 -j MASQUERADE 2>/dev/null ||
iptables -t nat -I POSTROUTING -o opkgtun0 -j MASQUERADE
EOF
chmod 700 "$ROOTFS/opt/etc/init.d/S98telegram-awg"

cat > "$ROOTFS/opt/etc/init.d/S99hrneo" <<'EOF'
#!/bin/sh
case "$1" in
  start) hrneo >/dev/null 2>&1 & ;;
  stop) killall hrneo 2>/dev/null || true ;;
esac
EOF
chmod 700 "$ROOTFS/opt/etc/init.d/S99hrneo"

cat > "$ROOTFS/opt/etc/ndm/netfilter.d/014-telegram-awg.sh" <<'EOF'
#!/bin/sh
iptables -t mangle -C PREROUTING -m set --match-set opkgtun0 dst -j CONNMARK --set-mark 0x3001 2>/dev/null ||
iptables -t mangle -I PREROUTING -m set --match-set opkgtun0 dst -j CONNMARK --set-mark 0x3001
EOF
chmod 700 "$ROOTFS/opt/etc/ndm/netfilter.d/014-telegram-awg.sh"

cat > "$ROOTFS/opt/etc/ndm/netfilter.d/015-hrneo.sh" <<'EOF'
#!/bin/sh
grep -q 'PolicyOrder=opkgtun0' /opt/etc/HydraRoute/hrneo.conf
EOF
chmod 700 "$ROOTFS/opt/etc/ndm/netfilter.d/015-hrneo.sh"

cat > "$ROOTFS/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh" <<'EOF'
#!/bin/sh
ip rule add fwmark 12289 table 301 2>/dev/null || true
EOF
chmod 700 "$ROOTFS/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh"

cat > "$ROOTFS/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh" <<'EOF'
#!/bin/sh
/opt/etc/init.d/S99hrneo start
EOF
chmod 700 "$ROOTFS/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh"

cat > "$ROOTFS/opt/etc/HydraRoute/hrneo.conf" <<'EOF'
# fixture
PolicyOrder=opkgtun0
Mode=fixture
EOF

cat > "$ROOTFS/opt/etc/HydraRoute/domain.conf" <<'EOF'
example.org
example.net
EOF

cat > "$ROOTFS/opt/etc/HydraRoute/ip.list" <<'EOF'
203.0.113.0/24
EOF

cat > "$BIN/opkg" <<'EOF'
#!/bin/sh
set -eu
[ "$1" = status ] || exit 2
case "$2" in
  chur-amneziawg) version=1.0.0-1 ;;
  chur-amneziawg-go) version=f4f4c99-1 ;;
  chur-amneziawg-tools) version=1.0.20260223-2 ;;
  hrneo) version=3.18.3-1 ;;
  *) exit 1 ;;
esac
printf 'Package: %s\nVersion: %s\nStatus: install user installed\n' "$2" "$version"
EOF
chmod 700 "$BIN/opkg"

cat > "$BIN/ip" <<'EOF'
#!/bin/sh
set -eu
case "$1 $2 $3 $4" in
  "link show dev opkgtun0")
    printf '%s\n' '7: opkgtun0: <POINTOPOINT,UP> mtu 1420 qdisc noqueue state UNKNOWN'
    ;;
  "-4 address show dev")
    [ "$5" = opkgtun0 ] || exit 2
    printf '%s\n' '    inet 10.0.0.2/32 scope global opkgtun0'
    ;;
  "rule show  ")
    printf '%s\n' '32760: from all fwmark 0x3001 lookup 301'
    ;;
  "route show table 301")
    printf '%s\n' 'default dev opkgtun0 scope link'
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod 700 "$BIN/ip"

cat > "$BIN/awg" <<'EOF'
#!/bin/sh
set -eu
[ "$1" = show ] || exit 2
[ "$2" = opkgtun0 ] || exit 2
case "$3" in
  peers)
    printf '%s\n' 'PUBLIC_KEY_REDACTED'
    ;;
  latest-handshakes)
    printf '%s\n' 'PUBLIC_KEY_REDACTED 1234567890'
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod 700 "$BIN/awg"

cat > "$BIN/iptables-save" <<'EOF'
#!/bin/sh
set -eu
[ "$1" = -t ] || exit 2
case "$2" in
  filter)
    printf '%s\n' '-A FORWARD -i br0 -o opkgtun0 -j ACCEPT'
    ;;
  nat)
    printf '%s\n' '-A POSTROUTING -o opkgtun0 -j MASQUERADE'
    ;;
  mangle)
    printf '%s\n' '-A PREROUTING -m set --match-set opkgtun0 dst -j CONNMARK --set-mark 0x3001'
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod 700 "$BIN/iptables-save"

cat > "$BIN/ipset" <<'EOF'
#!/bin/sh
set -eu
[ "$1" = list ] && [ "$2" = -n ] || exit 2
printf '%s\n' opkgtun0
EOF
chmod 700 "$BIN/ipset"

out="$BASE/out"
PATH="$BIN:$PATH" \
HOMEROUTE_REFERENCE_CAPTURE_TEST_MODE=1 \
HOMEROUTE_CAPTURE_ROOT="$ROOTFS" \
  sh "$SCRIPT" > "$out"

grep -Fx 'HOMEROUTE_ROUTER_REFERENCE schema=1' "$out" >/dev/null ||
  fail 'schema field missing'
grep -Fx 'HOMEROUTE_ROUTER_REFERENCE mode=read_only' "$out" >/dev/null ||
  fail 'read-only field missing'
grep -Fx 'HOMEROUTE_ROUTER_REFERENCE secret_values_printed=false' "$out" >/dev/null ||
  fail 'secret-output boundary missing'
grep -F 'id=netfilter_telegram_awg ' "$out" | grep -F 'mark_0x3001=true' | grep -F 'connmark=true' >/dev/null ||
  fail 'telegram netfilter semantics not captured'
grep -F 'id=init_telegram_awg ' "$out" | grep -F 'table_301=true' | grep -F 'masquerade=true' >/dev/null ||
  fail 'telegram init routing semantics not captured'
grep -F 'id=init_hrneo ' "$out" | grep -F 'hrneo=true' | grep -F 'service_start=true' | grep -F 'service_stop=true' >/dev/null ||
  fail 'HRNeo init semantics not captured'
grep -F 'HOMEROUTE_ROUTER_HRNEO_CONFIG schema=1 ' "$out" | grep -F 'policy_order_opkgtun0=true' | grep -F 'contents_printed=false' >/dev/null ||
  fail 'HRNeo config summary missing'
grep -Fx 'HOMEROUTE_ROUTER_PACKAGE schema=1 name=hrneo version=3.18.3-1 installed=true' "$out" >/dev/null ||
  fail 'HRNeo package record missing'
grep -F 'HOMEROUTE_ROUTER_AWG_RUNTIME schema=1 ' "$out" | grep -F 'interface_present=true' | grep -F 'ipv4_prefix=/32' | grep -F 'peer_count=1' | grep -F 'keys_printed=false' >/dev/null ||
  fail 'AWG runtime shape missing'
grep -F 'HOMEROUTE_ROUTER_RUNTIME schema=1 ' "$out" | grep -F 'ip_rule_301=true' | grep -F 'default_route_opkgtun0=true' | grep -F 'mark_0x3001=true' | grep -F 'ipset_opkgtun0=true' >/dev/null ||
  fail 'runtime routing shape missing'
grep -Fx 'HOMEROUTE_ROUTER_REFERENCE result=PASS' "$out" >/dev/null ||
  fail 'result PASS missing'

if grep -F 'PUBLIC_KEY_REDACTED' "$out" >/dev/null; then
  fail 'peer material leaked into capture output'
fi
if grep -F '10.0.0.2' "$out" >/dev/null; then
  fail 'interface address leaked into capture output'
fi
if grep -F 'example.org' "$out" >/dev/null; then
  fail 'domain contents leaked into capture output'
fi

printf '%s\n' '[PASS] sanitized reference-router semantic capture contract'
