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

    kind=${HOMEROUTE_TEST_TIMER_KIND:-calendar}

    case "$unit:$prop:$kind" in
      awg-adguard-dns.timer:TimersCalendar:calendar)
        printf '%s\n' 'OnCalendar=*-*-* *:*:00'
        ;;
      awg-adguard-dns.timer:TimersMonotonic:monotonic)
        printf '%s\n' 'OnUnitActiveUSec=1min'
        ;;
      awg-adguard-dns.timer:NextElapseUSecRealtime:calendar)
        printf '%s\n' 'Fri 2026-09-18 11:20:00 UTC'
        ;;
      awg-adguard-dns.timer:NextElapseUSecMonotonic:monotonic)
        printf '%s\n' '1min'
        ;;
      awg-adguard-dns.timer:LastTriggerUSec:*)
        printf '%s\n' 'Fri 2026-09-18 11:19:00 UTC'
        ;;
      awg-adguard-dns.timer:Persistent:*)
        printf '%s\n' yes
        ;;
      awg-adguard-dns.timer:AccuracyUSec:*)
        printf '%s\n' 1s
        ;;
      awg-adguard-dns.timer:RandomizedDelayUSec:*)
        printf '%s\n' 0
        ;;
      awg-adguard-dns.service:ExecStart:*)
        printf 'path=%s ; argv[]=%s ;\n' "$HOMEROUTE_TEST_HELPER" "$HOMEROUTE_TEST_HELPER"
        ;;
      awg-adguard-dns.timer:TimersCalendar:monotonic|awg-adguard-dns.timer:TimersMonotonic:calendar|awg-adguard-dns.timer:NextElapseUSecRealtime:monotonic|awg-adguard-dns.timer:NextElapseUSecMonotonic:calendar)
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

run_case() {
    kind=$1
    out=$(HOMEROUTE_TEST_HELPER="$HELPER" HOMEROUTE_TEST_TIMER_KIND="$kind" PATH="$BIN:$PATH" sh "$SCRIPT")

    for expected in \
      'HOMEROUTE_DNS_PERSISTENCE schema=2' \
      'HOMEROUTE_DNS_PERSISTENCE timer=awg-adguard-dns.timer' \
      'HOMEROUTE_DNS_PERSISTENCE service=awg-adguard-dns.service' \
      'HOMEROUTE_DNS_PERSISTENCE timer_active=active' \
      'HOMEROUTE_DNS_PERSISTENCE timer_enabled=enabled' \
      'HOMEROUTE_DNS_PERSISTENCE service_active=inactive' \
      "HOMEROUTE_DNS_PERSISTENCE schedule_kind=$kind" \
      'HOMEROUTE_DNS_PERSISTENCE last_trigger_state=SET' \
      'HOMEROUTE_DNS_PERSISTENCE persistent=yes' \
      'HOMEROUTE_DNS_PERSISTENCE accuracy_usec=1s' \
      'HOMEROUTE_DNS_PERSISTENCE randomized_delay_usec=0' \
      "HOMEROUTE_DNS_PERSISTENCE exec_path=$HELPER" \
      "HOMEROUTE_DNS_PERSISTENCE exec_sha256=$HELPER_SHA"
    do
        printf '%s\n' "$out" | grep -Fx "$expected" >/dev/null ||
            fail "missing DNS persistence field for $kind: $expected"
    done

    if [ "$kind" = calendar ]; then
        printf '%s\n' "$out" | grep -Fx 'HOMEROUTE_DNS_PERSISTENCE next_realtime_state=SET' >/dev/null ||
            fail 'calendar next realtime state missing'
        printf '%s\n' "$out" | grep -Fx 'HOMEROUTE_DNS_PERSISTENCE calendar_spec=OnCalendar=*-*-*_*:*:00' >/dev/null ||
            fail 'calendar spec missing'
    else
        printf '%s\n' "$out" | grep -Fx 'HOMEROUTE_DNS_PERSISTENCE next_monotonic_state=SET' >/dev/null ||
            fail 'monotonic next state missing'
        printf '%s\n' "$out" | grep -Fx 'HOMEROUTE_DNS_PERSISTENCE monotonic_spec=OnUnitActiveUSec=1min' >/dev/null ||
            fail 'monotonic spec missing'
    fi

    if printf '%s\n' "$out" | grep -F '#!/bin/sh' >/dev/null; then
        fail 'DNS persistence preflight leaked helper contents'
    fi
}

run_case calendar
run_case monotonic

printf '%s\n' '[PASS] DNS persistence preflight calendar/monotonic sanitized contract'
