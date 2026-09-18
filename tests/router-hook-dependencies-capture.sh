#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/router/capture-hook-dependencies.sh"

BASE=${TMPDIR:-/tmp}/homeroute-hook-deps-test.$$
ROOTFS="$BASE/root"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p   "$ROOTFS/opt/etc/init.d"   "$ROOTFS/opt/etc/ndm/netfilter.d"   "$ROOTFS/opt/etc/ndm/ifstatechanged.d"

cat > "$ROOTFS/opt/etc/init.d/S98telegram-awg" <<'EOF'
#!/bin/sh
. /opt/etc/init.d/rc.func
case "$1" in
  start) /opt/bin/awg-quick up opkgtun0 ;;
  stop) /opt/bin/awg-quick down opkgtun0 ;;
  restart) /opt/etc/init.d/S98telegram-awg stop; /opt/etc/init.d/S98telegram-awg start ;;
esac
EOF

cat > "$ROOTFS/opt/etc/init.d/S99hrneo" <<'EOF'
#!/bin/sh
. /opt/etc/init.d/rc.func
case "$1" in
  start) /opt/bin/hrneo >/dev/null 2>&1 & ;;
  stop) killall hrneo 2>/dev/null || true ;;
esac
EOF

cat > "$ROOTFS/opt/etc/ndm/netfilter.d/014-telegram-awg.sh" <<'EOF'
#!/bin/sh
/opt/etc/init.d/S98telegram-awg restart
EOF

cat > "$ROOTFS/opt/etc/ndm/netfilter.d/015-hrneo.sh" <<'EOF'
#!/bin/sh
/opt/etc/init.d/S99hrneo restart
EOF

cat > "$ROOTFS/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh" <<'EOF'
#!/bin/sh
[ "$1" = opkgtun0 ] || exit 0
/opt/etc/init.d/S98telegram-awg start
EOF

cat > "$ROOTFS/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh" <<'EOF'
#!/bin/sh
/opt/etc/init.d/S99hrneo start
EOF

chmod 700   "$ROOTFS/opt/etc/init.d/S98telegram-awg"   "$ROOTFS/opt/etc/init.d/S99hrneo"   "$ROOTFS/opt/etc/ndm/netfilter.d/014-telegram-awg.sh"   "$ROOTFS/opt/etc/ndm/netfilter.d/015-hrneo.sh"   "$ROOTFS/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh"   "$ROOTFS/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh"

OUT="$BASE/out"

HOMEROUTE_HOOK_DEP_CAPTURE_TEST_MODE=1 HOMEROUTE_CAPTURE_ROOT="$ROOTFS"   sh "$SCRIPT" > "$OUT"

grep -Fx 'HOMEROUTE_HOOK_DEPENDENCY schema=1' "$OUT" >/dev/null ||
  fail 'schema missing'
grep -Fx 'HOMEROUTE_HOOK_DEPENDENCY mode=read_only' "$OUT" >/dev/null ||
  fail 'mode missing'
grep -Fx 'HOMEROUTE_HOOK_DEPENDENCY arbitrary_source_printed=false' "$OUT" >/dev/null ||
  fail 'arbitrary source boundary missing'
grep -Fx 'HOMEROUTE_HOOK_DEPENDENCY secret_values_printed=false' "$OUT" >/dev/null ||
  fail 'secret boundary missing'

grep -F 'id=init_telegram_awg ' "$OUT" |
  grep -F 'ref_rc_func=true' |
  grep -F 'ref_awg_quick=true' |
  grep -F 'action_start=true' |
  grep -F 'action_stop=true' |
  grep -F 'action_restart=true' >/dev/null ||
  fail 'telegram init dependency shape missing'

grep -F 'id=init_hrneo ' "$OUT" |
  grep -F 'ref_rc_func=true' |
  grep -F 'ref_hrneo=true' |
  grep -F 'use_killall=true' |
  grep -F 'background=true' >/dev/null ||
  fail 'hrneo init dependency shape missing'

grep -F 'id=netfilter_telegram_awg ' "$OUT" |
  grep -F 'ref_S98telegram_awg=true' |
  grep -F 'action_restart=true' >/dev/null ||
  fail 'telegram netfilter delegation missing'

grep -F 'id=netfilter_hrneo ' "$OUT" |
  grep -F 'ref_S99hrneo=true' |
  grep -F 'action_restart=true' >/dev/null ||
  fail 'hrneo netfilter delegation missing'

grep -F 'id=ifstate_telegram_awg ' "$OUT" |
  grep -F 'ref_S98telegram_awg=true' |
  grep -F 'conditional_opkgtun0=true' |
  grep -F 'action_start=true' >/dev/null ||
  fail 'telegram ifstate delegation missing'

grep -F 'id=ifstate_hrneo ' "$OUT" |
  grep -F 'ref_S99hrneo=true' |
  grep -F 'action_start=true' >/dev/null ||
  fail 'hrneo ifstate delegation missing'

grep -Fx 'HOMEROUTE_HOOK_DEPENDENCY result=PASS' "$OUT" >/dev/null ||
  fail 'result PASS missing'

if grep -F 'PUBLIC_KEY' "$OUT" >/dev/null; then
  fail 'unexpected arbitrary data leaked'
fi

printf '%s\n' '[PASS] sanitized hook dependency capture contract'
