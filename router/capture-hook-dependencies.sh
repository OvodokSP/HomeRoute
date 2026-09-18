#!/bin/sh
# Sanitized read-only dependency capture for HomeRoute persistence hooks.
# Prints only allow-listed booleans/counts. Never prints source lines,
# arguments, variable values, addresses, keys, endpoints, or config contents.

set -eu
umask 077

ROOT=${HOMEROUTE_CAPTURE_ROOT:-}
TEST_MODE=${HOMEROUTE_HOOK_DEP_CAPTURE_TEST_MODE:-0}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_HOOK_DEPENDENCY %s=%s\n' "$1" "$2"
}

root_path() {
    printf '%s%s\n' "$ROOT" "$1"
}

has() {
    pattern=$1
    file=$2
    if grep -Eq "$pattern" "$file" 2>/dev/null; then
        printf true
    else
        printf false
    fi
}

count_unique_opt_paths() {
    file=$1
    grep -Eo '/opt/[A-Za-z0-9_./+-]+' "$file" 2>/dev/null |
        sed 's/[),;:]$//' |
        LC_ALL=C sort -u |
        awk 'NF {n++} END {print n+0}'
}

record() {
    id=$1
    rel=$2
    file=$(root_path "$rel")

    [ -f "$file" ] || fail "required hook missing: $rel"

    sha=$(sha256sum "$file" | awk '{print $1}')
    bytes=$(wc -c < "$file" | tr -d '[:space:]')
    lines=$(wc -l < "$file" | tr -d '[:space:]')
    opt_refs=$(count_unique_opt_paths "$file")

    printf 'HOMEROUTE_HOOK_GRAPH schema=1 id=%s path=%s sha256=%s bytes=%s lines=%s opt_path_refs=%s' \
        "$id" "$rel" "$sha" "$bytes" "$lines" "$opt_refs"

    # Only allow-listed dependency names/behaviors are emitted.
    printf ' ref_rc_func=%s' "$(has '/opt/etc/init\.d/rc\.func|(^|[^[:alnum:]_.-])rc\.func([^[:alnum:]_.-]|$)' "$file")"
    printf ' ref_S98telegram_awg=%s' "$(has 'S98telegram-awg' "$file")"
    printf ' ref_S99hrneo=%s' "$(has 'S99hrneo' "$file")"
    printf ' ref_neo=%s' "$(has '(^|/|[^[:alnum:]_-])neo([^[:alnum:]_-]|$)' "$file")"
    printf ' ref_hrneo=%s' "$(has '(^|/|[^[:alnum:]_-])hrneo([^[:alnum:]_-]|$)|HydraRoute' "$file")"
    printf ' ref_awg_quick=%s' "$(has 'awg-quick' "$file")"
    printf ' ref_awg=%s' "$(has '(^|/|[^[:alnum:]_-])awg([^[:alnum:]_-]|$)' "$file")"

    printf ' source_dot=%s' "$(has '^[[:space:]]*\.[[:space:]]+' "$file")"
    printf ' use_exec=%s' "$(has '(^|[[:space:]])exec([[:space:]]|$)' "$file")"
    printf ' use_start_stop_daemon=%s' "$(has 'start-stop-daemon' "$file")"
    printf ' use_killall=%s' "$(has '(^|/|[[:space:]])killall([[:space:]]|$)' "$file")"
    printf ' use_pidof=%s' "$(has '(^|/|[[:space:]])pidof([[:space:]]|$)' "$file")"
    printf ' use_pgrep=%s' "$(has '(^|/|[[:space:]])pgrep([[:space:]]|$)' "$file")"
    printf ' use_logger=%s' "$(has '(^|/|[[:space:]])logger([[:space:]]|$)' "$file")"
    printf ' use_sleep=%s' "$(has '(^|/|[[:space:]])sleep([[:space:]]|$)' "$file")"
    printf ' background=%s' "$(has '&[[:space:]]*($|#)' "$file")"

    printf ' action_start=%s' "$(has '(^|[^[:alnum:]_])start([^[:alnum:]_]|$)' "$file")"
    printf ' action_stop=%s' "$(has '(^|[^[:alnum:]_])stop([^[:alnum:]_]|$)' "$file")"
    printf ' action_restart=%s' "$(has '(^|[^[:alnum:]_])restart([^[:alnum:]_]|$)' "$file")"
    printf ' action_reload=%s' "$(has '(^|[^[:alnum:]_])reload([^[:alnum:]_]|$)' "$file")"
    printf ' action_up=%s' "$(has '(^|[^[:alnum:]_])up([^[:alnum:]_]|$)' "$file")"
    printf ' action_down=%s' "$(has '(^|[^[:alnum:]_])down([^[:alnum:]_]|$)' "$file")"

    printf ' var_action=%s' "$(has '\$\{?ACTION\}?|\$1' "$file")"
    printf ' var_interface=%s' "$(has '\$\{?(INTERFACE|interface|IFACE|iface)\}?' "$file")"
    printf ' conditional_opkgtun0=%s' "$(has 'opkgtun0' "$file")"

    # Detect direct network mutation presence, but never print rule text.
    printf ' direct_ip_rule=%s' "$(has 'ip[[:space:]]+rule' "$file")"
    printf ' direct_ip_route=%s' "$(has 'ip[[:space:]]+route' "$file")"
    printf ' direct_iptables=%s' "$(has 'iptables' "$file")"
    printf ' direct_ipset=%s' "$(has 'ipset' "$file")"

    printf ' contents_printed=false\n'
}

[ "$TEST_MODE" = 1 ] || [ -z "$ROOT" ] ||
    fail 'live capture root override is forbidden'

for cmd in grep sed sort awk sha256sum wc; do
    command -v "$cmd" >/dev/null 2>&1 || fail "$cmd unavailable"
done

printf '%s\n' '[INFO] HomeRoute hook dependency capture (read-only, allow-listed)'
field schema 1
field mode read_only
field arbitrary_source_printed false
field secret_values_printed false

record init_telegram_awg '/opt/etc/init.d/S98telegram-awg'
record init_hrneo '/opt/etc/init.d/S99hrneo'
record netfilter_telegram_awg '/opt/etc/ndm/netfilter.d/014-telegram-awg.sh'
record netfilter_hrneo '/opt/etc/ndm/netfilter.d/015-hrneo.sh'
record ifstate_telegram_awg '/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh'
record ifstate_hrneo '/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh'

field result PASS
printf '%s\n' '[PASS] hook dependency capture complete; only allow-listed booleans/counts were emitted'
