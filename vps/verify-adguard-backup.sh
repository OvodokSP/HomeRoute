#!/bin/sh
set -eu

dir=${1:-}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

[ -n "$dir" ] || fail 'usage: verify-adguard-backup.sh <backup-directory>'
[ -d "$dir" ] || fail 'backup directory is missing'
[ -f "$dir/conf/AdGuardHome.yaml" ] || fail 'AdGuardHome.yaml is missing'
[ -f "$dir/MANIFEST.sha256" ] || fail 'MANIFEST.sha256 is missing'
[ -f "$dir/metadata.txt" ] || fail 'metadata.txt is missing'

(
    cd "$dir"
    sha256sum -c MANIFEST.sha256 >/dev/null
) || fail 'AdGuard backup checksum verification failed'

file_count=$(find "$dir/conf" "$dir/work" -type f | wc -l | tr -d ' ')
printf 'HOMEROUTE_ADGUARD_BACKUP_VERIFY schema=1 result=PASS files=%s\n' "$file_count"
printf '%s\n' '[PASS] AdGuard backup integrity verified; no restore was performed'
