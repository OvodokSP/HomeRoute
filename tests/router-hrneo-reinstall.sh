#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/router/validate-hrneo-reinstall.sh"

BASE=${TMPDIR:-/tmp}/homeroute-hrneo-reinstall-test.$$
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

mkdir -p "$BIN" "$LIVE/opt/bin" "$LIVE/opt/etc/init.d" "$LIVE/opt/etc/HydraRoute" "$INFO" \
  "$RESCUE/files/opt/bin" "$RESCUE/opkg-info" "$RESCUE/package-side-effects" \
  "$RESCUE/package-database"

printf '%s\n' 'hrneo-binary-fixture' > "$LIVE/opt/bin/hrneo"
printf '%s\n' 'hrneo-binary-fixture' > "$RESCUE/files/opt/bin/hrneo"

mkdir -p "$RESCUE/files/opt/etc/HydraRoute"
for name in hrneo.conf domain.conf ip.list; do
  printf 'rescue-old-%s\n' "$name" > "$RESCUE/files/opt/etc/HydraRoute/$name"
  printf 'live-current-%s\n' "$name" > "$LIVE/opt/etc/HydraRoute/$name"
done

cat > "$LIVE/opt/etc/init.d/S99hrneo" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 700 "$LIVE/opt/etc/init.d/S99hrneo"

cat > "$LIVE/opt/etc/init.d/rc.unslung" <<'EOF'
#!/bin/sh
[ $ACTION = start ] && sleep 10
EOF
cp -a "$LIVE/opt/etc/init.d/rc.unslung" "$RESCUE/package-side-effects/rc.unslung"

ln -s /opt/etc/init.d/S99hrneo "$LIVE/opt/bin/neo"
ln -s /opt/etc/init.d/S99hrneo "$RESCUE/package-side-effects/neo"

printf '%s\n' 'Package: hrneo' 'Version: 3.18.3-1' > "$INFO/hrneo.control"
printf '%s\n' '/opt/bin/hrneo' > "$INFO/hrneo.list"
cp -a "$INFO/hrneo.control" "$RESCUE/opkg-info/hrneo.control"
cp -a "$INFO/hrneo.list" "$RESCUE/opkg-info/hrneo.list"

cat > "$STATUS" <<'EOF'
Package: libc
Version: 1
Status: install ok installed

Package: ipset
Version: 1
Status: install ok installed

Package: iptables
Version: 1
Status: install ok installed

Package: ip-full
Version: 1
Status: install ok installed

Package: hrneo
Version: 3.18.3-1
Status: install user installed
EOF
cp -a "$STATUS" "$RESCUE/package-database/opkg-status"

printf '%s\n' 'pinned-ipk-fixture' > "$RESCUE/hrneo-test.ipk"

cat > "$RESCUE/metadata.txt" <<'EOF'
schema=1
package=hrneo
version=3.18.3-1
arch=mipsel-3.4
artifact_filename=hrneo-test.ipk
EOF

