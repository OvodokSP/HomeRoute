#!/bin/sh
# HomeRoute AdGuard backup restore sandbox.
# Restores only conf/work inside an isolated filesystem root and rolls back on failure.

set -eu
umask 077

BACKUP_DIR=${1:-}
ROOT=${HOMEROUTE_RESTORE_SANDBOX_ROOT:-}
FORCE_FAIL=${HOMEROUTE_SANDBOX_FORCE_VERIFY_FAIL:-0}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

[ -n "$BACKUP_DIR" ] || fail 'usage: restore-adguard-backup-sandbox.sh <backup-directory>'
[ -n "$ROOT" ] || fail 'HOMEROUTE_RESTORE_SANDBOX_ROOT is required'

case "$ROOT" in
    /tmp/homeroute-adguard-restore-sandbox.*) ;;
    *) fail 'restore sandbox root must be /tmp/homeroute-adguard-restore-sandbox.*' ;;
esac

[ -f "$ROOT/.homeroute-restore-sandbox" ] || fail 'sandbox marker is missing'
[ -d "$BACKUP_DIR" ] || fail 'backup directory is missing'
[ -f "$BACKUP_DIR/MANIFEST.sha256" ] || fail 'backup checksum manifest is missing'
[ -f "$BACKUP_DIR/conf/AdGuardHome.yaml" ] || fail 'backup AdGuardHome.yaml is missing'
[ -d "$BACKUP_DIR/work" ] || fail 'backup work directory is missing'

(
    cd "$BACKUP_DIR"
    sha256sum -c MANIFEST.sha256 >/dev/null
) || fail 'backup checksum verification failed'

TARGET_BASE="$ROOT/opt/adguardhome"
TARGET_CONF="$TARGET_BASE/conf"
TARGET_WORK="$TARGET_BASE/work"
SNAPSHOT="$ROOT/.homeroute-restore-snapshot"

[ ! -e "$SNAPSHOT" ] || fail 'stale sandbox restore snapshot exists'
mkdir -p "$SNAPSHOT"
printf '%s\n' absent > "$SNAPSHOT/conf.state"
printf '%s\n' absent > "$SNAPSHOT/work.state"

if [ -d "$TARGET_CONF" ]; then
    printf '%s\n' present > "$SNAPSHOT/conf.state"
    cp -R "$TARGET_CONF" "$SNAPSHOT/conf.before"
fi
if [ -d "$TARGET_WORK" ]; then
    printf '%s\n' present > "$SNAPSHOT/work.state"
    cp -R "$TARGET_WORK" "$SNAPSHOT/work.before"
fi

rollback() {
    rm -rf "$TARGET_CONF" "$TARGET_WORK"

    if [ "$(cat "$SNAPSHOT/conf.state")" = present ]; then
        mkdir -p "$TARGET_BASE"
        cp -R "$SNAPSHOT/conf.before" "$TARGET_CONF"
    fi
    if [ "$(cat "$SNAPSHOT/work.state")" = present ]; then
        mkdir -p "$TARGET_BASE"
        cp -R "$SNAPSHOT/work.before" "$TARGET_WORK"
    fi

    rm -rf "$SNAPSHOT"
}

mkdir -p "$TARGET_BASE"
rm -rf "$TARGET_CONF" "$TARGET_WORK"
cp -R "$BACKUP_DIR/conf" "$TARGET_CONF"
cp -R "$BACKUP_DIR/work" "$TARGET_WORK"

verify_tree() {
    source_root=$1
    target_root=$2
    list="$ROOT/.verify-list.$$"
    find "$source_root" -type f -print | LC_ALL=C sort > "$list"

    ok=1
    while IFS= read -r source_file; do
        rel=${source_file#"$source_root/"}
        target_file="$target_root/$rel"
        if [ ! -f "$target_file" ]; then
            ok=0
            break
        fi
        source_sum=$(sha256sum "$source_file" | awk '{print $1}')
        target_sum=$(sha256sum "$target_file" | awk '{print $1}')
        if [ "$source_sum" != "$target_sum" ]; then
            ok=0
            break
        fi
    done < "$list"

    rm -f "$list"
    [ "$ok" -eq 1 ]
}

ok=1
verify_tree "$BACKUP_DIR/conf" "$TARGET_CONF" || ok=0
verify_tree "$BACKUP_DIR/work" "$TARGET_WORK" || ok=0

if [ "$FORCE_FAIL" = "1" ]; then
    ok=0
fi

if [ "$ok" -ne 1 ]; then
    rollback
    printf '%s\n' 'HOMEROUTE_ADGUARD_RESTORE_SANDBOX schema=1 result=ROLLBACK live=false'
    exit 3
fi

rm -rf "$SNAPSHOT"
file_count=$(find "$TARGET_CONF" "$TARGET_WORK" -type f | wc -l | tr -d ' ')
printf 'HOMEROUTE_ADGUARD_RESTORE_SANDBOX schema=1 result=PASS files=%s live=false\n' "$file_count"
printf '%s\n' '[PASS] AdGuard backup restored only into isolated sandbox; Docker and live VPS state were not touched'
