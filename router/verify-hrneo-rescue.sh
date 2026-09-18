#!/bin/sh
# Verify a captured HRNeo rescue set without changing package/runtime state.

set -eu

RESCUE=${1:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ARTIFACT_TOOL=${HOMEROUTE_HRNEO_ARTIFACT_TOOL:-$SCRIPT_DIR/hrneo-artifact.sh}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

field() {
    printf 'HOMEROUTE_HRNEO_RESCUE_VERIFY %s=%s\n' "$1" "$2"
}

[ -n "$RESCUE" ] || fail 'usage: verify-hrneo-rescue.sh <rescue-dir>'
[ -d "$RESCUE" ] || fail "rescue directory missing: $RESCUE"
[ -f "$RESCUE/metadata.txt" ] || fail 'metadata.txt missing'
[ -f "$RESCUE/package-files.txt" ] || fail 'package-files.txt missing'
[ -f "$RESCUE/FILES.sha256" ] || fail 'FILES.sha256 missing'
[ -f "$RESCUE/SYMLINKS.tsv" ] || fail 'SYMLINKS.tsv missing'
[ -f "$RESCUE/opkg-status.txt" ] || fail 'opkg-status.txt missing'
[ -f "$RESCUE/opkg-architecture.txt" ] || fail 'opkg-architecture.txt missing'
[ -d "$RESCUE/files" ] || fail 'files directory missing'
[ -f "$ARTIFACT_TOOL" ] || fail "artifact verifier missing: $ARTIFACT_TOOL"
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum unavailable'
command -v readlink >/dev/null 2>&1 || fail 'readlink unavailable'

meta() {
    key=$1
    sed -n "s/^${key}=//p" "$RESCUE/metadata.txt" | sed -n '1p'
}

schema=$(meta schema)
package=$(meta package)
version=$(meta version)
arch=$(meta arch)
filename=$(meta artifact_filename)
expected_sha=$(meta artifact_sha256)

[ "$schema" = 1 ] || fail "unexpected metadata schema: $schema"
[ "$package" = hrneo ] || fail "unexpected package: $package"
[ "$version" = 3.18.3-1 ] || fail "unexpected package version: $version"
case "$arch" in
    aarch64-3.10|mipsel-3.4|mips-3.4) ;;
    *) fail "unsupported rescue architecture: $arch" ;;
esac
[ -n "$filename" ] || fail 'artifact filename missing from metadata'
[ -f "$RESCUE/$filename" ] || fail "pinned artifact missing: $filename"

actual_artifact_sha=$(sha256sum "$RESCUE/$filename" | awk '{print $1}')
[ "$actual_artifact_sha" = "$expected_sha" ] ||
    fail 'artifact SHA256 differs from rescue metadata'

sh "$ARTIFACT_TOOL" verify-file "$arch" "$RESCUE/$filename" >/dev/null ||
    fail 'pinned artifact identity verification failed'

(
    cd "$RESCUE/files"
    sha256sum -c ../FILES.sha256 >/dev/null
) || fail 'regular-file backup checksum verification failed'

tab=$(printf '\t')
while IFS="$tab" read -r rel target; do
    [ -n "$rel" ] || continue
    case "$rel" in
        /*|*'..'*) fail "unsafe symlink path in rescue set: $rel" ;;
    esac
    path="$RESCUE/files/$rel"
    [ -L "$path" ] || fail "expected symlink missing from rescue set: $rel"
    actual=$(readlink "$path")
    [ "$actual" = "$target" ] || fail "symlink target mismatch: $rel"
done < "$RESCUE/SYMLINKS.tsv"

regular_files=$(awk 'NF {n++} END {print n+0}' "$RESCUE/FILES.sha256")
symlinks=$(awk 'NF {n++} END {print n+0}' "$RESCUE/SYMLINKS.tsv")
[ "$regular_files" -gt 0 ] || fail 'rescue set contains no regular package files'

field schema 1
field package hrneo
field version "$version"
field arch "$arch"
field regular_files "$regular_files"
field symlinks "$symlinks"
field artifact_sha256 "$actual_artifact_sha"
field package_change false
field service_restart false
field network_change false
field result PASS
printf '%s\n' '[PASS] HRNeo rescue set integrity verified; no live state was changed'
