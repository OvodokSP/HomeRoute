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

printf '[INFO] HomeRoute router preflight (read-only; no secret contents)\n'
section "System"
run_if_available "Kernel" uname -a
run_if_available "CPU architecture" uname -m
printf '[INFO] CPU summary\n'
if [ -r /proc/cpuinfo ]; then
    awk -F: '/^(system type|machine|model name|processor|cpu model|Hardware)/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $1 ": " $2}' /proc/cpuinfo | sort -u
else
    printf '[WARN] /proc/cpuinfo is unavailable\n'
fi
run_if_available "RAM" free -h

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
printf '[INFO] Preflight complete; configuration contents and secrets were not read\n'
