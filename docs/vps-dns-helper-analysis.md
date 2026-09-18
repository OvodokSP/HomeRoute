# Семантический отпечаток DNS helper

На reference VPS DNS persistence вызывает `/usr/local/sbin/awg-adguard-dns.sh`.

Публиковать содержимое этого файла для проверки не требуется.

`vps/analyze-dns-helper.sh` читает helper локально и выводит только:

- SHA256;
- результат `sh -n`;
- наличие Docker/Docker inspect;
- наличие имён reference-контейнеров и `amnezia-dns-net`;
- наличие iptables/NAT/PREROUTING;
- признаки TCP/UDP, dport 53, DNAT и `--to-destination`;
- признаки idempotency-команд `-C`, `-A`, `-I`, `-D`;
- признаки потенциально широких/опасных действий: `-F`, `docker restart`, `docker rm`, `reboot`, `rm`;
- количество строк.

Текст helper, адрес AdGuard и значения shell-переменных не печатаются.

Это не полноценный статический анализ shell-кода. Поля `pattern_*` означают только обнаружение синтаксических признаков и должны интерпретироваться как evidence, а не как доказательство полного поведения скрипта.
