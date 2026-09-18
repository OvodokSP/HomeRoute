#!/bin/sh
# Extend an existing verified HRNeo rescue set with opkg control metadata and
# postinst side-effect state. No package/service/network changes are performed.

set -eu
umask 077

MODE=${1:-plan}
RESCUE=${2:-}
ACK=${HOMEROUTE_HRNEO_OPKG_RESCUE_ACK:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERIFY_RESCUE=${HOMEROUTE_HRNEO_RESCUE_VERIFIER:-$SCRIPT_DIR/verify-hrneo-rescue.sh}
ARTIFACT_TOOL=${HOMEROUTE_HRNEO_ARTIFACT_TOOL:-$SCRIPT_DIR/hrneo-artifact.sh}
INFO_DIR=${HOMEROUTE_OPKG_INFO_DIR:-/opt/lib/opkg/info}
LIVE_ROOT=${HOMEROUTE_HRNEO_LIVE_ROOT:-}
TEST_MODE=${HOMEROUTE_HRNEO_OPKG_RESCUE_TEST_MODE:-0}

EXPECTED_POSTINST_SHA256=ff4192e0d9532f4df550687625efd698c5bcdc3659cdb40d75517d36f0409c2e
EXPECTED_CONFFILES_SHA256=255dc6d5a636b8645d0e306224df597afa1e7529a8b85647c83c14efe6280f5d

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_HRNEO_OPKG_RESCUE %s=%s\n' "$1" "$2"
}

show_plan() {
    field schema 1
    field mode plan
    field package hrneo
    field opkg_metadata_capture true
    field postinst_semantic_check true
    field side_effect_backup true
    field package_change false
    field service_restart false
    field network_change false
    field result PLAN_ONLY
    printf '%s\n' '[PASS] HRNeo opkg/control rescue plan rendered; no state changed'
}

case "$MODE" in
    plan|--plan)
        show_plan
        exit 0
        ;;
    capture|--capture)
        ;;
    help|--help|-h)
        printf '%s\n' 'Usage: capture-hrneo-opkg-state.sh [plan|capture <rescue-dir>]'
        exit 0
        ;;
    *)
        fail "unknown mode: $MODE"
        ;;
esac

[ -n "$RESCUE" ] || fail 'rescue directory is required'
[ "$ACK" = YES ] || fail 'set HOMEROUTE_HRNEO_OPKG_RESCUE_ACK=YES to extend the rescue set'
[ -d "$RESCUE" ] || fail "rescue directory missing: $RESCUE"
[ -f "$VERIFY_RESCUE" ] || fail "base rescue verifier missing: $VERIFY_RESCUE"
[ -f "$ARTIFACT_TOOL" ] || fail "artifact verifier missing: $ARTIFACT_TOOL"
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum unavailable'
command -v cp >/dev/null 2>&1 || fail 'cp unavailable'
command -v readlink >/dev/null 2>&1 || fail 'readlink unavailable'

