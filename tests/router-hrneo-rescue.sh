#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CAPTURE="$ROOT/router/prepare-hrneo-rescue.sh"
VERIFY="$ROOT/router/verify-hrneo-rescue.sh"
BASE=${TMPDIR:-/tmp}/homeroute-hrneo-rescue-test.$$
BIN="$BASE/bin"
LIVE="$BASE/live"
BACKUPS="$BASE/backups"
FIXTURE="$BASE/hrneo-test.ipk"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BIN"   "$LIVE/opt/bin"   "$LIVE/opt/etc/init.d"   "$LIVE/opt/lib"   "$LIVE/opt/share/hrneo"   "$BACKUPS"

printf '%s\n' 'hrneo-binary-fixture' > "$LIVE/opt/bin/hrneo"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$LIVE/opt/etc/init.d/S99hrneo"
ln -s ../bin/hrneo "$LIVE/opt/lib/hrneo-link"
printf '%s\n' 'pinned-ipk-fixture' > "$FIXTURE"

cat > "$BASE/doctor.sh" <<'EOF'
#!/bin/sh
printf '%s\n' 'HOMEROUTE_DOCTOR schema=1 type=router pass=26 warn=0 fail=0 result=PASS'
exit 0
EOF
chmod 700 "$BASE/doctor.sh"

cat > "$BASE/artifact.sh" <<'EOF'
#!/bin/sh
set -eu
mode=$1
arch=${2:-}
file=${3:-}
fixture=${HOMEROUTE_TEST_IPK:?}
sha=$(sha256sum "$fixture" | awk '{print $1}')
size=$(wc -c < "$fixture" | tr -d '[:space:]')
case "$mode" in
  plan)
    printf '%s\n' 'HOMEROUTE_HRNEO schema=1 mode=plan version=3.18.3-1 live_install=false'
    printf 'HOMEROUTE_HRNEO arch=%s filename=hrneo-test.ipk size_bytes=%s\n' "$arch" "$size"
    printf 'HOMEROUTE_HRNEO sha256=%s\n' "$sha"
    printf '%s\n' 'HOMEROUTE_HRNEO url=https://example.invalid/hrneo-test.ipk'
    ;;
  verify-file)
    [ "$arch" = mipsel-3.4 ] || exit 2
    cmp -s "$fixture" "$file" || exit 3
    printf '%s\n' 'HOMEROUTE_HRNEO_VERIFY schema=2 result=PASS'
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod 700 "$BASE/artifact.sh"

cat > "$BIN/opkg" <<'EOF'
#!/bin/sh
set -eu
case "$1" in
  print-architecture)
    printf '%s\n' 'arch all 100' 'arch mipsel-3.4 150' 'arch mipsel-3.4_kn 200'
    ;;
  list-installed)
    printf '%s\n' 'hrneo - 3.18.3-1'
    ;;
  files)
    [ "$2" = hrneo ] || exit 2
    printf '%s\n'       'Package hrneo (3.18.3-1) is installed on root and has the following files:'       '/opt/bin/hrneo'       '/opt/etc/init.d/S99hrneo'       '/opt/lib/hrneo-link'       '/opt/share/hrneo'       '/opt/missing'
    ;;
  status)
    [ "$2" = hrneo ] || exit 2
    printf '%s\n' 'Package: hrneo' 'Version: 3.18.3-1' 'Status: install user installed'
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod 700 "$BIN/opkg"

cat > "$BIN/curl" <<'EOF'
#!/bin/sh
set -eu
fixture=${HOMEROUTE_TEST_IPK:?}
dest=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      dest=$2
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[ -n "$dest" ] || exit 2
cp "$fixture" "$dest"
EOF
chmod 700 "$BIN/curl"

plan=$(sh "$CAPTURE" plan)
printf '%s\n' "$plan" | grep -Fx 'HOMEROUTE_HRNEO_RESCUE package_change=false' >/dev/null ||
  fail 'capture plan lost package safety boundary'
printf '%s\n' "$plan" | grep -Fx 'HOMEROUTE_HRNEO_RESCUE result=PLAN_ONLY' >/dev/null ||
  fail 'capture plan result missing'

if PATH="$BIN:$PATH"    HOMEROUTE_HRNEO_RESCUE_TEST_MODE=1    HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"    HOMEROUTE_ROUTER_BACKUP_ROOT="$BACKUPS"    HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"    HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"    HOMEROUTE_TEST_IPK="$FIXTURE"    sh "$CAPTURE" capture >/dev/null 2>&1; then
  fail 'rescue capture unexpectedly ran without explicit ACK'
fi

out=$(PATH="$BIN:$PATH"   HOMEROUTE_HRNEO_RESCUE_ACK=YES   HOMEROUTE_HRNEO_RESCUE_TEST_MODE=1   HOMEROUTE_HRNEO_LIVE_ROOT="$LIVE"   HOMEROUTE_ROUTER_BACKUP_ROOT="$BACKUPS"   HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"   HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh"   HOMEROUTE_TEST_IPK="$FIXTURE"   sh "$CAPTURE" capture)

for expected in   'HOMEROUTE_HRNEO_RESCUE schema=1'   'HOMEROUTE_HRNEO_RESCUE mode=capture'   'HOMEROUTE_HRNEO_RESCUE package=hrneo'   'HOMEROUTE_HRNEO_RESCUE version=3.18.3-1'   'HOMEROUTE_HRNEO_RESCUE arch=mipsel-3.4'   'HOMEROUTE_HRNEO_RESCUE regular_files=2'   'HOMEROUTE_HRNEO_RESCUE symlinks=1'   'HOMEROUTE_HRNEO_RESCUE directories=1'   'HOMEROUTE_HRNEO_RESCUE missing_paths=1'   'HOMEROUTE_HRNEO_RESCUE package_change=false'   'HOMEROUTE_HRNEO_RESCUE service_restart=false'   'HOMEROUTE_HRNEO_RESCUE network_change=false'   'HOMEROUTE_HRNEO_RESCUE result=PASS'
do
  printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null ||
    fail "missing rescue capture field: $expected"
done

rescue=$(printf '%s\n' "$out" | sed -n 's/^HOMEROUTE_HRNEO_RESCUE rescue_dir=//p')
[ -d "$rescue" ] || fail 'rescue directory was not created'

verify=$(HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"   HOMEROUTE_TEST_IPK="$FIXTURE"   sh "$VERIFY" "$rescue")

printf '%s\n' "$verify" | grep -Fx 'HOMEROUTE_HRNEO_RESCUE_VERIFY result=PASS' >/dev/null ||
  fail 'rescue verifier did not pass'

printf '%s\n' 'tampered' >> "$rescue/files/opt/bin/hrneo"
if HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh"    HOMEROUTE_TEST_IPK="$FIXTURE"    sh "$VERIFY" "$rescue" >/dev/null 2>&1; then
  fail 'rescue verifier unexpectedly accepted tampered backup file'
fi

printf '%s\n' '[PASS] HRNeo rescue-set capture/verify contract'
