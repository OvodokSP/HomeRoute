#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/router/rehearse-hrneo-rollback.sh"

BASE=${TMPDIR:-/tmp}/homeroute-hrneo-rollback-rehearsal-contract.$$
TMPROOT=/tmp/homeroute-hrneo-rollback-rehearsal-test.$$
RESCUE_BASE=/tmp/homeroute-hrneo-rescue-test.$$
RESCUE="$RESCUE_BASE/hrneo-rescue-fixture"
BIN="$BASE/bin"
trap 'rm -rf "$BASE" "$TMPROOT" "$RESCUE_BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BASE" "$BIN" "$TMPROOT"

cat > "$BASE/prepare.sh" <<'EOF'
#!/bin/sh
set -eu
rescue=${HOMEROUTE_TEST_RESCUE:?}
[ "${1:-}" = capture ] || exit 2
mkdir -p "$rescue"
printf 'HOMEROUTE_HRNEO_RESCUE rescue_dir=%s\n' "$rescue"
printf '%s\n' 'HOMEROUTE_HRNEO_RESCUE result=PASS'
EOF
chmod 700 "$BASE/prepare.sh"

cat > "$BASE/capture-control.sh" <<'EOF'
#!/bin/sh
set -eu
[ "${1:-}" = capture ] || exit 2
[ -d "${2:-}" ] || exit 2
printf '%s\n' 'HOMEROUTE_HRNEO_OPKG_RESCUE result=PASS'
EOF
chmod 700 "$BASE/capture-control.sh"

cat > "$BASE/capture-status.sh" <<'EOF'
#!/bin/sh
set -eu
[ "${1:-}" = capture ] || exit 2
[ -d "${2:-}" ] || exit 2
printf '%s\n' 'HOMEROUTE_HRNEO_STATUS_RESCUE result=PASS'
EOF
chmod 700 "$BASE/capture-status.sh"

cat > "$BASE/live-verify.sh" <<'EOF'
#!/bin/sh
set -eu
[ -d "${1:-}" ] || exit 2
printf '%s\n' 'HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFY result=PASS'
EOF
chmod 700 "$BASE/live-verify.sh"

cat > "$BASE/validator.sh" <<'EOF'
#!/bin/sh
set -eu
[ "${1:-}" = validate ] || exit 2
[ -d "${2:-}" ] || exit 2
[ "${HOMEROUTE_HRNEO_REINSTALL_FORCE_VERIFY_FAIL:-0}" = 1 ] || exit 2
printf '%s\n' '[FAIL] forced post-install verification failure requested' >&2
printf '%s\n' '[PASS] automatic HRNeo rollback completed' >&2
exit 2
EOF
chmod 700 "$BASE/validator.sh"

for name in base-verify.sh control-verify.sh status-verify.sh artifact.sh doctor.sh; do
  cat > "$BASE/$name" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod 700 "$BASE/$name"
done

cat > "$BIN/opkg" <<'EOF'
#!/bin/sh
set -eu
[ "$1" = list-installed ] || exit 2
printf '%s\n' \
  'hrneo - 3.18.3-1' \
  'ip-full - 1' \
  'ipset - 1' \
  'iptables - 1' \
  'libc - 1'
EOF
chmod 700 "$BIN/opkg"

plan=$(sh "$SCRIPT" plan)
for expected in \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL schema=1' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL mode=plan' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL fresh_rescue=true' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL forced_postinstall_failure=true' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL automatic_rollback_required=true' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL independent_post_rollback_verify=true' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL result=PLAN_ONLY'
do
  printf '%s\n' "$plan" | grep -Fx "$expected" >/dev/null ||
    fail "missing plan field: $expected"
done

