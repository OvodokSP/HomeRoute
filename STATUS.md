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
| Router package snapshot | CAPTURED + CLASSIFIED |
| Core router install roots | VALIDATED: `chur-amneziawg`, `hrneo` |
| Optional/reserve package profiles | CLASSIFIED, DISABLED BY DEFAULT |
| Router live doctor evidence | PASS 2026-09-17; initial FORWARD false-negative isolated to matcher |
| VPS live doctor | PASS 10/10 — 2026-09-17 |
| Router doctor matcher regression | FIXED + CI SELF-TEST |
| Router installer design | PREPARED |
| Router plan-only mode | TESTED, READ-ONLY; PACKAGE MANIFEST WIRED |
| Router feed provisioning | NOT VALIDATED |
| Router apply-mode | BLOCKED / NOT IMPLEMENTED |
| VPS installer design | PREPARED |
| VPS plan-only mode | TESTED, READ-ONLY |
| VPS apply-mode | BLOCKED / NOT IMPLEMENTED |
| Structured doctor summary | LIVE VALIDATED; see docs/live-doctor-2026-09-17.md |
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

Router package snapshot полностью сопоставлен с `config/router-package-manifest.json`. Core install roots намеренно минимальны: `chur-amneziawg` и `hrneo`; их доказанные transitive dependencies разрешает `opkg`. `nfqws` остаётся optional, `tg-ws-proxy` — reserve, а пакеты без evidence не продвигаются из `UNCLASSIFIED`.

Live doctor validation от 2026-09-17 зафиксирован в `docs/live-doctor-2026-09-17.md`. VPS doctor дал `pass=10 warn=0 fail=0 result=PASS`. Router doctor дал 24 PASS и один ложный FAIL на FORWARD matcher; непосредственный `iptables-save`, активный conntrack с mark `0x3001` и свежий AWG handshake подтвердили исправный FORWARD path. Matcher исправлен и покрыт CI self-test.

Для v1 действует supported-floor policy: текущая фактически работающая конфигурация является `Verified baseline`; конфигурации ниже неё — `Not validated`, а равные/более ресурсные совместимые платформы — `Expected compatible`. Это не является утверждением о физическом минимуме.

Router `plan` теперь использует доказанный package manifest, но live `apply` остаётся заблокирован до детерминированного feed provisioning, live-safe backup/verify/rollback и clean-device reproduction. VPS live `apply` остаётся заблокирован по тем же принципам.

Backup/restore transaction model прошёл тест только в фиктивном временном дереве и не означает готовность live restore.

Clean-device protocol и evidence-template подготовлены, но воспроизводимость на чистом устройстве не считается подтверждённой до фактического run без незадокументированных ручных исправлений.
