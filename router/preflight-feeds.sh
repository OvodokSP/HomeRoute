#!/bin/sh
# Read-only inventory of Entware opkg feed configuration.
# It prints feed names/URLs only and redacts URLs containing userinfo.

set -eu

OPKG_DIR=${HOMEROUTE_OPKG_DIR:-/opt/etc/opkg}

printf '%s\n' '[INFO] HomeRoute opkg feed inventory (read-only)'

if command -v opkg >/dev/null 2>&1; then
    printf '%s\n' '[INFO] opkg architectures:'
    opkg print-architecture 2>/dev/null || true
else
    printf '%s\n' '[WARN] opkg command not found'
fi

[ -d "$OPKG_DIR" ] || {
    printf '[WARN] opkg config directory not found: %s\n' "$OPKG_DIR"
    exit 0
}

found=0
for file in "$OPKG_DIR"/*.conf; do
    [ -f "$file" ] || continue
    base=$(basename "$file")
    while IFS=' ' read -r kind name url rest; do
        case "$kind" in
            src|src/gz)
                found=1
                case "$url" in
                    *://*@*) safe_url='[REDACTED_URL_WITH_USERINFO]' ;;
                    *) safe_url=$url ;;
                esac
                printf 'HOMEROUTE_FEED file=%s kind=%s name=%s url=%s\n' "$base" "$kind" "$name" "$safe_url"
                ;;
        esac
    done < "$file"
done

[ "$found" -eq 1 ] || printf '%s\n' '[WARN] no src/src-gz feed lines found'
printf '%s\n' '[PASS] opkg feed inventory complete; no files were changed'
