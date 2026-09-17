# Router installer design

Статус: **PRE-ALPHA / repository design only**. Документ не разрешает применение изменений на реальном роутере до завершения reference inventory и отдельной проверки apply-mode.

## Цель

Router installer должен быть воспроизводимым и идемпотентным: повторный запуск на уже приведённой к desired state системе не должен создавать дубли rules/hooks/config blocks или менять рабочую систему без необходимости.

## Режимы

### `plan`

Read-only режим. Он:

- проверяет доступность ожидаемых компонентов;
- показывает Golden State invariants;
- перечисляет будущие этапы установки;
- явно помечает неподтверждённые зависимости как `BLOCKED`/`NOT VALIDATED`;
- ничего не устанавливает и не меняет.

### `apply`

До отдельного architecture decision и успешного clean-device test режим обязан завершаться отказом до любых изменений.

## Pipeline

Будущий apply-mode должен состоять из отдельных стадий:

1. **Preflight** — architecture, storage, Entware/opkg, component/package compatibility.
2. **Plan** — desired state против observed state, без изменений.
3. **Backup** — сохранить только необходимые существующие конфиги/hooks и metadata для rollback.
4. **Apply** — минимальные изменения, только после всех gates.
5. **Verify** — doctor + routing contract + persistence checks.
6. **Commit state** — записать локальный deployment manifest без secrets.
7. **Rollback** — вернуть backup и удалить только объекты, созданные текущей транзакцией.

## Идемпотентность

Каждая изменяющая операция должна перед применением сравнить desired и current state.

Требования:

- не добавлять повторно существующий `ip rule`;
- не создавать дубли firewall/NAT rules;
- не дублировать HRNeo entries/ipsets;
- не перезаписывать совпадающий конфиг;
- не создавать второй peer для того же AllowedIPs;
- использовать atomic replacement для файлов, где это возможно;
- повторный `apply` после успешной установки должен давать `NO CHANGE` для уже совпадающих объектов.

## Golden State invariants

Installer не имеет права молча менять:

- AWG baseline: 2.x;
- router AWG interface: `opkgtun0`;
- mark: `0x3001`;
- routing table: `301`;
- HRNeo как selective-routing orchestrator;
- `nfqws` как независимый optional layer;
- `tg-ws-proxy` как reserve path.

Legacy `Wireguard0`/`nwg0`, table `4098`, mark `0xffffaab`, `WG443_TEST` и duplicate peers не являются допустимой desired state.

## Backup contract

Перед первым изменением конкретного ресурса installer должен сохранить:

- исходный файл или доказательство его отсутствия;
- mode/owner metadata, если применимо;
- manifest созданных/изменённых объектов;
- timestamp/transaction id.

Backup не хранится в Git и не должен печатать secret contents в stdout.

## Verify contract

Apply считается успешным только если после изменений проходят:

- `doctor-router.sh` без FAIL по обязательным Golden State checks;
- persistence checks;
- отсутствие legacy state;
- отдельная функциональная проверка, определённая clean-device protocol.

Если verify не проходит, installer не имеет права объявлять success.

## Rollback contract

Rollback должен быть ограничен текущей транзакцией. Он не должен удалять неизвестные пользователю правила или файлы только потому, что они не входят в HomeRoute desired state.

Порядок rollback проектируется в обратном порядке apply и должен быть безопасен при повторном запуске.

## Блокирующие данные

До фактического reference inventory остаются `NOT VALIDATED`:

- точные обязательные opkg packages;
- package provider для AWG/HRNeo и вспомогательных binaries;
- минимальный свободный storage/RAM;
- подтверждённые target paths для автоматически создаваемых файлов на чистом устройстве;
- безопасный способ первой установки AWG client на всех поддерживаемых платформах.

Эти значения нельзя придумывать в apply-mode.
