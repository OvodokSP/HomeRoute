#!/bin/sh
# HomeRoute AWG state backup.
# Non-disruptive: reads the running container and writes a root-only host backup.
# It does not stop/restart containers and never prints file contents.

set -eu
umask 077

AWG_CONTAINER=${AWG_CONTAINER:-amnezia-awg2}
ACK=${HOMEROUTE_AWG_BACKUP_ACK:-}
BACKUP_ROOT=${HOMEROUTE_BACKUP_ROOT:-/root/homeroute-backups}
STATE_PATH=/opt/amnezia/awg
START_PATH=/opt/amnezia/start.sh

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

[ "$ACK" = "YES" ] || fail 'set HOMEROUTE_AWG_BACKUP_ACK=YES to create a protected AWG state backup'

if [ "${HOMEROUTE_BACKUP_TEST_MODE:-0}" = "1" ]; then
    case "$BACKUP_ROOT" in
        /tmp/homeroute-awg-backup-test.*) ;;
        *) fail 'unsafe backup root in test mode' ;;
    esac
else
    [ "$(id -u)" -eq 0 ] || fail 'live AWG backup must run as root'
    [ "$BACKUP_ROOT" = "/root/homeroute-backups" ] || fail 'live backup root must be /root/homeroute-backups'
fi

command -v docker >/dev/null 2>&1 || fail 'docker command is unavailable'
docker info >/dev/null 2>&1 || fail 'docker daemon is unavailable'

status=$(docker inspect -f '{{.State.Status}}' "$AWG_CONTAINER" 2>/dev/null || true)
[ "$status" = "running" ] || fail "AWG container is not running: $AWG_CONTAINER"

docker exec "$AWG_CONTAINER" test -d "$STATE_PATH" >/dev/null 2>&1 ||
    fail "AWG state directory is missing: $STATE_PATH"
docker exec "$AWG_CONTAINER" test -f "$START_PATH" >/dev/null 2>&1 ||
    fail "AWG startup script is missing: $START_PATH"

mkdir -p "$BACKUP_ROOT"
chmod 700 "$BACKUP_ROOT"

stamp=$(date -u +%Y%m%dT%H%M%SZ)
dest="$BACKUP_ROOT/awg-state-$stamp"
[ ! -e "$dest" ] || fail "backup destination already exists: $dest"

mkdir -p "$dest/awg"
chmod 700 "$dest" "$dest/awg"

docker cp "$AWG_CONTAINER:$STATE_PATH/." "$dest/awg/" >/dev/null
docker cp "$AWG_CONTAINER:$START_PATH" "$dest/start.sh" >/dev/null

find "$dest" -type d -print | while IFS= read -r path; do
    chmod 700 "$path"
done
find "$dest" -type f -print | while IFS= read -r path; do
    chmod 600 "$path"
done

[ -f "$dest/awg/awg0.conf" ] || fail 'backup is incomplete: awg0.conf is missing'
[ -f "$dest/start.sh" ] || fail 'backup is incomplete: start.sh is missing'

cat > "$dest/metadata.txt" <<EOF
schema=1
container=$AWG_CONTAINER
state_path=$STATE_PATH
startup_path=$START_PATH
captured_utc=$stamp
scope=awg_state_and_startup
EOF
chmod 600 "$dest/metadata.txt"

(
    cd "$dest"
    : > MANIFEST.sha256
    find awg -type f -print | LC_ALL=C sort | while IFS= read -r file; do
        sha256sum "$file" >> MANIFEST.sha256
    done
    sha256sum start.sh metadata.txt >> MANIFEST.sha256
    chmod 600 MANIFEST.sha256
    sha256sum -c MANIFEST.sha256 >/dev/null
)

file_count=$(find "$dest/awg" -type f | wc -l | tr -d ' ')
bytes=$(du -sk "$dest" | awk '{print $1}')

printf 'HOMEROUTE_VPS_BACKUP schema=1 target=awg result=PASS files=%s size_kib=%s\n' "$file_count" "$bytes"
printf 'HOMEROUTE_VPS_BACKUP directory=%s\n' "$dest"
printf '%s\n' '[PASS] AWG state backup created; no container restart or configuration change was performed'
