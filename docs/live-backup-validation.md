# Контрольная проверка резервного копирования на живой файловой системе

Перед тем как разрешать установщику менять реальные конфиги, HomeRoute должен доказать, что его транзакционный механизм работает не только в CI, но и на файловых системах эталонного роутера и VPS.

Для этого используется `scripts/validation/live-transaction-canary.sh`.

## Что делает canary

Скрипт создаёт отдельную временную папку:

- на роутере: `/opt/tmp/homeroute-live-canary`;
- на VPS: `/var/tmp/homeroute-live-canary`.

Внутри неё он:

1. создаёт исходный управляемый файл;
2. создаёт посторонний файл, который нельзя менять;
3. запускает настоящий HomeRoute transaction helper;
4. меняет существующий файл;
5. создаёт новый файл;
6. проверяет результат;
7. выполняет rollback;
8. проверяет восстановление исходного файла;
9. проверяет удаление созданного файла;
10. проверяет сохранность постороннего файла;
11. удаляет служебную папку.

## Чего он не делает

Canary не:

- устанавливает пакеты;
- меняет `/opt/etc/opkg`;
- меняет HomeRoute-конфиги;
- меняет маршруты;
- меняет firewall;
- трогает AWG;
- перезапускает сервисы;
- управляет Docker;
- читает ключи или VPN-конфиги.

Запуск требует явного `HOMEROUTE_LIVE_CANARY_ACK=YES`.

На reference router 2026-09-18 canary завершился PASS: existing-file restore, transaction-created file removal и unrelated-file preservation прошли успешно; `/opt/tmp/homeroute-live-canary` после cleanup отсутствовал. HRNeo остался running, `opkgtun0` — present.

Даже успешный canary подтверждает только файловый слой backup/restore. Он не открывает live `apply` автоматически.

## Инвентаризация feed'ов

`router/preflight-feeds.sh` отдельно читает только строки `src` / `src/gz` из opkg-конфигов. Файлы не меняются.

Если URL содержит userinfo вида `user:password@host`, URL полностью редактируется в отчёте.

Этот вывод нужен, чтобы зафиксировать фактический источник пакета HRNeo на эталонном роутере без запуска удалённого bootstrap-скрипта.

## Read-only gate перед controlled live restore

Перед любой попыткой live restore используется `vps/preflight-live-restore.sh`.

Он:

- повторно проверяет целостность четырёх rescue-артефактов;
- подтверждает, что AWG2 и AdGuard сейчас запущены;
- сравнивает текущие Docker image ID с image ID, сохранёнными в rescue set;
- останавливает процедуру при любом drift;
- не выполняет `docker stop/restart/load/cp`;
- не меняет systemd, firewall, DNS или VPN state.

На reference VPS 2026-09-18 этот gate завершился `READY_FOR_CONTROLLED_VALIDATION`: rescue set integrity PASS, оба service containers running, current AWG/AdGuard image IDs совпали с сохранёнными rescue image IDs. Live restore, image load и restart не выполнялись.

Этот PASS **не означает**, что live restore уже проверен: он только разрешает перейти к следующей контролируемой стадии.

## Isolated stopped-container restore rehearsal

После read-only readiness gate проект может выполнить отдельный rehearsal через `vps/restore-rehearsal.sh`.

Режим `rehearse`:

- требует явного `HOMEROUTE_RESTORE_REHEARSAL_ACK=YES`;
- создаёт два временных **остановленных** Docker-контейнера;
- использует `--network none`;
- не запускает временные контейнеры;
- не останавливает и не перезапускает рабочие `amnezia-awg2` / `adguard-home`;
- не выполняет `docker load`;
- копирует уже проверенные backup-каталоги во временные контейнеры и обратно;
- повторно прогоняет SHA-256 verifier после round-trip;
- удаляет временные контейнеры и scratch-каталог.

На reference VPS 2026-09-18 rehearsal завершился PASS: AWG и AdGuard round-trip PASS, временные контейнеры не запускались, рабочие контейнеры остались running, leftovers отсутствуют.

Успешный rehearsal доказывает только корректность Docker copy/round-trip на живом VPS с exact rescue images. Он **не** является live restore рабочего сервиса и не закрывает HL-404.


## Controlled live AWG same-state restore validation

Перед закрытием VPS-части HL-404 используется отдельный `vps/validate-live-awg-restore.sh`.

Он намеренно проверяет не откат на старую конфигурацию, а более безопасный same-state restore: повторяет read-only readiness gate, требует явного ACK, штатно останавливает только `amnezia-awg2`, снимает quiescent snapshot уже остановленного контейнера, копирует этот же snapshot обратно, повторно вычитывает восстановленные файлы и сравнивает полный SHA-256 manifest, затем запускает исходный контейнер и ждёт восстановления `awg0` и TCP/UDP DNS DNAT 53.

При неуспешной post-check скрипт автоматически повторно применяет quiescent snapshot и запускает контейнер. AdGuard не останавливается и не изменяется; container recreate/remove и image load не выполняются.

На reference VPS 2026-09-18 этот validator завершился PASS: quiescent snapshot PASS, stopped restore round-trip PASS, `awg0` PASS, TCP/UDP DNS DNAT 53 PASS, validation window 6 секунд. После теста AWG2 и AdGuard были `running`.

AWG-часть live restore validation теперь подтверждена. AdGuard live restore validation остаётся отдельным следующим этапом.


## Controlled live AdGuard same-state restore validation

Для AdGuard используется отдельный `vps/validate-live-adguard-restore.sh`.

Он требует явного ACK, повторяет restore-readiness gate, останавливает только `adguard-home`, снимает quiescent snapshot каталогов `conf` и `work`, копирует этот же snapshot обратно в остановленный контейнер и повторно вычитывает его для полного SHA-256 manifest comparison.

После запуска исходного контейнера validator проверяет:

- наличие `AdGuardHome.yaml`;
- что AWG2 остаётся running;
- что TCP/UDP DNAT 53 внутри AWG2 сохранился;
- что восстановленный AdGuard реально отвечает как DNS-сервер по UDP/53 и TCP/53. DNS probe проверяет только корректный DNS response envelope; конкретный ответ/rcode не важен.

При любом сбое после готовности quiescent snapshot cleanup пытается снова остановить AdGuard, повторно применить snapshot и запустить контейнер. Recovery snapshot при ошибке сохраняется на диске для ручного разбора.

AWG не останавливается и не изменяется; container recreate/remove и image load не выполняются.

На reference VPS 2026-09-18 этот validator завершился PASS: quiescent snapshot PASS, stopped restore round-trip PASS, `AdGuardHome.yaml` present, AWG DNS redirect PASS, реальные UDP/53 и TCP/53 DNS probes PASS, validation window 10 секунд. После теста оба контейнера были `running`, а финальный restore-readiness gate снова подтвердил целостность rescue set и совпадение image IDs.

VPS-часть live service restore validation теперь подтверждена; следующий незакрытый live restore блок — Keenetic.
