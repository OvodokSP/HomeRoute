#!/bin/sh
# HomeRoute HRNeo pinned artifact helper.
# Read-only: renders immutable artifact metadata or verifies a local file.
# It never downloads or installs packages.

set -eu

MODE=${1:-help}
ARCH=${2:-}
FILE=${3:-}
RELEASE_COMMIT=4811c8d13fa4bd6eaed5080fd49788f5aee20883
BASE=https://raw.githubusercontent.com/Ground-Zerro/release

show_help() {
    cat <<'EOF'
Usage:
  hrneo-artifact.sh plan <entware-arch>
  hrneo-artifact.sh verify-file <entware-arch> <local-ipk>
  hrneo-artifact.sh selftest-git-blob <file>

Supported architectures:
  aarch64-3.10
  mipsel-3.4
  mips-3.4
EOF
}

metadata() {
    case "$1" in
        aarch64-3.10)
            FILENAME=hrneo_3.18.3-1_aarch64-3.10.ipk
            REPO_PATH=keenetic/aarch64-k3.10/hrneo_3.18.3-1_aarch64-3.10.ipk
            EXPECTED_SIZE=90689
            EXPECTED_BLOB=69e62156adf91868f58a85eaccc21916dc88f1c1
            ;;
        mipsel-3.4)
            FILENAME=hrneo_3.18.3-1_mipsel-3.4.ipk
            REPO_PATH=keenetic/mipselsf-k3.4/hrneo_3.18.3-1_mipsel-3.4.ipk
            EXPECTED_SIZE=111881
            EXPECTED_BLOB=eb4b7b17c7b987da88270935de74ce59f91c7b99
            ;;
        mips-3.4)
            FILENAME=hrneo_3.18.3-1_mips-3.4.ipk
            REPO_PATH=keenetic/mipssf-k3.4/hrneo_3.18.3-1_mips-3.4.ipk
            EXPECTED_SIZE=112060
            EXPECTED_BLOB=3d09aa888c1375a0f2a5aa7872638c8202c44e3a
            ;;
        *)
            printf '[FAIL] unsupported Entware architecture: %s\n' "$1" >&2
            return 2
            ;;
    esac
    URL="$BASE/$RELEASE_COMMIT/$REPO_PATH"
}

git_blob_sha1() {
    path=$1
    [ -f "$path" ] || {
        printf '[FAIL] file not found: %s\n' "$path" >&2
        return 2
    }
    command -v sha1sum >/dev/null 2>&1 || {
        printf '%s\n' '[FAIL] sha1sum is required for Git blob identity verification' >&2
        return 2
    }
    size=$(wc -c < "$path" | tr -d '[:space:]')
    {
        printf 'blob %s\000' "$size"
        cat "$path"
    } | sha1sum | awk '{print $1}'
}

case "$MODE" in
    plan)
        [ -n "$ARCH" ] || { printf '%s\n' '[FAIL] architecture is required' >&2; exit 2; }
        metadata "$ARCH"
        printf '%s\n' 'HOMEROUTE_HRNEO schema=1 mode=plan version=3.18.3-1 live_install=false'
        printf 'HOMEROUTE_HRNEO arch=%s filename=%s size_bytes=%s\n' "$ARCH" "$FILENAME" "$EXPECTED_SIZE"
        printf 'HOMEROUTE_HRNEO git_blob_sha1=%s\n' "$EXPECTED_BLOB"
        printf 'HOMEROUTE_HRNEO url=%s\n' "$URL"
        printf '%s\n' 'HOMEROUTE_HRNEO sha256=NOT_CAPTURED gpg=NOT_VERIFIED'
        ;;
    verify-file)
        [ -n "$ARCH" ] && [ -n "$FILE" ] || {
            printf '%s\n' '[FAIL] architecture and local file are required' >&2
            exit 2
        }
        metadata "$ARCH"
        [ -f "$FILE" ] || { printf '[FAIL] file not found: %s\n' "$FILE" >&2; exit 2; }
        actual_size=$(wc -c < "$FILE" | tr -d '[:space:]')
        [ "$actual_size" = "$EXPECTED_SIZE" ] || {
            printf '[FAIL] HRNeo artifact size mismatch: expected=%s actual=%s\n' "$EXPECTED_SIZE" "$actual_size" >&2
            exit 3
        }
        actual_blob=$(git_blob_sha1 "$FILE")
        [ "$actual_blob" = "$EXPECTED_BLOB" ] || {
            printf '[FAIL] HRNeo Git blob mismatch: expected=%s actual=%s\n' "$EXPECTED_BLOB" "$actual_blob" >&2
            exit 3
        }
        printf 'HOMEROUTE_HRNEO_VERIFY schema=1 result=PASS arch=%s size_bytes=%s git_blob_sha1=%s\n'             "$ARCH" "$actual_size" "$actual_blob"
        printf '%s\n' '[PASS] pinned HRNeo artifact identity verified; package was not installed'
        ;;
    selftest-git-blob)
        [ -n "$ARCH" ] || { printf '%s\n' '[FAIL] local file is required' >&2; exit 2; }
        git_blob_sha1 "$ARCH"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        printf '[FAIL] unknown mode: %s\n' "$MODE" >&2
        show_help >&2
        exit 2
        ;;
esac
