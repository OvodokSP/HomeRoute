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
