# Безопасный снимок формы контейнеров VPS

`vps/preflight-container-shape.sh` дополняет обычный runtime capture структурой, которая нужна для проектирования воспроизводимой установки.

Он читает только:

- repository tags/digests образа, если Docker их знает;
- имена подключённых Docker-сетей;
- тип и **destination** mount без host source path;
- container port/protocol и только число bindings, без host IP/port;
- exposed ports;
- AutoRemove;
- ReadonlyRootfs.

Он не читает и не публикует:

- Env;
- IP-адреса;
- host port numbers;
- host mount source paths;
- labels;
- container command/entrypoint;
- содержимое конфигов;
- ключи, PSK, пароли и токены.

Этот capture нужен для построения параметризуемого VPS installer. Даже после него secrets, локальные пути хранения и внешние порты должны задаваться локально пользователем или генерироваться установщиком, а не храниться в Git.


## Подтверждённый reference capture 2026-09-18

AWG2:

- container name: `amnezia-awg2`;
- Docker networks: `bridge` и `amnezia-dns-net`;
- bind destination: `/lib/modules`;
- container UDP port: `35404/udp`;
- privileged: `true`;
- restart policy зафиксирована отдельно как `always`.

AdGuard Home:

- container name: `adguard-home`;
- Docker network: `amnezia-dns-net`;
- bind destinations: `/opt/adguardhome/conf`, `/opt/adguardhome/work`;
- host port bindings отсутствуют;
- privileged: `false`;
- restart policy зафиксирована отдельно как `unless-stopped`.

Observed tags `amnezia-awg2:latest` и `adguard/adguardhome:latest` не считаются допустимыми version pins для clean install. Они описывают текущее состояние, а не гарантированно воспроизводимый источник образа.

## Параметризуемая модель

`config/vps-provisioning-template.json` фиксирует только безопасные постоянные части схемы. Следующие значения обязаны приходить локально при новой установке и не хранятся в Git:

- pinned AWG image;
- host source для `/lib/modules`;
- внешний UDP port AWG;
- источник или сгенерированное состояние AWG;
- pinned AdGuard image;
- host paths для AdGuard conf/work.

`vps/render-container-plan.sh` проверяет наличие этих параметров, но намеренно не печатает их значения.
