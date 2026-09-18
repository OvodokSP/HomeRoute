#!/bin/sh
# Export the six verified reference-router persistence hooks into a protected
# local bundle. This tool does not alter services, routes, packages or configs.
# It refuses to export if obvious secret/address material is detected.

set -eu
umask 077

ACK=${HOMEROUTE_HOOK_EXPORT_ACK:-}
OUT_ROOT=${HOMEROUTE_HOOK_EXPORT_ROOT:-/opt/tmp}
TEST_MODE=${HOMEROUTE_HOOK_EXPORT_TEST_MODE:-0}
SOURCE_ROOT=${HOMEROUTE_HOOK_EXPORT_SOURCE_ROOT:-}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

root_path() {
    printf '%s%s\n' "$SOURCE_ROOT" "$1"
}

[ "$ACK" = YES ] || fail 'set HOMEROUTE_HOOK_EXPORT_ACK=YES to create the local protected hook bundle'

if [ "$TEST_MODE" = 1 ]; then
    case "$OUT_ROOT" in
        /tmp/homeroute-hook-export-test.*) ;;
        *) fail 'unsafe export root in test mode' ;;
    esac
    case "$SOURCE_ROOT" in
        /tmp/homeroute-hook-source-test.*) ;;
        *) fail 'unsafe source root in test mode' ;;
    esac
else
    [ "$OUT_ROOT" = /opt/tmp ] || fail 'live export root must be /opt/tmp'
    [ -z "$SOURCE_ROOT" ] || fail 'live source root override is forbidden'
fi

for cmd in sha256sum tar grep wc date; do
    command -v "$cmd" >/dev/null 2>&1 || fail "$cmd unavailable"
done

HOOKS='
/opt/etc/init.d/S98telegram-awg
/opt/etc/init.d/S99hrneo
/opt/etc/ndm/netfilter.d/014-telegram-awg.sh
/opt/etc/ndm/netfilter.d/015-hrneo.sh
/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh
/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh
'

EXPECTED='
/opt/etc/init.d/S98telegram-awg 8165d5be13e57aa13eca8fb38a95bc179e37582f64732bd0e45a013727303504
/opt/etc/init.d/S99hrneo cd39a8804b991ae96995746e090a2b46e953930c7c8b89e27f11d4845abe3ceb
/opt/etc/ndm/netfilter.d/014-telegram-awg.sh c6766c421171d06a13ed8b30baa8d586a10a1373fce378f51bb94fdd46eff6f1
/opt/etc/ndm/netfilter.d/015-hrneo.sh fa01637e206c4c1a40d009a1b656ea9c98e8b94e652b720a9f1b4912af9c7342
/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh 4eafa3bab0b1a1b439ed7eb4bd0ec85705a56d60730f9a46f0e30aa48930d9d2
/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh fa01637e206c4c1a40d009a1b656ea9c98e8b94e652b720a9f1b4912af9c7342
'

expected_sha() {
    rel=$1
    printf '%s\n' "$EXPECTED" |
        awk -v p="$rel" '$1==p {print $2; exit}'
}

secret_scan() {
    file=$1

    # Named credential/endpoint material.
    if grep -Eiq         '(PrivateKey|PresharedKey|Password|Passphrase|Authorization|Bearer[[:space:]]|Endpoint[[:space:]]*=|token[[:space:]]*=|secret[[:space:]]*=)'         "$file"; then
        return 1
    fi

    # IPv4 literals are not expected in these persistence wrappers and are
    # deliberately refused so deployment addresses cannot leak via export.
    if grep -Eq         '(^|[^0-9])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9]|$)'         "$file"; then
        return 1
    fi

    return 0
}

stamp=$(date -u +%Y%m%dT%H%M%SZ)
work="$OUT_ROOT/homeroute-hook-export-$stamp"
archive="$OUT_ROOT/homeroute-hook-export-$stamp.tar.gz"

[ ! -e "$work" ] || fail "export directory already exists: $work"
[ ! -e "$archive" ] || fail "export archive already exists: $archive"

mkdir -p "$work/hooks"
chmod 700 "$work" "$work/hooks"

: > "$work/MANIFEST.sha256"
: > "$work/metadata.txt"

count=0
printf '%s\n' "$HOOKS" | while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    src=$(root_path "$rel")
    [ -f "$src" ] || fail "required reference hook missing: $rel"
    [ -x "$src" ] || fail "reference hook is not executable: $rel"
    sh -n "$src" >/dev/null 2>&1 || fail "reference hook shell syntax invalid: $rel"

    expected=$(expected_sha "$rel")
    [ -n "$expected" ] || fail "expected hook identity missing: $rel"
    actual=$(sha256sum "$src" | awk '{print $1}')
    [ "$actual" = "$expected" ] || fail "reference hook identity drifted: $rel"

    secret_scan "$src" || fail "hook export refused by secret/address scan: $rel"

    dest="$work/hooks$rel"
    mkdir -p "$(dirname "$dest")"
    cp -p "$src" "$dest"
    chmod 700 "$dest"

    printf '%s  hooks%s\n' "$actual" "$rel" >> "$work/MANIFEST.sha256"
done

# The loop above may run in a subshell on BusyBox; derive count from manifest.
count=$(wc -l < "$work/MANIFEST.sha256" | tr -d '[:space:]')
[ "$count" = 6 ] || fail "unexpected exported hook count: $count"

cat > "$work/metadata.txt" <<EOF
schema=1
scope=reference_router_persistence_hooks
captured_utc=$stamp
hook_count=$count
secret_scan=PASS
contents_printed=false
EOF
chmod 600 "$work/metadata.txt" "$work/MANIFEST.sha256"

(
    cd "$work"
    sha256sum -c MANIFEST.sha256 >/dev/null
)

tar -czf "$archive" -C "$work" metadata.txt MANIFEST.sha256 hooks
chmod 600 "$archive"

archive_sha=$(sha256sum "$archive" | awk '{print $1}')
archive_bytes=$(wc -c < "$archive" | tr -d '[:space:]')

printf 'HOMEROUTE_HOOK_EXPORT schema=1 result=PASS hooks=%s\n' "$count"
printf 'HOMEROUTE_HOOK_EXPORT archive=%s\n' "$archive"
printf 'HOMEROUTE_HOOK_EXPORT archive_bytes=%s\n' "$archive_bytes"
printf 'HOMEROUTE_HOOK_EXPORT archive_sha256=%s\n' "$archive_sha"
printf '%s\n' 'HOMEROUTE_HOOK_EXPORT secret_scan=PASS contents_printed=false'
printf '%s\n' '[PASS] verified reference hooks exported locally; no hook contents were printed'
