# Статус HomeRoute v0.1

| Проверка | Статус |
|---|---|
| Эталонная конфигурация v0.1 | PASS |
| Перезагрузка VPS | PASS |
| Перезагрузка Keenetic | PASS |
| Выборочная маршрутизация HRNeo | PASS |
| AWG2 | PASS |
| DNS redirect TCP/UDP 53 | PASS |
| Очистка старой схемы | PASS |
| Реальный inventory роутера | CAPTURED 2026-09-17 |
| Реальный inventory VPS | CAPTURED 2026-09-17 |
| Проверенная опорная конфигурация железа | DEFINED |
| Абсолютный физический минимум | НЕ ОПРЕДЕЛЯЕТСЯ ДЛЯ v1 |
| Состав пакетов роутера | CAPTURED + CLASSIFIED |
| Обязательные пакеты роутера | VALIDATED: `chur-amneziawg`, `hrneo` |
| Диагностика роутера | LIVE PASS 26/26 (2026-09-18) |
| Диагностика VPS | PASS 10/10 |
| План установщика роутера | TESTED, READ-ONLY |
| План установщика VPS | TESTED, READ-ONLY; RUNTIME MANIFEST WIRED |
| Sandbox-транзакция роутера | CI PASS: APPLY / NO CHANGE / VERIFY / ROLLBACK |
| Sandbox-транзакция VPS | CI PASS: APPLY / NO CHANGE / VERIFY / ROLLBACK |
| Файловый backup/restore | ROUTER LIVE FILESYSTEM CANARY PASS + VPS LIVE PASS |
| Chur/AmneziaWG feed provisioning | SANDBOX APPLY / NO CHANGE / ROLLBACK PASS |
| HydraRoute Neo package | PINNED 3.18.3-1 / 3 ARCHES / COMMIT+SIZE+GIT BLOB ID / SHA256 CAPTURED+PINNED / GPG CHANNEL NOT AVAILABLE AT OBSERVATION / LIVE INSTALL BLOCKED |
| Реальный apply роутера | BLOCKED |
| VPS runtime provisioning data | RUNTIME + CONTAINER SHAPE CAPTURED 2026-09-18 |
| VPS provisioning parameter model | DEFINED; LOCAL IMAGE/PATH/PORT/STATE REQUIRED |
| AWG upstream recipe | PINNED SOURCE COMMIT; BASE IMAGE `latest` STILL FLOATING |
| AWG state backup | LIVE PASS 2026-09-18; SHA256 VERIFY PASS |
| AWG restore algorithm | LIVE SAME-STATE RESTORE PASS; QUIESCENT SNAPSHOT + BYTE VERIFY + RUNTIME POSTCHECK; 6s WINDOW |
| Exact Docker image rescue | AWG2 + ADGUARD LIVE EXPORT PASS; SHA256/TAR VERIFY PASS |
| AdGuard state backup | LIVE PASS 2026-09-18; SHA256 VERIFY PASS |
| AdGuard restore algorithm | LIVE SAME-STATE RESTORE PASS; QUIESCENT CONF/WORK + BYTE VERIFY + TCP/UDP DNS POSTCHECK; 10s WINDOW |
| VPS rescue set | 4 LIVE ARTIFACTS CAPTURED; COMBINED VERIFIER READY |
| Amnezia Docker network | UPSTREAM PINNED: amnezia-dns-net / bridge / 172.29.172.0/24 / amn0 |
| HomeRoute AdGuard DNS target | DYNAMIC RUNTIME RESOLUTION CONTRACT TESTED |
| DNS redirect persistence | LIVE RULES PASS; TIMER ACTIVE+ENABLED; HELPER PATH+SHA CAPTURED |
| DNS timer schedule | LIVE PASS: MONOTONIC; ONBOOT 30s + ONUNITACTIVE 1min; PERSISTENT=yes |
| DNS helper semantics | LIVE SCHEMA-2 PARTIAL: TCP/UDP LOOP CONFIRMED; TARGET-RESOLUTION DETAILS NOT VALIDATED |
| DNS persistence desired state | DESIGN-ONLY CONTRACT + RENDERER; CI TESTED; LIVE APPLY BLOCKED |
| Реальный apply VPS | BLOCKED |
| Live backup/restore | VPS FILESYSTEM + AWG + ADGUARD LIVE RESTORE PASS; ROUTER/Keenetic PENDING; READINESS/REHEARSAL PASS |
| Протокол чистого воспроизведения | PREPARED |
| Первое чистое воспроизведение | NOT YET TESTED |
| AWG 3.x | NOT YET ADOPTED |
| Repository CI | CONFIGURED |

## Что это означает

Основная рабочая схема HomeRoute подтверждена на эталонной установке.

Установщики уже умеют:

- безопасно показать план;
- использовать доказанный список обязательных пакетов;
- выполнить реальную файловую транзакцию в изолированном sandbox;
- сохранить исходный файл;
- применить новое состояние;
- определить повторный запуск как `NO CHANGE`;
- откатить изменения при провале проверки;
- сформировать и транзакционно применить `chur.conf` для `aarch64-3.10`, `mips-3.4` и `mipsel-3.4` в sandbox.

При этом обычный `apply` специально остаётся заблокированным и не меняет реальный роутер/VPS.

Следующие реальные блокеры:

1. live-safe package transaction/rollback для закреплённого HRNeo `.ipk`; SHA-256 уже captured/pinned, GPG остаётся NOT VERIFIED из-за отсутствия подтверждённого signing/release channel;
2. live-safe backup/restore router package/config objects; filesystem transaction canary уже live PASS;
3. контрольная live backup/restore validation — VPS filesystem/AWG/AdGuard live restore PASS; Keenetic ещё не подтверждён;
4. первое чистое воспроизведение.
