#!/bin/sh
# HomeRoute AWG backup restore sandbox.
# Refuses live paths and Docker. Validates restore + rollback on an isolated filesystem root.

set -eu
umask 077

BACKUP_DIR=${1:-}
ROOT=${HOMEROUTE_RESTORE_SANDBOX_ROOT:-}
FORCE_FAIL=${HOMEROUTE_SANDBOX_FORCE_VERIFY_FAIL:-0}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

[ -n "$BACKUP_DIR" ] || fail 'usage: restore-awg-backup-sandbox.sh <backup-directory>'
[ -n "$ROOT" ] || fail 'HOMEROUTE_RESTORE_SANDBOX_ROOT is required'

case "$ROOT" in
    /tmp/homeroute-awg-restore-sandbox.*) ;;
    *) fail 'restore sandbox root must be /tmp/homeroute-awg-restore-sandbox.*' ;;
esac

[ -f "$ROOT/.homeroute-restore-sandbox" ] || fail 'sandbox marker is missing'
[ -d "$BACKUP_DIR" ] || fail 'backup directory is missing'
[ -f "$BACKUP_DIR/MANIFEST.sha256" ] || fail 'backup checksum manifest is missing'
[ -f "$BACKUP_DIR/awg/awg0.conf" ] || fail 'backup awg0.conf is missing'
[ -f "$BACKUP_DIR/start.sh" ] || fail 'backup start.sh is missing'

(
    cd "$BACKUP_DIR"
    sha256sum -c MANIFEST.sha256 >/dev/null
) || fail 'backup checksum verification failed'

TARGET_BASE="$ROOT/opt/amnezia"
TARGET_AWG="$TARGET_BASE/awg"
TARGET_START="$TARGET_BASE/start.sh"
SNAPSHOT="$ROOT/.homeroute-restore-snapshot"

[ ! -e "$SNAPSHOT" ] || fail 'stale sandbox restore snapshot exists'
mkdir -p "$SNAPSHOT"
printf '%s\n' absent > "$SNAPSHOT/awg.state"
printf '%s\n' absent > "$SNAPSHOT/start.state"

if [ -d "$TARGET_AWG" ]; then
    printf '%s\n' present > "$SNAPSHOT/awg.state"
    cp -R "$TARGET_AWG" "$SNAPSHOT/awg.before"
fi
if [ -f "$TARGET_START" ]; then
    printf '%s\n' present > "$SNAPSHOT/start.state"
    cp "$TARGET_START" "$SNAPSHOT/start.before"
fi

rollback() {
    if [ -d "$TARGET_AWG" ]; then
        rm -rf "$TARGET_AWG"
    fi
    if [ -f "$TARGET_START" ]; then
        rm -f "$TARGET_START"
    fi

    if [ "$(cat "$SNAPSHOT/awg.state")" = present ]; then
        mkdir -p "$TARGET_BASE"
        cp -R "$SNAPSHOT/awg.before" "$TARGET_AWG"
    fi
    if [ "$(cat "$SNAPSHOT/start.state")" = present ]; then
        mkdir -p "$TARGET_BASE"
        cp "$SNAPSHOT/start.before" "$TARGET_START"
    fi

    rm -rf "$SNAPSHOT"
}

mkdir -p "$TARGET_BASE"
if [ -d "$TARGET_AWG" ]; then
    rm -rf "$TARGET_AWG"
fi
rm -f "$TARGET_START"

cp -R "$BACKUP_DIR/awg" "$TARGET_AWG"
cp "$BACKUP_DIR/start.sh" "$TARGET_START"

verify_restored_file() {
    source_file=$1
    target_file=$2
    source_sum=$(sha256sum "$source_file" | awk '{print $1}')
    target_sum=$(sha256sum "$target_file" | awk '{print $1}')
    [ "$source_sum" = "$target_sum" ]
}

ok=1
find "$BACKUP_DIR/awg" -type f -print | while IFS= read -r source_file; do
    rel=${source_file#"$BACKUP_DIR/awg/"}
    verify_restored_file "$source_file" "$TARGET_AWG/$rel" || exit 7
done || ok=0
verify_restored_file "$BACKUP_DIR/start.sh" "$TARGET_START" || ok=0

if [ "$FORCE_FAIL" = "1" ]; then
    ok=0
fi

if [ "$ok" -ne 1 ]; then
    rollback
    printf '%s\n' 'HOMEROUTE_VPS_RESTORE_SANDBOX schema=1 result=ROLLBACK live=false'
    exit 3
fi

rm -rf "$SNAPSHOT"
file_count=$(find "$TARGET_AWG" -type f | wc -l | tr -d ' ')
printf 'HOMEROUTE_VPS_RESTORE_SANDBOX schema=1 result=PASS files=%s live=false\n' "$file_count"
printf '%s\n' '[PASS] AWG backup restored only into isolated sandbox; Docker and live VPS state were not touched'
