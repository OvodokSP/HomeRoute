# HomeRoute Autopilot v1

## Назначение

Автопилот последовательно обрабатывает `ROADMAP.md`, выполняет изменения в изолированной ветке, запускает детерминированные проверки и отдельный Codex-review. При `PASS` он создаёт аудируемый pull request, запускает отдельный workflow `Repository quality` на точном head-коммите, ждёт его успешного завершения и только затем выполняет squash merge. При ошибке создаётся или обновляется issue `BLOCKED`; инфраструктура не изменяется.

## Контур доверия

Автопилот имеет право записи только в GitHub-репозиторий. У него нет SSH-ключей, адресов или credentials реального Keenetic, NAS либо VPS. `scripts/ci/validate_repo.py --protect-policy` запрещает обычной Roadmap-задаче изменять правила, security policy, CI и сам workflow автопилота.

```text
ROADMAP
  -> Codex developer
  -> deterministic validation
  -> Codex reviewer
  -> one automatic repair attempt
  -> validation and review
  -> PR
  -> independent Repository quality workflow
  -> squash merge, or BLOCKED issue
```

## Однократное включение

В настройках репозитория нужно создать:

1. Actions secret `OPENAI_API_KEY` с отдельным API-ключом минимально необходимого проекта.
2. Actions variable `HOMEROUTE_AUTOPILOT=enabled`.

До появления переменной расписание ничего не выполняет. Ручной `workflow_dispatch` можно использовать для проверочного запуска.

API-ключ не передаётся модели напрямую: официальный `openai/codex-action` поднимает локальный прокси. Codex работает от непривилегированного пользователя и с профилем доступа только к workspace.

## Стоп-условия

Автопилот прекращает задачу и оставляет issue, если:

- отсутствует API-ключ;
- нет изменений помимо отметки Roadmap;
- детерминированная проверка завершилась ошибкой;
- reviewer дважды вернул `CHANGES_REQUIRED`;
- для этого Roadmap ID уже существует открытый issue `BLOCKED` (повторный расход API останавливается);
- обнаружена попытка изменить защищённую policy/workflow-зону;
- отдельный workflow `Repository quality` не запустился или завершился ошибкой;
- GitHub запретил push, создание PR или merge;
- задача требует подключения к реальной инфраструктуре или новых секретов.

## Отключение

Удалите или измените Actions variable `HOMEROUTE_AUTOPILOT`. Уже запущенный job можно отменить в GitHub Actions. Никаких изменений на устройствах отменять не требуется, потому что deploy не входит в полномочия workflow.

## Проверяемые источники механизма

- [OpenAI Codex GitHub Action](https://github.com/openai/codex-action) — inputs, permission profiles, proxy и safety strategies.
- [Codex code review for GitHub](https://developers.openai.com/codex/cloud/code-review) — `AGENTS.md`, automatic review и команды review/fix.
- [GitHub Actions encrypted secrets](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions) — хранение `OPENAI_API_KEY`.
- [GitHub Actions workflow syntax](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions) — schedule, permissions и concurrency.
