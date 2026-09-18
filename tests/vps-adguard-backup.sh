#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BACKUP="$ROOT/vps/backup-adguard-state.sh"
VERIFY="$ROOT/vps/verify-adguard-backup.sh"
BASE=${TMPDIR:-/tmp}/homeroute-adguard-test.$$
BIN="$BASE/bin"
BACKUPS="/tmp/homeroute-adguard-backup-test.$$"
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
    inspect) printf '%s\n' running ;;
    exec) exit 0 ;;
    cp)
        src=$2
        dst=$3
        case "$src" in
            *:/opt/adguardhome/conf/.)
                mkdir -p "$dst"
                printf '%s\n' 'fixture-config' > "$dst/AdGuardHome.yaml"
                ;;
            *:/opt/adguardhome/work/.)
                mkdir -p "$dst"
                printf '%s\n' 'fixture-work' > "$dst/data.db"
                ;;
            *) exit 1 ;;
        esac
        ;;
    *) exit 1 ;;
esac
EOF
chmod 700 "$BIN/docker"

if PATH="$BIN:$PATH" HOMEROUTE_BACKUP_TEST_MODE=1 HOMEROUTE_BACKUP_ROOT="$BACKUPS"    sh "$BACKUP" >/dev/null 2>&1; then
    fail 'AdGuard backup unexpectedly ran without acknowledgement'
fi

out=$(PATH="$BIN:$PATH"       HOMEROUTE_ADGUARD_BACKUP_ACK=YES       HOMEROUTE_BACKUP_TEST_MODE=1       HOMEROUTE_BACKUP_ROOT="$BACKUPS"       sh "$BACKUP")

printf '%s\n' "$out" | grep -F 'HOMEROUTE_ADGUARD_BACKUP schema=1 result=PASS files=2' >/dev/null ||
    fail 'AdGuard backup pass marker missing'
dir=$(printf '%s\n' "$out" | sed -n 's/^HOMEROUTE_ADGUARD_BACKUP directory=//p')

[ -f "$dir/conf/AdGuardHome.yaml" ] || fail 'AdGuard config missing'
[ -f "$dir/work/data.db" ] || fail 'AdGuard work data missing'
[ -f "$dir/MANIFEST.sha256" ] || fail 'AdGuard manifest missing'

verify_out=$(sh "$VERIFY" "$dir")
printf '%s\n' "$verify_out" | grep -F 'HOMEROUTE_ADGUARD_BACKUP_VERIFY schema=1 result=PASS files=2' >/dev/null ||
    fail 'AdGuard verification marker missing'

for forbidden in fixture-config fixture-work; do
    if printf '%s\n%s\n' "$out" "$verify_out" | grep -F "$forbidden" >/dev/null; then
        fail "AdGuard backup leaked fixture contents: $forbidden"
    fi
done

printf '%s\n' tamper >> "$dir/conf/AdGuardHome.yaml"
if sh "$VERIFY" "$dir" >/dev/null 2>&1; then
    fail 'tampered AdGuard backup unexpectedly verified'
fi

printf '%s\n' '[PASS] AdGuard state backup / verify contract'
