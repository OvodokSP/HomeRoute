# VPS installer design

Статус: **PRE-ALPHA / repository design only**. Реальный apply остаётся заблокирован до reference inventory, backup/verify/rollback реализации и clean-device validation.

## Цель

VPS installer должен воспроизводимо и идемпотентно приводить отдельный пользовательский VPS к HomeRoute desired state без скрытого изменения существующей инфраструктуры.

## Режимы

### `plan`

Read-only режим:

- проверяет наличие Docker и ожидаемых containers;
- показывает Golden State invariants;
- перечисляет будущие стадии транзакции;
- не создаёт, не удаляет и не перезапускает containers;
- не меняет iptables, DNS или VPN.

### `apply`

До отдельной проверки обязан завершаться отказом до любых изменений.

## Pipeline

1. **Preflight** — OS/kernel/CPU/RAM/storage/Docker inventory.
2. **Plan** — desired state против observed state.
3. **Backup** — сохранить необходимые container/config/firewall metadata и доказательство отсутствия объектов.
4. **Apply** — минимальные идемпотентные изменения.
5. **Verify** — `doctor-vps.sh`, AWG2, AdGuard, DNS redirect, legacy checks.
6. **Commit state** — локальный manifest без credentials.
7. **Rollback** — вернуть только объекты текущей транзакции.

## Desired-state invariants

- отдельный пользовательский VPS;
- AWG baseline: AmneziaWG 2.x;
- AWG2 container доступен и содержит ожидаемый AWG interface `awg0`;
- AdGuard Home используется как DNS-сервис reference implementation;
- DNS redirect TCP/UDP 53 проверяется внутри AWG2 container;
- host legacy `WG443_TEST` отсутствует;
- old Keenetic ordinary-WireGuard peer не является частью desired state;
- duplicate AllowedIPs для router peer недопустимы.

## Идемпотентность

Будущий apply обязан:

- не создавать второй container при уже совпадающем существующем;
- не добавлять повторно NAT/DNS rules;
- не добавлять duplicate peer/AllowedIPs;
- не перезаписывать совпадающий config;
- перед заменой несовпадающего объекта создавать backup/rollback record;
- повторный apply после успешной установки возвращать `NO CHANGE` для совпадающих объектов.

## Backup / rollback

Backup должен содержать только необходимое для восстановления текущей транзакции и не попадать в Git. Stdout не должен содержать private keys, PSK, tokens, passwords или содержимое VPN config.

Rollback выполняется в обратном порядке apply и не удаляет неизвестные сторонние containers/firewall rules.

## Verify

Success допустим только после:

- `doctor-vps.sh` без обязательных FAIL;
- AWG2 runtime проверки;
- AdGuard runtime проверки;
- DNS redirect TCP/UDP 53;
- отсутствия `WG443_TEST`;
- отсутствия legacy router peer/duplicate AllowedIPs;
- отдельной функциональной проверки clean-device protocol.

## NOT VALIDATED до reference inventory

- минимальные VPS CPU/RAM/storage thresholds;
- точные Docker/image requirements для новой чистой установки;
- способ безопасной генерации и доставки client credentials;
- автоматический provisioning firewall/DNS/container networking;
- apply/rollback implementation на чистом VPS.
