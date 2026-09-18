#!/bin/sh
# HomeRoute VPS runtime preflight.
# Read-only and sanitized: no Env values, IP addresses, port bindings,
# mount source paths, labels, container command lines, or secret/config contents.

set -eu

AWG_CONTAINER=${AWG_CONTAINER:-amnezia-awg2}
ADGUARD_CONTAINER=${ADGUARD_CONTAINER:-adguard-home}

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
field() {
    key=$1
    value=$2
    [ -n "$value" ] || value=NOT_VALIDATED
    printf 'HOMEROUTE_VPS_RUNTIME %s=%s\n' "$key" "$value"
}

inspect_scalar() {
    container=$1
    template=$2
    docker inspect -f "$template" "$container" 2>/dev/null || true
}

container_capture() {
    prefix=$1
    name=$2

    status=$(inspect_scalar "$name" '{{.State.Status}}')
    field "${prefix}_container_status" "$status"

    [ "$status" = "running" ] || {
        warn "container $name is not running; provisioning metadata is partial"
        return
    }

    image_ref=$(inspect_scalar "$name" '{{.Config.Image}}')
    image_id=$(inspect_scalar "$name" '{{.Image}}')
    restart=$(inspect_scalar "$name" '{{.HostConfig.RestartPolicy.Name}}')
    network_mode=$(inspect_scalar "$name" '{{.HostConfig.NetworkMode}}')
    privileged=$(inspect_scalar "$name" '{{.HostConfig.Privileged}}')

    network_count=$(docker inspect -f '{{len .NetworkSettings.Networks}}' "$name" 2>/dev/null || true)
    mount_count=$(docker inspect -f '{{len .Mounts}}' "$name" 2>/dev/null || true)

    field "${prefix}_image_reference" "$image_ref"
    field "${prefix}_image_id" "$image_id"
    field "${prefix}_restart_policy" "$restart"
    field "${prefix}_network_mode" "$network_mode"
    field "${prefix}_network_attachment_count" "$network_count"
    field "${prefix}_mount_count" "$mount_count"
    field "${prefix}_privileged" "$privileged"
}

info "HomeRoute VPS runtime preflight (read-only; sanitized)"

if ! command -v docker >/dev/null 2>&1; then
    printf '%s\n' '[FAIL] Docker command is unavailable' >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    printf '%s\n' '[FAIL] Docker daemon is unavailable' >&2
    exit 1
fi

field schema 1
field docker_version "$(docker --version 2>/dev/null | sed -n '1p')"
field awg_container_name "$AWG_CONTAINER"
field adguard_container_name "$ADGUARD_CONTAINER"

container_capture awg "$AWG_CONTAINER"
container_capture adguard "$ADGUARD_CONTAINER"

info "No Env values, IP addresses, published ports, mount source paths, labels or command lines were collected"
printf '%s\n' '[PASS] VPS runtime preflight complete'
