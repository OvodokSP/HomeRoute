# Clean-device reproduction protocol

Статус: **protocol prepared / first reproduction NOT YET TESTED**.

Этот документ определяет, какие доказательства нужны, прежде чем HomeRoute сможет заявить о воспроизводимости на чистом устройстве. Само наличие протокола не является доказательством успешной установки.

## Цель

Подтвердить, что человек, не опирающийся на скрытое состояние эталонного роутера/VPS, может последовательно получить проверенную HomeRoute desired state и восстановить её после reboot.

## Обязательные границы

- Использовать отдельный тестовый router/VPS или явно согласованное окно на устройствах, где допустимы изменения.
- Перед apply иметь backup/rollback plan.
- Не публиковать credentials, private keys, PSK, passwords, tokens, proxy secrets или приватные VPN configs.
- Не считать ручное исправление, отсутствующее в документации, частью успешного автоматизированного результата.
- AWG baseline для текущего протокола — 2.x.

## Шаг 0. Идентификация теста

Зафиксировать обезличенно:

- дата/идентификатор reproduction run;
- тип устройства: Native Keenetic или compatible KeeneticOS port;
- модель/версия firmware после фактического подтверждения;
- inventory schema/router inventory;
- VPS inventory;
- commit/tag HomeRoute, который проверяется.

## Шаг 1. Начальное состояние

Должно быть понятно, какие компоненты уже присутствуют до HomeRoute.

Зафиксировать:

- KeeneticOS/Entware baseline;
- наличие/отсутствие AWG/HRNeo/nfqws/tg-ws-proxy;
- VPS Docker baseline;
- наличие/отсутствие AWG2/AdGuard;
- отсутствие скрытых HomeRoute hooks/rules от предыдущего теста.

Если состояние не является чистым относительно проверяемого компонента, run нельзя использовать как доказательство clean reproduction.

## Шаг 2. Preflight и plan

1. Снять router/VPS inventory.
2. Выполнить router `install.sh plan`.
3. Выполнить VPS `install.sh plan`.
4. Выполнить `vps/render-dns-persistence-plan.sh` и убедиться, что он завершился `HOMEROUTE_DNS_DESIRED result=PASS`; renderer ничего не применяет.
5. Все `NOT VALIDATED`/`BLOCKED` зависимости должны быть либо разрешены подтверждёнными данными, либо run останавливается.

Plan сам по себе ничего не меняет.

## Шаг 3. Backup gate

Перед первым изменением:

- создать transaction backup согласно [`backup-restore-contract.md`](backup-restore-contract.md);
- проверить, что rollback target однозначен;
- проверить достаточное свободное место;
- не выводить backup contents в публичный лог.

Пока apply-mode не реализован, этот шаг служит acceptance requirement для будущей версии.

## Шаг 4. Apply

Apply допускается только в версии HomeRoute, где соответствующий installer больше не помечен BLOCKED и имеет отдельные тесты.

Запрещено считать успешным run, если в процессе потребовалась незадокументированная команда/ручная правка. Такая правка должна сначала попасть в код/документацию, после чего run начинается заново с чистого состояния.

## Шаг 5. Verify до reboot

Router:

- `doctor-router.sh` — exit 0;
- `HOMEROUTE_DOCTOR ... result=PASS`;
- routing contract `0x3001 -> table 301 -> opkgtun0`;
- required persistence hooks;
- отсутствие legacy state.

VPS:

- `doctor-vps.sh` — exit 0;
- `HOMEROUTE_DOCTOR ... result=PASS`;
- AWG2/AdGuard state;
- DNS redirect TCP/UDP 53;
- отсутствие `WG443_TEST` и duplicate/legacy router peer.

Также выполняется функциональная проверка целевого пользовательского сценария без публикации приватного трафика/идентификаторов.

## Шаг 6. Reboot persistence

Последовательно:

1. controlled reboot router;
2. после восстановления повторить router doctor и функциональную проверку;
3. controlled reboot VPS;
4. после восстановления повторить VPS doctor и функциональную проверку;
5. повторно подтвердить пользовательский end-to-end сценарий.

Run не считается PASS, если состояние восстановилось только после дополнительной ручной команды.

## Шаг 7. Идемпотентность

После успешного состояния повторный installer `plan` должен показывать отсутствие необходимых изменений для уже совпадающих объектов.

Будущий повторный `apply` должен быть `NO CHANGE` для совпадающего desired state и не создавать duplicate rules/hooks/peers.

## Шаг 8. Rollback test

На тестовом контуре отдельно проверить rollback:

- он возвращает managed-объекты к transaction snapshot;
- удаляет только доказанно созданные транзакцией объекты;
- не повреждает unrelated state;
- после rollback система соответствует зафиксированному pre-apply состоянию.

Не обязательно выполнять rollback в том же run, который используется как основной reproduction PASS; но без отдельного подтверждённого rollback installer не получает stable-status.

## PASS criteria

Clean-device reproduction можно отметить PASS только если одновременно:

- исходное состояние действительно чистое относительно проверяемого HomeRoute deployment;
- нет незадокументированных ручных исправлений;
- preflight/plan/apply/verify последовательность воспроизводима;
- router и VPS doctor дают PASS до reboot;
- router и VPS doctor дают PASS после reboot;
- end-to-end пользовательский сценарий работает после reboot;
- артефакты evidence не содержат секретов;
- commit/tag проверяемой версии зафиксирован.

## BLOCKED / FAIL

Run помечается BLOCKED/FAIL при:

- неизвестной обязательной зависимости;
- отсутствии backup/rollback gate перед изменением;
- ручной незадокументированной правке;
- doctor FAIL;
- потере состояния после reboot;
- невозможности определить, был ли тест действительно чистым;
- обнаружении secret material в подготавливаемом evidence.

## Evidence record

Для каждого run создаётся обезличенная запись по шаблону [`reproduction-record.example.md`](reproduction-record.example.md). Реальные credentials и приватная конфигурация в record не включаются.
