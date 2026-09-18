#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/vps/restore-rehearsal.sh"
BASE=${TMPDIR:-/tmp}/homeroute-restore-rehearsal-test.$$
BIN="$BASE/bin"
FAKE="$BASE/fake-docker"
BACKUPS="$BASE/backups"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BIN" "$FAKE" "$BACKUPS/awg-state/awg" "$BACKUPS/adguard-state/conf" "$BACKUPS/adguard-state/work" "$BACKUPS/awg-image" "$BACKUPS/adguard-image"

printf '%s\n' 'awg-config-fixture' > "$BACKUPS/awg-state/awg/awg0.conf"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$BACKUPS/awg-state/start.sh"
printf '%s\n' 'schema=1' > "$BACKUPS/awg-state/metadata.txt"
(
  cd "$BACKUPS/awg-state"
  sha256sum awg/awg0.conf start.sh metadata.txt > MANIFEST.sha256
)

printf '%s\n' 'dns:' '  port: 53' > "$BACKUPS/adguard-state/conf/AdGuardHome.yaml"
printf '%s\n' 'work-fixture' > "$BACKUPS/adguard-state/work/state.db"
printf '%s\n' 'schema=1' > "$BACKUPS/adguard-state/metadata.txt"
(
  cd "$BACKUPS/adguard-state"
  sha256sum conf/AdGuardHome.yaml work/state.db metadata.txt > MANIFEST.sha256
)

printf '%s\n' 'image_id=sha256:awg-fixture' > "$BACKUPS/awg-image/metadata.txt"
printf '%s\n' 'image_id=sha256:adguard-fixture' > "$BACKUPS/adguard-image/metadata.txt"

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
  image)
    [ "$1" = inspect ] || exit 2
    exit 0
    ;;
  create)
    network=
    name=
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --network)
          network=$2
          shift 2
          ;;
        --name)
          name=$2
          shift 2
          ;;
        *)
          image=$1
          shift
          ;;
      esac
    done
    [ "$network" = none ] || exit 3
    [ -n "$name" ] || exit 3
    mkdir -p "$ROOT/$name/tmp"
    printf '%s\n' created > "$ROOT/$name/status"
    printf '%s\n' "$name"
    ;;
  inspect)
    [ "$1" = -f ] || exit 2
    format=$2
    name=$3
    [ "$format" = '{{.State.Status}}' ] || exit 2
    cat "$ROOT/$name/status"
    ;;
  cp)
    src=$1
    dst=$2
    case "$src" in
      *:*)
        container=${src%%:*}
        cpath=${src#*:}
        host_src="$ROOT/$container$cpath"
        mkdir -p "$dst"
        cp -R "$host_src" "$dst/"
        ;;
      *)
        case "$dst" in
          *:*)
            container=${dst%%:*}
            cpath=${dst#*:}
            host_dst="$ROOT/$container$cpath"
            mkdir -p "$host_dst"
            cp -R "$src" "$host_dst/"
            ;;
          *)
            exit 4
            ;;
        esac
        ;;
    esac
    ;;
  rm)
    [ "$1" = -f ] || exit 2
    rm -rf "$ROOT/$2"
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod 700 "$BIN/docker"

plan=$(sh "$SCRIPT" plan)
printf '%s\n' "$plan" | grep -Fx 'HOMEROUTE_RESTORE_REHEARSAL live_containers_touched=false' >/dev/null ||
  fail 'plan lost live-container safety field'
printf '%s\n' "$plan" | grep -Fx 'HOMEROUTE_RESTORE_REHEARSAL temp_containers_started=false' >/dev/null ||
  fail 'plan lost stopped-container safety field'

if HOMEROUTE_DOCKER_BIN="$BIN/docker" sh "$SCRIPT" rehearse >/dev/null 2>&1; then
  fail 'rehearsal unexpectedly ran without explicit ACK'
fi

out=$(HOMEROUTE_RESTORE_REHEARSAL_ACK=YES \
  HOMEROUTE_DOCKER_BIN="$BIN/docker" \
  HOMEROUTE_FAKE_DOCKER_ROOT="$FAKE" \
  HOMEROUTE_RESTORE_READINESS="$BASE/readiness.sh" \
  HOMEROUTE_AWG_STATE_BACKUP="$BACKUPS/awg-state" \
  HOMEROUTE_ADGUARD_STATE_BACKUP="$BACKUPS/adguard-state" \
  HOMEROUTE_AWG_IMAGE_BACKUP="$BACKUPS/awg-image" \
  HOMEROUTE_ADGUARD_IMAGE_BACKUP="$BACKUPS/adguard-image" \
  HOMEROUTE_RESTORE_REHEARSAL_ROOT="/tmp/homeroute-restore-rehearsal.test.$$" \
  sh "$SCRIPT" rehearse)

for expected in \
  'HOMEROUTE_RESTORE_REHEARSAL schema=1' \
  'HOMEROUTE_RESTORE_REHEARSAL mode=rehearse' \
  'HOMEROUTE_RESTORE_REHEARSAL rescue_readiness=PASS' \
  'HOMEROUTE_RESTORE_REHEARSAL awg_roundtrip=PASS' \
  'HOMEROUTE_RESTORE_REHEARSAL adguard_roundtrip=PASS' \
  'HOMEROUTE_RESTORE_REHEARSAL temp_containers_started=false' \
  'HOMEROUTE_RESTORE_REHEARSAL temp_network=none' \
  'HOMEROUTE_RESTORE_REHEARSAL live_containers_touched=false' \
  'HOMEROUTE_RESTORE_REHEARSAL image_load=false' \
  'HOMEROUTE_RESTORE_REHEARSAL live_restore_validated=false' \
  'HOMEROUTE_RESTORE_REHEARSAL result=PASS'
do
  printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null || fail "missing rehearsal field: $expected"
done

if find "$FAKE" -mindepth 1 -maxdepth 1 -type d | grep -q .; then
  fail 'temporary rehearsal containers were not cleaned up'
fi

printf '%s\n' '[PASS] isolated stopped-container restore rehearsal contract'
