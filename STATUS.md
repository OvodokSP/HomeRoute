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
| Диагностика роутера | PASS |
| Диагностика VPS | PASS 10/10 |
| План установщика роутера | TESTED, READ-ONLY |
| План установщика VPS | TESTED, READ-ONLY; RUNTIME MANIFEST WIRED |
| Sandbox-транзакция роутера | CI PASS: APPLY / NO CHANGE / VERIFY / ROLLBACK |
| Sandbox-транзакция VPS | CI PASS: APPLY / NO CHANGE / VERIFY / ROLLBACK |
| Файловый backup/restore | IMPLEMENTED IN SANDBOX |
| Chur/AmneziaWG feed provisioning | SANDBOX APPLY / NO CHANGE / ROLLBACK PASS |
| HydraRoute Neo feed | UPSTREAM SCRIPT ONLY / LIVE BLOCKED |
| Реальный apply роутера | BLOCKED |
| VPS runtime provisioning data | REFERENCE RUNTIME CAPTURED 2026-09-18 |
| Реальный apply VPS | BLOCKED |
| Live backup/restore | VPS FILESYSTEM CANARY PASS / ROUTER PENDING |
| Протокол чистого воспроизведения | PREPARED |
| Первое чистое воспроизведение | NOT YET TESTED |
| AWG 3.x | NOT YET ADOPTED |
| Repository CI | CONFIGURED |
| Repository autopilot | CONFIGURED, INTENTIONALLY DISABLED |

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

1. детерминированный feed для HydraRoute Neo без скрытого `curl | sh`;
2. live-safe backup/restore всех изменяемых типов объектов;
3. контрольная live backup/restore validation — VPS filesystem canary PASS; Keenetic и реальные управляемые объекты ещё не подтверждены;
4. первое чистое воспроизведение.
