#!/bin/sh
# Export the exact Docker image used by a running reference container.
# Writes a root-only local rescue artifact; never uploads it to Git.

set -eu
umask 077

CONTAINER=${1:-}
NAME=${2:-}
ACK=${HOMEROUTE_IMAGE_BACKUP_ACK:-}
BACKUP_ROOT=${HOMEROUTE_BACKUP_ROOT:-/root/homeroute-backups}
TEST_MODE=${HOMEROUTE_BACKUP_TEST_MODE:-0}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

[ -n "$CONTAINER" ] || fail 'usage: backup-container-image.sh <container> <safe-name>'
[ -n "$NAME" ] || fail 'usage: backup-container-image.sh <container> <safe-name>'
case "$NAME" in *[!A-Za-z0-9._-]*) fail 'safe-name contains unsupported characters' ;; esac
[ "$ACK" = "YES" ] || fail 'set HOMEROUTE_IMAGE_BACKUP_ACK=YES to export the image'

if [ "$TEST_MODE" = "1" ]; then
    case "$BACKUP_ROOT" in
        /tmp/homeroute-image-backup-test.*) ;;
        *) fail 'unsafe backup root in test mode' ;;
    esac
else
    [ "$(id -u)" -eq 0 ] || fail 'live image backup must run as root'
    [ "$BACKUP_ROOT" = "/root/homeroute-backups" ] || fail 'live backup root must be /root/homeroute-backups'
fi

command -v docker >/dev/null 2>&1 || fail 'docker command is unavailable'
docker info >/dev/null 2>&1 || fail 'docker daemon is unavailable'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is unavailable'
command -v tar >/dev/null 2>&1 || fail 'tar is unavailable'

status=$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || true)
[ "$status" = "running" ] || fail "container is not running: $CONTAINER"

image_id=$(docker inspect -f '{{.Image}}' "$CONTAINER" 2>/dev/null || true)
[ -n "$image_id" ] || fail 'container image id is unavailable'
image_size=$(docker image inspect -f '{{.Size}}' "$image_id" 2>/dev/null || true)
case "$image_size" in ''|*[!0-9]*) fail 'container image size is unavailable' ;; esac

mkdir -p "$BACKUP_ROOT"
chmod 700 "$BACKUP_ROOT"

free_kib=$(df -Pk "$BACKUP_ROOT" | awk 'NR==2 {print $4}')
case "$free_kib" in ''|*[!0-9]*) fail 'free disk space could not be determined' ;; esac
free_bytes=$((free_kib * 1024))
required_bytes=$((image_size * 2 + 104857600))
[ "$free_bytes" -ge "$required_bytes" ] ||
    fail 'insufficient free space for conservative image export margin'

stamp=$(date -u +%Y%m%dT%H%M%SZ)
dest="$BACKUP_ROOT/image-$NAME-$stamp"
[ ! -e "$dest" ] || fail "backup destination already exists: $dest"
mkdir -p "$dest"
chmod 700 "$dest"

archive="$dest/image.tar"
docker image save -o "$archive" "$image_id"
chmod 600 "$archive"

tar -tf "$archive" >/dev/null || fail 'Docker image archive is not a readable tar'
(
    cd "$dest"
    sha256sum image.tar > IMAGE.sha256
    chmod 600 IMAGE.sha256
    sha256sum -c IMAGE.sha256 >/dev/null
)

cat > "$dest/metadata.txt" <<EOF
schema=1
container=$CONTAINER
safe_name=$NAME
image_id=$image_id
image_size_bytes=$image_size
captured_utc=$stamp
scope=exact_running_container_image
EOF
chmod 600 "$dest/metadata.txt"

archive_kib=$(du -k "$archive" | awk '{print $1}')
printf 'HOMEROUTE_IMAGE_BACKUP schema=1 result=PASS name=%s size_kib=%s\n' "$NAME" "$archive_kib"
printf 'HOMEROUTE_IMAGE_BACKUP image_id=%s\n' "$image_id"
printf 'HOMEROUTE_IMAGE_BACKUP directory=%s\n' "$dest"
printf '%s\n' '[PASS] exact running Docker image exported and checksum verified; container was not restarted'
