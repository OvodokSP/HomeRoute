#!/bin/sh
# HomeRoute VPS container-shape preflight.
# Read-only, sanitized structural metadata only.
# Never prints environment values, IP addresses, host mount sources,
# labels, command lines, secrets, or host port numbers.

set -eu

AWG_CONTAINER=${AWG_CONTAINER:-amnezia-awg2}
ADGUARD_CONTAINER=${ADGUARD_CONTAINER:-adguard-home}

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
field() {
    key=$1
    value=$2
    [ -n "$value" ] || value=NOT_VALIDATED
    printf 'HOMEROUTE_VPS_SHAPE %s=%s\n' "$key" "$value"
}

inspect() {
    name=$1
    template=$2
    docker inspect -f "$template" "$name" 2>/dev/null || true
}

image_inspect() {
    image=$1
    template=$2
    docker image inspect -f "$template" "$image" 2>/dev/null || true
}

capture_container() {
    prefix=$1
    name=$2

    status=$(inspect "$name" '{{.State.Status}}')
    field "${prefix}_status" "$status"
    [ "$status" = running ] || {
        warn "container $name is not running; shape capture is partial"
        return
    }

    image_id=$(inspect "$name" '{{.Image}}')
    repo_tags=$(image_inspect "$image_id" '{{range .RepoTags}}{{.}};{{end}}')
    repo_digests=$(image_inspect "$image_id" '{{range .RepoDigests}}{{.}};{{end}}')
    networks=$(inspect "$name" '{{range $name, $_ := .NetworkSettings.Networks}}{{$name}};{{end}}')
    mounts=$(inspect "$name" '{{range .Mounts}}{{.Type}}:{{.Destination}}:rw={{.RW}};{{end}}')
    ports=$(inspect "$name" '{{range $port, $bindings := .NetworkSettings.Ports}}{{$port}}:bindings={{len $bindings}};{{end}}')
    exposed=$(inspect "$name" '{{range $port, $_ := .Config.ExposedPorts}}{{$port}};{{end}}')
    auto_remove=$(inspect "$name" '{{.HostConfig.AutoRemove}}')
    readonly_rootfs=$(inspect "$name" '{{.HostConfig.ReadonlyRootfs}}')

    field "${prefix}_repo_tags" "$repo_tags"
    field "${prefix}_repo_digests" "$repo_digests"
    field "${prefix}_networks" "$networks"
    field "${prefix}_mount_destinations" "$mounts"
    field "${prefix}_port_binding_shape" "$ports"
    field "${prefix}_exposed_ports" "$exposed"
    field "${prefix}_auto_remove" "$auto_remove"
    field "${prefix}_readonly_rootfs" "$readonly_rootfs"
}

info "HomeRoute VPS container-shape preflight (read-only; sanitized)"

if ! command -v docker >/dev/null 2>&1; then
    printf '%s\n' '[FAIL] Docker command is unavailable' >&2
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    printf '%s\n' '[FAIL] Docker daemon is unavailable' >&2
    exit 1
fi

field schema 1
field awg_container_name "$AWG_CONTAINER"
field adguard_container_name "$ADGUARD_CONTAINER"

capture_container awg "$AWG_CONTAINER"
capture_container adguard "$ADGUARD_CONTAINER"

info "No Env values, IP addresses, host mount sources, host port numbers, labels or command lines were collected"
printf '%s\n' '[PASS] VPS container-shape preflight complete'
