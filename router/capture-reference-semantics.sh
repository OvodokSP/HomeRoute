#!/bin/sh
# Sanitized read-only capture of reference router semantics needed for clean reproduction.
# File contents, keys, endpoints and configuration values are never printed.

set -eu
umask 077

ROOT=${HOMEROUTE_CAPTURE_ROOT:-}
TEST_MODE=${HOMEROUTE_REFERENCE_CAPTURE_TEST_MODE:-0}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_ROUTER_REFERENCE %s=%s\n' "$1" "$2"
}

root_path() {
    printf '%s%s\n' "$ROOT" "$1"
}

bool_grep() {
    pattern=$1
    file=$2
    if grep -Eq "$pattern" "$file" 2>/dev/null; then
        printf true
    else
        printf false
    fi
}

hook_record() {
    id=$1
    rel=$2
    path=$(root_path "$rel")

    [ -f "$path" ] || fail "required hook missing: $rel"

    bytes=$(wc -c < "$path" | tr -d '[:space:]')
    lines=$(wc -l < "$path" | tr -d '[:space:]')
    sha=$(sha256sum "$path" | awk '{print $1}')

    executable=false
    [ -x "$path" ] && executable=true

    shell_syntax=not_applicable
    case "$rel" in
        *.sh|*/S98telegram-awg|*/S99hrneo)
            if sh -n "$path" >/dev/null 2>&1; then
                shell_syntax=valid
            else
                shell_syntax=invalid
            fi
            ;;
    esac

    printf 'HOMEROUTE_ROUTER_HOOK schema=1 id=%s path=%s sha256=%s bytes=%s lines=%s executable=%s shell_syntax=%s' \
        "$id" "$rel" "$sha" "$bytes" "$lines" "$executable" "$shell_syntax"

    printf ' awg=%s' "$(bool_grep '(^|[^[:alnum:]_])awg([[:space:]]|$)' "$path")"
    printf ' awg_quick=%s' "$(bool_grep 'awg-quick' "$path")"
    printf ' hrneo=%s' "$(bool_grep 'hrneo|HydraRoute' "$path")"
    printf ' opkgtun0=%s' "$(bool_grep 'opkgtun0' "$path")"
    printf ' mark_0x3001=%s' "$(bool_grep '0x3001|12289' "$path")"
    printf ' table_301=%s' "$(bool_grep '(^|[^0-9])301([^0-9]|$)' "$path")"
    printf ' ip_rule=%s' "$(bool_grep 'ip[[:space:]]+rule' "$path")"
    printf ' ip_route=%s' "$(bool_grep 'ip[[:space:]]+route' "$path")"
    printf ' iptables=%s' "$(bool_grep 'iptables' "$path")"
    printf ' ipset=%s' "$(bool_grep 'ipset' "$path")"
    printf ' connmark=%s' "$(bool_grep 'CONNMARK|connmark' "$path")"
    printf ' masquerade=%s' "$(bool_grep 'MASQUERADE' "$path")"
    printf ' forward=%s' "$(bool_grep 'FORWARD' "$path")"
    printf ' policy_order=%s' "$(bool_grep 'PolicyOrder' "$path")"
    printf ' service_start=%s' "$(bool_grep '(^|[^[:alnum:]_])start([^[:alnum:]_]|$)|ACTION.*start' "$path")"
    printf ' service_stop=%s' "$(bool_grep '(^|[^[:alnum:]_])stop([^[:alnum:]_]|$)|ACTION.*stop' "$path")"
    printf ' rule_delete=%s' "$(bool_grep 'iptables[^\n]*[[:space:]]-D[[:space:]]|ip[[:space:]]+rule[[:space:]]+del|ip[[:space:]]+route[[:space:]]+del|ipset[[:space:]]+destroy' "$path")"
    printf ' broad_flush=%s' "$(bool_grep 'iptables[^\n]*[[:space:]]-F([[:space:]]|$)|ipset[[:space:]]+flush' "$path")"
    printf '\n'
}

[ "$TEST_MODE" = 1 ] || [ -z "$ROOT" ] ||
    fail 'live capture root override is forbidden'

command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum unavailable'
command -v grep >/dev/null 2>&1 || fail 'grep unavailable'
command -v awk >/dev/null 2>&1 || fail 'awk unavailable'

printf '%s\n' '[INFO] HomeRoute reference-router semantic capture (read-only, sanitized)'
field schema 1
field mode read_only
field secret_values_printed false

hook_record init_telegram_awg '/opt/etc/init.d/S98telegram-awg'
hook_record init_hrneo '/opt/etc/init.d/S99hrneo'
hook_record netfilter_telegram_awg '/opt/etc/ndm/netfilter.d/014-telegram-awg.sh'
hook_record netfilter_hrneo '/opt/etc/ndm/netfilter.d/015-hrneo.sh'
hook_record ifstate_telegram_awg '/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh'
hook_record ifstate_hrneo '/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh'

hrneo_conf=$(root_path '/opt/etc/HydraRoute/hrneo.conf')
domain_conf=$(root_path '/opt/etc/HydraRoute/domain.conf')
ip_list=$(root_path '/opt/etc/HydraRoute/ip.list')

for f in "$hrneo_conf" "$domain_conf" "$ip_list"; do
    [ -f "$f" ] || fail "required HydraRoute conffile missing: $f"
done

