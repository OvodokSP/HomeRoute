#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RESTORE="$ROOT/vps/restore-adguard-backup-sandbox.sh"
BASE=${TMPDIR:-/tmp}/homeroute-adguard-restore-test.$$
BACKUP="$BASE/backup"
SANDBOX="/tmp/homeroute-adguard-restore-sandbox.$$"
trap 'rm -rf "$BASE" "$SANDBOX"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BACKUP/conf" "$BACKUP/work" "$SANDBOX/opt/adguardhome/conf" "$SANDBOX/opt/adguardhome/work"
: > "$SANDBOX/.homeroute-restore-sandbox"

printf '%s\n' 'fixture-config' > "$BACKUP/conf/AdGuardHome.yaml"
printf '%s\n' 'fixture-work' > "$BACKUP/work/data.db"
cat > "$BACKUP/metadata.txt" <<'EOF'
schema=1
scope=fixture
EOF

(
  cd "$BACKUP"
  : > MANIFEST.sha256
  find conf work -type f -print | LC_ALL=C sort | while IFS= read -r file; do
      sha256sum "$file" >> MANIFEST.sha256
  done
  sha256sum metadata.txt >> MANIFEST.sha256
)

printf '%s\n' 'old-conf' > "$SANDBOX/opt/adguardhome/conf/old.yaml"
printf '%s\n' 'old-work' > "$SANDBOX/opt/adguardhome/work/old.db"
printf '%s\n' 'unrelated' > "$SANDBOX/opt/adguardhome/unrelated.keep"

out=$(HOMEROUTE_RESTORE_SANDBOX_ROOT="$SANDBOX" sh "$RESTORE" "$BACKUP")
printf '%s\n' "$out" | grep -F 'HOMEROUTE_ADGUARD_RESTORE_SANDBOX schema=1 result=PASS files=2 live=false' >/dev/null ||
    fail 'AdGuard sandbox restore success contract missing'

[ -f "$SANDBOX/opt/adguardhome/conf/AdGuardHome.yaml" ] || fail 'restored AdGuardHome.yaml missing'
[ -f "$SANDBOX/opt/adguardhome/work/data.db" ] || fail 'restored AdGuard work data missing'
[ ! -f "$SANDBOX/opt/adguardhome/conf/old.yaml" ] || fail 'old conf survived successful replace'
[ ! -f "$SANDBOX/opt/adguardhome/work/old.db" ] || fail 'old work survived successful replace'
[ "$(cat "$SANDBOX/opt/adguardhome/unrelated.keep")" = unrelated ] || fail 'unrelated file changed'

for forbidden in fixture-config fixture-work; do
    if printf '%s\n' "$out" | grep -F "$forbidden" >/dev/null; then
        fail "AdGuard restore leaked backup contents: $forbidden"
    fi
done

rm -rf "$SANDBOX/opt/adguardhome/conf" "$SANDBOX/opt/adguardhome/work"
mkdir -p "$SANDBOX/opt/adguardhome/conf" "$SANDBOX/opt/adguardhome/work"
printf '%s\n' 'before-conf' > "$SANDBOX/opt/adguardhome/conf/original.yaml"
printf '%s\n' 'before-work' > "$SANDBOX/opt/adguardhome/work/original.db"

if HOMEROUTE_RESTORE_SANDBOX_ROOT="$SANDBOX"    HOMEROUTE_SANDBOX_FORCE_VERIFY_FAIL=1    sh "$RESTORE" "$BACKUP" >"$BASE/fail.out" 2>&1; then
    fail 'forced AdGuard sandbox restore failure unexpectedly succeeded'
fi

grep -F 'HOMEROUTE_ADGUARD_RESTORE_SANDBOX schema=1 result=ROLLBACK live=false' "$BASE/fail.out" >/dev/null ||
    fail 'AdGuard sandbox restore rollback marker missing'
[ "$(cat "$SANDBOX/opt/adguardhome/conf/original.yaml")" = before-conf ] ||
    fail 'original AdGuard conf was not restored after failure'
[ "$(cat "$SANDBOX/opt/adguardhome/work/original.db")" = before-work ] ||
    fail 'original AdGuard work was not restored after failure'
[ "$(cat "$SANDBOX/opt/adguardhome/unrelated.keep")" = unrelated ] ||
    fail 'unrelated file changed during rollback'

printf '%s\n' '[PASS] AdGuard restore sandbox / rollback contract'
