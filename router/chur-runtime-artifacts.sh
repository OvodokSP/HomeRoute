#!/bin/sh
# HomeRoute pinned Chur/AmneziaWG artifact helper.
# Read-only: renders artifact metadata or verifies already-downloaded local files.

set -eu

MODE=${1:-help}
ARCH=${2:-}
DIR=${3:-}
PAGES_COMMIT=b8493603eb08a631f4d93e4597f221830d2a8ba5
BASE=https://raw.githubusercontent.com/ward-sentry/ward-sentry.github.io

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

metadata() {
    case "$1" in
        aarch64-3.10)
            FEED_DIR=chur-keenetic/1_0_0/aarch64-3.10
            GO_FILE=chur-amneziawg-go_f4f4c99-1_aarch64-3.10.ipk
            GO_SIZE=1330809
            GO_SHA256=f722998eb4f9ea9b680e49924df5cddf981aa1cb01b8494de1fdf031765804ad
            GO_BLOB=803a91071b45299acc2cac7ebfa44d0f155605ad
            TOOLS_FILE=chur-amneziawg-tools_1.0.20260223-2_aarch64-3.10.ipk
            TOOLS_SIZE=55913
            TOOLS_SHA256=48e1486fd025d1bd35e61a97eedbf7dafc067056f850f9a0d009916d9e4a2454
            TOOLS_BLOB=371f9c4caf1883007c457900356a66d6d0b7b7f5
            META_FILE=chur-amneziawg_1.0.0-1_aarch64-3.10.ipk
            META_SIZE=841
            META_SHA256=2f7ab5e17f0ce51bb2e51078c9a73a81c6115be1da108ade27c37ed6179546d9
            META_BLOB=d702839dd195230277c732ca51dab81a965deaf2
            ;;
        mips-3.4)
            FEED_DIR=chur-keenetic/1_0_0/mips-3.4
            GO_FILE=chur-amneziawg-go_f4f4c99-1_mips-3.4.ipk
            GO_SIZE=1369317
            GO_SHA256=1ffefc4d740458abaa765f04962dbfe9728c3611ea7196209d6d788e02367cd6
            GO_BLOB=d9a2392c73f3484f111dc1f1f44651b3579abd46
            TOOLS_FILE=chur-amneziawg-tools_1.0.20260223-2_mips-3.4.ipk
            TOOLS_SIZE=43657
            TOOLS_SHA256=e10330f00234da5e9054862e1a2ea0fabf6a697c1750f220aad7ae197f04f80a
            TOOLS_BLOB=c40f44f4ce94e272ed2b05e0c76c63b08193d3a1
            META_FILE=chur-amneziawg_1.0.0-1_mips-3.4.ipk
            META_SIZE=840
            META_SHA256=32ecd04f828da12e3d44018a85df0837df62337fb03e19b3e92b7254db48e998
            META_BLOB=4bfa8f1e96cf5962c6bf080fd5058bab35746deb
            ;;
        mipsel-3.4)
            FEED_DIR=chur-keenetic/1_0_0/mipsel-3.4
            GO_FILE=chur-amneziawg-go_f4f4c99-1_mipsel-3.4.ipk
            GO_SIZE=1347467
            GO_SHA256=29fa09b90b30fa9bddc65836dd3c1f3ab9883811d9b5c69aff7fa959148f6457
            GO_BLOB=ea409731c65366d0570d4cfb3461c79773a7a62d
            TOOLS_FILE=chur-amneziawg-tools_1.0.20260223-2_mipsel-3.4.ipk
            TOOLS_SIZE=43738
            TOOLS_SHA256=6ab652ea6cf742ac67dbd5892750a24353b0d5fcfe4fb1b12724e35cd2cb1d7b
            TOOLS_BLOB=be6837e3a6896fd333dd7ef95c064ede3239292e
            META_FILE=chur-amneziawg_1.0.0-1_mipsel-3.4.ipk
            META_SIZE=838
            META_SHA256=3836b376d686427b587c450d2e4e8103bf05315801c33320ee76498ecd3661a9
            META_BLOB=138b0f48f84c915a5ef001e6c3cf0b9e32e971da
            ;;
        *)
            fail "unsupported Entware architecture: $1"
            ;;
    esac
}

