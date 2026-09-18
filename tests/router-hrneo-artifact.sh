#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TOOL="$ROOT/router/hrneo-artifact.sh"
BASE=${TMPDIR:-/tmp}/homeroute-hrneo-artifact-test.$$
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BASE"

check_plan() {
    arch=$1
    filename=$2
    size=$3
    blob=$4
    path=$5

    out=$(sh "$TOOL" plan "$arch")
    printf '%s\n' "$out" | grep -Fx 'HOMEROUTE_HRNEO schema=1 mode=plan version=3.18.3-1 live_install=false' >/dev/null ||
        fail "missing plan identity for $arch"
    printf '%s\n' "$out" | grep -Fx "HOMEROUTE_HRNEO arch=$arch filename=$filename size_bytes=$size" >/dev/null ||
        fail "artifact metadata drifted for $arch"
    printf '%s\n' "$out" | grep -Fx "HOMEROUTE_HRNEO git_blob_sha1=$blob" >/dev/null ||
        fail "blob identity drifted for $arch"
    printf '%s\n' "$out" | grep -Fx "HOMEROUTE_HRNEO url=https://raw.githubusercontent.com/Ground-Zerro/release/4811c8d13fa4bd6eaed5080fd49788f5aee20883/$path" >/dev/null ||
        fail "pinned URL drifted for $arch"
    printf '%s\n' "$out" | grep -Fx 'HOMEROUTE_HRNEO sha256=NOT_CAPTURED gpg=NOT_VERIFIED' >/dev/null ||
        fail "integrity boundary drifted for $arch"
}

check_plan aarch64-3.10 hrneo_3.18.3-1_aarch64-3.10.ipk 90689 69e62156adf91868f58a85eaccc21916dc88f1c1 keenetic/aarch64-k3.10/hrneo_3.18.3-1_aarch64-3.10.ipk
check_plan mipsel-3.4 hrneo_3.18.3-1_mipsel-3.4.ipk 111881 eb4b7b17c7b987da88270935de74ce59f91c7b99 keenetic/mipselsf-k3.4/hrneo_3.18.3-1_mipsel-3.4.ipk
check_plan mips-3.4 hrneo_3.18.3-1_mips-3.4.ipk 112060 3d09aa888c1375a0f2a5aa7872638c8202c44e3a keenetic/mipssf-k3.4/hrneo_3.18.3-1_mips-3.4.ipk

if sh "$TOOL" plan unsupported >/dev/null 2>&1; then
    fail 'unsupported architecture unexpectedly succeeded'
fi

printf '%s\n' 'HomeRoute Git blob verifier fixture' > "$BASE/fixture"
ours=$(sh "$TOOL" selftest-git-blob "$BASE/fixture")
expected=$(git hash-object "$BASE/fixture")
[ "$ours" = "$expected" ] || fail "Git blob SHA implementation mismatch: ours=$ours expected=$expected"

printf '%s\n' '[PASS] HRNeo pinned artifact plan / Git blob verifier contract'
