# План развития

Пункты Roadmap отмечаются выполненными только после детерминированных проверок и review соответствующих изменений.

## Phase 0 — Foundation

- [x] HL-001 — Зафиксировать Golden State v0.1, границы baseline и read-only diagnostics.
- [x] HL-002 — Добавить правила разработки, машиночитаемый Roadmap и CI-проверки репозитория.

## Phase 1 — Inventory & requirements

- [x] HL-101 — Описать и фактически проверить воспроизводимый сбор обезличенного hardware/package inventory для Keenetic/Entware и VPS.
- [x] HL-102 — Добавить схемы результатов inventory и примеры без реальных адресов, ключей и конфигураций.
- [x] HL-103 — Определить методику классов `Verified baseline / Expected compatible / Not validated / Not suitable` без выдачи supported floor за физический минимум.
- [x] HL-104 — Классифицировать reference Entware package snapshot на CORE / OPTIONAL / RESERVE / TRANSITIVE / UNCLASSIFIED / LEGACY и сформировать доказуемый install manifest.

## Phase 2 — Router installer

- [x] HL-201 — Спроектировать идемпотентный router installer с режимами plan/apply, backup, verify и rollback.
- [x] HL-202 — Реализовать plan-only этап router installer без изменения устройства.
- [x] HL-203 — Добавить тестовый стенд и негативные проверки router installer.
- [ ] HL-204 — Реализовать router apply engine после безопасного feed provisioning и backup/verify/rollback. После HL-404 допускается отдельный явно подтверждаемый `reproduction-apply` только для HL-502; обычный/stable `apply` разрешается только после успешного HL-502.

## Phase 3 — VPS installer

- [x] HL-301 — Спроектировать идемпотентный VPS installer с режимами plan/apply, backup, verify и rollback.
- [x] HL-302 — Реализовать plan-only этап VPS installer без подключения к реальному VPS.
- [x] HL-303 — Добавить тестовый стенд и негативные проверки VPS installer.
- [ ] HL-304 — Реализовать VPS apply engine с параметризуемыми AWG2/AdGuard settings, backup/verify/rollback и без embedded secrets. После HL-404 допускается отдельный явно подтверждаемый `reproduction-apply` только для HL-502; обычный/stable `apply` разрешается только после успешного HL-502.

## Phase 4 — Doctor, backup, restore

- [x] HL-401 — Расширить doctor-скрипты структурированным отчётом без секретов.
- [x] HL-402 — Описать и протестировать локальные backup/restore-контракты на фиктивных данных.
- [x] HL-403 — Провести live read-only doctor capture и проверить отчёт на Golden State.
- [x] HL-404 — Провести контролируемую live backup/restore validation до разрешения installer live apply-mode.

## Phase 5 — Clean-device reproduction

- [x] HL-501 — Подготовить протокол ручного подтверждения чистого воспроизведения.
- [ ] HL-502 — Зафиксировать результаты первого чистого воспроизведения и только после этого пересмотреть статус installers.

## Phase 6 — Compatibility matrix

- [ ] HL-601 — Опубликовать матрицу с `Verified baseline` и документарно обоснованными `Expected` моделями; повышать другую модель до `Verified` только после clean reproduction.

## Future

- [ ] HL-901 — Рассмотреть AWG 3.x только после появления и проверки совместимой реализации для целевого роутера/KeeneticOS.
