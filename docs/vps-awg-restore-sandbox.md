# Проверка восстановления AWG в sandbox

Live backup рабочего AWG2 уже подтверждён. Следующий безопасный этап — проверить сам алгоритм восстановления без изменения Docker и без остановки VPN.

`vps/restore-awg-backup-sandbox.sh` работает только если:

- target root имеет вид `/tmp/homeroute-awg-restore-sandbox.*`;
- внутри есть marker `.homeroute-restore-sandbox`;
- source backup проходит `MANIFEST.sha256`.

Алгоритм:

1. сохраняет существующие sandbox `opt/amnezia/awg` и `start.sh`;
2. восстанавливает backup в sandbox;
3. сравнивает SHA256 каждого восстановленного файла с source backup;
4. при любой ошибке возвращает прежнее sandbox-состояние;
5. не вызывает Docker и не знает live container path вне sandbox.

CI проверяет как успешный restore, так и искусственный verification failure с обязательным rollback.

Это **не** подтверждает live restore рабочего контейнера. Оно подтверждает только алгоритм файлового восстановления и rollback в изоляции.
