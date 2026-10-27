# Netis N6 v2 — verified HomeRoute recovery (2026-10-27)

**Status:** Stable candidate, runtime + one cold reboot confirmed by the operator on 2026-10-27. This is a **separate** target from the 2026-09-18 reference Keenetic / Netis N6 v1 (`mipsel-3.4`). **Do not overwrite v1 baseline or port v1 binaries.** Only one reboot and same-day manual verification are evidenced; long-term resilience remains unproven.

## Platform and scope

- Router: Netis N6 **v2**, ported KeeneticOS 5.01.C.2.0-2 (5.1.2), Entware on UBIFS `/opt`, `aarch64-3.10`. LAN `br0`, Entware management at `192.168.1.1`, HRweb UI `http://192.168.1.1:2000`.
- WAN ordinary default remains provider via `eth2.4`; only selected domains / networks routed to AWG.
- VPS AWG2 container `amnezia-awg2` (do not recreate), endpoint `31.77.56.66:35404/udp`. This installation uses a **new** Netis peer with tunnel IP `10.8.1.13/32`; old router peer `10.8.1.11/32` and all other peers untouched. Do **not** commit private keys or actual connection configs.
- Relevant Entware packages installed: `chur-amneziawg`, `chur-amneziawg-go`, `chur-amneziawg-tools`, `hrneo 3.24.2-1`, `hrweb 1.68.0-1`; `hrdns` used for DNS. No nfqws required for observed working services.
- AWG clients use **userspace** `amneziawg-go` (native kernel support unavailable), interface `opkgtun0`, MTU 1324, `Table=off`. Router client profile: `/opt/etc/telegram-awg/opkgtun0.conf` (600), private key separate in same directory (600). Never publish or display keys.
- On VPS, live peer addition was also persisted in the container's internal `/opt/amnezia/awg/awg0.conf`; this is **not established as a bind-mounted persistent host config**. Container replacement can therefore lose this peer. Previously created VPS config backups under `/root/homeroute-backups/`; verify before container upgrades. Avoid any VPS change during routine router recovery.

## Working architecture and observed invariants

- HRweb DirectRoute interface `opkgtun0`, not an ordinary rule assigned to Broadband.
- HR Neo marking `0x3001` -> `ip rule` priority 9 -> table `301` -> `default dev opkgtun0`; ipset `opkgtun0` carries selected addresses.
- LAN traffic requires **both** rules:
  ```sh
  iptables -C FORWARD -i br0 -o opkgtun0 -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -i br0 -o opkgtun0 -j ACCEPT
  iptables -t nat -C POSTROUTING -o opkgtun0 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -o opkgtun0 -j MASQUERADE
  ```
- Rule groups configured in `/opt/etc/HydraRoute/domain.conf`, networks in `/opt/etc/HydraRoute/ip.list`. Known restored legacy groups:
  ```ini
  ##iLook
  ilook.tv,zyntras.top/opkgtun0
  ##RuTracker
  rutracker.org,t-ru.org/opkgtun0
  ##Flibusta
  flibusta.is/opkgtun0
  ```
  Other working services confirmed by operator: Telegram (including media), YouTube, Instagram/Reels, ChatGPT, iLook, RuTracker, Flibusta. This file is **not** an exhaustive export of ~96 KB `domain.conf`; obtain sanitized export before clean install.
- DNS: local router DNS previously returned same ER-Telecom addresses for unrelated blocked sites (`ilook.tv`, `rutracker.org`, `instagram.com`) whereas Cloudflare returned other addresses; configured **HRDNS rule DNS**: Cloudflare Standard over DoH, route **Auto (system routing)**. Instagram recovered after this change. Do not assume every hostname is permanently valid or reachable.

## Timeline: diagnosis and proven fix