(
  cd "$RESCUE/files"
  sha256sum \
    opt/bin/hrneo \
    opt/etc/HydraRoute/hrneo.conf \
    opt/etc/HydraRoute/domain.conf \
    opt/etc/HydraRoute/ip.list \
    > ../FILES.sha256
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
printf '%s\t%s\n' neo /opt/etc/init.d/S99hrneo > "$RESCUE/SIDE_EFFECTS_SYMLINKS.tsv"

status_sha=$(sha256sum "$RESCUE/package-database/opkg-status" | awk '{print $1}')
status_bytes=$(wc -c < "$RESCUE/package-database/opkg-status" | tr -d '[:space:]')
cat > "$RESCUE/opkg-status-rescue-metadata.txt" <<EOF
schema=1
package=hrneo
version=3.18.3-1
status_database_sha256=$status_sha
status_database_bytes=$status_bytes
hrneo_status_stanza_sha256=fixture
package_change=false
service_restart=false
network_change=false
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
exit 0
EOF
chmod 700 "$BASE/doctor.sh"

cat > "$BIN/opkg" <<'EOF'
#!/bin/sh
set -eu

LIVE=${HOMEROUTE_TEST_LIVE_ROOT:?}
INFO=${HOMEROUTE_TEST_INFO_DIR:?}
STATUS=${HOMEROUTE_TEST_STATUS_FILE:?}

case "$1" in
  --help)
    printf '%s\n' '  --force-reinstall Reinstall package(s)' '  --nodeps Do not follow dependencies'
    ;;
  --force-reinstall)
    [ "$2" = --nodeps ] || exit 2
    [ "$3" = install ] || exit 2
    [ -f "$4" ] || exit 2
    if [ "${HOMEROUTE_TEST_OPKG_MUTATE:-0}" = 1 ]; then
      printf '%s\n' 'mutated-binary' > "$LIVE/opt/bin/hrneo"
      printf '%s\n' 'mutated-control' > "$INFO/hrneo.control"
      printf '%s\n' 'mutated-status' > "$STATUS"
      printf '%s\n' 'mutated-rc' > "$LIVE/opt/etc/init.d/rc.unslung"
      rm -f "$LIVE/opt/bin/neo"
      ln -s /tmp/wrong-target "$LIVE/opt/bin/neo"
      printf '%s\n' package-default > "$LIVE/opt/etc/HydraRoute/hrneo.conf-opkg"
      printf '%s\n' package-default > "$LIVE/opt/etc/HydraRoute/domain.conf-opkg"
      printf '%s\n' package-default > "$LIVE/opt/etc/HydraRoute/ip.list-opkg"
    fi
    ;;
  status)
    pkg=$2
    case "$pkg" in
      hrneo)
        printf '%s\n' 'Package: hrneo' 'Version: 3.18.3-1' 'Status: install user installed'
        ;;
      libc|ipset|iptables|ip-full)
        printf 'Package: %s\nVersion: 1\nStatus: install ok installed\n' "$pkg"
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  list-installed)
    printf '%s\n'       'hrneo - 3.18.3-1'       'ip-full - 1'       'ipset - 1'       'iptables - 1'       'libc - 1'
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod 700 "$BIN/opkg"

plan=$(sh "$SCRIPT" plan)
for expected in \
  'HOMEROUTE_HRNEO_REINSTALL exact_local_ipk=true' \
  'HOMEROUTE_HRNEO_REINSTALL force_reinstall=true' \
  'HOMEROUTE_HRNEO_REINSTALL nodeps=true' \
  'HOMEROUTE_HRNEO_REINSTALL rollback_opkg_status=true' \
  'HOMEROUTE_HRNEO_REINSTALL rollback_conffile_residue=true' \
  'HOMEROUTE_HRNEO_REINSTALL result=PLAN_ONLY'
do
  printf '%s\n' "$plan" | grep -Fx "$expected" >/dev/null ||
    fail "missing plan field: $expected"
done

common_env() {
  :
}

if PATH="$BIN:$PATH"   HOMEROUTE_HRNEO_REINSTALL_TEST_MODE=1   HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"   HOMEROUTE_OPKG_INFO_DIR="$INFO"   HOMEROUTE_OPKG_STATUS_FILE="$STATUS"   HOMEROUTE_HRNEO_RESCUE_VERIFIER="$BASE/base-verify.sh"   HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$BASE/control-verify.sh"   HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER="$BASE/status-verify.sh"   HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"   HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"   HOMEROUTE_TEST_LIVE_ROOT="$LIVE"   HOMEROUTE_TEST_INFO_DIR="$INFO"   HOMEROUTE_TEST_STATUS_FILE="$STATUS"   sh "$SCRIPT" validate "$RESCUE" >/dev/null 2>&1; then
  fail 'reinstall unexpectedly ran without explicit ACK'
fi

out=$(PATH="$BIN:$PATH"   HOMEROUTE_HRNEO_REINSTALL_ACK=YES   HOMEROUTE_HRNEO_REINSTALL_TEST_MODE=1   HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"   HOMEROUTE_OPKG_INFO_DIR="$INFO"   HOMEROUTE_OPKG_STATUS_FILE="$STATUS"   HOMEROUTE_HRNEO_RESCUE_VERIFIER="$BASE/base-verify.sh"   HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$BASE/control-verify.sh"   HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER="$BASE/status-verify.sh"   HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"   HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"   HOMEROUTE_TEST_LIVE_ROOT="$LIVE"   HOMEROUTE_TEST_INFO_DIR="$INFO"   HOMEROUTE_TEST_STATUS_FILE="$STATUS"   sh "$SCRIPT" validate "$RESCUE")

