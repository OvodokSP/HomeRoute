# История изменений

## Unreleased

- Удалён контур development autopilot: GitHub Actions workflow, Codex prompts и Roadmap helper. Обычный Repository quality CI сохранён.
- Зафиксирован live schema-2 preflight DNS persistence: monotonic timer, OnBoot 30s, OnUnitActive 1min, Persistent=yes и exact helper SHA.
- Добавлен sanitized DNS helper analyzer schema 2 для variable/loop patterns без вывода содержимого helper, IP или shell-переменных.
- Первый live helper fingerprint записан как partial evidence без преждевременного повышения dynamic target/TCP+UDP semantics до VERIFIED.
- Добавлен design-only DNS persistence contract и read-only renderer для monotonic timer, dynamic AdGuard target и TCP/UDP DNAT 53; live apply остаётся blocked.
- Уточнён HRNeo integrity boundary: release commit unsigned, GitHub Releases пуст, signing key не найден в main/pinned source commit; SHA-256 всех трёх pinned `.ipk` захвачен и добавлен в verifier, GPG остаётся NOT VERIFIED.
- Live DNS helper schema 2 подтвердил TCP/UDP loop через protocol variable; конкретный target-resolution path остаётся NOT VALIDATED.
- Добавлен read-only VPS restore-readiness gate: rescue-set integrity + current container/image identity, без stop/restart/load/restore.
- Добавлен isolated stopped-container restore rehearsal: temporary containers, network none, no start, backup round-trip + checksum reverify; live services не затрагиваются.


## 0.2.0 — repository workflow

- Добавлены `AGENTS.md` и `CURRENT_STATE.md` как правила и фактическая точка проекта.
- Roadmap преобразован в машиночитаемый список задач.
- Добавлены dependency-free repository validation и GitHub Actions CI.

## 0.1.0 — bootstrap

- Зафиксировано подтверждённое состояние HomeRoute Golden State v0.1.
- Добавлены русская и английская главные страницы и благодарности upstream-проектам.
- Добавлены reference-конфигурация и данные Telegram IPv4.
- Добавлены read-only diagnostics для роутера и VPS.
- Добавлены безопасные PRE-ALPHA заглушки installers.
