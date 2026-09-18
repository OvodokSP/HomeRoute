#!/bin/sh
# Verify an existing HomeRoute AWG backup without restoring it.

set -eu

dir=${1:-}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

[ -n "$dir" ] || fail 'usage: verify-awg-backup.sh <backup-directory>'
[ -d "$dir" ] || fail "backup directory does not exist: $dir"
[ -f "$dir/MANIFEST.sha256" ] || fail 'MANIFEST.sha256 is missing'
[ -f "$dir/metadata.txt" ] || fail 'metadata.txt is missing'
[ -f "$dir/awg/awg0.conf" ] || fail 'awg0.conf is missing'
[ -f "$dir/start.sh" ] || fail 'start.sh is missing'

(
    cd "$dir"
    sha256sum -c MANIFEST.sha256 >/dev/null
) || fail 'backup checksum verification failed'

file_count=$(find "$dir/awg" -type f | wc -l | tr -d ' ')
printf 'HOMEROUTE_VPS_BACKUP_VERIFY schema=1 result=PASS files=%s\n' "$file_count"
printf '%s\n' '[PASS] AWG backup integrity verified; no restore was performed'
