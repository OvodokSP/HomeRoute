# Семантический отпечаток DNS helper

На reference VPS DNS persistence вызывает `/usr/local/sbin/awg-adguard-dns.sh`.

Публиковать содержимое этого файла для проверки не требуется.

`vps/analyze-dns-helper.sh` читает helper локально и выводит только:

- SHA256;
- результат `sh -n`;
- наличие Docker/Docker inspect;
- наличие literal-имён reference-контейнеров и `amnezia-dns-net`;
- наличие Docker network/IP lookup constructs: `NetworkSettings.Networks` и `.IPAddress`;
- признаки variable indirection в `docker inspect`;
- наличие iptables/NAT/PREROUTING;
- literal TCP/UDP либо признаки protocol variable + `tcp udp` loop;
- dport 53, DNAT и `--to-destination`;
- использование переменной в `--to-destination`;
- признаки idempotency-команд `-C`, `-A`, `-I`, `-D`;
- признаки потенциально широких/опасных действий: `-F`, `docker restart`, `docker rm`, `reboot`, `rm`;
- количество строк.

Schema 2 дополнительно выводит два производных признака:

- `runtime_target_candidate=true` — только если одновременно видны `docker inspect`, `NetworkSettings.Networks`, `.IPAddress` и variable target в `--to-destination`;
- `protocol_loop_candidate=true` — только если протокол передаётся переменной и helper содержит пару `tcp udp`/ `udp tcp`.

Слова `candidate` намеренны: это синтаксические признаки, а не доказательство полного поведения shell-кода.

## Live capture 2026-09-18

Первый live запуск schema 1 подтвердил exact SHA256 helper, valid shell syntax, Docker inspect, AWG container, docker exec, iptables/NAT/PREROUTING, dport 53, DNAT, `--to-destination`, `-C` и `-I`.

Не обнаружены broad flush, container restart/removal, reboot или `rm`.

При этом literal patterns `adguard-home`, `amnezia-dns-net`, `-p tcp`, `-p udp` не найдены. Это совместимо с variable/loop implementation, но schema 1 не могла это различить.

Поэтому полное соответствие live helper desired dynamic AdGuard TCP/UDP DNAT implementation пока остаётся **NOT VALIDATED**. Для следующего read-only capture используется schema 2.

Текст helper, адрес AdGuard и значения shell-переменных не печатаются.
