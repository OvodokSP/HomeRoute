#!/bin/sh
# Verify a complete local HomeRoute VPS rescue set.
# Read-only. Does not load images or restore state.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

AWG_STATE=${HOMEROUTE_AWG_STATE_BACKUP:-}
ADGUARD_STATE=${HOMEROUTE_ADGUARD_STATE_BACKUP:-}
AWG_IMAGE=${HOMEROUTE_AWG_IMAGE_BACKUP:-}
ADGUARD_IMAGE=${HOMEROUTE_ADGUARD_IMAGE_BACKUP:-}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

for name in AWG_STATE ADGUARD_STATE AWG_IMAGE ADGUARD_IMAGE; do
    eval "value=\${$name:-}"
    [ -n "$value" ] || fail "missing required rescue-set variable: HOMEROUTE_$name"
    [ -d "$value" ] || fail "rescue-set directory is missing for $name"
done

sh "$SCRIPT_DIR/verify-awg-backup.sh" "$AWG_STATE" >/dev/null
sh "$SCRIPT_DIR/verify-adguard-backup.sh" "$ADGUARD_STATE" >/dev/null
sh "$SCRIPT_DIR/verify-container-image-backup.sh" "$AWG_IMAGE" >/dev/null
sh "$SCRIPT_DIR/verify-container-image-backup.sh" "$ADGUARD_IMAGE" >/dev/null

awg_image_id=$(sed -n 's/^image_id=//p' "$AWG_IMAGE/metadata.txt")
adguard_image_id=$(sed -n 's/^image_id=//p' "$ADGUARD_IMAGE/metadata.txt")

[ -n "$awg_image_id" ] || fail 'AWG image metadata has no image_id'
[ -n "$adguard_image_id" ] || fail 'AdGuard image metadata has no image_id'
[ "$awg_image_id" != "$adguard_image_id" ] || fail 'AWG and AdGuard image IDs unexpectedly match'

printf '%s\n' 'HOMEROUTE_RESCUE_SET schema=1 result=PASS artifacts=4'
printf 'HOMEROUTE_RESCUE_SET awg_image_id=%s\n' "$awg_image_id"
printf 'HOMEROUTE_RESCUE_SET adguard_image_id=%s\n' "$adguard_image_id"
printf '%s\n' '[PASS] complete VPS rescue set integrity verified; no image load or state restore was performed'
