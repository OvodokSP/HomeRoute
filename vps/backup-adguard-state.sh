#!/bin/sh
# Protected AdGuard state backup from the running container.
# Copies config/work data without printing file contents.

set -eu
umask 077

CONTAINER=${ADGUARD_CONTAINER:-adguard-home}
ACK=${HOMEROUTE_ADGUARD_BACKUP_ACK:-}
BACKUP_ROOT=${HOMEROUTE_BACKUP_ROOT:-/root/homeroute-backups}
TEST_MODE=${HOMEROUTE_BACKUP_TEST_MODE:-0}
CONF=/opt/adguardhome/conf
WORK=/opt/adguardhome/work

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

[ "$ACK" = "YES" ] || fail 'set HOMEROUTE_ADGUARD_BACKUP_ACK=YES to create a protected AdGuard backup'

if [ "$TEST_MODE" = "1" ]; then
    case "$BACKUP_ROOT" in
        /tmp/homeroute-adguard-backup-test.*) ;;
        *) fail 'unsafe backup root in test mode' ;;
    esac
else
    [ "$(id -u)" -eq 0 ] || fail 'live AdGuard backup must run as root'
    [ "$BACKUP_ROOT" = "/root/homeroute-backups" ] || fail 'live backup root must be /root/homeroute-backups'
fi

command -v docker >/dev/null 2>&1 || fail 'docker command is unavailable'
docker info >/dev/null 2>&1 || fail 'docker daemon is unavailable'

status=$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || true)
[ "$status" = "running" ] || fail "AdGuard container is not running: $CONTAINER"

docker exec "$CONTAINER" test -d "$CONF" >/dev/null 2>&1 || fail 'AdGuard conf directory is missing'
docker exec "$CONTAINER" test -d "$WORK" >/dev/null 2>&1 || fail 'AdGuard work directory is missing'
docker exec "$CONTAINER" test -f "$CONF/AdGuardHome.yaml" >/dev/null 2>&1 ||
    fail 'AdGuardHome.yaml is missing'

mkdir -p "$BACKUP_ROOT"
chmod 700 "$BACKUP_ROOT"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
dest="$BACKUP_ROOT/adguard-state-$stamp"
[ ! -e "$dest" ] || fail "backup destination already exists: $dest"
mkdir -p "$dest/conf" "$dest/work"
chmod 700 "$dest" "$dest/conf" "$dest/work"

docker cp "$CONTAINER:$CONF/." "$dest/conf/" >/dev/null
docker cp "$CONTAINER:$WORK/." "$dest/work/" >/dev/null

find "$dest" -type d -print | while IFS= read -r path; do chmod 700 "$path"; done
find "$dest" -type f -print | while IFS= read -r path; do chmod 600 "$path"; done

[ -f "$dest/conf/AdGuardHome.yaml" ] || fail 'backup is incomplete: AdGuardHome.yaml is missing'

cat > "$dest/metadata.txt" <<EOF
schema=1
container=$CONTAINER
conf_path=$CONF
work_path=$WORK
captured_utc=$stamp
scope=adguard_conf_and_work
EOF
chmod 600 "$dest/metadata.txt"

(
    cd "$dest"
    : > MANIFEST.sha256
    find conf work -type f -print | LC_ALL=C sort | while IFS= read -r file; do
        sha256sum "$file" >> MANIFEST.sha256
    done
    sha256sum metadata.txt >> MANIFEST.sha256
    chmod 600 MANIFEST.sha256
    sha256sum -c MANIFEST.sha256 >/dev/null
)

file_count=$(find "$dest/conf" "$dest/work" -type f | wc -l | tr -d ' ')
bytes=$(du -sk "$dest" | awk '{print $1}')
printf 'HOMEROUTE_ADGUARD_BACKUP schema=1 result=PASS files=%s size_kib=%s\n' "$file_count" "$bytes"
printf 'HOMEROUTE_ADGUARD_BACKUP directory=%s\n' "$dest"
printf '%s\n' '[PASS] AdGuard state backup created and checksum verified; container was not restarted'