if [ "$TEST_MODE" = 1 ]; then
    case "$RESCUE" in
        /tmp/homeroute-hrneo-rescue-test.*/*) ;;
        *) fail 'unsafe test rescue directory' ;;
    esac
    case "$INFO_DIR" in
        /tmp/homeroute-hrneo-opkg-info-test.*) ;;
        *) fail 'unsafe test opkg info directory' ;;
    esac
    case "$LIVE_ROOT" in
        /tmp/homeroute-hrneo-live-test.*) ;;
        *) fail 'unsafe test live root' ;;
    esac
else
    case "$RESCUE" in
        /opt/homeroute-backups/hrneo-rescue-*) ;;
        *) fail 'live rescue directory must be under /opt/homeroute-backups/hrneo-rescue-*' ;;
    esac
    [ "$INFO_DIR" = /opt/lib/opkg/info ] || fail 'live opkg info directory override is forbidden'
    [ -z "$LIVE_ROOT" ] || fail 'live root override is forbidden'
fi

HOMEROUTE_HRNEO_ARTIFACT_TOOL="$ARTIFACT_TOOL" sh "$VERIFY_RESCUE" "$RESCUE" >/dev/null ||
    fail 'base HRNeo rescue set did not verify before extension'

postinst="$INFO_DIR/hrneo.postinst"
conffiles="$INFO_DIR/hrneo.conffiles"
[ -f "$postinst" ] || fail "installed postinst missing: $postinst"
[ -f "$conffiles" ] || fail "installed conffiles metadata missing: $conffiles"

postinst_sha=$(sha256sum "$postinst" | awk '{print $1}')
conffiles_sha=$(sha256sum "$conffiles" | awk '{print $1}')
[ "$postinst_sha" = "$EXPECTED_POSTINST_SHA256" ] ||
    fail "installed hrneo.postinst differs from pinned source: $postinst_sha"
[ "$conffiles_sha" = "$EXPECTED_CONFFILES_SHA256" ] ||
    fail "installed hrneo.conffiles differs from pinned source: $conffiles_sha"
sh -n "$postinst" || fail 'installed hrneo.postinst has invalid shell syntax'

for unexpected in hrneo.preinst hrneo.prerm hrneo.postrm; do
    [ ! -e "$INFO_DIR/$unexpected" ] ||
        fail "unexpected maintainer script exists: $unexpected"
done

pattern_symlink=false
pattern_rc_unslung=false
pattern_stop=false
pattern_start=false
pattern_network_mutation=false
pattern_remove=false

grep -Fq 'ln -sf /opt/etc/init.d/S99hrneo /opt/bin/neo' "$postinst" && pattern_symlink=true
grep -Fq 'rc.unslung' "$postinst" && grep -Fq 'sleep 10' "$postinst" && pattern_rc_unslung=true
grep -Fq '/opt/etc/init.d/S99hrneo stop' "$postinst" && pattern_stop=true
grep -Fq '/opt/etc/init.d/S99hrneo start' "$postinst" && pattern_start=true
grep -Eq '(^|[;&|[:space:]])(iptables|ipset|ip)[[:space:]]+(rule|route|link|addr|set|add|del|flush|create|destroy)' "$postinst" &&
    pattern_network_mutation=true || true
grep -Eq '(^|[;&|[:space:]])rm[[:space:]]' "$postinst" && pattern_remove=true || true

[ "$pattern_symlink" = true ] || fail 'pinned postinst symlink behavior was not found'
[ "$pattern_rc_unslung" = true ] || fail 'pinned postinst rc.unslung behavior was not found'
[ "$pattern_stop" = true ] && [ "$pattern_start" = true ] ||
    fail 'pinned postinst stop/start behavior was not found'
[ "$pattern_network_mutation" = false ] || fail 'unexpected network mutation pattern in installed postinst'
[ "$pattern_remove" = false ] || fail 'unexpected rm pattern in installed postinst'

neo_path="$LIVE_ROOT/opt/bin/neo"
rc_path="$LIVE_ROOT/opt/etc/init.d/rc.unslung"
[ -L "$neo_path" ] || fail 'current /opt/bin/neo is not a symlink'
neo_target=$(readlink "$neo_path")
[ "$neo_target" = /opt/etc/init.d/S99hrneo ] ||
    fail "unexpected /opt/bin/neo target: $neo_target"
[ -f "$rc_path" ] || fail 'rc.unslung is missing'
grep -Fq '[ $ACTION = start ] && sleep 10' "$rc_path" ||
    fail 'expected HRNeo rc.unslung start-delay line is missing'

opkg_dst="$RESCUE/opkg-info"
side_dst="$RESCUE/package-side-effects"
[ ! -e "$opkg_dst" ] || fail 'opkg-info rescue directory already exists'
[ ! -e "$side_dst" ] || fail 'package-side-effects rescue directory already exists'
mkdir -p "$opkg_dst" "$side_dst"
chmod 700 "$opkg_dst" "$side_dst"

: > "$RESCUE/OPKG_INFO.sha256"
: > "$RESCUE/OPKG_INFO_SYMLINKS.tsv"

info_files=0
info_symlinks=0
matched=0
for path in "$INFO_DIR"/hrneo.*; do
    [ -e "$path" ] || [ -L "$path" ] || continue
    matched=1
    name=$(basename "$path")
    case "$name" in
        hrneo.*) ;;
        *) fail "unsafe opkg info name: $name" ;;
    esac

    if [ -L "$path" ]; then
        cp -a "$path" "$opkg_dst/$name"
        target=$(readlink "$path")
        printf '%s\t%s\n' "$name" "$target" >> "$RESCUE/OPKG_INFO_SYMLINKS.tsv"
        info_symlinks=$((info_symlinks + 1))
    elif [ -f "$path" ]; then
        cp -a "$path" "$opkg_dst/$name"
        hash=$(sha256sum "$opkg_dst/$name" | awk '{print $1}')
        printf '%s  %s\n' "$hash" "$name" >> "$RESCUE/OPKG_INFO.sha256"
        info_files=$((info_files + 1))
    else
        fail "unsupported opkg info object: $path"
    fi
done
[ "$matched" -eq 1 ] && [ "$info_files" -gt 0 ] || fail 'no hrneo opkg info files captured'

cp -a "$rc_path" "$side_dst/rc.unslung"
cp -a "$neo_path" "$side_dst/neo"
rc_sha=$(sha256sum "$side_dst/rc.unslung" | awk '{print $1}')
printf '%s  %s\n' "$rc_sha" 'rc.unslung' > "$RESCUE/SIDE_EFFECTS.sha256"
printf '%s\t%s\n' 'neo' "$neo_target" > "$RESCUE/SIDE_EFFECTS_SYMLINKS.tsv"

cat > "$RESCUE/opkg-rescue-metadata.txt" <<EOF
schema=1
package=hrneo
postinst_sha256=$postinst_sha
conffiles_sha256=$conffiles_sha
opkg_info_regular_files=$info_files
opkg_info_symlinks=$info_symlinks
neo_symlink_target=$neo_target
rc_unslung_sha256=$rc_sha
postinst_pattern_symlink=$pattern_symlink
postinst_pattern_rc_unslung=$pattern_rc_unslung
postinst_pattern_stop=$pattern_stop
postinst_pattern_start=$pattern_start
postinst_pattern_network_mutation=$pattern_network_mutation
postinst_pattern_remove=$pattern_remove
package_change=false
service_restart=false
network_change=false
EOF

chmod 600 "$RESCUE/OPKG_INFO.sha256" "$RESCUE/OPKG_INFO_SYMLINKS.tsv"     "$RESCUE/SIDE_EFFECTS.sha256" "$RESCUE/SIDE_EFFECTS_SYMLINKS.tsv"     "$RESCUE/opkg-rescue-metadata.txt"

field schema 1
field mode capture
field package hrneo
field postinst_sha256 "$postinst_sha"
field postinst_sha_match true
field conffiles_sha_match true
field maintainer_scripts postinst_only
field postinst_symlink_neo true
field postinst_rc_unslung_guard true
field postinst_stop_start true
field postinst_network_mutation false
field postinst_remove false
field current_neo_symlink_expected true
field current_rc_unslung_patch_present true
field opkg_info_regular_files "$info_files"
field opkg_info_symlinks "$info_symlinks"
field package_change false
field service_restart false
field network_change false
field result PASS
printf '%s\n' '[PASS] HRNeo opkg/control and postinst side-effect state captured; live package/runtime state was not changed'
