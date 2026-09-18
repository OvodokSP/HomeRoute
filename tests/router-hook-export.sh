#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/router/export-reference-hooks.sh"

SRC=/tmp/homeroute-hook-source-test.$$
OUT=/tmp/homeroute-hook-export-test.$$
EXPECTED=/tmp/homeroute-hook-expected-test.$$
trap 'rm -rf "$SRC" "$OUT" "$EXPECTED"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p \
  "$SRC/opt/etc/init.d" \
  "$SRC/opt/etc/ndm/netfilter.d" \
  "$SRC/opt/etc/ndm/ifstatechanged.d" \
  "$OUT"

cat > "$SRC/opt/etc/init.d/S98telegram-awg" <<'EOF'
#!/bin/sh
case "$1" in
  start) echo start >/dev/null ;;
  stop) echo stop >/dev/null ;;
esac
EOF

cat > "$SRC/opt/etc/init.d/S99hrneo" <<'EOF'
#!/bin/sh
case "$1" in
  start) echo hrneo >/dev/null ;;
  stop) : ;;
esac
EOF

cat > "$SRC/opt/etc/ndm/netfilter.d/014-telegram-awg.sh" <<'EOF'
#!/bin/sh
echo telegram-netfilter >/dev/null
EOF

cat > "$SRC/opt/etc/ndm/netfilter.d/015-hrneo.sh" <<'EOF'
#!/bin/sh
echo hrneo-netfilter >/dev/null
EOF

cat > "$SRC/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh" <<'EOF'
#!/bin/sh
echo telegram-ifstate >/dev/null
EOF

cat > "$SRC/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh" <<'EOF'
#!/bin/sh
echo hrneo-ifstate >/dev/null
EOF

chmod 700 \
  "$SRC/opt/etc/init.d/S98telegram-awg" \
  "$SRC/opt/etc/init.d/S99hrneo" \
  "$SRC/opt/etc/ndm/netfilter.d/014-telegram-awg.sh" \
  "$SRC/opt/etc/ndm/netfilter.d/015-hrneo.sh" \
  "$SRC/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh" \
  "$SRC/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh"

write_expected() {
    : > "$EXPECTED"
    for rel in \
      /opt/etc/init.d/S98telegram-awg \
      /opt/etc/init.d/S99hrneo \
      /opt/etc/ndm/netfilter.d/014-telegram-awg.sh \
      /opt/etc/ndm/netfilter.d/015-hrneo.sh \
      /opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh \
      /opt/etc/ndm/ifstatechanged.d/015-hrneo.sh
    do
        hash=$(sha256sum "$SRC$rel" | awk '{print $1}')
        printf '%s %s\n' "$rel" "$hash" >> "$EXPECTED"
    done
}

run_export() {
    HOMEROUTE_HOOK_EXPORT_ACK=YES \
    HOMEROUTE_HOOK_EXPORT_TEST_MODE=1 \
    HOMEROUTE_HOOK_EXPORT_ROOT="$OUT" \
    HOMEROUTE_HOOK_EXPORT_SOURCE_ROOT="$SRC" \
    HOMEROUTE_HOOK_EXPORT_EXPECTED_FILE="$EXPECTED" \
        sh "$SCRIPT"
}

write_expected
success_out=$(run_export)

printf '%s\n' "$success_out" | grep -F 'HOMEROUTE_HOOK_EXPORT schema=1 result=PASS hooks=6' >/dev/null ||
  fail 'successful export result marker missing'
printf '%s\n' "$success_out" | grep -F 'HOMEROUTE_HOOK_EXPORT secret_scan=PASS contents_printed=false' >/dev/null ||
  fail 'successful export secret boundary missing'

archive=$(printf '%s\n' "$success_out" | sed -n 's/^HOMEROUTE_HOOK_EXPORT archive=//p')
[ -f "$archive" ] || fail 'export archive missing'
[ "$(stat -c '%a' "$archive")" = 600 ] || fail 'export archive mode must be 600'

tar -tzf "$archive" | grep -Fx 'hooks/opt/etc/init.d/S98telegram-awg' >/dev/null ||
  fail 'expected hook missing from archive'
[ "$(tar -tzf "$archive" | grep '^hooks/' | wc -l | tr -d ' ')" = 12 ] || {
  # tar lists directories as well; require exactly six regular files separately.
  files=$(tar -tzf "$archive" | grep -E '^hooks/.+[^/]$' | wc -l | tr -d ' ')
  [ "$files" = 6 ] || fail "unexpected hook file count in archive: $files"
}

# Identity drift must fail before export.
printf '%s\n' '# drift' >> "$SRC/opt/etc/init.d/S99hrneo"
set +e
run_export >/tmp/homeroute-hook-export-drift.$$ 2>&1
rc=$?
set -e
rm -f /tmp/homeroute-hook-export-drift.$$
[ "$rc" -ne 0 ] || fail 'hook identity drift unexpectedly accepted'

# Restore a valid expected identity for the modified file, then inject a
# secret-like token: identity can match but secret scan must still refuse.
write_expected
cat >> "$SRC/opt/etc/init.d/S99hrneo" <<'EOF'
PrivateKey = SHOULD_NOT_EXPORT
EOF
write_expected

set +e
run_export >/tmp/homeroute-hook-export-secret.$$ 2>&1
rc=$?
set -e
grep -F 'secret/address scan' /tmp/homeroute-hook-export-secret.$$ >/dev/null ||
  fail 'secret-scan refusal marker missing'
rm -f /tmp/homeroute-hook-export-secret.$$
[ "$rc" -ne 0 ] || fail 'secret-bearing hook unexpectedly exported'

printf '%s\n' '[PASS] protected reference hook export contract'
