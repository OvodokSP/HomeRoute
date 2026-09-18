#!/bin/sh
# Controlled live validation of AdGuard state restore.
#
# This is NOT an installer apply path. It validates one narrow recovery path:
# 1) read-only restore readiness gate;
# 2) graceful stop of the live AdGuard container;
# 3) quiescent snapshot of the exact current conf/work state;
# 4) copy the same snapshot back into the stopped container;
# 5) byte-for-byte round-trip verification;
# 6) start the original container and verify DNS service availability.
#
# AWG is not stopped or modified. No image load/recreate/remove is performed.

set -eu
umask 077

MODE=${1:-plan}
DOCKER=${HOMEROUTE_DOCKER_BIN:-docker}
ADGUARD_CONTAINER=${ADGUARD_CONTAINER:-adguard-home}
AWG_CONTAINER=${AWG_CONTAINER:-amnezia-awg2}
DNS_NETWORK=${HOMEROUTE_DNS_NETWORK:-amnezia-dns-net}
CONF_PATH=/opt/adguardhome/conf
WORK_PATH=/opt/adguardhome/work
ACK=${HOMEROUTE_LIVE_ADGUARD_RESTORE_ACK:-}
READINESS=${HOMEROUTE_RESTORE_READINESS:-"$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/preflight-live-restore.sh"}
BACKUP_ROOT=${HOMEROUTE_BACKUP_ROOT:-/root/homeroute-backups}
TEST_MODE=${HOMEROUTE_LIVE_RESTORE_TEST_MODE:-0}
POSTCHECK_ATTEMPTS=${HOMEROUTE_LIVE_RESTORE_POSTCHECK_ATTEMPTS:-18}
POSTCHECK_SLEEP=${HOMEROUTE_LIVE_RESTORE_POSTCHECK_SLEEP:-5}
PROBE_OVERRIDE=${HOMEROUTE_ADGUARD_DNS_PROBE:-}

field() {
    printf 'HOMEROUTE_LIVE_RESTORE %s=%s\n' "$1" "$2"
}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

show_plan() {
    field schema 1
    field target adguard
    field mode plan
    field requires_explicit_ack true
    field live_container_stop true
    field live_container_recreate false
    field image_load false
    field awg_touched false
    field restore_source quiescent_same_state_snapshot
    field dns_tcp_udp_probe true
    field automatic_recovery_attempt true
    field result PLAN_ONLY
    printf '%s\n' '[PASS] controlled AdGuard restore-validation plan rendered; no live state changed'
}

case "$MODE" in
    plan|--plan)
        show_plan
        exit 0
        ;;
    validate|--validate)
        ;;
    help|--help|-h)
        printf '%s\n' 'Usage: validate-live-adguard-restore.sh [plan|validate]'
        exit 0
        ;;
    *)
        fail "unknown mode: $MODE"
        ;;
esac

[ "$ACK" = YES ] || fail 'set HOMEROUTE_LIVE_ADGUARD_RESTORE_ACK=YES to allow the brief AdGuard service interruption'

if [ "$TEST_MODE" = 1 ]; then
    case "$BACKUP_ROOT" in
        /tmp/homeroute-live-adguard-restore-test.*) ;;
        *) fail 'unsafe backup root in test mode' ;;
    esac
else
    [ "$(id -u)" -eq 0 ] || fail 'live AdGuard restore validation must run as root'
    [ "$BACKUP_ROOT" = /root/homeroute-backups ] || fail 'live backup root must be /root/homeroute-backups'
fi

command -v "$DOCKER" >/dev/null 2>&1 || fail 'docker command is unavailable'
"$DOCKER" info >/dev/null 2>&1 || fail 'docker daemon is unavailable'
[ -f "$READINESS" ] || fail "restore readiness gate is missing: $READINESS"

HOMEROUTE_BACKUP_ROOT="$BACKUP_ROOT" sh "$READINESS" >/dev/null ||
    fail 'restore-readiness gate did not pass immediately before validation'

running=$("$DOCKER" inspect -f '{{.State.Running}}' "$ADGUARD_CONTAINER" 2>/dev/null || true)
[ "$running" = true ] || fail "AdGuard container is not running: $ADGUARD_CONTAINER"
awg_running=$("$DOCKER" inspect -f '{{.State.Running}}' "$AWG_CONTAINER" 2>/dev/null || true)
[ "$awg_running" = true ] || fail "AWG container is not running: $AWG_CONTAINER"

