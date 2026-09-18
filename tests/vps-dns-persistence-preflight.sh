#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/vps/preflight-dns-persistence.sh"
BASE=${TMPDIR:-/tmp}/homeroute-dns-persistence-test.$$
BIN="$BASE/bin"
HELPER="$BASE/helper.sh"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

mkdir -p "$BIN"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$HELPER"
chmod 700 "$HELPER"
HELPER_SHA=$(sha256sum "$HELPER" | awk '{print $1}')

cat > "$BIN/systemctl" <<'EOF'
#!/bin/sh
set -eu

cmd=$1
case "$cmd" in
  is-active)
    case "$2" in
      awg-adguard-dns.timer) printf '%s\n' active ;;
      awg-adguard-dns.service) printf '%s\n' inactive ;;
      *) exit 3 ;;
    esac
    ;;
  is-enabled)
    [ "$2" = awg-adguard-dns.timer ] || exit 1
    printf '%s\n' enabled
    ;;
  show)
    unit=$2
    shift 2
    prop=
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -p)
          prop=$2
          shift 2
          ;;
        --value)
          shift
          ;;
        *)
          shift
          ;;
      esac
    done

    case "$unit:$prop" in
      awg-adguard-dns.timer:TimersCalendar)
        printf '%s\n' 'OnCalendar=*-*-* *:*:00'
        ;;
      awg-adguard-dns.timer:NextElapseUSecRealtime)
        printf '%s\n' 'Fri 2026-09-18 11:20:00 UTC'
        ;;
      awg-adguard-dns.service:ExecStart)
        printf 'path=%s ; argv[]=%s ;\n' "$HOMEROUTE_TEST_HELPER" "$HOMEROUTE_TEST_HELPER"
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  *)
    exit 1
    ;;
esac
EOF
chmod 700 "$BIN/systemctl"

out=$(HOMEROUTE_TEST_HELPER="$HELPER" PATH="$BIN:$PATH" sh "$SCRIPT")

for expected in \
  'HOMEROUTE_DNS_PERSISTENCE schema=1' \
  'HOMEROUTE_DNS_PERSISTENCE timer=awg-adguard-dns.timer' \
  'HOMEROUTE_DNS_PERSISTENCE service=awg-adguard-dns.service' \
  'HOMEROUTE_DNS_PERSISTENCE timer_active=active' \
  'HOMEROUTE_DNS_PERSISTENCE timer_enabled=enabled' \
  'HOMEROUTE_DNS_PERSISTENCE service_active=inactive' \
  "HOMEROUTE_DNS_PERSISTENCE exec_path=$HELPER" \
  "HOMEROUTE_DNS_PERSISTENCE exec_sha256=$HELPER_SHA"
do
    printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null ||
        fail "missing DNS persistence field: $expected"
done

if printf '%s\n' "$out" | grep -F '#!/bin/sh' >/dev/null; then
    fail 'DNS persistence preflight leaked helper contents'
fi

printf '%s\n' '[PASS] DNS persistence preflight sanitized contract'
