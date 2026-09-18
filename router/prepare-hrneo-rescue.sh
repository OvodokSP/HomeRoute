#!/bin/sh
# Capture a local HRNeo rescue set on the reference Keenetic/Entware system.
# This does not install/remove/restart packages or change networking.

set -eu
umask 077

MODE=${1:-plan}
ACK=${HOMEROUTE_HRNEO_RESCUE_ACK:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ARTIFACT_TOOL=${HOMEROUTE_HRNEO_ARTIFACT_TOOL:-$SCRIPT_DIR/hrneo-artifact.sh}
DOCTOR=${HOMEROUTE_ROUTER_DOCTOR:-$SCRIPT_DIR/doctor-router.sh}
BACKUP_ROOT=${HOMEROUTE_ROUTER_BACKUP_ROOT:-/opt/homeroute-backups}
TEST_MODE=${HOMEROUTE_HRNEO_RESCUE_TEST_MODE:-0}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_HRNEO_RESCUE %s=%s\n' "$1" "$2"
}

detect_arch() {
    opkg print-architecture 2>/dev/null |
    awk '
      $2=="aarch64-3.10" || $2=="mipsel-3.4" || $2=="mips-3.4" {
        print $2
      }
    '
}

installed_version() {
    opkg list-installed 2>/dev/null |
    awk '$1=="hrneo" && $2=="-" {print $3; exit}'
}

show_plan() {
    field schema 1
    field mode plan
    field package hrneo
    field expected_version 3.18.3-1
    field package_change false
    field service_restart false
    field network_change false
    field backup_root "$BACKUP_ROOT"
    field result PLAN_ONLY
    printf '%s\n' '[PASS] HRNeo rescue capture plan rendered; no state changed'
}

case "$MODE" in
    plan|--plan)
        show_plan
        exit 0
        ;;
    capture|--capture)
        ;;
    help|--help|-h)
        printf '%s\n' 'Usage: prepare-hrneo-rescue.sh [plan|capture]'
        exit 0
        ;;
    *)
        fail "unknown mode: $MODE"
        ;;
esac

[ "$ACK" = YES ] || fail 'set HOMEROUTE_HRNEO_RESCUE_ACK=YES to capture the local rescue set'

command -v opkg >/dev/null 2>&1 || fail 'opkg is unavailable'
command -v curl >/dev/null 2>&1 || fail 'curl is unavailable'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is unavailable'
command -v cp >/dev/null 2>&1 || fail 'cp is unavailable'
command -v readlink >/dev/null 2>&1 || fail 'readlink is unavailable'
[ -f "$ARTIFACT_TOOL" ] || fail "HRNeo artifact verifier missing: $ARTIFACT_TOOL"
[ -f "$DOCTOR" ] || fail "router doctor missing: $DOCTOR"

if [ "$TEST_MODE" = 1 ]; then
    case "$BACKUP_ROOT" in
        /tmp/homeroute-hrneo-rescue-test.*) ;;
        *) fail 'unsafe test backup root' ;;
    esac
else
    [ "$BACKUP_ROOT" = /opt/homeroute-backups ] || fail 'live backup root must be /opt/homeroute-backups'
fi

doctor_out=$(sh "$DOCTOR" 2>&1) || {
    printf '%s\n' "$doctor_out" >&2
    fail 'router doctor did not pass before rescue capture'
}
printf '%s\n' "$doctor_out" | grep -F 'result=PASS' >/dev/null ||
    fail 'router doctor PASS marker missing'

archs=$(detect_arch)
arch_count=$(printf '%s\n' "$archs" | awk 'NF {n++} END {print n+0}')
[ "$arch_count" -eq 1 ] || fail "expected exactly one supported Entware architecture, found: $arch_count"
arch=$(printf '%s\n' "$archs" | sed -n '1p')

version=$(installed_version)
[ "$version" = 3.18.3-1 ] || fail "installed HRNeo version is not the pinned baseline: ${version:-missing}"

