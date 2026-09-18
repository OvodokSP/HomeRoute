#!/bin/sh
# Verify HRNeo opkg/control metadata and postinst side-effect rescue extension.

set -eu

RESCUE=${1:-}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFY %s=%s\n' "$1" "$2"
}

[ -n "$RESCUE" ] || fail 'usage: verify-hrneo-opkg-state.sh <rescue-dir>'
[ -d "$RESCUE" ] || fail "rescue directory missing: $RESCUE"
[ -d "$RESCUE/opkg-info" ] || fail 'opkg-info directory missing'
[ -d "$RESCUE/package-side-effects" ] || fail 'package-side-effects directory missing'
[ -f "$RESCUE/OPKG_INFO.sha256" ] || fail 'OPKG_INFO.sha256 missing'
[ -f "$RESCUE/OPKG_INFO_SYMLINKS.tsv" ] || fail 'OPKG_INFO_SYMLINKS.tsv missing'
[ -f "$RESCUE/SIDE_EFFECTS.sha256" ] || fail 'SIDE_EFFECTS.sha256 missing'
[ -f "$RESCUE/SIDE_EFFECTS_SYMLINKS.tsv" ] || fail 'SIDE_EFFECTS_SYMLINKS.tsv missing'
[ -f "$RESCUE/opkg-rescue-metadata.txt" ] || fail 'opkg-rescue-metadata.txt missing'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum unavailable'
command -v readlink >/dev/null 2>&1 || fail 'readlink unavailable'

meta() {
    key=$1
    sed -n "s/^${key}=//p" "$RESCUE/opkg-rescue-metadata.txt" | sed -n '1p'
}

[ "$(meta schema)" = 1 ] || fail 'unexpected opkg rescue metadata schema'
[ "$(meta package)" = hrneo ] || fail 'unexpected package in opkg rescue metadata'
[ "$(meta postinst_sha256)" = ff4192e0d9532f4df550687625efd698c5bcdc3659cdb40d75517d36f0409c2e ] ||
    fail 'postinst SHA256 metadata drifted'
[ "$(meta conffiles_sha256)" = 255dc6d5a636b8645d0e306224df597afa1e7529a8b85647c83c14efe6280f5d ] ||
    fail 'conffiles SHA256 metadata drifted'
[ "$(meta neo_symlink_target)" = /opt/etc/init.d/S99hrneo ] ||
    fail 'neo symlink target metadata drifted'

for key in     postinst_pattern_symlink     postinst_pattern_rc_unslung     postinst_pattern_stop     postinst_pattern_start
do
    [ "$(meta "$key")" = true ] || fail "required semantic flag is not true: $key"
done

[ "$(meta postinst_pattern_network_mutation)" = false ] ||
    fail 'postinst network mutation flag is not false'
[ "$(meta postinst_pattern_remove)" = false ] ||
    fail 'postinst remove flag is not false'
[ "$(meta package_change)" = false ] ||
    fail 'capture metadata incorrectly claims package change'
[ "$(meta service_restart)" = false ] ||
    fail 'capture metadata incorrectly claims service restart'
[ "$(meta network_change)" = false ] ||
    fail 'capture metadata incorrectly claims network change'

(
    cd "$RESCUE/opkg-info"
    sha256sum -c ../OPKG_INFO.sha256 >/dev/null
) || fail 'opkg info checksum verification failed'

tab=$(printf '\t')
while IFS="$tab" read -r name target; do
    [ -n "$name" ] || continue
    case "$name" in
        hrneo.*) ;;
        *) fail "unsafe opkg info symlink name: $name" ;;
    esac
    path="$RESCUE/opkg-info/$name"
    [ -L "$path" ] || fail "expected opkg info symlink missing: $name"
    [ "$(readlink "$path")" = "$target" ] ||
        fail "opkg info symlink target mismatch: $name"
done < "$RESCUE/OPKG_INFO_SYMLINKS.tsv"

(
    cd "$RESCUE/package-side-effects"
    sha256sum -c ../SIDE_EFFECTS.sha256 >/dev/null
) || fail 'side-effect regular-file checksum verification failed'

while IFS="$tab" read -r name target; do
    [ -n "$name" ] || continue
    [ "$name" = neo ] || fail "unexpected side-effect symlink name: $name"
    path="$RESCUE/package-side-effects/$name"
    [ -L "$path" ] || fail 'saved neo symlink is missing'
    [ "$(readlink "$path")" = "$target" ] ||
        fail 'saved neo symlink target mismatch'
done < "$RESCUE/SIDE_EFFECTS_SYMLINKS.tsv"

info_files=$(awk 'NF {n++} END {print n+0}' "$RESCUE/OPKG_INFO.sha256")
info_symlinks=$(awk 'NF {n++} END {print n+0}' "$RESCUE/OPKG_INFO_SYMLINKS.tsv")

[ "$info_files" -gt 0 ] || fail 'opkg rescue contains no regular metadata files'
[ -f "$RESCUE/opkg-info/hrneo.postinst" ] || fail 'saved hrneo.postinst missing'
[ -f "$RESCUE/opkg-info/hrneo.conffiles" ] || fail 'saved hrneo.conffiles missing'
[ -f "$RESCUE/package-side-effects/rc.unslung" ] || fail 'saved rc.unslung missing'
[ -L "$RESCUE/package-side-effects/neo" ] || fail 'saved neo symlink missing'

field schema 1
field package hrneo
field postinst_sha_match true
field conffiles_sha_match true
field opkg_info_regular_files "$info_files"
field opkg_info_symlinks "$info_symlinks"
field side_effect_rc_unslung true
field side_effect_neo_symlink true
field result PASS
printf '%s\n' '[PASS] HRNeo opkg/control rescue extension integrity verified; no live state was changed'
