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
- безопасный read-only capture image/restart/network-mode/count/privileged metadata без чтения Env/IP/host paths;
- sanitized container-shape: сети, container-side mount destinations, exposed/container ports и отсутствие host-published AdGuard ports;
- параметризуемая модель будущего provisioning, где image pins, host paths, AWG host UDP port и AWG state source задаются локально и не попадают в Git;
- обязательный backup `/opt/amnezia/awg` перед заменой AWG2-контейнера;
- закреплённый upstream Amnezia source recipe с совпадающей формой контейнера;
- CI-tested backup/verify tooling для `/opt/amnezia/awg` и `/opt/amnezia/start.sh`, без вывода содержимого секретных файлов;
- live-verified export точных AWG2/AdGuard image ID в локальные root-only rescue archives с tar/SHA256 verification;
- live-verified backup/verify AdGuard `conf/work` без вывода содержимого конфигурации;
- sandbox-tested AdGuard restore + forced-failure rollback;
- единый read-only verifier четырёх локальных rescue-артефактов;
- закреплённый upstream contract сети `amnezia-dns-net`;
- динамическое разрешение AdGuard target через Docker без публикации внутреннего IP;
- CI-tested renderer TCP/UDP 53 DNAT для AWG2;
- live-confirmed active+enabled `awg-adguard-dns.timer`, service identity, helper path и helper SHA256;
- live-confirmed monotonic timer schedule: `OnBootSec=30s`, `OnUnitActiveSec=60s`, `Persistent=yes`, accuracy `10s`, randomized delay `0`;
- design-only `config/vps-dns-persistence.json` и non-mutating renderer `vps/render-dns-persistence-plan.sh`, фиксирующие target resolution, TCP/UDP DNAT 53 и safety boundary без выполнения команд;
- calendar/monotonic-aware read-only timer preflight;
- CI-tested sanitized semantic analyzer DNS helper schema 2 без публикации содержимого;
- read-only live-restore readiness gate, который повторно проверяет rescue-set и exact current/rescue image identity до любого controlled restore;
- isolated stopped-container restore rehearsal: временные контейнеры с `--network none`, без start/restart рабочих сервисов, с backup round-trip и повторной SHA-256 verification.

## Что ещё блокирует live-apply

- immutable image/base-image pin для новой установки;
- детерминированное создание Docker network/container state и schema-2 live semantic fingerprint текущего DNS persistence helper;
- безопасная генерация и доставка credentials;
- транзакционный учёт firewall/DNS;
- успешный live restore-readiness preflight и затем отдельная controlled live restore validation;
- первое чистое воспроизведение.

Sandbox-успех не считается доказательством готовности production-установщика.
