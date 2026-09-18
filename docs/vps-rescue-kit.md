# Локальный аварийный комплект VPS

Цель — дать владельцу возможность восстановить reference VPS даже если внешний registry или upstream временно изменился.

Артефакты аварийного комплекта **не публикуются в GitHub**. Репозиторий хранит только инструменты и проверяемые контракты.

## Точный Docker image работающего контейнера

`vps/backup-container-image.sh <container> <safe-name>`:

- требует явное подтверждение;
- читает image ID именно работающего контейнера;
- проверяет консервативный запас свободного места;
- выполняет `docker image save` по image ID;
- сохраняет root-only `image.tar`;
- создаёт и проверяет `IMAGE.sha256`;
- проверяет tar-структуру;
- не делает `docker load`;
- не перезапускает контейнер.

Такой архив полезен как локальный rescue source для exact working image, особенно когда upstream Dockerfile зависит от плавающего `latest`.

## AdGuard state

`vps/backup-adguard-state.sh` копирует из работающего контейнера:

- `/opt/adguardhome/conf`;
- `/opt/adguardhome/work`.

Backup root-only, имеет локальный SHA256 manifest и не печатает содержимое конфигурации.

`vps/verify-adguard-backup.sh` выполняет только integrity check.

## Границы

Наличие rescue archive не означает, что public installer должен распространять чужой Docker image. Это локальный recovery artifact владельца VPS.

Live restore image/AdGuard пока не выполнялся и остаётся отдельным validation gate.


## Подтверждённый комплект reference VPS от 2026-09-18

На живом VPS уже созданы и отдельно проверены:

- AWG state backup: 5 файлов, 40 KiB;
- AdGuard state backup: 6 файлов, 35060 KiB;
- точный AWG2 image: 12204 KiB, image ID `sha256:37314a32abb8ce2283e087f69e3ef020dd0eac655350313b860d82059c425d2d`;
- точный AdGuard image: 28828 KiB, image ID `sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0`.

Все операции завершились PASS. Контейнеры не перезапускались, images не загружались обратно, restore не выполнялся.

После backup на root filesystem осталось 13 GiB свободно (54% used).

## Проверка всего комплекта

`vps/verify-rescue-set.sh` принимает четыре пути через локальные переменные:

- `HOMEROUTE_AWG_STATE_BACKUP`;
- `HOMEROUTE_ADGUARD_STATE_BACKUP`;
- `HOMEROUTE_AWG_IMAGE_BACKUP`;
- `HOMEROUTE_ADGUARD_IMAGE_BACKUP`.

Он повторно проверяет integrity каждого artifact и сверяет наличие разных AWG/AdGuard image ID.

Скрипт ничего не восстанавливает и не делает `docker load`.

## Restore status

- AWG state: sandbox restore + forced-failure rollback — PASS; live restore не проверен.
- AdGuard state: sandbox restore + forced-failure rollback — PASS; live restore не проверен.
- Docker images: live export + verify — PASS; image load не проверен.

Поэтому rescue-set уже полезен как локальная страховка, но полный disaster-recovery rehearsal на чистом VPS ещё впереди.