git_blob_sha1() {
    file=$1
    command -v sha1sum >/dev/null 2>&1 || fail 'sha1sum is required'
    size=$(wc -c < "$file" | tr -d '[:space:]')
    {
        printf 'blob %s\000' "$size"
        cat "$file"
    } | sha1sum | awk '{print $1}'
}

print_artifact() {
    name=$1
    file=$2
    size=$3
    sha=$4
    blob=$5
    printf 'HOMEROUTE_CHUR artifact=%s filename=%s size_bytes=%s sha256=%s git_blob_sha1=%s\n'         "$name" "$file" "$size" "$sha" "$blob"
    printf 'HOMEROUTE_CHUR url=%s/%s/%s/%s\n' "$BASE" "$PAGES_COMMIT" "$FEED_DIR" "$file"
}

verify_one() {
    name=$1
    file=$2
    expected_size=$3
    expected_sha=$4
    expected_blob=$5
    path="$DIR/$file"

    [ -f "$path" ] || fail "missing pinned Chur artifact: $file"
    actual_size=$(wc -c < "$path" | tr -d '[:space:]')
    [ "$actual_size" = "$expected_size" ] || fail "$name size mismatch"

    command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required'
    actual_sha=$(sha256sum "$path" | awk '{print $1}')
    [ "$actual_sha" = "$expected_sha" ] || fail "$name SHA256 mismatch"

    actual_blob=$(git_blob_sha1 "$path")
    [ "$actual_blob" = "$expected_blob" ] || fail "$name Git blob identity mismatch"
}

case "$MODE" in
    plan)
        [ -n "$ARCH" ] || fail 'architecture is required'
        metadata "$ARCH"
        printf '%s\n' 'HOMEROUTE_CHUR schema=1 mode=plan release=1.0.0 artifacts=3 live_install=false'
        print_artifact chur-amneziawg-go "$GO_FILE" "$GO_SIZE" "$GO_SHA256" "$GO_BLOB"
        print_artifact chur-amneziawg-tools "$TOOLS_FILE" "$TOOLS_SIZE" "$TOOLS_SHA256" "$TOOLS_BLOB"
        print_artifact chur-amneziawg "$META_FILE" "$META_SIZE" "$META_SHA256" "$META_BLOB"
        ;;
    verify-set)
        [ -n "$ARCH" ] && [ -n "$DIR" ] || fail 'architecture and local artifact directory are required'
        [ -d "$DIR" ] || fail "artifact directory is missing: $DIR"
        metadata "$ARCH"
        verify_one chur-amneziawg-go "$GO_FILE" "$GO_SIZE" "$GO_SHA256" "$GO_BLOB"
        verify_one chur-amneziawg-tools "$TOOLS_FILE" "$TOOLS_SIZE" "$TOOLS_SHA256" "$TOOLS_BLOB"
        verify_one chur-amneziawg "$META_FILE" "$META_SIZE" "$META_SHA256" "$META_BLOB"
        printf 'HOMEROUTE_CHUR_VERIFY schema=1 result=PASS arch=%s artifacts=3\n' "$ARCH"
        printf '%s\n' '[PASS] pinned Chur AmneziaWG runtime set verified; no packages were installed'
        ;;
    selftest-git-blob)
        [ -n "$ARCH" ] || fail 'local file is required'
        [ -f "$ARCH" ] || fail "file not found: $ARCH"
        git_blob_sha1 "$ARCH"
        ;;
    help|--help|-h)
        printf '%s\n' 'Usage: chur-runtime-artifacts.sh plan <arch>'
        printf '%s\n' '       chur-runtime-artifacts.sh verify-set <arch> <directory>'
        ;;
    *)
        fail "unknown mode: $MODE"
        ;;
esac
