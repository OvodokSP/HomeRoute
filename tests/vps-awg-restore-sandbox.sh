#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RESTORE="$ROOT/vps/restore-awg-backup-sandbox.sh"
TMPDIR_BASE=${TMPDIR:-/tmp}
BASE="$TMPDIR_BASE/homeroute-awg-restore-test.$$"
BACKUP="$BASE/backup"
SANDBOX="/tmp/homeroute-awg-restore-sandbox.$$"
trap 'rm -rf "$BASE" "$SANDBOX"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BACKUP/awg" "$SANDBOX/opt/amnezia/awg"
: > "$SANDBOX/.homeroute-restore-sandbox"

printf '%s\n' '[Interface]' > "$BACKUP/awg/awg0.conf"
printf '%s\n' 'fixture-private' > "$BACKUP/awg/wireguard_server_private_key.key"
printf '%s\n' '[]' > "$BACKUP/awg/clientsTable"
printf '%s\n' '#!/bin/sh' > "$BACKUP/start.sh"
cat > "$BACKUP/metadata.txt" <<'EOF'
schema=1
scope=fixture
EOF

(
  cd "$BACKUP"
  : > MANIFEST.sha256
  find awg -type f -print | LC_ALL=C sort | while IFS= read -r file; do
      sha256sum "$file" >> MANIFEST.sha256
  done
  sha256sum start.sh metadata.txt >> MANIFEST.sha256
)

printf '%s\n' 'old-state' > "$SANDBOX/opt/amnezia/awg/old.conf"
printf '%s\n' 'old-start' > "$SANDBOX/opt/amnezia/start.sh"
printf '%s\n' 'unrelated' > "$SANDBOX/opt/amnezia/unrelated.keep"

out=$(HOMEROUTE_RESTORE_SANDBOX_ROOT="$SANDBOX" sh "$RESTORE" "$BACKUP")
printf '%s\n' "$out" | grep -F 'HOMEROUTE_VPS_RESTORE_SANDBOX schema=1 result=PASS files=3 live=false' >/dev/null ||
    fail 'sandbox restore success contract missing'

[ -f "$SANDBOX/opt/amnezia/awg/awg0.conf" ] || fail 'restored awg0.conf missing'
[ ! -f "$SANDBOX/opt/amnezia/awg/old.conf" ] || fail 'old AWG state survived successful replace'
[ "$(cat "$SANDBOX/opt/amnezia/unrelated.keep")" = unrelated ] || fail 'unrelated file changed'

for forbidden in fixture-private '[Interface]'; do
    if printf '%s\n' "$out" | grep -F "$forbidden" >/dev/null; then
        fail "sandbox restore leaked backup contents: $forbidden"
    fi
done

# Build a pre-existing target and force verification failure. It must be restored.
rm -rf "$SANDBOX/opt/amnezia/awg"
mkdir -p "$SANDBOX/opt/amnezia/awg"
printf '%s\n' 'before-rollback' > "$SANDBOX/opt/amnezia/awg/original.conf"
printf '%s\n' 'before-start' > "$SANDBOX/opt/amnezia/start.sh"

if HOMEROUTE_RESTORE_SANDBOX_ROOT="$SANDBOX"    HOMEROUTE_SANDBOX_FORCE_VERIFY_FAIL=1    sh "$RESTORE" "$BACKUP" >"$BASE/fail.out" 2>&1; then
    fail 'forced sandbox restore failure unexpectedly succeeded'
fi

grep -F 'HOMEROUTE_VPS_RESTORE_SANDBOX schema=1 result=ROLLBACK live=false' "$BASE/fail.out" >/dev/null ||
    fail 'sandbox restore rollback marker missing'
[ "$(cat "$SANDBOX/opt/amnezia/awg/original.conf")" = before-rollback ] ||
    fail 'original AWG state was not restored after failure'
[ "$(cat "$SANDBOX/opt/amnezia/start.sh")" = before-start ] ||
    fail 'original start.sh was not restored after failure'
[ "$(cat "$SANDBOX/opt/amnezia/unrelated.keep")" = unrelated ] ||
    fail 'unrelated file changed during rollback'

printf '%s\n' '[PASS] AWG restore sandbox / rollback contract'