hrneo_sha=$(sha256sum "$hrneo_conf" | awk '{print $1}')
domain_sha=$(sha256sum "$domain_conf" | awk '{print $1}')
ip_sha=$(sha256sum "$ip_list" | awk '{print $1}')

hrneo_active=$(awk '!/^[[:space:]]*(#|$)/ {n++} END {print n+0}' "$hrneo_conf")
domain_active=$(awk '!/^[[:space:]]*(#|$)/ {n++} END {print n+0}' "$domain_conf")
ip_active=$(awk '!/^[[:space:]]*(#|$)/ {n++} END {print n+0}' "$ip_list")

policy_order=false
grep -Eq '^[[:space:]]*PolicyOrder=opkgtun0[[:space:]]*$' "$hrneo_conf" && policy_order=true

printf 'HOMEROUTE_ROUTER_HRNEO_CONFIG schema=1 hrneo_sha256=%s domain_sha256=%s ip_list_sha256=%s hrneo_active_lines=%s domain_active_lines=%s ip_list_active_lines=%s policy_order_opkgtun0=%s contents_printed=false\n' \
    "$hrneo_sha" "$domain_sha" "$ip_sha" "$hrneo_active" "$domain_active" "$ip_active" "$policy_order"

if command -v opkg >/dev/null 2>&1; then
    for package in chur-amneziawg chur-amneziawg-go chur-amneziawg-tools hrneo; do
        status=$(opkg status "$package" 2>/dev/null || true)
        version=$(printf '%s\n' "$status" | sed -n 's/^Version:[[:space:]]*//p' | sed -n '1p')
        installed=false
        printf '%s\n' "$status" | grep -Eq '^Status: .* installed$' && installed=true
        [ -n "$version" ] || version=NOT_INSTALLED
        printf 'HOMEROUTE_ROUTER_PACKAGE schema=1 name=%s version=%s installed=%s\n' \
            "$package" "$version" "$installed"
    done
else
    fail 'opkg unavailable'
fi

interface=opkgtun0
interface_present=false
ipv4_prefix=NOT_SET
mtu=NOT_SET
peer_count=NOT_VALIDATED
handshake_present=false

if command -v ip >/dev/null 2>&1 && ip link show dev "$interface" >/dev/null 2>&1; then
    interface_present=true
    ipv4_prefix=$(ip -4 address show dev "$interface" 2>/dev/null |
        awk '/inet / {split($2,a,"/"); print "/" a[2]; exit}')
    [ -n "$ipv4_prefix" ] || ipv4_prefix=NOT_SET
    mtu=$(ip link show dev "$interface" 2>/dev/null |
        awk '{for(i=1;i<=NF;i++) if($i=="mtu" && (i+1)<=NF){print $(i+1); exit}}')
    [ -n "$mtu" ] || mtu=NOT_SET
fi

if command -v awg >/dev/null 2>&1; then
    peer_count=$(awg show "$interface" peers 2>/dev/null | awk 'NF {n++} END {print n+0}')
    if awg show "$interface" latest-handshakes 2>/dev/null |
       awk '$2 > 0 {found=1} END {exit(found ? 0 : 1)}'; then
        handshake_present=true
    fi
fi

printf 'HOMEROUTE_ROUTER_AWG_RUNTIME schema=1 interface=%s interface_present=%s ipv4_prefix=%s mtu=%s peer_count=%s handshake_present=%s addresses_printed=false peers_printed=false endpoints_printed=false keys_printed=false\n' \
    "$interface" "$interface_present" "$ipv4_prefix" "$mtu" "$peer_count" "$handshake_present"

runtime_rule=false
runtime_route=false
runtime_forward=false
runtime_masquerade=false
runtime_mark=false
runtime_ipset=false

if command -v ip >/dev/null 2>&1; then
    ip rule show 2>/dev/null | grep -Eq '(lookup|table)[[:space:]]+301([[:space:]]|$)' && runtime_rule=true
    ip route show table 301 2>/dev/null | grep -Eq '^default([[:space:]].*)? dev opkgtun0([[:space:]]|$)' && runtime_route=true
fi
if command -v iptables-save >/dev/null 2>&1; then
    iptables-save -t filter 2>/dev/null |
        grep '^-A FORWARD ' |
        grep -q -- '-i br0' &&
        iptables-save -t filter 2>/dev/null |
        grep '^-A FORWARD ' |
        grep -q -- '-o opkgtun0' && runtime_forward=true
    iptables-save -t nat 2>/dev/null |
        grep '^-A POSTROUTING ' |
        grep -q -- '-o opkgtun0 .*MASQUERADE' && runtime_masquerade=true
    iptables-save -t mangle 2>/dev/null | grep -qi -- '0x3001' && runtime_mark=true
fi
if command -v ipset >/dev/null 2>&1; then
    ipset list -n 2>/dev/null | grep -Fxq opkgtun0 && runtime_ipset=true
fi

printf 'HOMEROUTE_ROUTER_RUNTIME schema=1 ip_rule_301=%s default_route_opkgtun0=%s forward_br0_opkgtun0=%s masquerade_opkgtun0=%s mark_0x3001=%s ipset_opkgtun0=%s rules_printed=false\n' \
    "$runtime_rule" "$runtime_route" "$runtime_forward" "$runtime_masquerade" "$runtime_mark" "$runtime_ipset"

field result PASS
printf '%s\n' '[PASS] reference-router semantic capture complete; hook/config contents and secret values were not printed'
