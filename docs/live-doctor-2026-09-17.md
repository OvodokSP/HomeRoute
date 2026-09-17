# Live doctor validation — 2026-09-17

Цель — зафиксировать безопасные результаты read-only проверки Golden State без публикации raw SSH/PuTTY логов, адресов, credentials, keys/PSK или VPN-конфигураций.

## Router

Первый live-run `router/doctor-router.sh` дал:

```text
HOMEROUTE_DOCTOR schema=1 type=router pass=24 warn=0 fail=1 result=FAIL
```

Единственный FAIL относился к обнаружению `FORWARD br0 -> opkgtun0`.

Дополнительная read-only диагностика сразу после этого подтвердила, что рабочее правило фактически присутствует:

```text
-A FORWARD -s 192.168.1.0/24 -i br0 -o opkgtun0 -j ACCEPT
```

Также одновременно подтверждены:

- активный Telegram conntrack через AWG client address `10.8.1.11`;
- connmark `12289` (`0x3001`);
- свежий AWG handshake;
- рост AWG transfer counters.

Следовательно, FAIL был ложным отрицанием doctor-скрипта, а не отказом рабочего маршрута. Причина — слишком хрупкий whitespace-sensitive matcher iptables rule. Matcher заменён на разбор токенов `-i`/`-o` через `awk` и получил отдельный CI self-test на фактическом формате правила Golden State.

Остальные обязательные router checks прошли live-run, включая AWG/HRNeo/ipset, table 301, MASQUERADE, persistence hooks и отсутствие legacy `nwg0`, table 4098, mark `0xffffaab` и HydraRoute ipsets.

## VPS

Live-run `vps/doctor-vps.sh` завершился полностью успешно:

```text
HOMEROUTE_DOCTOR schema=1 type=vps pass=10 warn=0 fail=0 result=PASS
```

Подтверждены:

- Docker;
- running AWG2 container;
- `awg0` внутри AWG2;
- единственный ожидаемый router peer AllowedIPs;
- running AdGuard Home;
- DNS redirect TCP/UDP 53 внутри AWG2;
- отсутствие host `WG443_TEST`;
- отсутствие legacy Keenetic WireGuard peer в старом WG container.

## Итог

Golden State runtime подтверждён live evidence на обеих сторонах. Router doctor потребовал только исправления собственного matcher; фактический FORWARD path во время проверки был исправен.

Это подтверждает reference state, но не заменяет clean-device reproduction и не означает готовность installer `apply`.
