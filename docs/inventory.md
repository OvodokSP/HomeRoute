# Inventory эталонной системы

Inventory нужен для того, чтобы требования HomeRoute выводились из наблюдаемого состояния проверенной установки, а не из предположений. Сбор должен быть воспроизводимым, read-only и безопасным для публичного репозитория.

## Правила доказательности

- Значение считается **VERIFIED** только после фактического получения на конкретной системе.
- Отсутствующее значение не угадывается и помечается `NOT VALIDATED`.
- Inventory одной установки не доказывает совместимость других моделей.
- Реальные credentials, private keys, PSK, токены, пароли, proxy secrets, приватные VPN-конфиги и ненужные публичные инфраструктурные адреса не публикуются.

## Router identity

Для reference-router собираются:

- vendor/model — только после подтверждения на устройстве;
- версия KeeneticOS;
- platform/system type;
- CPU architecture;
- CPU model/SoC, если безопасно и однозначно доступен;
- RAM total/free;
- storage total/free;
- filesystem и размер `/opt`;
- расположение Entware.

## Package environment

Фиксируются:

- opkg architecture;
- список установленных opkg packages;
- путь и версия, если она определяется безопасно, для:
  - `awg`;
  - `awg-quick`;
  - `amneziawg-go`;
  - `hrneo`;
  - `nfqws`;
  - `tg-ws-proxy`.

Список пакетов используется для восстановления зависимостей, но сам по себе не означает, что каждый пакет обязателен для HomeRoute.

## HomeRoute runtime

Inventory должен подтверждать без изменения системы:

- наличие router AWG interface `opkgtun0`;
- routing contract `0x3001 -> table 301`;
- наличие HRNeo;
- используемые ipset-наборы;
- наличие persistence hooks;
- присутствие optional `nfqws`;
- присутствие reserve `tg-ws-proxy`.

Фактическое содержимое VPN-конфигов не читается и не публикуется.

## VPS environment

Для VPS предусматривается отдельный обезличенный inventory:

- OS и kernel;
- vCPU/CPU architecture;
- RAM;
- storage;
- Docker version;
- состояние AWG2;
- состояние AdGuard Home;
- обязательные runtime-зависимости.

Реальный hostname, SSH credentials, публичный адрес VPS, ключи и peer secrets не входят в публичный inventory, если они не нужны для доказательства совместимости.

## Формат результата

Read-only preflight может выдавать как человекочитаемый отчёт, так и безопасные строки:

```text
HOMEROUTE_INVENTORY key=value
```

Такие строки предназначены для последующего разбора без публикации секретов. Пример обезличенного результата находится в [`../inventory/router-reference.example.txt`](../inventory/router-reference.example.txt).

## Acceptance criteria Phase 1

Phase 1 не считается завершённой только из-за появления этой схемы. Для числовых аппаратных требований необходим реальный inventory reference-router, а для утверждения совместимости модели — отдельное воспроизводимое подтверждение на этой модели.
