#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/vps/preflight-runtime.sh"
TMPDIR_BASE=${TMPDIR:-/tmp}
BASE="$TMPDIR_BASE/homeroute-vps-runtime-test.$$"
BIN="$BASE/bin"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BIN"

cat > "$BIN/docker" <<'EOF'
#!/bin/sh
set -eu

if [ "$1" = "info" ]; then
    exit 0
fi

if [ "$1" = "--version" ]; then
    printf '%s\n' 'Docker version 29.1.3, build fixture'
    exit 0
fi

if [ "$1" = "inspect" ] && [ "$2" = "-f" ]; then
    template=$3
    name=$4
    case "$name:$template" in
        "amnezia-awg2:{{.State.Status}}"|"adguard-home:{{.State.Status}}")
            printf '%s\n' running ;;
        "amnezia-awg2:{{.Config.Image}}")
            printf '%s\n' example/awg2:2.x ;;
        "adguard-home:{{.Config.Image}}")
            printf '%s\n' example/adguard:stable ;;
        "amnezia-awg2:{{.Image}}")
            printf '%s\n' sha256:awgfixture ;;
        "adguard-home:{{.Image}}")
            printf '%s\n' sha256:adguardfixture ;;
        "amnezia-awg2:{{.HostConfig.RestartPolicy.Name}}"|"adguard-home:{{.HostConfig.RestartPolicy.Name}}")
            printf '%s\n' unless-stopped ;;
        "amnezia-awg2:{{.HostConfig.NetworkMode}}"|"adguard-home:{{.HostConfig.NetworkMode}}")
            printf '%s\n' bridge ;;
        "amnezia-awg2:{{.HostConfig.Privileged}}")
            printf '%s\n' true ;;
        "adguard-home:{{.HostConfig.Privileged}}")
            printf '%s\n' false ;;
        "amnezia-awg2:{{len .NetworkSettings.Networks}}")
            printf '%s\n' 1 ;;
        "adguard-home:{{len .NetworkSettings.Networks}}")
            printf '%s\n' 2 ;;
        "amnezia-awg2:{{len .Mounts}}")
            printf '%s\n' 1 ;;
        "adguard-home:{{len .Mounts}}")
            printf '%s\n' 3 ;;
        *)
            exit 1 ;;
    esac
    exit 0
fi

exit 1
EOF
chmod 700 "$BIN/docker"

out=$(PATH="$BIN:$PATH" AWG_CONTAINER=amnezia-awg2 ADGUARD_CONTAINER=adguard-home sh "$SCRIPT")

for expected in \
    'HOMEROUTE_VPS_RUNTIME schema=1' \
    'HOMEROUTE_VPS_RUNTIME awg_image_reference=example/awg2:2.x' \
    'HOMEROUTE_VPS_RUNTIME awg_image_id=sha256:awgfixture' \
    'HOMEROUTE_VPS_RUNTIME awg_restart_policy=unless-stopped' \
    'HOMEROUTE_VPS_RUNTIME awg_network_mode=bridge' \
    'HOMEROUTE_VPS_RUNTIME awg_network_attachment_count=1' \
    'HOMEROUTE_VPS_RUNTIME awg_mount_count=1' \
    'HOMEROUTE_VPS_RUNTIME awg_privileged=true' \
    'HOMEROUTE_VPS_RUNTIME adguard_image_reference=example/adguard:stable' \
    'HOMEROUTE_VPS_RUNTIME adguard_image_id=sha256:adguardfixture' \
    'HOMEROUTE_VPS_RUNTIME adguard_restart_policy=unless-stopped' \
    'HOMEROUTE_VPS_RUNTIME adguard_network_mode=bridge' \
    'HOMEROUTE_VPS_RUNTIME adguard_network_attachment_count=2' \
    'HOMEROUTE_VPS_RUNTIME adguard_mount_count=3' \
    'HOMEROUTE_VPS_RUNTIME adguard_privileged=false'
do
    printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null || fail "missing runtime field: $expected"
done

if printf '%s\n' "$out" | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}|PRIVATE|PASSWORD|TOKEN|Mounts.*Source|Env=' >/dev/null; then
    fail 'runtime preflight emitted forbidden sensitive pattern'
fi

printf '%s\n' '[PASS] VPS runtime preflight sanitized contract'
