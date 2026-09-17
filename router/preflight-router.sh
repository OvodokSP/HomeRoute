#!/bin/sh
# Read-only inventory. Never prints configuration file contents.

section() { printf '\n[INFO] === %s ===\n' "$1"; }
run_if_available() {
    label=$1
    shift
    if command -v "$1" >/dev/null 2>&1; then
        printf '[INFO] %s\n' "$label"
        "$@" 2>&1 || printf '[WARN] command failed: %s\n' "$1"
    else
        printf '[WARN] command unavailable: %s\n' "$1"
    fi
}
inventory() {
    key=$1
    value=$2
    [ -n "$value" ] || value=NOT_VALIDATED
    printf 'HOMEROUTE_INVENTORY %s=%s\n' "$key" "$value"
}

printf '[INFO] HomeRoute router preflight (read-only; no secret contents)\n'
section "System"
run_if_available "Kernel" uname -sr
run_if_available "CPU architecture" uname -m
printf '[INFO] CPU summary\n'
if [ -r /proc/cpuinfo ]; then
    awk -F: '/^(system type|machine|model name|processor|cpu model|Hardware)/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $1 ": " $2}' /proc/cpuinfo | sort -u
else
    printf '[WARN] /proc/cpuinfo is unavailable\n'
fi
run_if_available "RAM" free -h

section "Safe Keenetic identity"
keenetic_release=
router_model=
if command -v ndmc >/dev/null 2>&1; then
    version_out=$(ndmc -c 'show version' 2>/dev/null || true)
    keenetic_release=$(printf '%s\n' "$version_out" | awk -F: '/^[[:space:]]*release:/ {sub(/^[[:space:]]*/, "", $2); sub(/[[:space:]]*$/, "", $2); print $2; exit}')
    router_model=$(printf '%s\n' "$version_out" | awk -F: '/^[[:space:]]*model:/ {sub(/^[[:space:]]*/, "", $2); sub(/[[:space:]]*$/, "", $2); print $2; exit}')
    if [ -z "$router_model" ]; then
        router_model=$(printf '%s\n' "$version_out" | awk -F: '/^[[:space:]]*device:/ {sub(/^[[:space:]]*/, "", $2); sub(/[[:space:]]*$/, "", $2); print $2; exit}')
    fi
else
    printf '%s\n' '[WARN] ndmc is unavailable; Keenetic release/model may remain NOT_VALIDATED'
fi
if [ -z "$router_model" ] && [ -r /proc/device-tree/model ]; then
    router_model=$(tr -d '\000' < /proc/device-tree/model 2>/dev/null | sed -n '1p' || true)
fi
printf '[INFO] Keenetic release: %s\n' "${keenetic_release:-NOT_VALIDATED}"
printf '[INFO] Router model: %s\n' "${router_model:-NOT_VALIDATED}"

section "Filesystems"
run_if_available "Mounted filesystems" mount
if command -v df >/dev/null 2>&1; then
    printf '[INFO] Free space\n'; df -h 2>&1
    printf '[INFO] /opt filesystem\n'; df -h /opt 2>&1 || printf '[WARN] /opt is unavailable\n'
fi

section "Entware packages"
if command -v opkg >/dev/null 2>&1; then
    printf '[INFO] opkg architecture\n'; opkg print-architecture 2>&1
    printf '[INFO] installed opkg packages\n'; opkg list-installed 2>&1
else
    printf '[WARN] opkg is unavailable\n'
fi

section "Component binaries"
for name in awg awg-quick amneziawg-go hrneo nfqws tg-ws-proxy; do
    path=$(command -v "$name" 2>/dev/null || true)
    if [ -n "$path" ]; then
        printf '[INFO] %s path=%s\n' "$name" "$path"
        size=$(wc -c < "$path" 2>/dev/null || printf unknown)
        printf '[INFO] %s size=%s bytes\n' "$name" "$size"
        case "$name" in
            awg) "$path" --version 2>&1 | sed -n '1p' || true ;;
            *) "$path" --version 2>&1 | sed -n '1p' || printf '[INFO] version query unsupported\n' ;;
        esac
    else
        printf '[WARN] %s not found\n' "$name"
    fi
done

section "Relevant file names (contents intentionally omitted)"
for directory in /opt/etc/HydraRoute /opt/etc/telegram-awg; do
    if [ -d "$directory" ]; then
        find "$directory" -maxdepth 2 -type f -print 2>/dev/null | sort
    fi
done
for path in \
    /opt/etc/init.d/S98telegram-awg \
    /opt/etc/init.d/S99hrneo \
    /opt/etc/ndm/netfilter.d/014-telegram-awg.sh \
    /opt/etc/ndm/netfilter.d/015-hrneo.sh \
    /opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh \
    /opt/etc/ndm/ifstatechanged.d/015-hrneo.sh
do
    [ -e "$path" ] && printf '%s\n' "$path"
done

section "Machine-readable safe inventory"
inventory inventory_schema 1
inventory inventory_type router
inventory router_model "$router_model"
inventory keenetic_release "$keenetic_release"

uname_machine=$(uname -m 2>/dev/null || true)
inventory uname_machine "$uname_machine"

ram_total=$(awk '/^MemTotal:/ {print $2 "_KiB"; exit}' /proc/meminfo 2>/dev/null || true)
inventory ram_total "$ram_total"

if command -v df >/dev/null 2>&1 && [ -d /opt ]; then
    opt_total=$(df -kP /opt 2>/dev/null | awk 'NR==2 {print $2 "_KiB"}')
    opt_free=$(df -kP /opt 2>/dev/null | awk 'NR==2 {print $4 "_KiB"}')
else
    opt_total=
    opt_free=
fi
inventory opt_total "$opt_total"
inventory opt_free "$opt_free"

if command -v opkg >/dev/null 2>&1; then
    opkg_arch=$(opkg print-architecture 2>/dev/null | awk 'NF >= 2 {printf "%s%s", sep, $2; sep=","}')
else
    opkg_arch=
fi
inventory opkg_arch "$opkg_arch"

for name in awg awg-quick amneziawg-go hrneo nfqws tg-ws-proxy; do
    path=$(command -v "$name" 2>/dev/null || true)
    key=$(printf '%s' "$name" | tr '-' '_')
    inventory "component_$key" "$path"
done

section "Machine-readable opkg package inventory"
if command -v opkg >/dev/null 2>&1; then
    opkg list-installed 2>/dev/null | awk -F ' - ' '
        NF >= 2 {
            name=$1
            version=$2
            gsub(/^[ \t]+|[ \t]+$/, "", name)
            gsub(/^[ \t]+|[ \t]+$/, "", version)
            if (name != "" && version != "")
                print "HOMEROUTE_PACKAGE name=" name " version=" version
        }
    '
else
    printf '[WARN] package inventory unavailable because opkg is missing\n'
fi

printf '[INFO] Preflight complete; configuration contents and secrets were not read\n'
