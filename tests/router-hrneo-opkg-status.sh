#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CAPTURE="$ROOT/router/capture-hrneo-opkg-status.sh"
VERIFY="$ROOT/router/verify-hrneo-opkg-status.sh"
BASE=${TMPDIR:-/tmp}/homeroute-hrneo-status-test.$$
RESCUE_BASE=/tmp/homeroute-hrneo-rescue-test.$$
RESCUE="$RESCUE_BASE/hrneo-rescue-fixture"
STATUS=/tmp/homeroute-opkg-status-test.$$
BIN="$BASE/bin"
trap 'rm -rf "$BASE" "$RESCUE_BASE" "$STATUS"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BASE" "$BIN" "$RESCUE"

cat > "$BASE/control-verify.sh" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 700 "$BASE/control-verify.sh"

cat > "$STATUS" <<'EOF'
Package: libc
Version: 1.0
Status: install ok installed

Package: hrneo
Version: 3.18.3-1
Architecture: mipsel-3.4
Status: install user installed
Description: fixture

Package: test
Version: 2.0
Status: install ok installed
EOF

cat > "$BIN/opkg" <<'EOF'
#!/bin/sh
set -eu
case "$1" in
  status)
    [ "$2" = hrneo ] || exit 2
    cat <<'OUT'
Package: hrneo
Version: 3.18.3-1
Architecture: mipsel-3.4
Status: install user installed
Description: fixture
OUT
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod 700 "$BIN/opkg"

plan=$(sh "$CAPTURE" plan)
for expected in   'HOMEROUTE_HRNEO_STATUS_RESCUE status_database_capture=true'   'HOMEROUTE_HRNEO_STATUS_RESCUE package_change=false'   'HOMEROUTE_HRNEO_STATUS_RESCUE service_restart=false'   'HOMEROUTE_HRNEO_STATUS_RESCUE network_change=false'   'HOMEROUTE_HRNEO_STATUS_RESCUE result=PLAN_ONLY'
do
  printf '%s\n' "$plan" | grep -Fx "$expected" >/dev/null ||
    fail "missing plan field: $expected"
done

if PATH="$BIN:$PATH"    HOMEROUTE_HRNEO_STATUS_RESCUE_TEST_MODE=1    HOMEROUTE_OPKG_STATUS_FILE="$STATUS"    HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$BASE/control-verify.sh"    sh "$CAPTURE" capture "$RESCUE" >/dev/null 2>&1; then
  fail 'status rescue capture unexpectedly ran without explicit ACK'
fi

out=$(PATH="$BIN:$PATH"   HOMEROUTE_HRNEO_STATUS_RESCUE_ACK=YES   HOMEROUTE_HRNEO_STATUS_RESCUE_TEST_MODE=1   HOMEROUTE_OPKG_STATUS_FILE="$STATUS"   HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$BASE/control-verify.sh"   sh "$CAPTURE" capture "$RESCUE")

for expected in   'HOMEROUTE_HRNEO_STATUS_RESCUE schema=1'   'HOMEROUTE_HRNEO_STATUS_RESCUE mode=capture'   'HOMEROUTE_HRNEO_STATUS_RESCUE package=hrneo'   'HOMEROUTE_HRNEO_STATUS_RESCUE version=3.18.3-1'   'HOMEROUTE_HRNEO_STATUS_RESCUE package_change=false'   'HOMEROUTE_HRNEO_STATUS_RESCUE service_restart=false'   'HOMEROUTE_HRNEO_STATUS_RESCUE network_change=false'   'HOMEROUTE_HRNEO_STATUS_RESCUE result=PASS'
do
  printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null ||
    fail "missing capture field: $expected"
done

verify=$(sh "$VERIFY" "$RESCUE")
printf '%s\n' "$verify" | grep -Fx 'HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFY result=PASS' >/dev/null ||
  fail 'status rescue verifier did not pass'

printf '%s\n' 'tampered' >> "$RESCUE/package-database/opkg-status"
if sh "$VERIFY" "$RESCUE" >/dev/null 2>&1; then
  fail 'status rescue verifier unexpectedly accepted tampered database'
fi

printf '%s\n' '[PASS] HRNeo global opkg status rescue contract'
