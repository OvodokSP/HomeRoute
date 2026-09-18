# Источник AWG2 для VPS

HomeRoute не должен самостоятельно придумывать способ создания AWG2-контейнера. Поэтому схема сверена с официальным репозиторием Amnezia.

## Закреплённый upstream

Источник:

- repository: `amnezia-vpn/amnezia-client`;
- commit: `de93650a90739b87bb47a632872ea9d0adc9412f`.

Файлы и их Git blob SHA зафиксированы в `config/vps-awg-upstream.json`.

Официальная структура использует каталог `client/server_scripts/awg/`.

## Что совпадает с работающим VPS

Официальный `run_container.sh` задаёт:

- `--restart always`;
- `--privileged`;
- capabilities `NET_ADMIN` и `SYS_MODULE`;
- публикацию одного UDP-порта AWG;
- bind `/lib/modules:/lib/modules`;
- sysctl `net.ipv4.conf.all.src_valid_mark=1`;
- подключение контейнера к `amnezia-dns-net`.

Это согласуется с sanitized capture эталонного VPS.

Официальный AWG state создаётся в `/opt/amnezia/awg`, а запуск выполняется через `/opt/amnezia/start.sh`.

## Важное ограничение

Закреплённый commit **не делает Docker image детерминированным**.

Dockerfile этого commit начинается с:

`FROM amneziavpn/amneziawg-go:latest`

То есть base image остаётся плавающим. Поэтому HomeRoute пока не имеет права утверждать, что чистая сборка сегодня создаст тот же image, который работает на reference VPS.

До получения проверенного image pin возможны два безопасных направления:

1. локально предоставить заранее проверенный AWG image;
2. отдельно зафиксировать pullable immutable digest совместимого base/final image.

## Почему state нужно сохранять отдельно

Официальный configure script создаёт в `/opt/amnezia/awg` приватный ключ сервера, публичный ключ, PSK и `awg0.conf`. Client management также использует `clientsTable` в каталоге AWG.

На reference VPS этот каталог не вынесен отдельным bind mount. Поэтому удаление AWG2-контейнера без backup может уничтожить рабочее состояние.

HomeRoute запрещает автоматическую замену AWG2 до успешного backup этого state.
