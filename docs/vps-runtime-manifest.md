# VPS runtime manifest

Этот документ отделяет **подтверждённое состояние эталонного VPS** от параметров, которые ещё нужно снять перед автоматическим созданием контейнеров.

## Уже подтверждено

Из reference inventory и live doctor от 2026-09-17 подтверждены:

- Ubuntu 26.04;
- архитектура x86_64;
- Docker 29.1.3;
- контейнер AWG2 с именем `amnezia-awg2`;
- контейнер AdGuard Home с именем `adguard-home`;
- интерфейс `awg0` внутри AWG2;
- DNS redirect TCP/UDP 53 внутри AWG2;
- отсутствие host-правила `WG443_TEST`.

Эти значения находятся в `config/vps-runtime-manifest.json`.

## Что подтверждено дополнительным capture 2026-09-18

Для работающего reference VPS теперь также зафиксированы:

- AWG2 image reference и image ID;
- AWG2 restart policy, network mode, число подключённых сетей и mounts, privileged flag;
- те же runtime-поля для AdGuard Home.

Эти значения описывают **наблюдаемую работающую конфигурацию**, но ещё не являются полным рецептом создания контейнеров с нуля.

Особенно важно: `adguard/adguardhome:latest` — плавающий tag. Сам факт, что текущий контейнер работает с этим tag, не делает `latest` детерминированным источником для будущего installer.

## Что всё ещё не подтверждено для полного воспроизведения

Без отдельного безопасного решения HomeRoute пока не фиксирует публично:

- значения container environment;
- IP-адреса;
- published port mappings;
- mount source paths;
- credentials и приватные конфиги;
- полный способ первоначального получения AWG2 image;
- безопасный способ переноса/generation secrets на чистый VPS.

Поэтому live VPS apply остаётся заблокированным даже после заполнения runtime manifest.

## Безопасный capture

`vps/preflight-runtime.sh` читает только не-секретные Docker metadata.

Он **не читает и не выводит**:

- значения переменных окружения контейнера;
- IP-адреса;
- published ports;
- source paths volumes/mounts;
- labels;
- команды запуска;
- содержимое конфигурационных файлов;
- ключи, PSK, пароли или токены.

Собираются только имя контейнера, status, image reference/id, restart policy, network mode, количество network attachments, количество mounts и privileged flag.

Эти сведения достаточны для следующего шага проектирования, но сами по себе ещё не позволяют автоматически воспроизвести volumes, ports и credentials.
