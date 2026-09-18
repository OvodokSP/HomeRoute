# Установщик роутера: техническое устройство

Статус: **PRE-ALPHA**. Режим просмотра плана и sandbox-транзакция реализованы. Изменения на реальном роутере по-прежнему заблокированы.

## Режимы

### `plan`

Только чтение. Показывает текущие инварианты HomeRoute, обязательные пакеты и незакрытые проверки.

### `sandbox-apply`

Только для тестов репозитория.

Требует отдельный каталог `HOMEROUTE_SANDBOX_ROOT` с маркером `.homeroute-sandbox`. Установщик создаёт в нём фиктивное управляемое состояние, выполняет проверку и умеет откатывать изменения.

Этот режим не устанавливает пакеты, не меняет firewall, маршруты, VPN или реальные конфиги.

### `apply`

На реальном роутере **заблокирован**.

## Уже подтверждено

- обязательные install roots: `chur-amneziawg` и `hrneo`;
- опорные ресурсы роутера;
- интерфейс `opkgtun0`;
- метка `0x3001`;
- таблица `301`;
- роль HydraRoute Neo;
- sandbox backup/apply/verify/rollback;
- идемпотентность файлового слоя;
- явные Chur feed-адреса для `aarch64-3.10`, `mips-3.4`, `mipsel-3.4`;
- HRNeo `3.18.3-1` как pinned `.ipk` для всех трёх архитектур: release commit + path + byte size + Git blob SHA;
- read-only helper для выбора pinned HRNeo artifact и проверки локального файла без установки;
- HRNeo rescue-set capture/verifier: package-owned files + checksums/symlinks + opkg metadata + exact pinned `.ipk`, без package/service/network changes.

## Что ещё блокирует live-apply

- live capture/verify глобального `/opt/lib/opkg/status` в тот же rescue set перед package transaction;
- live-safe изменение opkg feed-файлов для Chur;
- установка/удаление pinned HRNeo/Chur package roots с транзакционным учётом;
- резервное копирование реальных HomeRoute-конфигов и hooks;
- откат сетевых объектов;
- HL-404: live backup/restore validation;
- HL-502: первое чистое воспроизведение.

## Требование идемпотентности

Повторный успешный запуск не должен:

- добавлять второй `ip rule`;
- создавать дубли firewall/NAT;
- дублировать hooks;
- перезаписывать совпадающий файл;
- создавать повторный peer;
- переустанавливать уже совпадающее состояние без причины.

Для совпадающего файлового состояния sandbox уже требует `NO CHANGE`.

## Controlled HRNeo same-version reinstall validation

Before clean-device automation, the reference router uses a dedicated validator for the pinned local `hrneo 3.18.3-1` IPK. It requires the full rescue set (package files, `hrneo.*` opkg info, side effects and global opkg status) to verify and requires the current live state to still match that rescue snapshot immediately before the package transaction.

The validator invokes only the exact local pinned artifact with `opkg install --force-reinstall --nodeps`. It then requires the installed package set, HRNeo managed files, opkg info, `neo` symlink, `rc.unslung` side effect and router doctor to remain valid. If any post-transaction check fails, it restores package files, `hrneo.*`, the saved global opkg status, `rc.unslung` and `neo`, restarts HRNeo and verifies the router doctor again.

The live run remains pending until the global opkg status rescue is captured on the reference router.
