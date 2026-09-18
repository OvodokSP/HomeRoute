# Live DNS persistence evidence — 2026-09-18

Проверка выполнена на reference VPS read-only инструментами из HomeRoute. Содержимое systemd unit и helper не публиковалось.

## Проверено

Команда `vps/preflight-dns-persistence.sh` schema 2 подтвердила:

- timer: `awg-adguard-dns.timer`;
- timer state: `active`;
- timer enablement: `enabled`;
- service: `awg-adguard-dns.service`;
- service state в момент capture: `inactive`;
- schedule kind: `monotonic`;
- monotonic schedule содержит `OnUnitActiveUSec=1min` и `OnBootUSec=30s`;
- next monotonic elapse: SET;
- last trigger: SET;
- `Persistent=yes`;
- accuracy: `10s`;
- randomized delay: `0`;
- ExecStart path: `/usr/local/sbin/awg-adguard-dns.sh`;
- helper SHA256: `96766c14d26edb63877aaf8f2bff5de577e42683b99b86b1b2b7bc382424c2b0`.

`service_active=inactive` сам по себе не является failure для timer-triggered service между запусками. Тип service этой проверкой отдельно не фиксировался.

## Helper semantic fingerprint

`vps/analyze-dns-helper.sh` schema 1 подтвердил:

- SHA256 совпадает с ранее captured reference SHA;
- shell syntax valid;
- присутствуют Docker и `docker inspect`;
- присутствует reference AWG container name `amnezia-awg2`;
- присутствует `docker exec`;
- присутствуют iptables, nat, PREROUTING, dport 53, DNAT и `--to-destination`;
- присутствует idempotency check `iptables -C`;
- rule insertion выполняется через `iptables -I`;
- не обнаружены broad flush `iptables -F`, `docker restart`, `docker rm`, `reboot` или `rm`;
- helper содержит 26 строк.

## Что fingerprint НЕ доказал

В helper не были найдены literal patterns:

- `adguard-home`;
- `amnezia-dns-net`;
- literal `-p tcp`;
- literal `-p udp`.

Это не означает, что helper не использует AdGuard, нужную Docker network или оба протокола: значения могут передаваться через переменные/циклы. Но текущий analyzer schema 1 этого не различает.

Поэтому claim «live helper полностью соответствует desired dynamic AdGuard TCP/UDP DNAT implementation» остаётся **NOT VALIDATED** до повторного sanitized анализа с поддержкой variable/loop patterns.

## Safety boundary

Во время capture:

- unit/script contents не выводились;
- runtime AdGuard IP не выводился;
- secrets, PSK, private keys, passwords и tokens не читались и не публиковались;
- iptables не изменялся;
- container restart/restore/image load не выполнялись.
