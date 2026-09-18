# История изменений

## 0.2.1 — independent merge gate

- Автопилот теперь запускает и дожидается отдельного `Repository quality` workflow на точном head-коммите PR.
- Squash merge выполняется только после успешного завершения этого независимого CI-запуска.
- Merge привязан к проверенному head SHA, а `actions: write` изолирован от jobs, в которых запускается Codex.

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
