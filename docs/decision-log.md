# Журнал решений

| Решение | Обоснование |
|---|---|
| Documentation-first | Сначала описывается проверяемое состояние и границы автоматизации. |
| Reference-state-first | Реализация строится от фактически подтверждённого Golden State. |
| No ad-hoc changes | Изменения routing contract и ролей компонентов принимаются отдельно и документируются. |
| AWG 2.x remains baseline | Это версия подтверждённой reference implementation. |
| HRNeo — policy/routing orchestrator | HRNeo отвечает за выборочный маршрут, а не за реализацию туннеля. |
| `opkgtun0` — dedicated AWG interface | Имя входит в проверенный контракт v0.1. |
| `0x3001 → table 301` | Фиксированный routing contract Golden State. |
| nfqws — independent optional layer | Его работа не должна смешиваться с AWG-маршрутом. |
| tg-ws-proxy — reserve path | Канал сохраняется как резервный, но не основной. |
| Separate VPS per deployment | Каждый пользователь использует собственный VPS. |
| No secrets in Git | Репозиторий публичный. |
| Clean reproduction before stable installer | Installer не станет стабильным до проверки на чистом устройстве. |
| DNS persistence follows verified reference timer | Для v1 desired schedule принят подтверждённый monotonic timer: boot +30s, затем 60s после активации; helper semantics задаются отдельно и остаются render-only до live validation. |
