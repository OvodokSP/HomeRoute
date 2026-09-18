#!/bin/sh
# Verify global opkg status-database rescue extension for HRNeo.

set -eu

RESCUE=${1:-}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFY %s=%s\n' "$1" "$2"
}

[ -n "$RESCUE" ] || fail 'usage: verify-hrneo-opkg-status.sh <rescue-dir>'
[ -d "$RESCUE" ] || fail "rescue directory missing: $RESCUE"
[ -d "$RESCUE/package-database" ] || fail 'package-database directory missing'
[ -f "$RESCUE/package-database/opkg-status" ] || fail 'saved opkg-status missing'
[ -f "$RESCUE/package-database/hrneo-status-stanza.txt" ] || fail 'saved HRNeo status stanza missing'
[ -f "$RESCUE/opkg-status-rescue-metadata.txt" ] || fail 'opkg status rescue metadata missing'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum unavailable'

meta() {
    key=$1
    sed -n "s/^${key}=//p" "$RESCUE/opkg-status-rescue-metadata.txt" | sed -n '1p'
}

[ "$(meta schema)" = 1 ] || fail 'unexpected status rescue metadata schema'
[ "$(meta package)" = hrneo ] || fail 'unexpected package in status rescue metadata'
[ "$(meta version)" = 3.18.3-1 ] || fail 'unexpected package version in status rescue metadata'
[ "$(meta package_change)" = false ] || fail 'metadata incorrectly claims package change'
[ "$(meta service_restart)" = false ] || fail 'metadata incorrectly claims service restart'
[ "$(meta network_change)" = false ] || fail 'metadata incorrectly claims network change'

db_sha=$(sha256sum "$RESCUE/package-database/opkg-status" | awk '{print $1}')
stanza_sha=$(sha256sum "$RESCUE/package-database/hrneo-status-stanza.txt" | awk '{print $1}')
db_bytes=$(wc -c < "$RESCUE/package-database/opkg-status" | tr -d '[:space:]')

[ "$db_sha" = "$(meta status_database_sha256)" ] ||
    fail 'saved opkg status database SHA256 mismatch'
[ "$stanza_sha" = "$(meta hrneo_status_stanza_sha256)" ] ||
    fail 'saved HRNeo status stanza SHA256 mismatch'
[ "$db_bytes" = "$(meta status_database_bytes)" ] ||
    fail 'saved opkg status database size mismatch'

grep -Fx 'Package: hrneo' "$RESCUE/package-database/hrneo-status-stanza.txt" >/dev/null ||
    fail 'saved status stanza package mismatch'
grep -Fx 'Version: 3.18.3-1' "$RESCUE/package-database/hrneo-status-stanza.txt" >/dev/null ||
    fail 'saved status stanza version mismatch'
grep -E '^Status: .* installed$' "$RESCUE/package-database/hrneo-status-stanza.txt" >/dev/null ||
    fail 'saved status stanza does not mark HRNeo installed'

field schema 1
field package hrneo
field version 3.18.3-1
field status_database_sha256 "$db_sha"
field status_database_bytes "$db_bytes"
field hrneo_status_stanza_sha256 "$stanza_sha"
field result PASS
printf '%s\n' '[PASS] global opkg status-database rescue integrity verified; no live state was changed'
