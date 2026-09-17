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
| Phase 1 inventory framework | PREPARED |
| Router/VPS capture tooling | PREPARED |
| Inventory schema/examples | PREPARED |
| Real router inventory | NOT YET CAPTURED |
| Real VPS inventory | NOT YET CAPTURED |
| Hardware thresholds | NOT VALIDATED |
| Compatibility matrix | NOT VALIDATED |
| Router installer design | PREPARED |
| Router plan-only mode | TESTED, READ-ONLY |
| Router apply-mode | BLOCKED / NOT IMPLEMENTED |
| VPS installer design | PREPARED |
| VPS plan-only mode | TESTED, READ-ONLY |
| VPS apply-mode | BLOCKED / NOT IMPLEMENTED |
| Structured doctor summary | IMPLEMENTED, LIVE CAPTURE PENDING |
| Backup/restore contract | TESTED ON FICTITIOUS DATA |
| Live backup/restore | NOT VALIDATED |
| Clean-device reproduction protocol | PREPARED |
| First clean-device reproduction | NOT YET TESTED |
| Installer | NOT VALIDATED |
| AWG 3.x | NOT YET ADOPTED |
| Repository CI | CONFIGURED |
| Repository autopilot | CONFIGURED, DISABLED UNTIL SECRET/VARIABLE SETUP |

Статусы PASS относятся к фактически проверенной reference-инсталляции, а не гарантируют переносимость на произвольное оборудование.

Phase 1 подготовил формат безопасного inventory, router/VPS preflight, allowlisted schema и методику классификации. Числовые требования и совместимость моделей должны опираться на отдельные фактические измерения.

Router и VPS `plan` допускают только read-only оценку. Реальный `apply` останется заблокирован до reference inventory, точного dependency mapping/provisioning requirements, backup/verify/rollback реализации и clean-device validation.

Doctor structured summary содержит только агрегированные счётчики. Backup/restore transaction model прошёл тест только в фиктивном временном дереве и не означает готовность live restore.

Clean-device protocol и evidence-template подготовлены, но воспроизводимость на чистом устройстве не считается подтверждённой до фактического run без незадокументированных ручных исправлений.