stamp=$(date -u +%Y%m%dT%H%M%SZ)
work="$BACKUP_ROOT/live-adguard-restore-validation-$stamp"
[ ! -e "$work" ] || fail "validation directory already exists: $work"
mkdir -p "$work/snapshot/conf" "$work/snapshot/work" "$work/verify/conf" "$work/verify/work"
chmod 700 "$work" "$work/snapshot" "$work/snapshot/conf" "$work/snapshot/work" "$work/verify" "$work/verify/conf" "$work/verify/work"

container_stopped=0
snapshot_ready=0
success=0

build_manifest() {
    root=$1
    out=$2
    (
        cd "$root"
        find conf work -type f -print | LC_ALL=C sort |
        while IFS= read -r file; do
            sha256sum "$file"
        done
    ) > "$out"
}

restore_snapshot() {
    "$DOCKER" cp -a "$work/snapshot/conf/." "$ADGUARD_CONTAINER:$CONF_PATH/" >/dev/null
    "$DOCKER" cp -a "$work/snapshot/work/." "$ADGUARD_CONTAINER:$WORK_PATH/" >/dev/null
}

ensure_stopped() {
    running=$("$DOCKER" inspect -f '{{.State.Running}}' "$ADGUARD_CONTAINER" 2>/dev/null || true)
    if [ "$running" = true ]; then
        "$DOCKER" stop -t 30 "$ADGUARD_CONTAINER" >/dev/null || return 1
    fi
    container_stopped=1
    return 0
}

ensure_started() {
    running=$("$DOCKER" inspect -f '{{.State.Running}}' "$ADGUARD_CONTAINER" 2>/dev/null || true)
    if [ "$running" != true ]; then
        "$DOCKER" start "$ADGUARD_CONTAINER" >/dev/null || return 1
    fi
    container_stopped=0
    return 0
}

cleanup() {
    rc=$?
    trap - EXIT HUP INT TERM

    if [ "$success" -ne 1 ] && [ "$snapshot_ready" -eq 1 ]; then
        printf '%s\n' '[INFO] attempting automatic AdGuard recovery from quiescent snapshot' >&2
        if ensure_stopped; then
            restore_snapshot >/dev/null 2>&1 || printf '%s\n' '[FAIL] automatic snapshot reapply failed' >&2
            ensure_started || printf '%s\n' '[FAIL] automatic AdGuard restart failed' >&2
        else
            printf '%s\n' '[FAIL] could not stop AdGuard for automatic recovery' >&2
        fi
    else
        ensure_started >/dev/null 2>&1 || true
    fi

    if [ "$success" -eq 1 ]; then
        rm -rf "$work"
    else
        printf '[INFO] recovery snapshot retained at %s\n' "$work" >&2
    fi
    exit "$rc"
}
trap cleanup EXIT HUP INT TERM

verify_stopped_roundtrip() {
    rm -rf "$work/verify"
    mkdir -p "$work/verify/conf" "$work/verify/work"
    chmod 700 "$work/verify" "$work/verify/conf" "$work/verify/work"

    "$DOCKER" cp -a "$ADGUARD_CONTAINER:$CONF_PATH/." "$work/verify/conf/" >/dev/null
    "$DOCKER" cp -a "$ADGUARD_CONTAINER:$WORK_PATH/." "$work/verify/work/" >/dev/null

    build_manifest "$work/verify" "$work/verify.MANIFEST.sha256"
    cmp -s "$work/snapshot.MANIFEST.sha256" "$work/verify.MANIFEST.sha256"
}

