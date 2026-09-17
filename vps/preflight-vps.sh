#!/bin/sh
# Read-only VPS inventory. Intentionally avoids hostnames, public addresses and secret/config contents.

AWG_CONTAINER=${AWG_CONTAINER:-amnezia-awg2}
ADGUARD_CONTAINER=${ADGUARD_CONTAINER:-adguard-home}
VPS_AWG_INTERFACE=${VPS_AWG_INTERFACE:-awg0}

section() { printf '\n[INFO] === %s ===\n' "$1"; }
inventory() {
    key=$1
    value=$2
    [ -n "$value" ] || value=NOT_VALIDATED
    printf 'HOMEROUTE_INVENTORY %s=%s\n' "$key" "$value"
}
container_status() {
    name=$1
    if ! command -v docker >/dev/null 2>&1; then
        printf '%s' NOT_VALIDATED
        return
    fi
    docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || printf '%s' absent
}

printf '[INFO] HomeRoute VPS preflight (read-only; sanitized for public inventory)\n'

section "System"
printf '[INFO] Kernel: '
uname -sr 2>/dev/null || printf 'unavailable\n'
printf '[INFO] Architecture: '
uname -m 2>/dev/null || printf 'unavailable\n'
if [ -r /etc/os-release ]; then
    os_id=$(sed -n 's/^ID=//p' /etc/os-release | head -1 | tr -d '"')
    os_version_id=$(sed -n 's/^VERSION_ID=//p' /etc/os-release | head -1 | tr -d '"')
    printf '[INFO] OS: %s %s\n' "${os_id:-unknown}" "${os_version_id:-unknown}"
else
    os_id=
    os_version_id=
    printf '[WARN] /etc/os-release is unavailable\n'
fi
if command -v getconf >/dev/null 2>&1; then
    vcpu_count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)
else
    vcpu_count=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || true)
fi
printf '[INFO] vCPU count: %s\n' "${vcpu_count:-unknown}"
if command -v free >/dev/null 2>&1; then
    free -h 2>&1
fi

section "Filesystem"
if command -v df >/dev/null 2>&1; then
    df -h / 2>&1 || true
    root_total=$(df -kP / 2>/dev/null | awk 'NR==2 {print $2 "_KiB"}')
    root_free=$(df -kP / 2>/dev/null | awk 'NR==2 {print $4 "_KiB"}')
else
    root_total=
    root_free=
    printf '[WARN] df is unavailable\n'
fi

section "Docker and HomeRoute services"
if command -v docker >/dev/null 2>&1; then
    docker_path=$(command -v docker 2>/dev/null || true)
    docker_version=$(docker --version 2>/dev/null | sed -n '1p')
    printf '[INFO] Docker: %s\n' "${docker_version:-version unavailable}"

    awg_status=$(container_status "$AWG_CONTAINER")
    adguard_status=$(container_status "$ADGUARD_CONTAINER")
    printf '[INFO] AWG2 container %s status=%s\n' "$AWG_CONTAINER" "$awg_status"
    printf '[INFO] AdGuard container %s status=%s\n' "$ADGUARD_CONTAINER" "$adguard_status"

    if [ "$awg_status" = running ]; then
        if docker exec "$AWG_CONTAINER" ip link show "$VPS_AWG_INTERFACE" >/dev/null 2>&1; then
            awg_interface_present=true
            printf '[INFO] AWG interface %s is present inside %s\n' "$VPS_AWG_INTERFACE" "$AWG_CONTAINER"
        else
            awg_interface_present=false
            printf '[WARN] AWG interface %s was not found inside %s\n' "$VPS_AWG_INTERFACE" "$AWG_CONTAINER"
        fi
    else
        awg_interface_present=NOT_VALIDATED
    fi
else
    docker_path=
    docker_version=
    awg_status=NOT_VALIDATED
    adguard_status=NOT_VALIDATED
    awg_interface_present=NOT_VALIDATED
    printf '[WARN] docker is unavailable\n'
fi

section "Machine-readable safe inventory"
inventory inventory_schema 1
inventory inventory_type vps
inventory os_id "$os_id"
inventory os_version_id "$os_version_id"
inventory kernel_release "$(uname -r 2>/dev/null || true)"
inventory uname_machine "$(uname -m 2>/dev/null || true)"
inventory vcpu_count "$vcpu_count"
inventory ram_total "$(awk '/^MemTotal:/ {print $2 "_KiB"; exit}' /proc/meminfo 2>/dev/null || true)"
inventory root_total "$root_total"
inventory root_free "$root_free"
inventory component_docker "$docker_path"
inventory docker_version "$docker_version"
inventory awg_container_status "$awg_status"
inventory adguard_container_status "$adguard_status"
inventory awg_interface_present "$awg_interface_present"

printf '[INFO] VPS preflight complete; hostnames, addresses, credentials and VPN configuration contents were not collected\n'