for expected in   'HOMEROUTE_HRNEO_REINSTALL schema=1'   'HOMEROUTE_HRNEO_REINSTALL mode=validate'   'HOMEROUTE_HRNEO_REINSTALL package=hrneo'   'HOMEROUTE_HRNEO_REINSTALL version=3.18.3-1'   'HOMEROUTE_HRNEO_REINSTALL force_reinstall=true'   'HOMEROUTE_HRNEO_REINSTALL nodeps=true'   'HOMEROUTE_HRNEO_REINSTALL installed_package_set_unchanged=true'   'HOMEROUTE_HRNEO_REINSTALL immutable_package_files_match_rescue=true'   'HOMEROUTE_HRNEO_REINSTALL mutable_conffiles_unchanged=true'   'HOMEROUTE_HRNEO_REINSTALL opkg_info_match_rescue=true'   'HOMEROUTE_HRNEO_REINSTALL side_effect_state_idempotent=true'   'HOMEROUTE_HRNEO_REINSTALL doctor=PASS'   'HOMEROUTE_HRNEO_REINSTALL rollback=NOT_NEEDED'   'HOMEROUTE_HRNEO_REINSTALL live_package_transaction_validated=true'   'HOMEROUTE_HRNEO_REINSTALL result=PASS'
do
  printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null ||
    fail "missing success field: $expected"
done

# Recreate the transaction precondition after the successful run.
rm -rf "$RESCUE/reinstall-work"

set +e
PATH="$BIN:$PATH"   HOMEROUTE_HRNEO_REINSTALL_ACK=YES   HOMEROUTE_HRNEO_REINSTALL_TEST_MODE=1   HOMEROUTE_HRNEO_REINSTALL_FORCE_VERIFY_FAIL=1   HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"   HOMEROUTE_OPKG_INFO_DIR="$INFO"   HOMEROUTE_OPKG_STATUS_FILE="$STATUS"   HOMEROUTE_HRNEO_RESCUE_VERIFIER="$BASE/base-verify.sh"   HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$BASE/control-verify.sh"   HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER="$BASE/status-verify.sh"   HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"   HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"   HOMEROUTE_TEST_LIVE_ROOT="$LIVE"   HOMEROUTE_TEST_INFO_DIR="$INFO"   HOMEROUTE_TEST_STATUS_FILE="$STATUS"   HOMEROUTE_TEST_OPKG_MUTATE=1   sh "$SCRIPT" validate "$RESCUE" >"$BASE/fail.out" 2>"$BASE/fail.err"
rc=$?
set -e

[ "$rc" -ne 0 ] || fail 'forced failure unexpectedly succeeded'
grep -F '[PASS] automatic HRNeo rollback completed' "$BASE/fail.err" >/dev/null ||
  fail 'automatic rollback PASS marker missing'

cmp -s "$LIVE/opt/bin/hrneo" "$RESCUE/files/opt/bin/hrneo" ||
  fail 'rollback did not restore package file'
cmp -s "$INFO/hrneo.control" "$RESCUE/opkg-info/hrneo.control" ||
  fail 'rollback did not restore opkg info'
cmp -s "$STATUS" "$RESCUE/package-database/opkg-status" ||
  fail 'rollback did not restore global opkg status'
cmp -s "$LIVE/opt/etc/init.d/rc.unslung" "$RESCUE/package-side-effects/rc.unslung" ||
  fail 'rollback did not restore rc.unslung'
[ -L "$LIVE/opt/bin/neo" ] || fail 'rollback did not restore neo symlink'
[ "$(readlink "$LIVE/opt/bin/neo")" = /opt/etc/init.d/S99hrneo ] ||
  fail 'rollback restored wrong neo symlink target'

for name in hrneo.conf domain.conf ip.list; do
  expected="live-current-$name"
  actual=$(cat "$LIVE/opt/etc/HydraRoute/$name")
  [ "$actual" = "$expected" ] ||
    fail "rollback overwrote mutable conffile with stale rescue copy: $name"
done

for residue in \
  "$LIVE/opt/etc/HydraRoute/hrneo.conf-opkg" \
  "$LIVE/opt/etc/HydraRoute/domain.conf-opkg" \
  "$LIVE/opt/etc/HydraRoute/ip.list-opkg"
do
  [ ! -e "$residue" ] || fail "rollback left generated conffile residue: $residue"
done

printf '%s\n' '[PASS] controlled HRNeo same-version reinstall/rollback contract'
