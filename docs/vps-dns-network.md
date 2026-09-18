# Сеть Amnezia и DNS HomeRoute

HomeRoute использует сеть Amnezia, но DNS-слой отличается от штатного upstream.

## Что подтверждено upstream Amnezia

В commit `de93650a90739b87bb47a632872ea9d0adc9412f` официальный `prepare_host.sh` создаёт:

- сеть `amnezia-dns-net`;
- driver `bridge`;
- subnet `172.29.172.0/24`;
- host bridge name `amn0`.

Официальный Amnezia DNS-контейнер в том же commit использует фиксированный адрес `172.29.172.254`.

Эти факты закреплены в `config/vps-network-upstream.json`.

## Чем отличается HomeRoute

Reference HomeRoute использует **AdGuard Home**, а не штатный Amnezia DNS-контейнер.

Поэтому HomeRoute не имеет права назначать AdGuard адрес `.254` только потому, что так делает upstream DNS.

Вместо этого target для DNAT должен разрешаться через Docker network inspection в момент применения:

1. убедиться, что AWG2 подключён к `amnezia-dns-net`;
2. получить текущий IPv4 AdGuard на этой сети;
3. не публиковать этот IP в логах;
4. построить TCP/UDP DNAT 53 внутри AWG2;
5. проверить правила doctor'ом.

`vps/resolve-adguard-dns-target.sh` реализует только read-only пункты 1–3.

`vps/render-awg-dns-rules.sh` рендерит ожидаемые правила из явно переданного адреса, но сам iptables не меняет.

## Persistence

На reference VPS ранее подтверждён активный `awg-adguard-dns.timer`.

`vps/preflight-dns-persistence.sh` собирает только:

- active/enabled state timer;
- active state service;
- schedule metadata;
- путь `ExecStart`;
- SHA256 исполняемого файла.

Содержимое unit или скрипта не печатается.

Live preflight 2026-09-18 подтвердил:

- timer: `awg-adguard-dns.timer`;
- state: active + enabled;
- service: `awg-adguard-dns.service`;
- ExecStart: `/usr/local/sbin/awg-adguard-dns.sh`;
- helper SHA256: `96766c14d26edb63877aaf8f2bff5de577e42683b99b86b1b2b7bc382424c2b0`.

Повторный live preflight schema 2 подтвердил, что timer **monotonic**: присутствуют `OnUnitActiveUSec=1min` и `OnBootUSec=30s`, next monotonic elapse и last trigger установлены, `Persistent=yes`, accuracy `10s`, randomized delay `0`. Next realtime elapse отсутствует, что соответствует monotonic schedule.

Первый live semantic fingerprint helper подтвердил exact SHA, valid shell syntax, Docker inspect + docker exec и DNAT 53 через iptables/NAT/PREROUTING с `-C` и `-I`; broad flush/restart/remove/reboot/rm не обнаружены. Literal `adguard-home`, `amnezia-dns-net`, `-p tcp` и `-p udp` не обнаружены, поэтому полное соответствие desired dynamic TCP/UDP implementation пока не повышается до VERIFIED: значения могут быть переданы через переменные/циклы. Schema 2 analyzer добавляет безопасные признаки такого indirection без вывода содержимого helper.

Полный sanitized capture зафиксирован в `docs/live-dns-persistence-2026-09-18.md`.

## Desired-state contract

Рабочий reference timer теперь используется как исходная модель для будущего воспроизведения:

- monotonic timer;
- запуск после boot через 30 секунд;
- повторный запуск через 60 секунд после предыдущей активации;
- `Persistent=yes`;
- accuracy 10 секунд;
- без randomized delay.

Сам helper при этом не копируется из live VPS в репозиторий. Его целевая семантика описана отдельно в `config/vps-dns-persistence.json` и выводится read-only скриптом `vps/render-dns-persistence-plan.sh`.

Desired helper должен:

1. разрешать IPv4 AdGuard динамически через Docker на `amnezia-dns-net`;
2. не печатать runtime IP;
3. проверять TCP и UDP DNAT 53 внутри `amnezia-awg2`;
4. перед вставкой правила выполнять точную проверку существования;
5. не использовать broad flush, container restart/remove или reboot как часть обычного reconciliation.

Это пока **DESIGN_ONLY**. Live apply systemd/iptables по-прежнему запрещён.
