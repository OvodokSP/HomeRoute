#!/bin/sh
set -eu

dir=${1:-}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

[ -n "$dir" ] || fail 'usage: verify-container-image-backup.sh <backup-directory>'
[ -d "$dir" ] || fail 'backup directory is missing'
[ -f "$dir/image.tar" ] || fail 'image.tar is missing'
[ -f "$dir/IMAGE.sha256" ] || fail 'IMAGE.sha256 is missing'
[ -f "$dir/metadata.txt" ] || fail 'metadata.txt is missing'

(
    cd "$dir"
    sha256sum -c IMAGE.sha256 >/dev/null
) || fail 'image archive checksum verification failed'

tar -tf "$dir/image.tar" >/dev/null || fail 'image archive is not a readable tar'
printf '%s\n' 'HOMEROUTE_IMAGE_BACKUP_VERIFY schema=1 result=PASS'
printf '%s\n' '[PASS] Docker image rescue archive integrity verified; image was not loaded'
