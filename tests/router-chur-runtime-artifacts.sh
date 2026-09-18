#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TOOL="$ROOT/router/chur-runtime-artifacts.sh"
BASE=${TMPDIR:-/tmp}/homeroute-chur-runtime-test.$$
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BASE"

check_plan() {
    arch=$1
    marker=$2
    out=$(sh "$TOOL" plan "$arch")
    printf '%s\n' "$out" | grep -Fx 'HOMEROUTE_CHUR schema=1 mode=plan release=1.0.0 artifacts=3 live_install=false' >/dev/null ||
        fail "plan identity missing for $arch"
    count=$(printf '%s\n' "$out" | grep -c '^HOMEROUTE_CHUR artifact=')
    [ "$count" -eq 3 ] || fail "expected three runtime artifacts for $arch"
    printf '%s\n' "$out" | grep -F "$marker" >/dev/null ||
        fail "expected pinned SHA256 missing for $arch"
    if printf '%s\n' "$out" | grep -F '/latest/' >/dev/null; then
        fail "mutable latest URL leaked into pinned plan for $arch"
    fi
    printf '%s\n' "$out" | grep -F '/b8493603eb08a631f4d93e4597f221830d2a8ba5/chur-keenetic/1_0_0/' >/dev/null ||
        fail "pinned Pages commit URL missing for $arch"
}

check_plan aarch64-3.10 f722998eb4f9ea9b680e49924df5cddf981aa1cb01b8494de1fdf031765804ad
check_plan mips-3.4 1ffefc4d740458abaa765f04962dbfe9728c3611ea7196209d6d788e02367cd6
check_plan mipsel-3.4 29fa09b90b30fa9bddc65836dd3c1f3ab9883811d9b5c69aff7fa959148f6457

if sh "$TOOL" plan unsupported >/dev/null 2>&1; then
    fail 'unsupported Chur architecture unexpectedly succeeded'
fi

printf '%s\n' 'HomeRoute Chur Git blob fixture' > "$BASE/fixture"
ours=$(sh "$TOOL" selftest-git-blob "$BASE/fixture")
expected=$(git hash-object "$BASE/fixture")
[ "$ours" = "$expected" ] || fail "Git blob SHA implementation mismatch"

mkdir -p "$BASE/incomplete"
if sh "$TOOL" verify-set aarch64-3.10 "$BASE/incomplete" >/dev/null 2>&1; then
    fail 'incomplete Chur artifact set unexpectedly verified'
fi

printf '%s\n' '[PASS] pinned Chur runtime plan / integrity verifier contract'
