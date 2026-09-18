#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/vps/validate-live-awg-restore.sh"
BASE=${TMPDIR:-/tmp}/homeroute-live-awg-restore-test.$$
BIN="$BASE/bin"
FAKE="$BASE/fake"
BACKUPS="$BASE/backups"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BIN" "$FAKE/amnezia-awg2/opt/amnezia/awg" "$BACKUPS"
printf '%s\n' true > "$FAKE/amnezia-awg2/.running"
printf '%s\n' 'config-fixture' > "$FAKE/amnezia-awg2/opt/amnezia/awg/awg0.conf"
printf '%s\n' 'state-fixture' > "$FAKE/amnezia-awg2/opt/amnezia/awg/state.txt"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$FAKE/amnezia-awg2/opt/amnezia/start.sh"

cat > "$BASE/readiness.sh" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' 'HOMEROUTE_RESTORE_READINESS result=READY_FOR_CONTROLLED_VALIDATION'
exit 0
EOF
chmod 700 "$BASE/readiness.sh"

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
    if [ "${HOMEROUTE_FAKE_POSTCHECK_FAIL:-0}" = 1 ]; then
      exit 4
    fi
    case "$1 ${2:-} ${3:-} ${4:-} ${5:-}" in
      "ip link show dev awg0")
        exit 0
        ;;
    esac
    if [ "$1" = iptables-save ] && [ "${2:-}" = -t ] && [ "${3:-}" = nat ]; then
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
  'HOMEROUTE_LIVE_RESTORE target=awg' \
  'HOMEROUTE_LIVE_RESTORE mode=plan' \
  'HOMEROUTE_LIVE_RESTORE live_container_stop=true' \
  'HOMEROUTE_LIVE_RESTORE live_container_recreate=false' \
  'HOMEROUTE_LIVE_RESTORE image_load=false' \
  'HOMEROUTE_LIVE_RESTORE adguard_touched=false' \
  'HOMEROUTE_LIVE_RESTORE result=PLAN_ONLY'
do
  printf '%s\n' "$plan" | grep -Fx "$expected" >/dev/null || fail "missing plan field: $expected"
done

if HOMEROUTE_DOCKER_BIN="$BIN/docker" \
   HOMEROUTE_FAKE_DOCKER_ROOT="$FAKE" \
   HOMEROUTE_LIVE_RESTORE_TEST_MODE=1 \
   HOMEROUTE_BACKUP_ROOT="$BACKUPS" \
   HOMEROUTE_RESTORE_READINESS="$BASE/readiness.sh" \
   sh "$SCRIPT" validate >/dev/null 2>&1; then
    fail 'live AWG validation unexpectedly ran without explicit ACK'
fi

out=$(HOMEROUTE_LIVE_AWG_RESTORE_ACK=YES \
  HOMEROUTE_DOCKER_BIN="$BIN/docker" \
  HOMEROUTE_FAKE_DOCKER_ROOT="$FAKE" \
  HOMEROUTE_LIVE_RESTORE_TEST_MODE=1 \
  HOMEROUTE_BACKUP_ROOT="$BACKUPS" \
  HOMEROUTE_RESTORE_READINESS="$BASE/readiness.sh" \
  HOMEROUTE_LIVE_RESTORE_POSTCHECK_ATTEMPTS=1 \
  HOMEROUTE_LIVE_RESTORE_POSTCHECK_SLEEP=0 \
  sh "$SCRIPT" validate)

for expected in \
  'HOMEROUTE_LIVE_RESTORE schema=1' \
  'HOMEROUTE_LIVE_RESTORE target=awg' \
  'HOMEROUTE_LIVE_RESTORE mode=validate' \
  'HOMEROUTE_LIVE_RESTORE readiness=PASS' \
  'HOMEROUTE_LIVE_RESTORE quiescent_snapshot=PASS' \
  'HOMEROUTE_LIVE_RESTORE stopped_restore_roundtrip=PASS' \
  'HOMEROUTE_LIVE_RESTORE container_recreated=false' \
  'HOMEROUTE_LIVE_RESTORE image_load=false' \
  'HOMEROUTE_LIVE_RESTORE adguard_touched=false' \
  'HOMEROUTE_LIVE_RESTORE runtime_interface=PASS' \
  'HOMEROUTE_LIVE_RESTORE dns_tcp_udp_53=PASS' \
  'HOMEROUTE_LIVE_RESTORE live_restore_validated=true' \
  'HOMEROUTE_LIVE_RESTORE result=PASS'
do
  printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null || fail "missing validate field: $expected"
done

[ "$(cat "$FAKE/amnezia-awg2/.running")" = true ] || fail 'AWG fixture was not restarted'
[ "$(cat "$FAKE/amnezia-awg2/opt/amnezia/awg/awg0.conf")" = config-fixture ] ||
  fail 'AWG config changed during same-state restore'
[ "$(cat "$FAKE/amnezia-awg2/opt/amnezia/awg/state.txt")" = state-fixture ] ||
  fail 'AWG state changed during same-state restore'

# Failure path: force postcheck failure, require automatic restart and retained recovery snapshot.
set +e
HOMEROUTE_LIVE_AWG_RESTORE_ACK=YES \
  HOMEROUTE_DOCKER_BIN="$BIN/docker" \
  HOMEROUTE_FAKE_DOCKER_ROOT="$FAKE" \
  HOMEROUTE_FAKE_POSTCHECK_FAIL=1 \
  HOMEROUTE_LIVE_RESTORE_TEST_MODE=1 \
  HOMEROUTE_BACKUP_ROOT="$BACKUPS" \
  HOMEROUTE_RESTORE_READINESS="$BASE/readiness.sh" \
  HOMEROUTE_LIVE_RESTORE_POSTCHECK_ATTEMPTS=1 \
  HOMEROUTE_LIVE_RESTORE_POSTCHECK_SLEEP=0 \
  sh "$SCRIPT" validate >/dev/null 2>&1
rc=$?
set -e

[ "$rc" -ne 0 ] || fail 'forced postcheck failure unexpectedly succeeded'
[ "$(cat "$FAKE/amnezia-awg2/.running")" = true ] || fail 'AWG fixture was not restarted after failure'

find "$BACKUPS" -maxdepth 1 -type d -name 'live-awg-restore-validation-*' | grep -q . ||
  fail 'failure path did not retain a recovery snapshot'

printf '%s\n' '[PASS] controlled live AWG restore-validation contract'
