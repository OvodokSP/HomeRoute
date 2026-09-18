# Закреплённый пакет HydraRoute Neo

HomeRoute больше не рассматривает удалённый `install-feed.sh | sh` как допустимый способ автоматической установки HRNeo.

## Что подтверждено

На 2026-09-18 проверены два upstream-репозитория:

- исходники: `Ground-Zerro/HydraRoute`;
- опубликованные Keenetic-пакеты: `Ground-Zerro/release`.

В release commit `4811c8d13fa4bd6eaed5080fd49788f5aee20883` находятся пакеты `hrneo 3.18.3-1` для трёх поддерживаемых Entware-архитектур.

HomeRoute фиксирует для каждого файла:

- точный repository path;
- размер;
- Git blob SHA-1;
- URL с commit SHA, а не с branch/latest.

Манифест: `config/hrneo-release-manifest.json`.

## Почему не используется mutable feed

Upstream `install-feed.sh` выбирает feed по архитектуре и добавляет его в `customfeeds.conf`, после чего обычный `opkg update` всегда видит текущее содержимое feed.

Для воспроизводимой установки v1 HomeRoute выбирает другой путь:

1. определить Entware architecture;
2. выбрать конкретный `.ipk` из pinned manifest;
3. скачать файл по URL, содержащему commit SHA;
4. проверить размер и Git blob identity;
5. только после отдельного live-validation установить локальный `.ipk` через opkg.

Шаги 3–5 пока не включены в live installer.

## Integrity boundary

Upstream README описывает `SHA256SUMS`, detached GPG signatures и `Neo/RELEASE_SIGNING_KEY.asc`.

При повторной проверке 2026-09-18:

- GitHub Releases API для `Ground-Zerro/HydraRoute` вернул пустой список;
- `Neo/RELEASE_SIGNING_KEY.asc` не найден ни в текущем `main`, ни в закреплённом source commit `984ec135dbc3e9fb54e0c8c63a0e2fd829538772`;
- release-repository commit `4811c8d13fa4bd6eaed5080fd49788f5aee20883`, содержащий нужные `.ipk`, GitHub помечает как unsigned;
- README upstream при этом описывает SHA256SUMS/GPG workflow — это документированное намерение upstream, но доступных release assets/key для фактической проверки на момент observation нет;
- SHA-256 всех трёх закреплённых `.ipk` захвачен 2026-09-18 после проверки размера и Git blob identity.

Поэтому HomeRoute **не заявляет**, что GPG release verification сейчас доступен. Это не трактуется как «подпись плохая»: доступный для проверки канал подписи не подтверждён.

HomeRoute теперь фиксирует точную Git object identity **и SHA-256** каждого pinned `.ipk`. GPG остаётся `NOT_VERIFIED`, а exact binary-to-source provenance всё ещё не доказан.

## Source provenance boundary

Версия package и reviewed source совпадает: `3.18.3-1`.

Но HomeRoute не имеет отдельного доказательства, что конкретные binary `.ipk` были построены именно из reviewed source commit. Этот факт намеренно не повышается до VERIFIED.

## Helper

`router/hrneo-artifact.sh plan <arch>` показывает pinned metadata.

`router/hrneo-artifact.sh verify-file <arch> <local-ipk>` проверяет размер и Git blob identity локального файла, но ничего не устанавливает.
