# Установщик VPS: техническое устройство

Статус: **PRE-ALPHA**. Режим просмотра плана и sandbox-транзакция реализованы. Изменения на реальном VPS по-прежнему заблокированы.

## Режимы

### `plan`

Только чтение. Показывает ожидаемые компоненты и состояние Docker/AWG2/AdGuard, если они уже существуют.

### `sandbox-apply`

Только для тестов репозитория.

Работает исключительно внутри каталога `HOMEROUTE_SANDBOX_ROOT` с маркером `.homeroute-sandbox`. Проверяет файловую транзакцию, идемпотентность и откат.

Контейнеры Docker, firewall, DNS и VPN при этом не меняются.

### `apply`

На реальном VPS **заблокирован**.

## Уже подтверждено

- опорные ресурсы VPS;
- Docker/AWG2/AdGuard на reference-инсталляции;
- интерфейс `awg0`;
- DNS redirect TCP/UDP 53 в AWG2;
- отсутствие `WG443_TEST`;
- sandbox backup/apply/verify/rollback;
- идемпотентность файлового слоя;
- частичный VPS runtime-manifest с подтверждёнными reference-параметрами;
- безопасный read-only capture image/restart/network-mode/count/privileged metadata без чтения Env/IP/port bindings/mount source paths.

## Что ещё блокирует live-apply

- точные image/version rules для новой установки;
- детерминированное создание Docker network/container state;
- безопасная генерация и доставка credentials;
- транзакционный учёт firewall/DNS;
- live backup/restore validation;
- первое чистое воспроизведение.

Sandbox-успех не считается доказательством готовности production-установщика.
