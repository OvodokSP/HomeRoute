#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/vps/preflight-container-shape.sh"
TMPDIR_BASE=${TMPDIR:-/tmp}
BASE="$TMPDIR_BASE/homeroute-vps-shape-test.$$"
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

if [ "$1" = "inspect" ] && [ "$2" = "-f" ]; then
    template=$3
    name=$4
    case "$name:$template" in
        "amnezia-awg2:{{.State.Status}}"|"adguard-home:{{.State.Status}}")
            printf '%s\n' running ;;
        "amnezia-awg2:{{.Image}}")
            printf '%s\n' sha256:awgfixture ;;
        "adguard-home:{{.Image}}")
            printf '%s\n' sha256:adguardfixture ;;
        "amnezia-awg2:{{range "*)
            case "$template" in
                *NetworkSettings.Networks*) printf '%s\n' 'amnezia-dns-net;bridge;' ;;
                *Mounts*) printf '%s\n' 'bind:/opt/amnezia:rw=true;' ;;
                *NetworkSettings.Ports*) printf '%s\n' '35404/udp:bindings=1;' ;;
                *Config.ExposedPorts*) printf '%s\n' '35404/udp;' ;;
                *) exit 1 ;;
            esac ;;
        "adguard-home:{{range "*)
            case "$template" in
                *NetworkSettings.Networks*) printf '%s\n' 'amnezia-dns-net;' ;;
                *Mounts*) printf '%s\n' 'bind:/opt/adguardhome/work:rw=true;bind:/opt/adguardhome/conf:rw=true;' ;;
                *NetworkSettings.Ports*) printf '%s\n' '53/tcp:bindings=0;53/udp:bindings=0;' ;;
                *Config.ExposedPorts*) printf '%s\n' '53/tcp;53/udp;' ;;
                *) exit 1 ;;
            esac ;;
        "amnezia-awg2:{{.HostConfig.AutoRemove}}"|"adguard-home:{{.HostConfig.AutoRemove}}")
            printf '%s\n' false ;;
        "amnezia-awg2:{{.HostConfig.ReadonlyRootfs}}"|"adguard-home:{{.HostConfig.ReadonlyRootfs}}")
            printf '%s\n' false ;;
        *) exit 1 ;;
    esac
    exit 0
fi

if [ "$1" = "image" ] && [ "$2" = "inspect" ] && [ "$3" = "-f" ]; then
    template=$4
    image=$5
    case "$image:$template" in
        "sha256:awgfixture:{{range .RepoTags}}{{.}};{{end}}")
            printf '%s\n' 'example/awg2:2.x;' ;;
        "sha256:adguardfixture:{{range .RepoTags}}{{.}};{{end}}")
            printf '%s\n' 'adguard/adguardhome:stable;' ;;
        "sha256:awgfixture:{{range .RepoDigests}}{{.}};{{end}}")
            printf '%s\n' 'example/awg2@sha256:fixture;' ;;
        "sha256:adguardfixture:{{range .RepoDigests}}{{.}};{{end}}")
            printf '%s\n' 'adguard/adguardhome@sha256:fixture;' ;;
        *) exit 1 ;;
    esac
    exit 0
fi

exit 1
EOF
chmod 700 "$BIN/docker"

out=$(PATH="$BIN:$PATH" sh "$SCRIPT")

for expected in \
    'HOMEROUTE_VPS_SHAPE schema=1' \
    'HOMEROUTE_VPS_SHAPE awg_repo_tags=example/awg2:2.x;' \
    'HOMEROUTE_VPS_SHAPE awg_repo_digests=example/awg2@sha256:fixture;' \
    'HOMEROUTE_VPS_SHAPE awg_networks=amnezia-dns-net;bridge;' \
    'HOMEROUTE_VPS_SHAPE awg_mount_destinations=bind:/opt/amnezia:rw=true;' \
    'HOMEROUTE_VPS_SHAPE awg_port_binding_shape=35404/udp:bindings=1;' \
    'HOMEROUTE_VPS_SHAPE adguard_networks=amnezia-dns-net;' \
    'HOMEROUTE_VPS_SHAPE adguard_mount_destinations=bind:/opt/adguardhome/work:rw=true;bind:/opt/adguardhome/conf:rw=true;' \
    'HOMEROUTE_VPS_SHAPE adguard_port_binding_shape=53/tcp:bindings=0;53/udp:bindings=0;'
do
    printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null || fail "missing container-shape field: $expected"
done

if printf '%s\n' "$out" | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}|PASSWORD=|TOKEN=|/host/secret|HostPort=[0-9]' >/dev/null; then
    fail 'container-shape preflight emitted forbidden sensitive pattern'
fi

printf '%s\n' '[PASS] VPS container-shape sanitized contract'