1. **Oct 26:** New peer assigned `10.8.1.13/32` without disturbing old peer; userspace AWG handshake good. DirectRoute and routing table 301 worked but LAN clients failed until FORWARD and MASQUERADE were added manually. DNS correction and legacy domain groups restored all tested services.
2. **Oct 27 (~19:19 UTC shown in conversation):** User reported that nothing proxied worked after ~one day. Router uptime **1 day 1:57** (no reboot), `amneziawg-go`, `hrneo`, `hrdns`, AWG handshake, `0x3001` rule, table 301 and domain config were all present. **Both FORWARD and MASQUERADE rules were absent** (`iptables -S FORWARD` only displayed default DROP). Re-applying the two rules immediately restored all services. Thus the specific observed failure was firewall-rule loss, likely due to firewall refresh, **not** a broken AWG connection; exact event triggering reset was not captured.
3. Added `/opt/etc/ndm/netfilter.d/014-homeroute-awg.sh` (mode 700), manual execution twice produced exactly one FORWARD and one NAT rule. Existing HR Neo hook `015-hrneo.sh` sends `SIGUSR1` to running HR Neo; it was not replaced.
4. Refined `014` to act selectively on `type=iptables,table=filter` and `type=iptables,table=nat`, allowing no-env manual invocation. Simulated events `type=iptables table=filter sh ...` and `type=iptables table=nat sh ...` both passed; **a real network/firewall regeneration event was not explicitly observed**.
5. Installed `/opt/etc/init.d/S98telegram-awg` (mode 700), idempotent `start`: if `opkgtun0` exists, skip `awg-quick up`; then invoke firewall hook. Manual invocation returned `AWG already running`. `S99hrneo` and `S99hrweb` present. `rc.unslung` sorts executable `S*` files. `/opt/etc/initrc` absent; no startup log found. `ndmc` inside `exec sh` returned `failed to initialize` for `show version`, so it was not used for mutation.
6. **Oct 27 after actual reboot (~19:58 UTC):** Operator confirmed automatically present: `opkgtun0 UP/LOWER_UP`, AWG peer handshake record, `0x3001` policy rule, table 301 default route, exactly one FORWARD and MASQUERADE rule, running `hrneo`, `hrdns`, `amneziawg-go`. At ~20:02 UTC operator explicitly confirmed **all services working** after reboot. This demonstrates one successful reboot recovery, **not** proof of hook re-invocation after future dynamic WAN/firewall resets.

## Deployed persistence scripts (record of validated on-device content)

`/opt/etc/ndm/netfilter.d/014-homeroute-awg.sh`:
```sh
#!/bin/sh
PATH=/opt/sbin:/opt/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
ip link show opkgtun0 >/dev/null 2>&1 || exit 0
case "${type:-iptables}:${table:-all}" in
    iptables:filter|iptables:all)
        iptables -C FORWARD -i br0 -o opkgtun0 -j ACCEPT 2>/dev/null ||
        iptables -I FORWARD 1 -i br0 -o opkgtun0 -j ACCEPT
        ;;
esac
case "${type:-iptables}:${table:-all}" in
    iptables:nat|iptables:all)
        iptables -t nat -C POSTROUTING -o opkgtun0 -j MASQUERADE 2>/dev/null ||
        iptables -t nat -A POSTROUTING -o opkgtun0 -j MASQUERADE
        ;;
esac
```

`/opt/etc/init.d/S98telegram-awg`:
```sh
#!/bin/sh
PATH=/opt/sbin:/opt/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
CFG=/opt/etc/telegram-awg/opkgtun0.conf
HOOK=/opt/etc/ndm/netfilter.d/014-homeroute-awg.sh
start() {
    if ip link show opkgtun0 >/dev/null 2>&1; then
        echo "AWG already running"
    else
        echo "Starting AWG"
        /opt/bin/awg-quick up "$CFG" || return 1
    fi
    if [ -x "$HOOK" ]; then
        sh "$HOOK" || return 1
    fi
}
case "$1" in
    start) start ;;
    *) echo "Usage: $0 start"; exit 1 ;;
esac
```

**Caution:** These are recorded working scripts, not a universal install recipe. A missing AWG interface when `netfilter.d` runs causes an intentional no-op; WAN-ready race / tunnel recovery after runtime crash has not been tested. Do not issue a blind `rc.unslung restart`: this service deliberately implements only `start`.

## Recovery and verification (router shell; read-only unless marked)

Read-only:
```sh
ip link show opkgtun0
awg show opkgtun0 latest-handshakes
ip -4 rule show | grep 0x3001
ip -4 route show table 301
iptables -S FORWARD | grep opkgtun0
iptables -t nat -S POSTROUTING | grep opkgtun0
ps | grep -E '[h]rneo|[h]rdns|[a]mneziawg-go'
```

If **only** firewall rules are missing but AWG and table 301 remain working, restore both idempotently (mutating):
```sh
sh /opt/etc/ndm/netfilter.d/014-homeroute-awg.sh
```
Or use the two `iptables -C ... || ...` lines above if the hook is unavailable. Validate with real LAN client traffic. Do not regenerate keys, replace peers or restart VPS containers.

Local backups made during repair: `/opt/homeroute-backups/firewall-persistence/iptables-before.v4`, `opkgtun0.conf`, and `014-homeroute-awg.before-table-fix.sh`. **Private backup** `opkgtun0.conf` contains a key; keep backups on trusted storage, never commit them.

## Remaining work

- Export sanitized, complete HR Neo/HRDNS settings and rules + secure offline encrypted credentials/keys for disaster recovery. No claim of full clean-install bundle yet.
- Prove firewall hook on a **genuine** post-boot network/firewall recreation event without risking other services; add safe observable logging/test if needed. Test WAN loss/reconnection and AWG crash recovery separately.
- Validate VPS peer persistence across a safe container replacement only after backups and explicit approval.
- Configure Synology NAS selective-routing policies (not yet implemented).
- No changes authorized to Bonuska, NetWeather, qwdtt, VLESS or other VPS containers.
