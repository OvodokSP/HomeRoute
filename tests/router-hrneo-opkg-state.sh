#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CAPTURE="$ROOT/router/capture-hrneo-opkg-state.sh"
VERIFY="$ROOT/router/verify-hrneo-opkg-state.sh"
BASE=${TMPDIR:-/tmp}/homeroute-hrneo-opkg-state-test.$$
INFO=/tmp/homeroute-hrneo-opkg-info-test.$$
LIVE=/tmp/homeroute-hrneo-live-test.$$
RESCUE_BASE=/tmp/homeroute-hrneo-rescue-test.$$
RESCUE="$RESCUE_BASE/hrneo-rescue-fixture"
trap 'rm -rf "$BASE" "$INFO" "$LIVE" "$RESCUE_BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p   "$BASE"   "$INFO"   "$LIVE/opt/bin"   "$LIVE/opt/etc/init.d"   "$RESCUE/files"

cat > "$BASE/base-verify.sh" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 700 "$BASE/base-verify.sh"

cat > "$BASE/artifact.sh" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 700 "$BASE/artifact.sh"

cat > "$INFO/hrneo.postinst" <<'EOF'
#!/bin/sh
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'
ln -sf /opt/etc/init.d/S99hrneo /opt/bin/neo
if [ -f /opt/etc/init.d/rc.unslung ] &&
   ! grep -q '\[ $ACTION = start \] && sleep 10' /opt/etc/init.d/rc.unslung
then
    sed -i '/\[ $ACTION = stop -o $ACTION = restart -o $ACTION = kill \] && ORDER="-r"/a[ $ACTION = start ] && sleep 10' /opt/etc/init.d/rc.unslung
fi
/opt/etc/init.d/S99hrneo stop > /dev/null 2>&1
/opt/etc/init.d/S99hrneo start || printf "${RED}[WARN]${RESET} Failed to start the HR Neo service\n"
exit 0
EOF

cat > "$INFO/hrneo.conffiles" <<'EOF'
/opt/etc/HydraRoute/hrneo.conf
/opt/etc/HydraRoute/domain.conf
/opt/etc/HydraRoute/ip.list
EOF

cat > "$INFO/hrneo.control" <<'EOF'
Package: hrneo
Version: 3.18.3-1
Architecture: mipsel-3.4
EOF

cat > "$INFO/hrneo.list" <<'EOF'
/opt/bin/hrneo
/opt/etc/init.d/S99hrneo
EOF

ln -s /opt/etc/init.d/S99hrneo "$LIVE/opt/bin/neo"

cat > "$LIVE/opt/etc/init.d/rc.unslung" <<'EOF'
#!/bin/sh
[ $ACTION = stop -o $ACTION = restart -o $ACTION = kill ] && ORDER="-r"
[ $ACTION = start ] && sleep 10
EOF

plan=$(sh "$CAPTURE" plan)
for expected in   'HOMEROUTE_HRNEO_OPKG_RESCUE package_change=false'   'HOMEROUTE_HRNEO_OPKG_RESCUE service_restart=false'   'HOMEROUTE_HRNEO_OPKG_RESCUE network_change=false'   'HOMEROUTE_HRNEO_OPKG_RESCUE result=PLAN_ONLY'
do
  printf '%s\n' "$plan" | grep -Fx "$expected" >/dev/null ||
    fail "missing plan field: $expected"
done

if HOMEROUTE_HRNEO_OPKG_RESCUE_TEST_MODE=1    HOMEROUTE_OPKG_INFO_DIR="$INFO"    HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"    HOMEROUTE_HRNEO_RESCUE_VERIFIER="$BASE/base-verify.sh"    HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"    sh "$CAPTURE" capture "$RESCUE" >/dev/null 2>&1; then
  fail 'opkg rescue capture unexpectedly ran without explicit ACK'
fi

out=$(HOMEROUTE_HRNEO_OPKG_RESCUE_ACK=YES   HOMEROUTE_HRNEO_OPKG_RESCUE_TEST_MODE=1   HOMEROUTE_OPKG_INFO_DIR="$INFO"   HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"   HOMEROUTE_HRNEO_RESCUE_VERIFIER="$BASE/base-verify.sh"   HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"   sh "$CAPTURE" capture "$RESCUE")

for expected in   'HOMEROUTE_HRNEO_OPKG_RESCUE schema=1'   'HOMEROUTE_HRNEO_OPKG_RESCUE mode=capture'   'HOMEROUTE_HRNEO_OPKG_RESCUE package=hrneo'   'HOMEROUTE_HRNEO_OPKG_RESCUE postinst_sha_match=true'   'HOMEROUTE_HRNEO_OPKG_RESCUE conffiles_sha_match=true'   'HOMEROUTE_HRNEO_OPKG_RESCUE maintainer_scripts=postinst_only'   'HOMEROUTE_HRNEO_OPKG_RESCUE postinst_symlink_neo=true'   'HOMEROUTE_HRNEO_OPKG_RESCUE postinst_rc_unslung_guard=true'   'HOMEROUTE_HRNEO_OPKG_RESCUE postinst_stop_start=true'   'HOMEROUTE_HRNEO_OPKG_RESCUE postinst_network_mutation=false'   'HOMEROUTE_HRNEO_OPKG_RESCUE postinst_remove=false'   'HOMEROUTE_HRNEO_OPKG_RESCUE current_neo_symlink_expected=true'   'HOMEROUTE_HRNEO_OPKG_RESCUE current_rc_unslung_patch_present=true'   'HOMEROUTE_HRNEO_OPKG_RESCUE opkg_info_regular_files=4'   'HOMEROUTE_HRNEO_OPKG_RESCUE opkg_info_symlinks=0'   'HOMEROUTE_HRNEO_OPKG_RESCUE package_change=false'   'HOMEROUTE_HRNEO_OPKG_RESCUE service_restart=false'   'HOMEROUTE_HRNEO_OPKG_RESCUE network_change=false'   'HOMEROUTE_HRNEO_OPKG_RESCUE result=PASS'
do
  printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null ||
    fail "missing capture field: $expected"
done

verify=$(sh "$VERIFY" "$RESCUE")
printf '%s\n' "$verify" | grep -Fx 'HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFY result=PASS' >/dev/null ||
  fail 'opkg rescue verifier did not pass'

printf '%s\n' 'tampered' >> "$RESCUE/opkg-info/hrneo.control"
if sh "$VERIFY" "$RESCUE" >/dev/null 2>&1; then
  fail 'opkg rescue verifier unexpectedly accepted tampered metadata'
fi

printf '%s\n' '[PASS] HRNeo opkg/control metadata rescue contract'
