#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/vps/preflight-live-restore.sh"
BASE=${TMPDIR:-/tmp}/homeroute-restore-readiness-test.$$
BIN="$BASE/bin"
BACKUPS="$BASE/backups"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BIN" "$BACKUPS/awg-state" "$BACKUPS/adguard-state" "$BACKUPS/awg-image" "$BACKUPS/adguard-image"

cat > "$BASE/verify-rescue-set.sh" <<'EOF'
#!/bin/sh
set -eu
for name in HOMEROUTE_AWG_STATE_BACKUP HOMEROUTE_ADGUARD_STATE_BACKUP HOMEROUTE_AWG_IMAGE_BACKUP HOMEROUTE_ADGUARD_IMAGE_BACKUP; do
    eval "value=\${$name:-}"
    [ -d "$value" ] || exit 2
done
exit 0
EOF
chmod 700 "$BASE/verify-rescue-set.sh"

cat > "$BACKUPS/awg-image/metadata.txt" <<'EOF'
image_id=sha256:awg-fixture
EOF
cat > "$BACKUPS/adguard-image/metadata.txt" <<'EOF'
image_id=sha256:adguard-fixture
EOF

cat > "$BIN/docker" <<'EOF'
#!/bin/sh
set -eu
case "$1" in
  info) exit 0 ;;
  inspect)
    shift
    [ "$1" = "-f" ] || exit 2
    format=$2
    name=$3
    case "$format:$name" in
      '{{.State.Status}}:amnezia-awg2'|'{{.State.Status}}:adguard-home')
        printf '%s\n' running ;;
      '{{.Image}}:amnezia-awg2')
        printf '%s\n' "${HOMEROUTE_TEST_AWG_IMAGE:-sha256:awg-fixture}" ;;
      '{{.Image}}:adguard-home')
        printf '%s\n' "${HOMEROUTE_TEST_ADGUARD_IMAGE:-sha256:adguard-fixture}" ;;
      *) exit 2 ;;
    esac
    ;;
  *) exit 2 ;;
esac
EOF
chmod 700 "$BIN/docker"

out=$(PATH="$BIN:$PATH" \
  HOMEROUTE_RESCUE_VERIFIER="$BASE/verify-rescue-set.sh" \
  HOMEROUTE_AWG_STATE_BACKUP="$BACKUPS/awg-state" \
  HOMEROUTE_ADGUARD_STATE_BACKUP="$BACKUPS/adguard-state" \
  HOMEROUTE_AWG_IMAGE_BACKUP="$BACKUPS/awg-image" \
  HOMEROUTE_ADGUARD_IMAGE_BACKUP="$BACKUPS/adguard-image" \
  sh "$SCRIPT")

for expected in \
  'HOMEROUTE_RESTORE_READINESS schema=1' \
  'HOMEROUTE_RESTORE_READINESS rescue_set_integrity=PASS' \
  'HOMEROUTE_RESTORE_READINESS awg_container_state=running' \
  'HOMEROUTE_RESTORE_READINESS adguard_container_state=running' \
  'HOMEROUTE_RESTORE_READINESS awg_image_matches_rescue=true' \
  'HOMEROUTE_RESTORE_READINESS adguard_image_matches_rescue=true' \
  'HOMEROUTE_RESTORE_READINESS live_restore_executed=false' \
  'HOMEROUTE_RESTORE_READINESS image_load_executed=false' \
  'HOMEROUTE_RESTORE_READINESS container_restart_executed=false' \
  'HOMEROUTE_RESTORE_READINESS result=READY_FOR_CONTROLLED_VALIDATION'
do
    printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null || fail "missing readiness field: $expected"
done

if PATH="$BIN:$PATH" \
  HOMEROUTE_RESCUE_VERIFIER="$BASE/verify-rescue-set.sh" \
  HOMEROUTE_AWG_STATE_BACKUP="$BACKUPS/awg-state" \
  HOMEROUTE_ADGUARD_STATE_BACKUP="$BACKUPS/adguard-state" \
  HOMEROUTE_AWG_IMAGE_BACKUP="$BACKUPS/awg-image" \
  HOMEROUTE_ADGUARD_IMAGE_BACKUP="$BACKUPS/adguard-image" \
  HOMEROUTE_TEST_AWG_IMAGE='sha256:drifted' \
  sh "$SCRIPT" >/dev/null 2>&1; then
    fail 'readiness gate unexpectedly accepted AWG image drift'
fi

printf '%s\n' '[PASS] VPS live-restore readiness gate contract'
