# Статус HomeRoute v0.1

| Проверка | Статус |
|---|---|
| Golden State v0.1 подтверждён | PASS |
| VPS reboot test | PASS |
| Keenetic reboot test | PASS |
| HRNeo selective routing | PASS |
| AWG2 | PASS |
| DNS redirect TCP/UDP 53 | PASS |
| Legacy cleanup | PASS |
| Phase 1 inventory framework | PASS |
| Router/VPS capture tooling | PASS |
| Inventory schema/examples | PASS |
| Real router inventory | CAPTURED 2026-09-17 |
| Real VPS inventory | CAPTURED 2026-09-17 |
| Verified hardware supported floor | DEFINED |
| Physical minimum hardware | NOT VALIDATED / NOT REQUIRED FOR v1 |
| Compatibility matrix | BASELINE/EXPECTED POLICY ACTIVE; CLEAN REPRODUCTION PENDING |
| Router package snapshot | CAPTURED; DEPENDENCY CLASSIFICATION PENDING |
| Router installer design | PREPARED |
| Router plan-only mode | TESTED, READ-ONLY |
| Router apply-mode | BLOCKED / NOT IMPLEMENTED |
| VPS installer design | PREPARED |
| VPS plan-only mode | TESTED, READ-ONLY |
| VPS apply-mode | BLOCKED / NOT IMPLEMENTED |
| Structured doctor summary | IMPLEMENTED, LIVE DOCTOR CAPTURE PENDING |
| Backup/restore contract | TESTED ON FICTITIOUS DATA |
| Live backup/restore | NOT VALIDATED |
| Clean-device reproduction protocol | PREPARED |
| First clean-device reproduction | NOT YET TESTED |
| Installer | NOT VALIDATED |
| AWG 3.x | NOT YET ADOPTED |
| Repository CI | CONFIGURED |
| Repository autopilot | CONFIGURED, INTENTIONALLY DISABLED |

Статусы PASS относятся к фактически проверенной reference-инсталляции, а не гарантируют переносимость на произвольное оборудование.

Reference inventory от 2026-09-17 сохранён в обезличенном виде в `inventory/reference-2026-09-17/`. Router capture подтвердил MT7621/MIPS, рабочий Entware/OPKG и наличие AWG/HRNeo/nfqws/tg-ws-proxy. VPS capture подтвердил Ubuntu 26.04, 1 vCPU, около 1.92 GiB RAM, около 29.44 GiB root filesystem, работающие Docker/AWG2/AdGuard.

Для v1 действует supported-floor policy: текущая фактически работающая конфигурация является `Verified baseline`; конфигурации ниже неё — `Not validated`, а равные/более ресурсные совместимые платформы — `Expected compatible`. Это не является утверждением о физическом минимуме.

Router и VPS `plan` допускают только read-only оценку. Реальный `apply` останется заблокирован до точного dependency mapping/provisioning requirements, backup/verify/rollback реализации и clean-device validation.

Doctor structured summary содержит только агрегированные счётчики. Backup/restore transaction model прошёл тест только в фиктивном временном дереве и не означает готовность live restore.

Clean-device protocol и evidence-template подготовлены, но воспроизводимость на чистом устройстве не считается подтверждённой до фактического run без незадокументированных ручных исправлений.
