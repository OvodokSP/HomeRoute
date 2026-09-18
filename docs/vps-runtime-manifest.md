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

## Что пока не подтверждено для воспроизводимого создания

До отдельного безопасного capture HomeRoute не утверждает:

- точную ссылку на Docker image AWG2;
- точный image ID;
- restart policy;
- network mode;
- число network attachments;
- число mounts;
- privileged mode;
- те же параметры для AdGuard Home.

Пока любое из этих полей равно `null`, live VPS apply остаётся заблокированным.

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
