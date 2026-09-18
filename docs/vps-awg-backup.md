# Резервная копия состояния AWG на VPS

Перед заменой, удалением или пересозданием `amnezia-awg2` HomeRoute обязан сохранить внутреннее AWG-состояние.

## Почему это обязательно

Reference-контейнер имеет bind только в `/lib/modules`. Каталог `/opt/amnezia/awg` находится внутри writable layer контейнера.

Официальные скрипты Amnezia хранят там:

- `awg0.conf`;
- приватный ключ сервера;
- публичный ключ сервера;
- PSK;
- client-management state (`clientsTable`).

Отдельно `/opt/amnezia/start.sh` содержит startup logic контейнера.

Удаление контейнера без backup этих объектов может привести к потере рабочего VPN-state.

## Скрипт backup

`vps/backup-awg-state.sh`:

1. требует явный `HOMEROUTE_AWG_BACKUP_ACK=YES`;
2. проверяет работающий AWG-контейнер;
3. создаёт root-only каталог `/root/homeroute-backups/awg-state-<UTC>`;
4. копирует `/opt/amnezia/awg` и `/opt/amnezia/start.sh`;
5. выставляет права 700/600;
6. создаёт локальный `MANIFEST.sha256`;
7. сразу проверяет checksum manifest;
8. печатает только число файлов, размер и путь backup.

Содержимое конфигов, ключей, PSK и `clientsTable` в stdout не выводится.

## Проверка

`vps/verify-awg-backup.sh <backup-directory>` проверяет структуру и SHA256, но ничего не восстанавливает.

## Что пока запрещено

Автоматический restore пока не реализован. Он потребует контролируемого изменения live-контейнера и отдельной проверки работоспособности после восстановления.

Успешный backup не равен успешному restore и сам по себе не закрывает HL-404.
