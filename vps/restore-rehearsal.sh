#!/bin/sh
# HomeRoute VPS isolated container restore rehearsal.
#
# plan: read-only description.
# rehearse: creates two temporary STOPPED containers with --network none,
# copies the already-verified state backups into them, copies them back out,
# re-verifies checksums, then removes the temporary containers.
#
# It never stops/restarts the live AWG2/AdGuard containers, never starts the
# temporary containers, never loads images, and never changes systemd/iptables.

set -eu
umask 077

MODE=${1:-plan}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
READINESS=${HOMEROUTE_RESTORE_READINESS:-$SCRIPT_DIR/preflight-live-restore.sh}
VERIFY_AWG=${HOMEROUTE_VERIFY_AWG_BACKUP:-$SCRIPT_DIR/verify-awg-backup.sh}
VERIFY_ADGUARD=${HOMEROUTE_VERIFY_ADGUARD_BACKUP:-$SCRIPT_DIR/verify-adguard-backup.sh}
DOCKER=${HOMEROUTE_DOCKER_BIN:-docker}

BACKUP_ROOT=${HOMEROUTE_BACKUP_ROOT:-/root/homeroute-backups}
AWG_STATE=${HOMEROUTE_AWG_STATE_BACKUP:-$BACKUP_ROOT/awg-state-20260918T103646Z}
ADGUARD_STATE=${HOMEROUTE_ADGUARD_STATE_BACKUP:-$BACKUP_ROOT/adguard-state-20260918T110820Z}
AWG_IMAGE=${HOMEROUTE_AWG_IMAGE_BACKUP:-$BACKUP_ROOT/image-awg2-20260918T110821Z}
ADGUARD_IMAGE=${HOMEROUTE_ADGUARD_IMAGE_BACKUP:-$BACKUP_ROOT/image-adguard-20260918T110822Z}
ACK=${HOMEROUTE_RESTORE_REHEARSAL_ACK:-}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_RESTORE_REHEARSAL %s=%s\n' "$1" "$2"
}

show_plan() {
    field schema 1
    field mode plan
    field live_containers_touched false
    field temp_containers_started false
    field temp_network none
    field image_load false
    field state_restore_target temporary_stopped_containers
    field cleanup_required true
    field live_restore_validated false
    printf '%s\n' '[PASS] rehearsal plan rendered; no Docker or filesystem changes were made'
}

case "$MODE" in
    plan|--plan)
        show_plan
        exit 0
        ;;
    rehearse|--rehearse)
        ;;
    help|--help|-h)
        printf '%s\n' 'Usage: restore-rehearsal.sh [plan|rehearse]'
        exit 0
        ;;
    *)
        fail "unknown mode: $MODE"
        ;;
esac

[ "$ACK" = YES ] || fail 'set HOMEROUTE_RESTORE_REHEARSAL_ACK=YES to run the isolated rehearsal'
[ -f "$READINESS" ] || fail "readiness gate missing: $READINESS"
[ -f "$VERIFY_AWG" ] || fail "AWG verifier missing: $VERIFY_AWG"
[ -f "$VERIFY_ADGUARD" ] || fail "AdGuard verifier missing: $VERIFY_ADGUARD"

command -v "$DOCKER" >/dev/null 2>&1 || fail 'docker command is unavailable'
"$DOCKER" info >/dev/null 2>&1 || fail 'docker daemon is unavailable'

HOMEROUTE_AWG_STATE_BACKUP="$AWG_STATE" \
HOMEROUTE_ADGUARD_STATE_BACKUP="$ADGUARD_STATE" \
HOMEROUTE_AWG_IMAGE_BACKUP="$AWG_IMAGE" \
HOMEROUTE_ADGUARD_IMAGE_BACKUP="$ADGUARD_IMAGE" \
sh "$READINESS" >/dev/null || fail 'restore readiness gate did not pass'

awg_image_id=$(sed -n 's/^image_id=//p' "$AWG_IMAGE/metadata.txt" | sed -n '1p')
adguard_image_id=$(sed -n 's/^image_id=//p' "$ADGUARD_IMAGE/metadata.txt" | sed -n '1p')
[ -n "$awg_image_id" ] || fail 'AWG image ID unavailable'
[ -n "$adguard_image_id" ] || fail 'AdGuard image ID unavailable'

"$DOCKER" image inspect "$awg_image_id" >/dev/null 2>&1 || fail 'AWG rescue image is not present locally'
"$DOCKER" image inspect "$adguard_image_id" >/dev/null 2>&1 || fail 'AdGuard rescue image is not present locally'

scratch=${HOMEROUTE_RESTORE_REHEARSAL_ROOT:-/tmp/homeroute-restore-rehearsal.$$}
case "$scratch" in
    /tmp/homeroute-restore-rehearsal.*) ;;
    *) fail 'rehearsal root must be /tmp/homeroute-restore-rehearsal.*' ;;
esac
[ ! -e "$scratch" ] || fail "rehearsal root already exists: $scratch"
mkdir -p "$scratch/out-awg" "$scratch/out-adguard"
chmod 700 "$scratch" "$scratch/out-awg" "$scratch/out-adguard"

awg_name="homeroute-restore-awg-$$"
adguard_name="homeroute-restore-adguard-$$"
awg_created=0
adguard_created=0

cleanup() {
    if [ "$awg_created" -eq 1 ]; then
        "$DOCKER" rm -f "$awg_name" >/dev/null 2>&1 || true
    fi
    if [ "$adguard_created" -eq 1 ]; then
        "$DOCKER" rm -f "$adguard_name" >/dev/null 2>&1 || true
    fi
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

"$DOCKER" create --network none --name "$awg_name" "$awg_image_id" >/dev/null
awg_created=1
"$DOCKER" create --network none --name "$adguard_name" "$adguard_image_id" >/dev/null
adguard_created=1

# The temporary containers are intentionally never started.
awg_status=$("$DOCKER" inspect -f '{{.State.Status}}' "$awg_name" 2>/dev/null || true)
adguard_status=$("$DOCKER" inspect -f '{{.State.Status}}' "$adguard_name" 2>/dev/null || true)
[ "$awg_status" = created ] || fail 'temporary AWG container was not left stopped/created'
[ "$adguard_status" = created ] || fail 'temporary AdGuard container was not left stopped/created'

awg_base=$(basename "$AWG_STATE")
adguard_base=$(basename "$ADGUARD_STATE")

"$DOCKER" cp "$AWG_STATE" "$awg_name:/tmp/" >/dev/null
"$DOCKER" cp "$ADGUARD_STATE" "$adguard_name:/tmp/" >/dev/null

"$DOCKER" cp "$awg_name:/tmp/$awg_base" "$scratch/out-awg/" >/dev/null
"$DOCKER" cp "$adguard_name:/tmp/$adguard_base" "$scratch/out-adguard/" >/dev/null

sh "$VERIFY_AWG" "$scratch/out-awg/$awg_base" >/dev/null ||
    fail 'AWG backup failed checksum verification after container round-trip'
sh "$VERIFY_ADGUARD" "$scratch/out-adguard/$adguard_base" >/dev/null ||
    fail 'AdGuard backup failed checksum verification after container round-trip'

field schema 1
field mode rehearse
field rescue_readiness PASS
field awg_roundtrip PASS
field adguard_roundtrip PASS
field temp_containers_started false
field temp_network none
field live_containers_touched false
field image_load false
field live_restore_validated false
field result PASS

printf '%s\n' '[PASS] isolated Docker restore rehearsal completed; live containers were not touched'
