#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROUTER="$ROOT/router/install.sh"
VPS="$ROOT/vps/install.sh"
TMPDIR_BASE=${TMPDIR:-/tmp}
BASE="$TMPDIR_BASE/homeroute-installer-sandbox.$$"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

new_box() {
    box=$1
    mkdir -p "$box/etc/homeroute"
    : > "$box/.homeroute-sandbox"
}

# Router: apply, idempotent re-apply, unrelated state isolation.
R="$BASE/router"
new_box "$R"
printf '%s\n' 'OLD_ROUTER_STATE=1' > "$R/etc/homeroute/router-state.env"
printf '%s\n' 'do-not-touch' > "$R/etc/homeroute/unrelated.txt"

HOMEROUTE_SANDBOX_ROOT="$R" HOMEROUTE_TX_ID=router-1 HOMEROUTE_ENTWARE_ARCH=mips-3.4     sh "$ROUTER" sandbox-apply > "$BASE/router-first.out"

grep -F 'HOMEROUTE_SANDBOX target=router result=PASS' "$BASE/router-first.out" >/dev/null ||
    fail 'router sandbox apply did not pass'
grep -F 'AWG_INTERFACE=opkgtun0' "$R/etc/homeroute/router-state.env" >/dev/null ||
    fail 'router desired state missing'
grep -Fx 'src/gz chur https://ward-sentry.github.io/chur-keenetic/latest/mips-3.4' "$R/opt/etc/opkg/chur.conf" >/dev/null ||
    fail 'router Chur feed state missing'
grep -Fx 'do-not-touch' "$R/etc/homeroute/unrelated.txt" >/dev/null ||
    fail 'router unrelated state changed'

HOMEROUTE_SANDBOX_ROOT="$R" HOMEROUTE_TX_ID=router-2 HOMEROUTE_ENTWARE_ARCH=mips-3.4     sh "$ROUTER" sandbox-apply > "$BASE/router-second.out"
grep -F '[NO CHANGE] etc/homeroute/router-state.env' "$BASE/router-second.out" >/dev/null ||
    fail 'router second apply was not idempotent'
grep -F '[NO CHANGE] opt/etc/opkg/chur.conf' "$BASE/router-second.out" >/dev/null ||
    fail 'router feed second apply was not idempotent'

# Router: forced verification failure must restore the previous file.
RF="$BASE/router-fail"
new_box "$RF"
printf '%s\n' 'ORIGINAL_ROUTER=1' > "$RF/etc/homeroute/router-state.env"
mkdir -p "$RF/opt/etc/opkg"
printf '%s\n' 'src/gz previous https://example.invalid/feed' > "$RF/opt/etc/opkg/chur.conf"
if HOMEROUTE_SANDBOX_ROOT="$RF" HOMEROUTE_TX_ID=router-fail HOMEROUTE_ENTWARE_ARCH=mips-3.4    HOMEROUTE_SANDBOX_FORCE_VERIFY_FAIL=1    sh "$ROUTER" sandbox-apply > "$BASE/router-fail.out" 2>&1; then
    fail 'forced router verification failure unexpectedly succeeded'
fi
grep -Fx 'ORIGINAL_ROUTER=1' "$RF/etc/homeroute/router-state.env" >/dev/null ||
    fail 'router rollback did not restore original file'
grep -Fx 'src/gz previous https://example.invalid/feed' "$RF/opt/etc/opkg/chur.conf" >/dev/null ||
    fail 'router rollback did not restore previous Chur feed'
grep -F '[TX] rollback complete' "$BASE/router-fail.out" >/dev/null ||
    fail 'router rollback marker missing'

# VPS: same contract.
V="$BASE/vps"
new_box "$V"
printf '%s\n' 'OLD_VPS_STATE=1' > "$V/etc/homeroute/vps-state.env"
printf '%s\n' 'do-not-touch' > "$V/etc/homeroute/unrelated.txt"

HOMEROUTE_SANDBOX_ROOT="$V" HOMEROUTE_TX_ID=vps-1     sh "$VPS" sandbox-apply > "$BASE/vps-first.out"
grep -F 'HOMEROUTE_SANDBOX target=vps result=PASS' "$BASE/vps-first.out" >/dev/null ||
    fail 'VPS sandbox apply did not pass'
grep -F 'AWG_INTERFACE=awg0' "$V/etc/homeroute/vps-state.env" >/dev/null ||
    fail 'VPS desired state missing'
grep -Fx 'do-not-touch' "$V/etc/homeroute/unrelated.txt" >/dev/null ||
    fail 'VPS unrelated state changed'

HOMEROUTE_SANDBOX_ROOT="$V" HOMEROUTE_TX_ID=vps-2     sh "$VPS" sandbox-apply > "$BASE/vps-second.out"
grep -F '[NO CHANGE] etc/homeroute/vps-state.env' "$BASE/vps-second.out" >/dev/null ||
    fail 'VPS second apply was not idempotent'

VF="$BASE/vps-fail"
new_box "$VF"
printf '%s\n' 'ORIGINAL_VPS=1' > "$VF/etc/homeroute/vps-state.env"
if HOMEROUTE_SANDBOX_ROOT="$VF" HOMEROUTE_TX_ID=vps-fail    HOMEROUTE_SANDBOX_FORCE_VERIFY_FAIL=1    sh "$VPS" sandbox-apply > "$BASE/vps-fail.out" 2>&1; then
    fail 'forced VPS verification failure unexpectedly succeeded'
fi
grep -Fx 'ORIGINAL_VPS=1' "$VF/etc/homeroute/vps-state.env" >/dev/null ||
    fail 'VPS rollback did not restore original file'
grep -F '[TX] rollback complete' "$BASE/vps-fail.out" >/dev/null ||
    fail 'VPS rollback marker missing'

# Hard safety gate: no marker => no mutation.
N="$BASE/no-marker"
mkdir -p "$N"
if HOMEROUTE_SANDBOX_ROOT="$N" HOMEROUTE_TX_ID=no-marker HOMEROUTE_ENTWARE_ARCH=mips-3.4    sh "$ROUTER" sandbox-apply > "$BASE/no-marker.out" 2>&1; then
    fail 'sandbox apply succeeded without marker'
fi
grep -F 'sandbox marker missing' "$BASE/no-marker.out" >/dev/null ||
    fail 'sandbox marker safety failure missing'

printf '%s\n' '[PASS] installer sandbox transaction / rollback / idempotency'
