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

До live capture этого persistence-механизма его точная реализация остаётся незафиксированной.
