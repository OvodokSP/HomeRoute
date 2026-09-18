#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RENDER="$ROOT/vps/render-container-plan.sh"

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

OUT=${TMPDIR:-/tmp}/homeroute-vps-render.$$
trap 'rm -f "$OUT"' EXIT HUP INT TERM

if sh "$RENDER" >"$OUT" 2>&1; then
    fail 'renderer unexpectedly succeeded without local parameters'
fi
grep -F 'HOMEROUTE_VPS_DESIRED result=BLOCKED missing_local_parameters=7' "$OUT" >/dev/null ||
    fail 'renderer missing-parameter gate drifted'

HOMEROUTE_AWG_IMAGE='pinned-awg-image' \
HOMEROUTE_AWG_MODULES_SOURCE='/fixture/modules' \
HOMEROUTE_AWG_HOST_UDP_PORT='30000' \
HOMEROUTE_AWG_STATE_SOURCE='/fixture/awg-state' \
HOMEROUTE_ADGUARD_IMAGE='pinned-adguard-image' \
HOMEROUTE_ADGUARD_CONF_SOURCE='/fixture/adguard-conf' \
HOMEROUTE_ADGUARD_WORK_SOURCE='/fixture/adguard-work' \
sh "$RENDER" >"$OUT"

grep -Fx 'HOMEROUTE_VPS_DESIRED result=READY_FOR_SANDBOX_RENDER' "$OUT" >/dev/null ||
    fail 'renderer did not become ready with all local parameters'

for forbidden in     'pinned-awg-image'     '/fixture/modules'     '30000'     '/fixture/awg-state'     'pinned-adguard-image'     '/fixture/adguard-conf'     '/fixture/adguard-work'
do
    if grep -F "$forbidden" "$OUT" >/dev/null; then
        fail "renderer leaked local parameter value: $forbidden"
    fi
done

grep -Fx 'HOMEROUTE_VPS_DESIRED awg_state_backup_required=true' "$OUT" >/dev/null ||
    fail 'AWG state backup gate missing'

printf '%s\n' '[PASS] VPS desired-state renderer contract'
