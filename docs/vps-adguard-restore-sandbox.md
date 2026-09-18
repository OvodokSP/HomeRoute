# Проверка восстановления AdGuard в sandbox

После успешного live backup состояние AdGuard проверяется на восстановление только в изолированном filesystem sandbox.

`vps/restore-adguard-backup-sandbox.sh` восстанавливает исключительно:

- `/opt/adguardhome/conf`;
- `/opt/adguardhome/work`.

Но реальные пути подменяются sandbox-root вида `/tmp/homeroute-adguard-restore-sandbox.*`.

## Проверяемый алгоритм

1. source backup обязан пройти `MANIFEST.sha256`;
2. существующие sandbox `conf/work` сохраняются;
3. backup восстанавливается;
4. каждый файл сравнивается по SHA256;
5. при любой ошибке возвращаются предыдущие `conf/work`;
6. посторонние файлы рядом не затрагиваются.

CI отдельно моделирует принудительный verification failure и требует `ROLLBACK`.

Скрипт не вызывает Docker и не может работать с live `/opt/adguardhome` напрямую.

Успешный sandbox restore не равен live restore работающего AdGuard-контейнера.
