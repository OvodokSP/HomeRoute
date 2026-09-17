# Router plan contract

Статус: **PRE-ALPHA / read-only**. Контракт описывает только вывод `router/install.sh plan`; он не разрешает apply на реальном устройстве.

## Цель

Человекочитаемый plan удобен для диагностики, но последующая автоматизация должна уметь проверять его без разбора произвольного текста. Поэтому `plan` дополнительно выдаёт строки:

```text
HOMEROUTE_PLAN key=value
```

## Schema v1

Обязательные поля:

| Key | Значение v1 | Смысл |
|---|---|---|
| `schema` | `1` | версия plan contract |
| `target` | `router` | целевой тип системы |
| `mode` | `plan` | read-only режим |
| `apply_available` | `false` | apply намеренно заблокирован |
| `awg_baseline` | `AmneziaWG_2.x` | текущий Golden State baseline |
| `awg_interface` | `opkgtun0` | выделенный router AWG interface |
| `routing_mark` | `0x3001` | подтверждённый routing mark |
| `routing_table` | `301` | подтверждённая routing table |
| `orchestrator` | `HRNeo` | selective-routing orchestrator |
| `dependency_state` | `NOT_VALIDATED` | exact package baseline ещё не утверждён |
| `resource_thresholds` | `NOT_VALIDATED` | числовые hardware thresholds ещё не утверждены |
| `clean_device_validation` | `NOT_VALIDATED` | clean reproduction ещё не завершён |

## Инварианты

До отдельного architecture decision plan contract не должен молча менять:

- AWG baseline;
- `opkgtun0`;
- mark `0x3001`;
- table `301`;
- роль HRNeo;
- статус apply как заблокированного.

Изменение любого из этих полей требует синхронного обновления `CURRENT_STATE.md`, architecture/decision log и migration/rollback плана.

## Что plan НЕ делает

`router/install.sh plan` не должен:

- запускать `opkg install/update/upgrade/remove`;
- создавать или удалять файлы;
- менять routes, rules, ipsets или firewall;
- поднимать/опускать VPN interfaces;
- запускать/останавливать services;
- перезагружать router;
- читать или печатать secrets.

## Test contract

`tests/router-install-plan.sh` проверяет:

1. `plan` возвращает 0;
2. присутствует success marker;
3. inventory gates остаются `NOT_VALIDATED`;
4. все обязательные `HOMEROUTE_PLAN` поля совпадают с Golden State;
5. `apply` не выполняется и возвращает non-zero;
6. неизвестный режим отклоняется.

Тест доказывает интерфейс plan-only режима в repository environment. Он не доказывает готовность installer к реальному Keenetic.
