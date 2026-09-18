#!/bin/sh
# Read-only semantic fingerprint for the reference AWG->AdGuard DNS helper.
# Reads the local helper but prints only normalized boolean facts and SHA256.

set -eu

HELPER=${HOMEROUTE_DNS_HELPER:-/usr/local/sbin/awg-adguard-dns.sh}
EXPECTED_SHA=${HOMEROUTE_DNS_HELPER_EXPECTED_SHA256:-}

field() {
    printf 'HOMEROUTE_DNS_HELPER %s=%s\n' "$1" "$2"
}

bool_grep() {
    key=$1
    pattern=$2
    if grep -Eq -- "$pattern" "$HELPER"; then
        field "$key" true
    else
        field "$key" false
    fi
}

has_pattern() {
    grep -Eq -- "$1" "$HELPER"
}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

[ -f "$HELPER" ] || fail "DNS helper is missing: $HELPER"
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is unavailable'
command -v grep >/dev/null 2>&1 || fail 'grep is unavailable'

sha=$(sha256sum "$HELPER" | awk '{print $1}')
field schema 2
field helper_path "$HELPER"
field helper_sha256 "$sha"

if [ -n "$EXPECTED_SHA" ]; then
    if [ "$sha" = "$EXPECTED_SHA" ]; then
        field expected_sha_match true
    else
        field expected_sha_match false
        fail 'DNS helper SHA256 does not match expected reference'
    fi
else
    field expected_sha_match NOT_REQUESTED
fi

if sh -n "$HELPER" >/dev/null 2>&1; then
    field shell_syntax valid
else
    field shell_syntax invalid
fi

bool_grep pattern_docker '(^|[^[:alnum:]_])docker([[:space:]]|$)'
bool_grep pattern_docker_inspect 'docker[[:space:]]+inspect'
bool_grep pattern_adguard_name 'adguard-home'
bool_grep pattern_awg_name 'amnezia-awg2'
bool_grep pattern_dns_network 'amnezia-dns-net'
bool_grep pattern_docker_exec 'docker[[:space:]]+exec'
bool_grep pattern_networks_object 'NetworkSettings[.]Networks'
bool_grep pattern_ip_address_field '[.]IPAddress'
bool_grep pattern_inspect_variable 'docker[[:space:]]+inspect.*\$[{]?[[:alnum:]_]+'
bool_grep pattern_iptables '(^|[^[:alnum:]_])iptables([[:space:]]|$)'
bool_grep pattern_nat_table '(-t[[:space:]]+nat|--table[=[:space:]]+nat)'
bool_grep pattern_prerouting 'PREROUTING'
bool_grep pattern_tcp '(-p|--protocol)[=[:space:]]+tcp'
bool_grep pattern_udp '(-p|--protocol)[=[:space:]]+udp'
bool_grep pattern_protocol_variable '(-p|--protocol)[=[:space:]]+[^[:space:]]*\$[{]?[[:alnum:]_]+'
bool_grep pattern_tcp_udp_pair '(tcp[[:space:]]+udp|udp[[:space:]]+tcp)'
bool_grep pattern_for_loop 'for[[:space:]]+[[:alnum:]_]+[[:space:]]+in([[:space:]]|$)'
bool_grep pattern_dport_53 '(--dport|--destination-port)[=[:space:]]+53'
bool_grep pattern_dnat 'DNAT'
bool_grep pattern_to_destination '--to-destination'
bool_grep pattern_to_destination_variable '--to-destination[=[:space:]]+[^[:space:]]*\$[{]?[[:alnum:]_]+'
bool_grep pattern_rule_check 'iptables.*[[:space:]]-C([[:space:]]|$)'
bool_grep pattern_rule_append 'iptables.*[[:space:]]-A([[:space:]]|$)'
bool_grep pattern_rule_insert 'iptables.*[[:space:]]-I([[:space:]]|$)'
bool_grep pattern_rule_delete 'iptables.*[[:space:]]-D([[:space:]]|$)'
bool_grep pattern_rule_flush 'iptables.*[[:space:]]-F([[:space:]]|$)'
bool_grep pattern_docker_restart 'docker[[:space:]]+restart'
bool_grep pattern_docker_rm 'docker[[:space:]]+rm'
bool_grep pattern_system_reboot '(^|[;&|[:space:]])reboot([;&|[:space:]]|$)'
bool_grep pattern_rm_command '(^|[;&|[:space:]])rm([;&|[:space:]]|$)'

runtime_target_candidate=false
if has_pattern 'docker[[:space:]]+inspect' &&
   has_pattern 'NetworkSettings[.]Networks' &&
   has_pattern '[.]IPAddress' &&
   has_pattern '--to-destination[=[:space:]]+[^[:space:]]*\$[{]?[[:alnum:]_]+'; then
    runtime_target_candidate=true
fi
field runtime_target_candidate "$runtime_target_candidate"

protocol_loop_candidate=false
if has_pattern '(-p|--protocol)[=[:space:]]+[^[:space:]]*\$[{]?[[:alnum:]_]+' &&
   has_pattern '(tcp[[:space:]]+udp|udp[[:space:]]+tcp)'; then
    protocol_loop_candidate=true
fi
field protocol_loop_candidate "$protocol_loop_candidate"

line_count=$(wc -l < "$HELPER" | tr -d ' ')
case "$line_count" in ''|*[!0-9]*) line_count=NOT_VALIDATED ;; esac
field line_count "$line_count"

printf '%s\n' '[PASS] DNS helper semantic fingerprint complete; helper contents were not printed'
