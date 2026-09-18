#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/vps/validate-live-adguard-restore.sh"
BASE=${TMPDIR:-/tmp}/homeroute-live-adguard-restore-test.$$
BIN="$BASE/bin"
FAKE="$BASE/fake"
BACKUPS="$BASE/backups"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BIN" \
  "$FAKE/adguard-home/opt/adguardhome/conf" \
  "$FAKE/adguard-home/opt/adguardhome/work" \
  "$FAKE/amnezia-awg2" \
  "$BACKUPS"

printf '%s\n' true > "$FAKE/adguard-home/.running"
printf '%s\n' true > "$FAKE/amnezia-awg2/.running"
printf '%s\n' 'dns:' '  port: 53' > "$FAKE/adguard-home/opt/adguardhome/conf/AdGuardHome.yaml"
printf '%s\n' 'runtime-state' > "$FAKE/adguard-home/opt/adguardhome/work/state.db"

cat > "$BASE/readiness.sh" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' 'HOMEROUTE_RESTORE_READINESS result=READY_FOR_CONTROLLED_VALIDATION'
exit 0
EOF
chmod 700 "$BASE/readiness.sh"

cat > "$BASE/probe-pass.sh" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 700 "$BASE/probe-pass.sh"

cat > "$BASE/probe-fail.sh" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 700 "$BASE/probe-fail.sh"

cat > "$BIN/docker" <<'EOF'
#!/bin/sh
set -eu

ROOT=${HOMEROUTE_FAKE_DOCKER_ROOT:?}
cmd=$1
shift

case "$cmd" in
  info)
    exit 0
    ;;
  inspect)
    [ "$1" = -f ] || exit 2
    format=$2
    name=$3
    case "$format" in
      '{{.State.Running}}')
        cat "$ROOT/$name/.running"
        ;;
      *)
        exit 2
        ;;
    esac
    ;;
  stop)
    [ "$1" = -t ] || exit 2
    shift 2
    name=$1
    printf '%s\n' false > "$ROOT/$name/.running"
    ;;
  start)
    name=$1
    printf '%s\n' true > "$ROOT/$name/.running"
    ;;
  cp)
    [ "$1" = -a ] || exit 2
    shift
    src=$1
    dst=$2

    case "$src" in
      *:*)
        container=${src%%:*}
        path=${src#*:}
        case "$path" in
          */.)
            path=${path%/.}
            mkdir -p "$dst"
            cp -a "$ROOT/$container$path/." "$dst/"
            ;;
          *)
            mkdir -p "$(dirname "$dst")"
            cp -a "$ROOT/$container$path" "$dst"
            ;;
        esac
        ;;
      *)
        case "$dst" in
          *:*)
            container=${dst%%:*}
            path=${dst#*:}
            case "$src" in
              */.)
                src=${src%/.}
                mkdir -p "$ROOT/$container$path"
                cp -a "$src/." "$ROOT/$container$path/"
                ;;
              *)
                mkdir -p "$(dirname "$ROOT/$container$path")"
                cp -a "$src" "$ROOT/$container$path"
                ;;
            esac
            ;;
          *)
            exit 2
            ;;
        esac
        ;;
    esac
    ;;
  exec)
    name=$1
    shift
    [ "$(cat "$ROOT/$name/.running")" = true ] || exit 3

    if [ "$name" = adguard-home ] && [ "$1" = test ] && [ "$2" = -f ]; then
      [ -f "$ROOT/$name$3" ]
      exit $?
    fi

    if [ "$name" = amnezia-awg2 ] && [ "$1" = iptables-save ] &&
       [ "${2:-}" = -t ] && [ "${3:-}" = nat ]; then
      printf '%s\n' '-A PREROUTING -p tcp --dport 53 -j DNAT --to-destination 192.0.2.1:53'
      printf '%s\n' '-A PREROUTING -p udp --dport 53 -j DNAT --to-destination 192.0.2.1:53'
      exit 0
    fi
    exit 2
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod 700 "$BIN/docker"

plan=$(sh "$SCRIPT" plan)
for expected in \
  'HOMEROUTE_LIVE_RESTORE schema=1' \
  'HOMEROUTE_LIVE_RESTORE target=adguard' \
  'HOMEROUTE_LIVE_RESTORE mode=plan' \
  'HOMEROUTE_LIVE_RESTORE live_container_stop=true' \
  'HOMEROUTE_LIVE_RESTORE live_container_recreate=false' \
  'HOMEROUTE_LIVE_RESTORE image_load=false' \
  'HOMEROUTE_LIVE_RESTORE awg_touched=false' \
  'HOMEROUTE_LIVE_RESTORE dns_tcp_udp_probe=true' \
  'HOMEROUTE_LIVE_RESTORE result=PLAN_ONLY'
do
  printf '%s\n' "$plan" | grep -Fx "$expected" >/dev/null || fail "missing plan field: $expected"
done