if PATH="$BIN:$PATH" \
   HOMEROUTE_TEST_RESCUE="$RESCUE" \
   HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL_TEST_MODE=1 \
   HOMEROUTE_HRNEO_ROLLBACK_TMPROOT="$TMPROOT" \
   HOMEROUTE_HRNEO_RESCUE_PREPARE="$BASE/prepare.sh" \
   HOMEROUTE_HRNEO_OPKG_STATE_CAPTURE="$BASE/capture-control.sh" \
   HOMEROUTE_HRNEO_OPKG_STATUS_CAPTURE="$BASE/capture-status.sh" \
   HOMEROUTE_HRNEO_RESCUE_VERIFIER="$BASE/base-verify.sh" \
   HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$BASE/control-verify.sh" \
   HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER="$BASE/status-verify.sh" \
   HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFIER="$BASE/live-verify.sh" \
   HOMEROUTE_HRNEO_REINSTALL_VALIDATOR="$BASE/validator.sh" \
   HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh" \
   HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh" \
   sh "$SCRIPT" rehearse >/dev/null 2>&1; then
  fail 'rollback rehearsal unexpectedly ran without explicit ACK'
fi

out=$(PATH="$BIN:$PATH" \
  HOMEROUTE_TEST_RESCUE="$RESCUE" \
  HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL_ACK=YES \
  HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL_TEST_MODE=1 \
  HOMEROUTE_HRNEO_ROLLBACK_TMPROOT="$TMPROOT" \
  HOMEROUTE_HRNEO_RESCUE_PREPARE="$BASE/prepare.sh" \
  HOMEROUTE_HRNEO_OPKG_STATE_CAPTURE="$BASE/capture-control.sh" \
  HOMEROUTE_HRNEO_OPKG_STATUS_CAPTURE="$BASE/capture-status.sh" \
  HOMEROUTE_HRNEO_RESCUE_VERIFIER="$BASE/base-verify.sh" \
  HOMEROUTE_HRNEO_OPKG_RESCUE_VERIFIER="$BASE/control-verify.sh" \
  HOMEROUTE_HRNEO_STATUS_RESCUE_VERIFIER="$BASE/status-verify.sh" \
  HOMEROUTE_HRNEO_LIVE_RESCUE_VERIFIER="$BASE/live-verify.sh" \
  HOMEROUTE_HRNEO_REINSTALL_VALIDATOR="$BASE/validator.sh" \
  HOMEROUTE_HRNEO_ARTIFACT_TOOL="$BASE/artifact.sh" \
  HOMEROUTE_ROUTER_DOCTOR="$BASE/doctor.sh" \
  sh "$SCRIPT" rehearse)

for expected in \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL schema=1' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL mode=rehearse' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL package=hrneo' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL version=3.18.3-1' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL fresh_rescue=PASS' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL forced_postinstall_failure=true' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL automatic_rollback=PASS' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL live_state_matches_fresh_rescue=true' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL installed_package_set_unchanged=true' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL conffile_residue=none' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL doctor=PASS' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL live_rollback_validated=true' \
  'HOMEROUTE_HRNEO_ROLLBACK_REHEARSAL result=PASS'
do
  printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null ||
    fail "missing rehearsal field: $expected"
done

[ -f "$RESCUE/rollback-rehearsal-evidence.txt" ] ||
  fail 'rollback rehearsal evidence file was not written'
grep -Fx 'automatic_rollback=PASS' "$RESCUE/rollback-rehearsal-evidence.txt" >/dev/null ||
  fail 'rollback rehearsal evidence lacks rollback PASS'
grep -Fx 'live_state_matches_fresh_rescue=true' "$RESCUE/rollback-rehearsal-evidence.txt" >/dev/null ||
  fail 'rollback rehearsal evidence lacks live-state match'

[ -f "$RESCUE/rollback-rehearsal-validator.out" ] ||
  fail 'validator stdout diagnostic was not preserved'
[ -f "$RESCUE/rollback-rehearsal-validator.err" ] ||
  fail 'validator stderr diagnostic was not preserved'
grep -F '[FAIL] forced post-install verification failure requested' \
  "$RESCUE/rollback-rehearsal-validator.err" >/dev/null ||
  fail 'preserved validator stderr lacks forced-failure marker'
grep -F '[PASS] automatic HRNeo rollback completed' \
  "$RESCUE/rollback-rehearsal-validator.err" >/dev/null ||
  fail 'preserved validator stderr lacks rollback PASS marker'

printf '%s\n' '[PASS] controlled HRNeo live rollback rehearsal contract'
