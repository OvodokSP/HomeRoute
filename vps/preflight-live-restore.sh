#!/bin/sh
# HomeRoute VPS live-restore readiness gate.
# Read-only: verifies rescue artifacts and current container/image identity.
# Does not stop/restart containers, load images, copy state, or change Docker/systemd/iptables.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERIFY_SET=${HOMEROUTE_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-rescue-set.sh}

AWG_CONTAINER=${AWG_CONTAINER:-amnezia-awg2}
ADGUARD_CONTAINER=${ADGUARD_CONTAINER:-adguard-home}

BACKUP_ROOT=${HOMEROUTE_BACKUP_ROOT:-/root/homeroute-backups}
AWG_STATE=${HOMEROUTE_AWG_STATE_BACKUP:-$BACKUP_ROOT/awg-state-20260918T103646Z}
ADGUARD_STATE=${HOMEROUTE_ADGUARD_STATE_BACKUP:-$BACKUP_ROOT/adguard-state-20260918T110820Z}
AWG_IMAGE=${HOMEROUTE_AWG_IMAGE_BACKUP:-$BACKUP_ROOT/image-awg2-20260918T110821Z}
ADGUARD_IMAGE=${HOMEROUTE_ADGUARD_IMAGE_BACKUP:-$BACKUP_ROOT/image-adguard-20260918T110822Z}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_RESTORE_READINESS %s=%s\n' "$1" "$2"
}

[ -x "$VERIFY_SET" ] || [ -f "$VERIFY_SET" ] || fail "rescue verifier is missing: $VERIFY_SET"
command -v docker >/dev/null 2>&1 || fail 'docker command is unavailable'
docker info >/dev/null 2>&1 || fail 'docker daemon is unavailable'

HOMEROUTE_AWG_STATE_BACKUP="$AWG_STATE" \
HOMEROUTE_ADGUARD_STATE_BACKUP="$ADGUARD_STATE" \
HOMEROUTE_AWG_IMAGE_BACKUP="$AWG_IMAGE" \
HOMEROUTE_ADGUARD_IMAGE_BACKUP="$ADGUARD_IMAGE" \
sh "$VERIFY_SET" >/dev/null || fail 'complete rescue-set verification failed'

for dir in "$AWG_IMAGE" "$ADGUARD_IMAGE"; do
    [ -f "$dir/metadata.txt" ] || fail "image backup metadata missing: $dir"
done

expected_awg_image=$(sed -n 's/^image_id=//p' "$AWG_IMAGE/metadata.txt" | sed -n '1p')
expected_adguard_image=$(sed -n 's/^image_id=//p' "$ADGUARD_IMAGE/metadata.txt" | sed -n '1p')
[ -n "$expected_awg_image" ] || fail 'AWG image backup has no image_id'
[ -n "$expected_adguard_image" ] || fail 'AdGuard image backup has no image_id'

awg_status=$(docker inspect -f '{{.State.Status}}' "$AWG_CONTAINER" 2>/dev/null || true)
adguard_status=$(docker inspect -f '{{.State.Status}}' "$ADGUARD_CONTAINER" 2>/dev/null || true)
[ "$awg_status" = running ] || fail "AWG container is not running: $AWG_CONTAINER"
[ "$adguard_status" = running ] || fail "AdGuard container is not running: $ADGUARD_CONTAINER"

current_awg_image=$(docker inspect -f '{{.Image}}' "$AWG_CONTAINER" 2>/dev/null || true)
current_adguard_image=$(docker inspect -f '{{.Image}}' "$ADGUARD_CONTAINER" 2>/dev/null || true)
[ -n "$current_awg_image" ] || fail 'current AWG image ID unavailable'
[ -n "$current_adguard_image" ] || fail 'current AdGuard image ID unavailable'

awg_match=false
adguard_match=false
[ "$current_awg_image" = "$expected_awg_image" ] && awg_match=true
[ "$current_adguard_image" = "$expected_adguard_image" ] && adguard_match=true

field schema 1
field rescue_set_integrity PASS
field awg_container_state running
field adguard_container_state running
field awg_image_matches_rescue "$awg_match"
field adguard_image_matches_rescue "$adguard_match"

[ "$awg_match" = true ] || fail 'current AWG container image differs from rescue image'
[ "$adguard_match" = true ] || fail 'current AdGuard container image differs from rescue image'

field live_restore_executed false
field image_load_executed false
field container_restart_executed false
field result READY_FOR_CONTROLLED_VALIDATION

printf '%s\n' '[PASS] live-restore readiness gate passed; no live state was changed'
