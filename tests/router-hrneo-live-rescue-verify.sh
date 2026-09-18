#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/router/verify-hrneo-live-rescue-state.sh"

BASE=${TMPDIR:-/tmp}/homeroute-hrneo-live-rescue-verify-test.$$
LIVE=/tmp/homeroute-hrneo-live-test.$$
INFO=/tmp/homeroute-hrneo-opkg-info-test.$$
STATUS=/tmp/homeroute-opkg-status-test.$$
RESCUE_BASE=/tmp/homeroute-hrneo-rescue-test.$$
RESCUE="$RESCUE_BASE/hrneo-rescue-fixture"
BIN="$BASE/bin"
trap 'rm -rf "$BASE" "$LIVE" "$INFO" "$STATUS" "$RESCUE_BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BIN" "$LIVE/opt/bin" "$LIVE/opt/etc/init.d" "$LIVE/opt/etc/HydraRoute"   "$INFO" "$RESCUE/files/opt/bin" "$RESCUE/opkg-info"   "$RESCUE/package-side-effects" "$RESCUE/package-database"

printf '%s\n' binary > "$LIVE/opt/bin/hrneo"
cp -a "$LIVE/opt/bin/hrneo" "$RESCUE/files/opt/bin/hrneo"

cat > "$LIVE/opt/etc/init.d/rc.unslung" <<'EOF'
#!/bin/sh
[ $ACTION = start ] && sleep 10
EOF
cp -a "$LIVE/opt/etc/init.d/rc.unslung" "$RESCUE/package-side-effects/rc.unslung"

ln -s /opt/etc/init.d/S99hrneo "$LIVE/opt/bin/neo"

printf '%s\n' control > "$INFO/hrneo.control"
printf '%s\n' list > "$INFO/hrneo.list"
cp -a "$INFO/hrneo.control" "$RESCUE/opkg-info/hrneo.control"
cp -a "$INFO/hrneo.list" "$RESCUE/opkg-info/hrneo.list"

cat > "$STATUS" <<'EOF'
Package: hrneo
Version: 3.18.3-1
Status: install user installed
EOF
cp -a "$STATUS" "$RESCUE/package-database/opkg-status"

(
  cd "$RESCUE/files"
  sha256sum opt/bin/hrneo > ../FILES.sha256
)
: > "$RESCUE/SYMLINKS.tsv"

(
  cd "$RESCUE/opkg-info"
  sha256sum hrneo.control hrneo.list > ../OPKG_INFO.sha256
)
: > "$RESCUE/OPKG_INFO_SYMLINKS.tsv"

(
  cd "$RESCUE/package-side-effects"
  sha256sum rc.unslung > ../SIDE_EFFECTS.sha256
)
printf '%s\n' 'neo	/opt/etc/init.d/S99hrneo' > "$RESCUE/SIDE_EFFECTS_SYMLINKS.tsv"

status_sha=$(sha256sum "$STATUS" | awk '{print $1}')
cat > "$RESCUE/opkg-status-rescue-metadata.txt" <<EOF
schema=1
package=hrneo
version=3.18.3-1
status_database_sha256=$status_sha
EOF

for name in base-verify.sh control-verify.sh status-verify.sh artifact.sh; do
  cat > "$BASE/$name" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod 700 "$BASE/$name"
done

cat > "$BASE/doctor.sh" <<'EOF'
#!/bin/sh
printf '%s\n' 'HOMEROUTE_DOCTOR schema=1 type=router pass=26 warn=0 fail=0 result=PASS'
EOF
chmod 700 "$BASE/doctor.sh"

cat > "$BIN/opkg" <<'EOF'
#!/bin/sh
set -eu
[ "$1" = status ] || exit 2
[ "$2" = hrneo ] || exit 2
printf '%s\n' 'Package: hrneo' 'Version: 3.18.3-1' 'Status: install user installed'
EOF
chmod 700 "$BIN/opkg"

out=$(PATH="$BIN:$PATH"   HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY_TEST_MODE=1   HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"   HOMEROUTE_OPKG_INFO_DIR="$INFO"   HOMEROUTE_OPKG_STATUS_FILE="$STATUS"   HOMEROUTE_HRNEO_RESCUE_VERIFIER="$BASE/base-verify.sh"   HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$BASE/control-verify.sh"   HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER="$BASE/status-verify.sh"   HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"   HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"   sh "$SCRIPT" "$RESCUE")

for expected in   'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY schema=1'   'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY package=hrneo'   'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY version=3.18.3-1'   'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY package_files=PASS'   'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY opkg_info=PASS'   'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY side_effect_state=PASS'   'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY status_database=PASS'   'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY conffile_residue=none'   'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY doctor=PASS'   'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY result=PASS'
do
  printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null ||
    fail "missing verifier field: $expected"
done

printf '%s\n' residue > "$LIVE/opt/etc/HydraRoute/hrneo.conf-opkg"
if PATH="$BIN:$PATH"    HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY_TEST_MODE=1    HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"    HOMEROUTE_OPKG_INFO_DIR="$INFO"    HOMEROUTE_OPKG_STATUS_FILE="$STATUS"    HOMEROUTE_HRNEO_RESCUE_VERIFIER="$BASE/base-verify.sh"    HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$BASE/control-verify.sh"    HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER="$BASE/status-verify.sh"    HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"    HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"    sh "$SCRIPT" "$RESCUE" >/dev/null 2>&1; then
  fail 'live-vs-rescue verifier unexpectedly accepted conffile residue'
fi

rm -f "$LIVE/opt/etc/HydraRoute/hrneo.conf-opkg"
printf '%s\n' tampered > "$LIVE/opt/bin/hrneo"
if PATH="$BIN:$PATH"    HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY_TEST_MODE=1    HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"    HOMEROUTE_OPKG_INFO_DIR="$INFO"    HOMEROUTE_OPKG_STATUS_FILE="$STATUS"    HOMEROUTE_HRNEO_RESCUE_VERIFIER="$BASE/base-verify.sh"    HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$BASE/control-verify.sh"    HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER="$BASE/status-verify.sh"    HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"    HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"    sh "$SCRIPT" "$RESCUE" >/dev/null 2>&1; then
  fail 'live-vs-rescue verifier unexpectedly accepted package-file drift'
fi

printf '%s\n' '[PASS] HRNeo live-vs-rescue verification contract'
