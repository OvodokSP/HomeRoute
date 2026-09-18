# История изменений

## Unreleased

- Зафиксирован live schema-2 preflight DNS persistence: monotonic timer, OnBoot 30s, OnUnitActive 1min, Persistent=yes и exact helper SHA.
- Добавлен sanitized DNS helper analyzer schema 2 для variable/loop patterns без вывода содержимого helper, IP или shell-переменных.
- Первый live helper fingerprint записан как partial evidence без преждевременного повышения dynamic target/TCP+UDP semantics до VERIFIED.
- Добавлен design-only DNS persistence contract и read-only renderer для monotonic timer, dynamic AdGuard target и TCP/UDP DNAT 53; live apply остаётся blocked.


## 0.2.0 — autonomous repository workflow

- Добавлены `AGENTS.md` и `CURRENT_STATE.md` как правила и фактическая точка для агентов.
- Roadmap преобразован в машиночитаемую очередь задач.
- Добавлены dependency-free repository validation и GitHub Actions CI.
- Добавлен отключённый по умолчанию Codex-autopilot с независимым review, одной автоматической доработкой и стоп-условиями.
- Production deployment остаётся вне полномочий автопилота.

## 0.1.0 — bootstrap

- Зафиксировано подтверждённое состояние HomeRoute Golden State v0.1.
- Добавлены русская и английская главные страницы и благодарности upstream-проектам.
- Добавлены reference-конфигурация и данные Telegram IPv4.
- Добавлены read-only diagnostics для роутера и VPS.
- Добавлены безопасные PRE-ALPHA заглушки installers.
