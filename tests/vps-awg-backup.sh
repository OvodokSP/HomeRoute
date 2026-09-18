#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BACKUP="$ROOT/vps/backup-awg-state.sh"
VERIFY="$ROOT/vps/verify-awg-backup.sh"
TMPDIR_BASE=${TMPDIR:-/tmp}
BASE="$TMPDIR_BASE/homeroute-awg-backup-test.$$"
BIN="$BASE/bin"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BIN"

cat > "$BIN/docker" <<'EOF'
#!/bin/sh
set -eu

case "$1" in
    info)
        exit 0
        ;;
    inspect)
        printf '%s\n' running
        exit 0
        ;;
    exec)
        # test -d / test -f checks
        exit 0
        ;;
    cp)
        src=$2
        dst=$3
        case "$src" in
            *:/opt/amnezia/awg/.)
                mkdir -p "$dst"
                printf '%s\n' '[Interface]' > "$dst/awg0.conf"
                printf '%s\n' 'fixture-private' > "$dst/wireguard_server_private_key.key"
                printf '%s\n' 'fixture-public' > "$dst/wireguard_server_public_key.key"
                printf '%s\n' 'fixture-psk' > "$dst/wireguard_psk.key"
                printf '%s\n' '[]' > "$dst/clientsTable"
                ;;
            *:/opt/amnezia/start.sh)
                printf '%s\n' '#!/bin/sh' > "$dst"
                ;;
            *)
                exit 1
                ;;
        esac
        exit 0
        ;;
esac

exit 1
EOF
chmod 700 "$BIN/docker"

# Explicit acknowledgement is mandatory.
if PATH="$BIN:$PATH" HOMEROUTE_BACKUP_TEST_MODE=1 HOMEROUTE_BACKUP_ROOT="$BASE/noack"    sh "$BACKUP" >/dev/null 2>&1; then
    fail 'backup unexpectedly ran without acknowledgement'
fi

out=$(PATH="$BIN:$PATH"       HOMEROUTE_AWG_BACKUP_ACK=YES       HOMEROUTE_BACKUP_TEST_MODE=1       HOMEROUTE_BACKUP_ROOT="$BASE/backups"       sh "$BACKUP")

printf '%s\n' "$out" | grep -F 'HOMEROUTE_VPS_BACKUP schema=1 target=awg result=PASS' >/dev/null ||
    fail 'AWG backup did not pass'

dir=$(printf '%s\n' "$out" | sed -n 's/^HOMEROUTE_VPS_BACKUP directory=//p')
[ -n "$dir" ] || fail 'backup directory was not reported'
[ -f "$dir/awg/awg0.conf" ] || fail 'fixture awg0.conf missing from backup'
[ -f "$dir/awg/clientsTable" ] || fail 'fixture clientsTable missing from backup'
[ -f "$dir/start.sh" ] || fail 'fixture start.sh missing from backup'
[ -f "$dir/MANIFEST.sha256" ] || fail 'backup checksum manifest missing'

verify_out=$(sh "$VERIFY" "$dir")
printf '%s\n' "$verify_out" | grep -F 'HOMEROUTE_VPS_BACKUP_VERIFY schema=1 result=PASS' >/dev/null ||
    fail 'AWG backup verification did not pass'

# Secret fixture contents must never be printed.
for forbidden in fixture-private fixture-public fixture-psk '[Interface]'; do
    if printf '%s\n%s\n' "$out" "$verify_out" | grep -F "$forbidden" >/dev/null; then
        fail "backup tooling leaked fixture content: $forbidden"
    fi
done

# Tamper detection.
printf '%s\n' 'tampered' >> "$dir/awg/awg0.conf"
if sh "$VERIFY" "$dir" >/dev/null 2>&1; then
    fail 'tampered backup unexpectedly verified'
fi

printf '%s\n' '[PASS] AWG backup / verify safety contract'
