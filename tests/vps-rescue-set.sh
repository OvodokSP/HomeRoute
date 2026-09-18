#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERIFY_SET="$ROOT/vps/verify-rescue-set.sh"
BASE=${TMPDIR:-/tmp}/homeroute-rescue-set-test.$$
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BASE/awg-state/awg" "$BASE/adguard-state/conf" "$BASE/adguard-state/work"          "$BASE/awg-image" "$BASE/adguard-image"

printf '%s\n' '[Interface]' > "$BASE/awg-state/awg/awg0.conf"
printf '%s\n' '#!/bin/sh' > "$BASE/awg-state/start.sh"
printf '%s\n' 'schema=1' > "$BASE/awg-state/metadata.txt"
(
 cd "$BASE/awg-state"
 : > MANIFEST.sha256
 sha256sum awg/awg0.conf start.sh metadata.txt >> MANIFEST.sha256
)

printf '%s\n' 'config' > "$BASE/adguard-state/conf/AdGuardHome.yaml"
printf '%s\n' 'work' > "$BASE/adguard-state/work/data.db"
printf '%s\n' 'schema=1' > "$BASE/adguard-state/metadata.txt"
(
 cd "$BASE/adguard-state"
 : > MANIFEST.sha256
 sha256sum conf/AdGuardHome.yaml work/data.db metadata.txt >> MANIFEST.sha256
)

make_image_backup() {
    dir=$1
    id=$2
    mkdir -p "$dir/tar-src"
    printf '%s\n' '[{"Config":"config.json","RepoTags":[],"Layers":[]}]' > "$dir/tar-src/manifest.json"
    tar -cf "$dir/image.tar" -C "$dir/tar-src" manifest.json
    rm -rf "$dir/tar-src"
    printf 'image_id=%s\n' "$id" > "$dir/metadata.txt"
    (
      cd "$dir"
      sha256sum image.tar > IMAGE.sha256
    )
}

make_image_backup "$BASE/awg-image" sha256:awgfixture
make_image_backup "$BASE/adguard-image" sha256:adguardfixture

out=$(HOMEROUTE_AWG_STATE_BACKUP="$BASE/awg-state"       HOMEROUTE_ADGUARD_STATE_BACKUP="$BASE/adguard-state"       HOMEROUTE_AWG_IMAGE_BACKUP="$BASE/awg-image"       HOMEROUTE_ADGUARD_IMAGE_BACKUP="$BASE/adguard-image"       sh "$VERIFY_SET")

printf '%s\n' "$out" | grep -Fx 'HOMEROUTE_RESCUE_SET schema=1 result=PASS artifacts=4' >/dev/null ||
    fail 'rescue-set pass marker missing'
printf '%s\n' "$out" | grep -Fx 'HOMEROUTE_RESCUE_SET awg_image_id=sha256:awgfixture' >/dev/null ||
    fail 'AWG image ID missing'
printf '%s\n' "$out" | grep -Fx 'HOMEROUTE_RESCUE_SET adguard_image_id=sha256:adguardfixture' >/dev/null ||
    fail 'AdGuard image ID missing'

rm -f "$BASE/adguard-state/work/data.db"
if HOMEROUTE_AWG_STATE_BACKUP="$BASE/awg-state"    HOMEROUTE_ADGUARD_STATE_BACKUP="$BASE/adguard-state"    HOMEROUTE_AWG_IMAGE_BACKUP="$BASE/awg-image"    HOMEROUTE_ADGUARD_IMAGE_BACKUP="$BASE/adguard-image"    sh "$VERIFY_SET" >/dev/null 2>&1; then
    fail 'incomplete rescue set unexpectedly verified'
fi

printf '%s\n' '[PASS] complete VPS rescue-set verification contract'