artifact_plan=$(sh "$ARTIFACT_TOOL" plan "$arch")
filename=$(printf '%s\n' "$artifact_plan" | sed -n 's/^HOMEROUTE_HRNEO arch=[^ ]* filename=\([^ ]*\) size_bytes=.*/\1/p')
url=$(printf '%s\n' "$artifact_plan" | sed -n 's/^HOMEROUTE_HRNEO url=//p')
expected_sha=$(printf '%s\n' "$artifact_plan" | sed -n 's/^HOMEROUTE_HRNEO sha256=//p')
[ -n "$filename" ] && [ -n "$url" ] && [ -n "$expected_sha" ] ||
    fail 'could not resolve pinned HRNeo artifact metadata'

if [ "$TEST_MODE" != 1 ]; then
    avail_kib=$(df -kP /opt 2>/dev/null | awk 'NR==2 {print $4}')
    case "$avail_kib" in ''|*[!0-9]*) fail 'could not determine /opt free space' ;; esac
    [ "$avail_kib" -ge 4096 ] || fail "less than 4 MiB free on /opt: ${avail_kib} KiB"
fi

stamp=$(date -u +%Y%m%dT%H%M%SZ)
rescue="$BACKUP_ROOT/hrneo-rescue-$stamp"
[ ! -e "$rescue" ] || fail "rescue directory already exists: $rescue"

mkdir -p "$rescue/files"
chmod 700 "$BACKUP_ROOT" 2>/dev/null || true
chmod 700 "$rescue" "$rescue/files"

package_files="$rescue/package-files.txt"
opkg files hrneo 2>/dev/null | awk '/^\// {print}' | LC_ALL=C sort -u > "$package_files"
[ -s "$package_files" ] || fail 'opkg did not report any HRNeo package-owned paths'

: > "$rescue/FILES.sha256"
: > "$rescue/SYMLINKS.tsv"

file_count=0
symlink_count=0
dir_count=0
missing_count=0

while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
        /opt/*) ;;
        *) fail "package-owned path is outside /opt: $path" ;;
    esac

    rel=${path#/}
    case "$rel" in
        *'..'*)
            fail "unsafe package-owned path: $path"
            ;;
    esac

    if [ -L "$path" ]; then
        target=$(readlink "$path")
        mkdir -p "$rescue/files/$(dirname "$rel")"
        cp -a "$path" "$rescue/files/$rel"
        printf '%s\t%s\n' "$rel" "$target" >> "$rescue/SYMLINKS.tsv"
        symlink_count=$((symlink_count + 1))
    elif [ -f "$path" ]; then
        mkdir -p "$rescue/files/$(dirname "$rel")"
        cp -a "$path" "$rescue/files/$rel"
        hash=$(sha256sum "$rescue/files/$rel" | awk '{print $1}')
        printf '%s  %s\n' "$hash" "$rel" >> "$rescue/FILES.sha256"
        file_count=$((file_count + 1))
    elif [ -d "$path" ]; then
        dir_count=$((dir_count + 1))
    else
        missing_count=$((missing_count + 1))
    fi
done < "$package_files"

[ "$file_count" -gt 0 ] || fail 'no regular HRNeo package files were captured'

opkg status hrneo > "$rescue/opkg-status.txt"
opkg print-architecture > "$rescue/opkg-architecture.txt"

curl -fsSL "$url" -o "$rescue/$filename"
sh "$ARTIFACT_TOOL" verify-file "$arch" "$rescue/$filename" >/dev/null ||
    fail 'pinned HRNeo artifact verification failed after download'

cat > "$rescue/metadata.txt" <<EOF
schema=1
package=hrneo
version=$version
arch=$arch
artifact_filename=$filename
artifact_sha256=$expected_sha
package_regular_files=$file_count
package_symlinks=$symlink_count
package_directories=$dir_count
package_missing_paths=$missing_count
package_change=false
service_restart=false
network_change=false
EOF

chmod 600 "$rescue/metadata.txt" "$rescue/package-files.txt" "$rescue/FILES.sha256"     "$rescue/SYMLINKS.tsv" "$rescue/opkg-status.txt" "$rescue/opkg-architecture.txt" "$rescue/$filename"

field schema 1
field mode capture
field package hrneo
field version "$version"
field arch "$arch"
field regular_files "$file_count"
field symlinks "$symlink_count"
field directories "$dir_count"
field missing_paths "$missing_count"
field artifact_sha256 "$expected_sha"
field rescue_dir "$rescue"
field package_change false
field service_restart false
field network_change false
field result PASS
printf '%s\n' '[PASS] HRNeo rescue set captured; package and runtime state were not changed'
