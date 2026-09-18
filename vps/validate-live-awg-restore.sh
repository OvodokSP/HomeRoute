#!/bin/sh
# Controlled live validation of AWG state restore.
#
# This is NOT an installer apply path. It validates one narrow recovery path:
# 1) read-only restore readiness gate;
# 2) graceful stop of the live AWG container;
# 3) quiescent snapshot of the exact current AWG state;
# 4) copy the same snapshot back into the stopped container;
# 5) byte-for-byte round-trip verification;
# 6) start the original container and verify its basic runtime/DNS state.
#
# AdGuard is not stopped or modified. No image load/recreate/remove is performed.

set -eu
umask 077

MODE=${1:-plan}
DOCKER=${HOMEROUTE_DOCKER_BIN:-docker}
AWG_CONTAINER=${AWG_CONTAINER:-amnezia-awg2}
AWG_INTERFACE=${VPS_AWG_INTERFACE:-awg0}
STATE_PATH=/opt/amnezia/awg
START_PATH=/opt/amnezia/start.sh
ACK=${HOMEROUTE_LIVE_AWG_RESTORE_ACK:-}
READINESS=${HOMEROUTE_RESTORE_READINESS:-"$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/preflight-live-restore.sh"}
BACKUP_ROOT=${HOMEROUTE_BACKUP_ROOT:-/root/homeroute-backups}
TEST_MODE=${HOMEROUTE_LIVE_RESTORE_TEST_MODE:-0}
POSTCHECK_ATTEMPTS=${HOMEROUTE_LIVE_RESTORE_POSTCHECK_ATTEMPTS:-18}
POSTCHECK_SLEEP=${HOMEROUTE_LIVE_RESTORE_POSTCHECK_SLEEP:-5}

field() {
    printf 'HOMEROUTE_LIVE_RESTORE %s=%s\n' "$1" "$2"
}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

show_plan() {
    field schema 1
    field target awg
    field mode plan
    field requires_explicit_ack true
    field live_container_stop true
    field live_container_recreate false
    field image_load false
    field adguard_touched false
    field restore_source quiescent_same_state_snapshot
    field automatic_recovery_attempt true
    field result PLAN_ONLY
    printf '%s\n' '[PASS] controlled AWG restore-validation plan rendered; no live state changed'
}

case "$MODE" in
    plan|--plan)
        show_plan
        exit 0
        ;;
    validate|--validate)
        ;;
    help|--help|-h)
        printf '%s\n' 'Usage: validate-live-awg-restore.sh [plan|validate]'
        exit 0
        ;;
    *)
        fail "unknown mode: $MODE"
        ;;
esac

[ "$ACK" = YES ] || fail 'set HOMEROUTE_LIVE_AWG_RESTORE_ACK=YES to allow the brief AWG service interruption'

if [ "$TEST_MODE" = 1 ]; then
    case "$BACKUP_ROOT" in
        /tmp/homeroute-live-awg-restore-test.*) ;;
        *) fail 'unsafe backup root in test mode' ;;
    esac
else
    [ "$(id -u)" -eq 0 ] || fail 'live AWG restore validation must run as root'
    [ "$BACKUP_ROOT" = /root/homeroute-backups ] || fail 'live backup root must be /root/homeroute-backups'
fi

command -v "$DOCKER" >/dev/null 2>&1 || fail 'docker command is unavailable'
"$DOCKER" info >/dev/null 2>&1 || fail 'docker daemon is unavailable'
[ -f "$READINESS" ] || fail "restore readiness gate is missing: $READINESS"

HOMEROUTE_BACKUP_ROOT="$BACKUP_ROOT" sh "$READINESS" >/dev/null ||
    fail 'restore-readiness gate did not pass immediately before validation'

running=$("$DOCKER" inspect -f '{{.State.Running}}' "$AWG_CONTAINER" 2>/dev/null || true)
[ "$running" = true ] || fail "AWG container is not running: $AWG_CONTAINER"

stamp=$(date -u +%Y%m%dT%H%M%SZ)
work="$BACKUP_ROOT/live-awg-restore-validation-$stamp"
[ ! -e "$work" ] || fail "validation directory already exists: $work"
mkdir -p "$work/snapshot/awg" "$work/verify/awg"
chmod 700 "$work" "$work/snapshot" "$work/snapshot/awg" "$work/verify" "$work/verify/awg"

container_stopped=0
success=0

start_if_needed() {
    if [ "$container_stopped" -eq 1 ]; then
        "$DOCKER" start "$AWG_CONTAINER" >/dev/null 2>&1 || true
        container_stopped=0
    fi
}

cleanup() {
    rc=$?
    trap - EXIT HUP INT TERM
    start_if_needed
    if [ "$success" -eq 1 ]; then
        rm -rf "$work"
    else
        printf '[INFO] recovery snapshot retained at %s\n' "$work" >&2
    fi
    exit "$rc"
}
trap cleanup EXIT HUP INT TERM