if HOMEROUTE_DOCKER_BIN="$BIN/docker" \
   HOMEROUTE_FAKE_DOCKER_ROOT="$FAKE" \
   HOMEROUTE_LIVE_RESTORE_TEST_MODE=1 \
   HOMEROUTE_BACKUP_ROOT="$BACKUPS" \
   HOMEROUTE_RESTORE_READINESS="$BASE/readiness.sh" \
   HOMEROUTE_ADGUARD_DNS_PROBE="$BASE/probe-pass.sh" \
   sh "$SCRIPT" validate >/dev/null 2>&1; then
  fail 'AdGuard validation unexpectedly ran without explicit ACK'
fi

out=$(HOMEROUTE_LIVE_ADGUARD_RESTORE_ACK=YES \
  HOMEROUTE_DOCKER_BIN="$BIN/docker" \
  HOMEROUTE_FAKE_DOCKER_ROOT="$FAKE" \
  HOMEROUTE_LIVE_RESTORE_TEST_MODE=1 \
  HOMEROUTE_BACKUP_ROOT="$BACKUPS" \
  HOMEROUTE_RESTORE_READINESS="$BASE/readiness.sh" \
  HOMEROUTE_ADGUARD_DNS_PROBE="$BASE/probe-pass.sh" \
  HOMEROUTE_LIVE_RESTORE_POSTCHECK_ATTEMPTS=1 \
  HOMEROUTE_LIVE_RESTORE_POSTCHECK_SLEEP=0 \
  sh "$SCRIPT" validate)

for expected in \
  'HOMEROUTE_LIVE_RESTORE schema=1' \
  'HOMEROUTE_LIVE_RESTORE target=adguard' \
  'HOMEROUTE_LIVE_RESTORE mode=validate' \
  'HOMEROUTE_LIVE_RESTORE readiness=PASS' \
  'HOMEROUTE_LIVE_RESTORE quiescent_snapshot=PASS' \
  'HOMEROUTE_LIVE_RESTORE stopped_restore_roundtrip=PASS' \
  'HOMEROUTE_LIVE_RESTORE container_recreated=false' \
  'HOMEROUTE_LIVE_RESTORE image_load=false' \
  'HOMEROUTE_LIVE_RESTORE awg_touched=false' \
  'HOMEROUTE_LIVE_RESTORE config_present=PASS' \
  'HOMEROUTE_LIVE_RESTORE awg_dns_redirect=PASS' \
  'HOMEROUTE_LIVE_RESTORE dns_udp_53=PASS' \
  'HOMEROUTE_LIVE_RESTORE dns_tcp_53=PASS' \
  'HOMEROUTE_LIVE_RESTORE live_restore_validated=true' \
  'HOMEROUTE_LIVE_RESTORE result=PASS'
do
  printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null || fail "missing validate field: $expected"
done

[ "$(cat "$FAKE/adguard-home/.running")" = true ] || fail 'AdGuard fixture was not restarted'
[ "$(cat "$FAKE/amnezia-awg2/.running")" = true ] || fail 'AWG fixture was unexpectedly stopped'
grep -Fx 'dns:' "$FAKE/adguard-home/opt/adguardhome/conf/AdGuardHome.yaml" >/dev/null ||
  fail 'AdGuard config changed during same-state restore'
[ "$(cat "$FAKE/adguard-home/opt/adguardhome/work/state.db")" = runtime-state ] ||
  fail 'AdGuard work state changed during same-state restore'

set +e
HOMEROUTE_LIVE_ADGUARD_RESTORE_ACK=YES \
  HOMEROUTE_DOCKER_BIN="$BIN/docker" \
  HOMEROUTE_FAKE_DOCKER_ROOT="$FAKE" \
  HOMEROUTE_LIVE_RESTORE_TEST_MODE=1 \
  HOMEROUTE_BACKUP_ROOT="$BACKUPS" \
  HOMEROUTE_RESTORE_READINESS="$BASE/readiness.sh" \
  HOMEROUTE_ADGUARD_DNS_PROBE="$BASE/probe-fail.sh" \
  HOMEROUTE_LIVE_RESTORE_POSTCHECK_ATTEMPTS=1 \
  HOMEROUTE_LIVE_RESTORE_POSTCHECK_SLEEP=0 \
  sh "$SCRIPT" validate >/dev/null 2>&1
rc=$?
set -e

[ "$rc" -ne 0 ] || fail 'forced DNS postcheck failure unexpectedly succeeded'
[ "$(cat "$FAKE/adguard-home/.running")" = true ] || fail 'AdGuard fixture was not restarted after failure'
[ "$(cat "$FAKE/amnezia-awg2/.running")" = true ] || fail 'AWG fixture changed during failure recovery'

find "$BACKUPS" -maxdepth 1 -type d -name 'live-adguard-restore-validation-*' | grep -q . ||
  fail 'failure path did not retain a recovery snapshot'

printf '%s\n' '[PASS] controlled live AdGuard restore-validation contract'