default_dns_probe() {
    command -v python3 >/dev/null 2>&1 || return 1

    adg_ip=$("$DOCKER" inspect -f "{{with index .NetworkSettings.Networks \"$DNS_NETWORK\"}}{{.IPAddress}}{{end}}" "$ADGUARD_CONTAINER" 2>/dev/null || true)
    [ -n "$adg_ip" ] || return 1

    HOMEROUTE_DNS_PROBE_IP="$adg_ip" python3 - <<'PY'
import os
import socket
import struct
import sys

host = os.environ.get("HOMEROUTE_DNS_PROBE_IP", "")
if not host:
    sys.exit(2)

# Fixed transaction ID; response code itself is irrelevant. We only require
# a syntactically valid DNS response from the restored AdGuard listener.
txid = 0x484C
labels = [b"example", b"com"]
qname = b"".join(bytes([len(x)]) + x for x in labels) + b"\x00"
query = struct.pack("!HHHHHH", txid, 0x0100, 1, 0, 0, 0) + qname + struct.pack("!HH", 1, 1)

def valid(payload):
    if len(payload) < 12:
        return False
    rid, flags = struct.unpack("!HH", payload[:4])
    return rid == txid and bool(flags & 0x8000)

try:
    u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    u.settimeout(2.0)
    u.sendto(query, (host, 53))
    udp, _ = u.recvfrom(4096)
    u.close()
    if not valid(udp):
        sys.exit(3)

    t = socket.create_connection((host, 53), timeout=2.0)
    t.settimeout(2.0)
    t.sendall(struct.pack("!H", len(query)) + query)
    hdr = t.recv(2)
    if len(hdr) != 2:
        sys.exit(4)
    want = struct.unpack("!H", hdr)[0]
    chunks = bytearray()
    while len(chunks) < want:
        part = t.recv(want - len(chunks))
        if not part:
            break
        chunks.extend(part)
    t.close()
    if len(chunks) != want or not valid(bytes(chunks)):
        sys.exit(5)
except Exception:
    sys.exit(6)

sys.exit(0)
PY
}

dns_probe() {
    if [ -n "$PROBE_OVERRIDE" ]; then
        "$PROBE_OVERRIDE"
    else
        default_dns_probe
    fi
}

postcheck() {
    running=$("$DOCKER" inspect -f '{{.State.Running}}' "$ADGUARD_CONTAINER" 2>/dev/null || true)
    [ "$running" = true ] || return 1

    awg_running=$("$DOCKER" inspect -f '{{.State.Running}}' "$AWG_CONTAINER" 2>/dev/null || true)
    [ "$awg_running" = true ] || return 1

    "$DOCKER" exec "$ADGUARD_CONTAINER" test -f "$CONF_PATH/AdGuardHome.yaml" >/dev/null 2>&1 || return 1

    nat=$("$DOCKER" exec "$AWG_CONTAINER" iptables-save -t nat 2>/dev/null || true)
    printf '%s\n' "$nat" | grep -E -- '(-p tcp|--protocol tcp).*--dport 53.*(REDIRECT|DNAT)' >/dev/null || return 1
    printf '%s\n' "$nat" | grep -E -- '(-p udp|--protocol udp).*--dport 53.*(REDIRECT|DNAT)' >/dev/null || return 1

    dns_probe || return 1
    return 0
}

validation_started=$(date +%s)

ensure_stopped || fail 'AdGuard container did not stop cleanly'
running=$("$DOCKER" inspect -f '{{.State.Running}}' "$ADGUARD_CONTAINER" 2>/dev/null || true)
[ "$running" = false ] || fail 'AdGuard container still reports running after stop'

"$DOCKER" cp -a "$ADGUARD_CONTAINER:$CONF_PATH/." "$work/snapshot/conf/" >/dev/null
"$DOCKER" cp -a "$ADGUARD_CONTAINER:$WORK_PATH/." "$work/snapshot/work/" >/dev/null

[ -f "$work/snapshot/conf/AdGuardHome.yaml" ] || fail 'quiescent AdGuard snapshot is incomplete: AdGuardHome.yaml missing'

build_manifest "$work/snapshot" "$work/snapshot.MANIFEST.sha256"
[ -s "$work/snapshot.MANIFEST.sha256" ] || fail 'quiescent snapshot manifest is empty'
snapshot_ready=1

restore_snapshot || fail 'copying the quiescent AdGuard snapshot back into the stopped container failed'
verify_stopped_roundtrip || fail 'AdGuard stopped-container restore did not reproduce the exact snapshot bytes'

ensure_started || fail 'AdGuard container did not start after restore'

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

[ "$post_ok" -eq 1 ] || fail 'AdGuard post-restore runtime/DNS verification failed'

validation_finished=$(date +%s)
window=$((validation_finished - validation_started))

field schema 1
field target adguard
field mode validate
field readiness PASS
field quiescent_snapshot PASS
field stopped_restore_roundtrip PASS
field container_recreated false
field image_load false
field awg_touched false
field config_present PASS
field awg_dns_redirect PASS
field dns_udp_53 PASS
field dns_tcp_53 PASS
field validation_window_seconds "$window"
field live_restore_validated true
field result PASS

success=1
printf '%s\n' '[PASS] controlled live AdGuard same-state restore validation completed'
