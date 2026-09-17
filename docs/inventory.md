# Inventory эталонной системы

Inventory нужен для того, чтобы требования HomeRoute выводились из наблюдаемого состояния проверенной установки, а не из предположений. Сбор должен быть воспроизводимым, read-only и безопасным для публичного репозитория.

## Правила доказательности

- Значение считается **VERIFIED** только после фактического получения на конкретной системе.
- Отсутствующее значение не угадывается и помечается `NOT VALIDATED`.
- Inventory одной установки не доказывает совместимость других моделей.
- Реальные credentials, private keys, PSK, токены, пароли, proxy secrets, приватные VPN-конфиги и ненужные публичные инфраструктурные адреса не публикуются.
- Формальная трактовка `VERIFIED / OBSERVED / NOT VALIDATED / DEPRECATED` описана в [`inventory-evidence.md`](inventory-evidence.md).

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
- путь и версия, если она определяется безопасно, для `awg`, `awg-quick`, `amneziawg-go`, `hrneo`, `nfqws` и `tg-ws-proxy`.

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

Для VPS собираются:

- OS и kernel;
- vCPU/CPU architecture;
- RAM;
- root storage;
- Docker version;
- состояние AWG2 container;
- состояние AdGuard Home;
- наличие AWG interface внутри AWG2.

Реальный hostname, SSH credentials, публичный адрес VPS, ключи и peer secrets в публичный inventory не входят.

## Инструменты сбора

- Router: [`../router/preflight-router.sh`](../router/preflight-router.sh)
- VPS: [`../vps/preflight-vps.sh`](../vps/preflight-vps.sh)
- Последовательная процедура: [`evening-capture.md`](evening-capture.md)
- Схема безопасных полей: [`../inventory/schema-v1.md`](../inventory/schema-v1.md)
- Нормализатор allowlist: [`../scripts/inventory/extract_inventory.py`](../scripts/inventory/extract_inventory.py)
- Сравнение нормализованных снимков: [`../scripts/inventory/compare_inventory.py`](../scripts/inventory/compare_inventory.py)

Оба preflight выдают человекочитаемый отчёт и строки:

```text
HOMEROUTE_INVENTORY key=value
```

Примеры без данных реальной инфраструктуры:

- [`../inventory/router-reference.example.txt`](../inventory/router-reference.example.txt)
- [`../inventory/vps-reference.example.txt`](../inventory/vps-reference.example.txt)

Нормализатор публикует только поля, явно разрешённые schema v1. Неизвестный ключ приводит к ошибке, а не переносится автоматически в JSON.

После нормализации два снимка одного типа можно сравнить без чтения исходного полного лога:

```sh
python3 scripts/inventory/compare_inventory.py before.json after.json --strict-type
```

## Acceptance criteria Phase 1

Подготовка схемы, примеров и capture tooling не создаёт числовых аппаратных требований сама по себе. Для этого необходим реальный inventory reference-router и VPS. Для утверждения совместимости конкретной модели требуется отдельное воспроизводимое подтверждение на этой модели.
