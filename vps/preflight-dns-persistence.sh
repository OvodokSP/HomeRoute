#!/bin/sh
# Read-only preflight for the reference awg-adguard-dns persistence mechanism.
# Prints unit state, sanitized schedule metadata and command path/hash only; never file contents.

set -eu

TIMER=${HOMEROUTE_DNS_TIMER:-awg-adguard-dns.timer}
SERVICE=${HOMEROUTE_DNS_SERVICE:-awg-adguard-dns.service}

field() {
    key=$1
    value=$2
    [ -n "$value" ] || value=NOT_VALIDATED
    printf 'HOMEROUTE_DNS_PERSISTENCE %s=%s\n' "$key" "$value"
}

state_field() {
    key=$1
    value=$2
    if [ -n "$value" ]; then
        field "$key" SET
    else
        field "$key" NOT_SET
    fi
}

sanitize_value() {
    printf '%s' "$1" | tr ' \t' '__' | tr -cd '[:alnum:]_{}=;:.,+*/@-'
}

printf '%s\n' '[INFO] HomeRoute DNS persistence preflight (read-only)'

if ! command -v systemctl >/dev/null 2>&1; then
    printf '%s\n' '[FAIL] systemctl is unavailable' >&2
    exit 1
fi

field schema 2
field timer "$TIMER"
field service "$SERVICE"
field timer_active "$(systemctl is-active "$TIMER" 2>/dev/null || true)"
field timer_enabled "$(systemctl is-enabled "$TIMER" 2>/dev/null || true)"
field service_active "$(systemctl is-active "$SERVICE" 2>/dev/null || true)"

timers_calendar=$(systemctl show "$TIMER" -p TimersCalendar --value 2>/dev/null || true)
timers_monotonic=$(systemctl show "$TIMER" -p TimersMonotonic --value 2>/dev/null || true)
next_realtime=$(systemctl show "$TIMER" -p NextElapseUSecRealtime --value 2>/dev/null || true)
next_monotonic=$(systemctl show "$TIMER" -p NextElapseUSecMonotonic --value 2>/dev/null || true)
last_trigger=$(systemctl show "$TIMER" -p LastTriggerUSec --value 2>/dev/null || true)
persistent=$(systemctl show "$TIMER" -p Persistent --value 2>/dev/null || true)
accuracy=$(systemctl show "$TIMER" -p AccuracyUSec --value 2>/dev/null || true)
randomized_delay=$(systemctl show "$TIMER" -p RandomizedDelayUSec --value 2>/dev/null || true)
exec_start=$(systemctl show "$SERVICE" -p ExecStart --value 2>/dev/null || true)

schedule_kind=unknown
if [ -n "$timers_calendar" ]; then
    schedule_kind=calendar
elif [ -n "$timers_monotonic" ]; then
    schedule_kind=monotonic
fi

field schedule_kind "$schedule_kind"
field calendar_spec "$(sanitize_value "$timers_calendar")"
field monotonic_spec "$(sanitize_value "$timers_monotonic")"
state_field next_realtime_state "$next_realtime"
state_field next_monotonic_state "$next_monotonic"
state_field last_trigger_state "$last_trigger"
field persistent "$persistent"
field accuracy_usec "$(sanitize_value "$accuracy")"
field randomized_delay_usec "$(sanitize_value "$randomized_delay")"

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
