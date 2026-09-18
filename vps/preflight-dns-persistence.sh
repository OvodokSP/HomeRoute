#!/bin/sh
# Read-only preflight for the reference awg-adguard-dns persistence mechanism.
# Prints unit state, schedule and command path/hash only; never file contents.

set -eu

TIMER=${HOMEROUTE_DNS_TIMER:-awg-adguard-dns.timer}
SERVICE=${HOMEROUTE_DNS_SERVICE:-awg-adguard-dns.service}

field() {
    key=$1
    value=$2
    [ -n "$value" ] || value=NOT_VALIDATED
    printf 'HOMEROUTE_DNS_PERSISTENCE %s=%s\n' "$key" "$value"
}

printf '%s\n' '[INFO] HomeRoute DNS persistence preflight (read-only)'

if ! command -v systemctl >/dev/null 2>&1; then
    printf '%s\n' '[FAIL] systemctl is unavailable' >&2
    exit 1
fi

field schema 1
field timer "$TIMER"
field service "$SERVICE"
field timer_active "$(systemctl is-active "$TIMER" 2>/dev/null || true)"
field timer_enabled "$(systemctl is-enabled "$TIMER" 2>/dev/null || true)"
field service_active "$(systemctl is-active "$SERVICE" 2>/dev/null || true)"

on_calendar=$(systemctl show "$TIMER" -p TimersCalendar --value 2>/dev/null || true)
next_elapse=$(systemctl show "$TIMER" -p NextElapseUSecRealtime --value 2>/dev/null || true)
exec_start=$(systemctl show "$SERVICE" -p ExecStart --value 2>/dev/null || true)

field timer_calendar "$(printf '%s' "$on_calendar" | tr ' ' '_')"
field next_elapse_state "$([ -n "$next_elapse" ] && printf SET || printf NOT_SET)"

exec_path=$(printf '%s\n' "$exec_start" | sed -n 's/.*path=\([^ ;}]*\).*/\1/p' | sed -n '1p')
if [ -z "$exec_path" ]; then
    exec_path=$(printf '%s\n' "$exec_start" | awk '{for(i=1;i<=NF;i++) if($i ~ /^\//){print $i; exit}}')
fi

if [ -n "$exec_path" ]; then
    field exec_path "$exec_path"
    if [ -f "$exec_path" ] && command -v sha256sum >/dev/null 2>&1; then
        field exec_sha256 "$(sha256sum "$exec_path" | awk '{print $1}')"
    else
        field exec_sha256 NOT_VALIDATED
    fi
else
    field exec_path NOT_VALIDATED
    field exec_sha256 NOT_VALIDATED
fi

printf '%s\n' '[PASS] DNS persistence preflight complete; unit/script contents were not printed'
