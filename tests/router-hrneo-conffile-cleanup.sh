#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/router/cleanup-hrneo-opkg-conffiles.sh"

BASE=${TMPDIR:-/tmp}/homeroute-hrneo-conffile-cleanup-test.$$
LIVE=/tmp/homeroute-hrneo-live-test.$$
RESCUE_BASE=/tmp/homeroute-hrneo-rescue-test.$$
RESCUE="$RESCUE_BASE/hrneo-rescue-fixture"
trap 'rm -rf "$BASE" "$LIVE" "$RESCUE_BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BASE" "$LIVE/opt/etc/HydraRoute" "$RESCUE/files/opt/etc/HydraRoute"

for name in hrneo.conf domain.conf ip.list; do
    printf 'live-%s\n' "$name" > "$LIVE/opt/etc/HydraRoute/$name"
    cp -a "$LIVE/opt/etc/HydraRoute/$name" "$RESCUE/files/opt/etc/HydraRoute/$name"
    printf 'package-default-%s\n' "$name" > "$LIVE/opt/etc/HydraRoute/$name-opkg"
done

(
    cd "$RESCUE/files"
    sha256sum       opt/etc/HydraRoute/hrneo.conf       opt/etc/HydraRoute/domain.conf       opt/etc/HydraRoute/ip.list       > ../FILES.sha256
)

cat > "$BASE/doctor.sh" <<'EOF'
#!/bin/sh
printf '%s\n' 'HOMEROUTE_DOCTOR schema=1 type=router pass=26 warn=0 fail=0 result=PASS'
exit 0
EOF
chmod 700 "$BASE/doctor.sh"

plan=$(sh "$SCRIPT" plan)
for expected in   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP expected_artifacts=3'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP capture_before_remove=true'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP service_restart=false'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP package_change=false'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP network_change=false'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP result=PLAN_ONLY'
do
  printf '%s\n' "$plan" | grep -Fx "$expected" >/dev/null ||
    fail "missing plan field: $expected"
done

if HOMEROUTE_HRNEO_CONFFILE_CLEANUP_TEST_MODE=1    HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"    HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"    sh "$SCRIPT" clean "$RESCUE" >/dev/null 2>&1; then
  fail 'cleanup unexpectedly ran without explicit ACK'
fi

out=$(HOMEROUTE_HRNEO_CONFFILE_CLEANUP_ACK=YES   HOMEROUTE_HRNEO_CONFFILE_CLEANUP_TEST_MODE=1   HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"   HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"   sh "$SCRIPT" clean "$RESCUE")

for expected in   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP schema=1'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP mode=clean'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP expected_artifacts=3'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP captured_artifacts=3'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP removed_artifacts=3'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP already_clean=false'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP doctor=PASS'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP service_restart=false'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP package_change=false'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP network_change=false'   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP result=PASS'
do
  printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null ||
    fail "missing cleanup field: $expected"
done

for name in hrneo.conf domain.conf ip.list; do
  [ ! -e "$LIVE/opt/etc/HydraRoute/$name-opkg" ] ||
    fail "generated artifact remained after cleanup: $name-opkg"
  cmp -s "$LIVE/opt/etc/HydraRoute/$name" "$RESCUE/files/opt/etc/HydraRoute/$name" ||
    fail "live conffile changed during cleanup: $name"
  [ -f "$RESCUE/reinstall-conffile-alternates/$name-opkg" ] ||
    fail "captured residue evidence missing: $name-opkg"
done

(
  cd "$RESCUE/reinstall-conffile-alternates"
  sha256sum -c FILES.sha256 >/dev/null
) || fail 'captured residue evidence does not verify'

out2=$(HOMEROUTE_HRNEO_CONFFILE_CLEANUP_ACK=YES   HOMEROUTE_HRNEO_CONFFILE_CLEANUP_TEST_MODE=1   HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"   HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"   sh "$SCRIPT" clean "$RESCUE")

printf '%s\n' "$out2" | grep -Fx   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP already_clean=true' >/dev/null ||
  fail 'second cleanup did not report already_clean=true'
printf '%s\n' "$out2" | grep -Fx   'HOMEROUTE_HRNEO_CONFFILE_CLEANUP result=PASS' >/dev/null ||
  fail 'second cleanup did not pass'

# Unexpected residue must block cleanup.
LIVE2=/tmp/homeroute-hrneo-live-test.unexpected.$$
RESCUE2=/tmp/homeroute-hrneo-rescue-test.unexpected.$$/hrneo-rescue-fixture
mkdir -p "$LIVE2/opt/etc/HydraRoute" "$RESCUE2/files/opt/etc/HydraRoute"
for name in hrneo.conf domain.conf ip.list; do
  printf 'live-%s\n' "$name" > "$LIVE2/opt/etc/HydraRoute/$name"
  cp -a "$LIVE2/opt/etc/HydraRoute/$name" "$RESCUE2/files/opt/etc/HydraRoute/$name"
  printf 'package-default-%s\n' "$name" > "$LIVE2/opt/etc/HydraRoute/$name-opkg"
done
printf '%s\n' unexpected > "$LIVE2/opt/etc/HydraRoute/other.conf-opkg"
(
  cd "$RESCUE2/files"
  sha256sum     opt/etc/HydraRoute/hrneo.conf     opt/etc/HydraRoute/domain.conf     opt/etc/HydraRoute/ip.list     > ../FILES.sha256
)

set +e
HOMEROUTE_HRNEO_CONFFILE_CLEANUP_ACK=YES   HOMEROUTE_HRNEO_CONFFILE_CLEANUP_TEST_MODE=1   HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE2"   HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"   sh "$SCRIPT" clean "$RESCUE2" >/dev/null 2>&1
rc=$?
set -e
rm -rf "$LIVE2" "$(dirname "$RESCUE2")"

[ "$rc" -ne 0 ] || fail 'cleanup unexpectedly accepted an unexpected *-opkg artifact'

printf '%s\n' '[PASS] HRNeo conffile residue cleanup contract'
