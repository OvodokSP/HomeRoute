#!/bin/sh
set -eu

TMPDIR_BASE=${TMPDIR:-/tmp}
BASE="$TMPDIR_BASE/homeroute-backup-contract.$$"
DEVICE="$BASE/device"
BACKUP="$BASE/backup"
MANIFEST="$BACKUP/manifest"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$DEVICE/config" "$BACKUP/files/config"
printf '%s\n' 'original managed content' > "$DEVICE/config/existing.conf"
printf '%s\n' 'unrelated content' > "$DEVICE/config/unrelated.conf"
cp -p "$DEVICE/config/existing.conf" "$BACKUP/files/config/existing.conf"
cat > "$MANIFEST" <<'EOF'
present config/existing.conf
absent config/generated.conf
EOF

# Simulated apply in the fictitious root only.
printf '%s\n' 'changed managed content' > "$DEVICE/config/existing.conf"
printf '%s\n' 'created by transaction' > "$DEVICE/config/generated.conf"

# Simulated restore driven only by the manifest.
while read -r state relative; do
    case "$state" in
        present)
            [ -f "$BACKUP/files/$relative" ] || fail "missing snapshot for $relative"
            mkdir -p "$(dirname "$DEVICE/$relative")"
            cp -p "$BACKUP/files/$relative" "$DEVICE/$relative"
            ;;
        absent)
            rm -f "$DEVICE/$relative"
            ;;
        *)
            fail "unknown manifest state: $state"
            ;;
    esac
done < "$MANIFEST"

cmp -s "$DEVICE/config/existing.conf" "$BACKUP/files/config/existing.conf" || fail 'existing file was not restored'
[ ! -e "$DEVICE/config/generated.conf" ] || fail 'transaction-created file still exists after restore'
grep -Fx 'unrelated content' "$DEVICE/config/unrelated.conf" >/dev/null || fail 'unrelated file was changed'

printf '%s\n' '[PASS] backup/restore transaction isolation on fictitious data'
