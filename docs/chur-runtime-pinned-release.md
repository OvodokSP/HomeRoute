# Закреплённый runtime AmneziaWG от Chur

Для HomeRoute обязательным компонентом остаётся `chur-amneziawg`, а не веб-менеджер `chur-keenetic`.

Upstream Chur версии `1.0.0` публикует отдельный версионный каталог `1_0_0` для:

- `aarch64-3.10`;
- `mips-3.4`;
- `mipsel-3.4`.

## Состав runtime

Meta-package `chur-amneziawg 1.0.0-1` требует:

- `chur-amneziawg-go f4f4c99-1`;
- `chur-amneziawg-tools 1.0.20260223-2`.

В исходниках Chur закреплены upstream-источники:

- AmneziaWG Go commit `f4f4c999267437c3eb909e8d0e5278fb4596d9a7`;
- AmneziaWG tools commit `5d6179a6d0842e98dfb349c28cf1bd8e4b9d1079`;
- source tar SHA-256 tools: `e79a3c7f2def315d052a3648b49058a268c4b63cdb5e082b696d2a4a0a2367f0`.

## Почему `latest` больше не нужен

В `ward-sentry/ward-sentry.github.io` каталог `chur-keenetic/1_0_0` содержит `Packages` и три runtime `.ipk` для каждой архитектуры.

Каждая запись `Packages` содержит SHA-256 конкретного `.ipk`.

HomeRoute фиксирует:

- source commit Chur;
- Pages commit;
- версионный каталог `1_0_0`;
- имя и размер каждого `.ipk`;
- SHA-256;
- Git blob SHA-1.

Поэтому install strategy может использовать URL с **Pages repository commit SHA**, а не `latest`.

## Что не устанавливается автоматически

`chur-keenetic` — удобный веб-менеджер, но он не является core install root HomeRoute и по умолчанию не устанавливается.

## Live gate

`router/chur-runtime-artifacts.sh` уже умеет:

- показать точный набор из трёх runtime-пакетов для архитектуры;
- проверить локально скачанный набор по размеру, SHA-256 и Git blob identity.

Скачивание и `opkg install` в live-режиме пока намеренно не выполняются. Перед этим нужно проверить транзакционный backup/rollback состояния пакетов и конфигурации на эталонном Keenetic.