build_manifest() {
    root=$1
    out=$2
    (
        cd "$root"
        find . -type f -print | LC_ALL=C sort |
        while IFS= read -r file; do
            sha256sum "$file"
        done
    ) > "$out"
}

restore_snapshot() {
    "$DOCKER" cp -a "$work/snapshot/awg/." "$AWG_CONTAINER:$STATE_PATH/" >/dev/null
    "$DOCKER" cp -a "$work/snapshot/start.sh" "$AWG_CONTAINER:$START_PATH" >/dev/null
}

verify_stopped_roundtrip() {
    rm -rf "$work/verify"
    mkdir -p "$work/verify/awg"
    chmod 700 "$work/verify" "$work/verify/awg"

    "$DOCKER" cp -a "$AWG_CONTAINER:$STATE_PATH/." "$work/verify/awg/" >/dev/null
    "$DOCKER" cp -a "$AWG_CONTAINER:$START_PATH" "$work/verify/start.sh" >/dev/null

    build_manifest "$work/verify" "$work/verify.MANIFEST.sha256"
    cmp -s "$work/snapshot.MANIFEST.sha256" "$work/verify.MANIFEST.sha256"
}

postcheck() {
    running=$("$DOCKER" inspect -f '{{.State.Running}}' "$AWG_CONTAINER" 2>/dev/null || true)
    [ "$running" = true ] || return 1
    "$DOCKER" exec "$AWG_CONTAINER" ip link show dev "$AWG_INTERFACE" >/dev/null 2>&1 || return 1

    nat=$("$DOCKER" exec "$AWG_CONTAINER" iptables-save -t nat 2>/dev/null || true)
    printf '%s\n' "$nat" | grep -E -- '(-p tcp|--protocol tcp).*--dport 53.*(REDIRECT|DNAT)' >/dev/null || return 1
    printf '%s\n' "$nat" | grep -E -- '(-p udp|--protocol udp).*--dport 53.*(REDIRECT|DNAT)' >/dev/null || return 1
    return 0
}

rollback_and_restart() {
    printf '%s\n' '[INFO] post-restore verification failed; reapplying the quiescent snapshot'
    running=$("$DOCKER" inspect -f '{{.State.Running}}' "$AWG_CONTAINER" 2>/dev/null || true)
    if [ "$running" = true ]; then
        "$DOCKER" stop -t 30 "$AWG_CONTAINER" >/dev/null
    fi
    container_stopped=1
    restore_snapshot || return 1
    "$DOCKER" start "$AWG_CONTAINER" >/dev/null || return 1
    container_stopped=0
    return 0
}

validation_started=$(date +%s)

"$DOCKER" stop -t 30 "$AWG_CONTAINER" >/dev/null
container_stopped=1

running=$("$DOCKER" inspect -f '{{.State.Running}}' "$AWG_CONTAINER" 2>/dev/null || true)
[ "$running" = false ] || fail 'AWG container did not stop cleanly'

"$DOCKER" cp -a "$AWG_CONTAINER:$STATE_PATH/." "$work/snapshot/awg/" >/dev/null
"$DOCKER" cp -a "$AWG_CONTAINER:$START_PATH" "$work/snapshot/start.sh" >/dev/null

[ -f "$work/snapshot/awg/awg0.conf" ] || fail 'quiescent AWG snapshot is incomplete: awg0.conf missing'
[ -f "$work/snapshot/start.sh" ] || fail 'quiescent AWG snapshot is incomplete: start.sh missing'

build_manifest "$work/snapshot" "$work/snapshot.MANIFEST.sha256"
[ -s "$work/snapshot.MANIFEST.sha256" ] || fail 'quiescent snapshot manifest is empty'

restore_snapshot || fail 'copying the quiescent AWG snapshot back into the stopped container failed'
verify_stopped_roundtrip || fail 'AWG stopped-container restore did not reproduce the exact snapshot bytes'

"$DOCKER" start "$AWG_CONTAINER" >/dev/null
container_stopped=0

post_ok=0
attempt=0
while [ "$attempt" -lt "$POSTCHECK_ATTEMPTS" ]; do
    if postcheck; then
        post_ok=1
        break
    fi
    attempt=$((attempt + 1))
    sleep "$POSTCHECK_SLEEP"
done

if [ "$post_ok" -ne 1 ]; then
    rollback_and_restart || fail 'automatic AWG recovery attempt failed'
    fail 'AWG post-restore runtime verification failed; quiescent snapshot was reapplied'
fi

validation_finished=$(date +%s)
window=$((validation_finished - validation_started))

field schema 1
field target awg
field mode validate
field readiness PASS
field quiescent_snapshot PASS
field stopped_restore_roundtrip PASS
field container_recreated false
field image_load false
field adguard_touched false
field runtime_interface PASS
field dns_tcp_udp_53 PASS
field validation_window_seconds "$window"
field live_restore_validated true
field result PASS

success=1
printf '%s\n' '[PASS] controlled live AWG same-state restore validation completed'
