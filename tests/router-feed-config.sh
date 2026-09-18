#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TOOL="$ROOT/router/feed-config.sh"

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

check() {
    arch=$1
    expected=$2
    actual=$(sh "$TOOL" render-chur "$arch")
    [ "$actual" = "$expected" ] || fail "unexpected Chur feed for $arch"
}

check aarch64-3.10 'src/gz chur https://ward-sentry.github.io/chur-keenetic/latest/aarch64-3.10'
check mips-3.4 'src/gz chur https://ward-sentry.github.io/chur-keenetic/latest/mips-3.4'
check mipsel-3.4 'src/gz chur https://ward-sentry.github.io/chur-keenetic/latest/mipsel-3.4'

if sh "$TOOL" render-chur unsupported-arch >/dev/null 2>&1; then
    fail 'unsupported architecture unexpectedly succeeded'
fi

hrneo=$(sh "$TOOL" hrneo-status)
[ "$hrneo" = 'HOMEROUTE_FEED component=hrneo status=PINNED_ARTIFACT version=3.18.3-1 integrity=GIT_BLOB_ONLY live_install=false' ] ||
    fail 'HRNeo pinned artifact status drifted'

printf '%s\n' '[PASS] router feed renderer contract'
