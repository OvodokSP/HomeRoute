#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BACKUP="$ROOT/vps/backup-container-image.sh"
VERIFY="$ROOT/vps/verify-container-image-backup.sh"
BASE=${TMPDIR:-/tmp}/homeroute-image-backup-test.$$
BIN="$BASE/bin"
BACKUPS="/tmp/homeroute-image-backup-test.$$"
trap 'rm -rf "$BASE" "$BACKUPS"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BIN"

cat > "$BIN/docker" <<'EOF'
#!/bin/sh
set -eu
case "$1" in
    info) exit 0 ;;
    inspect)
        template=$3
        case "$template" in
            '{{.State.Status}}') printf '%s\n' running ;;
            '{{.Image}}') printf '%s\n' sha256:fixtureimage ;;
            *) exit 1 ;;
        esac
        ;;
    image)
        case "$2" in
            inspect)
                printf '%s\n' 1024
                ;;
            save)
                [ "$3" = "-o" ] || exit 1
                archive=$4
                image=$5
                [ "$image" = "sha256:fixtureimage" ] || exit 1
                tmp=${TMPDIR:-/tmp}/homeroute-fake-image.$$
                mkdir -p "$tmp"
                printf '%s\n' '[{"Config":"config.json","RepoTags":["fixture:local"],"Layers":[]}]' > "$tmp/manifest.json"
                tar -cf "$archive" -C "$tmp" manifest.json
                rm -rf "$tmp"
                ;;
            *) exit 1 ;;
        esac
        ;;
    *) exit 1 ;;
esac
EOF
chmod 700 "$BIN/docker"

if PATH="$BIN:$PATH" HOMEROUTE_BACKUP_TEST_MODE=1 HOMEROUTE_BACKUP_ROOT="$BACKUPS"    sh "$BACKUP" fixture awg >/dev/null 2>&1; then
    fail 'image export unexpectedly ran without acknowledgement'
fi

out=$(PATH="$BIN:$PATH"       HOMEROUTE_IMAGE_BACKUP_ACK=YES       HOMEROUTE_BACKUP_TEST_MODE=1       HOMEROUTE_BACKUP_ROOT="$BACKUPS"       sh "$BACKUP" fixture awg)

printf '%s\n' "$out" | grep -F 'HOMEROUTE_IMAGE_BACKUP schema=1 result=PASS name=awg' >/dev/null ||
    fail 'image export pass marker missing'
printf '%s\n' "$out" | grep -F 'HOMEROUTE_IMAGE_BACKUP image_id=sha256:fixtureimage' >/dev/null ||
    fail 'image id marker missing'

dir=$(printf '%s\n' "$out" | sed -n 's/^HOMEROUTE_IMAGE_BACKUP directory=//p')
[ -f "$dir/image.tar" ] || fail 'image.tar missing'
[ -f "$dir/IMAGE.sha256" ] || fail 'IMAGE.sha256 missing'
[ -f "$dir/metadata.txt" ] || fail 'metadata missing'

verify_out=$(sh "$VERIFY" "$dir")
printf '%s\n' "$verify_out" | grep -Fx 'HOMEROUTE_IMAGE_BACKUP_VERIFY schema=1 result=PASS' >/dev/null ||
    fail 'image verification pass marker missing'

printf '%s\n' tamper >> "$dir/image.tar"
if sh "$VERIFY" "$dir" >/dev/null 2>&1; then
    fail 'tampered image archive unexpectedly verified'
fi

printf '%s\n' '[PASS] exact Docker image rescue export contract'
