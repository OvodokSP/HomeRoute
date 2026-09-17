# Structured doctor report

`doctor-router.sh` и `doctor-vps.sh` сохраняют человекочитаемые строки `[PASS]`, `[WARN]`, `[FAIL]`, `[INFO]` и дополнительно завершаются одной безопасной машиночитаемой строкой.

Формат v1:

```text
HOMEROUTE_DOCTOR schema=1 type=<router|vps> pass=<N> warn=<N> fail=<N> result=<PASS|FAIL>
```

## Свойства

- строка содержит только агрегированные счётчики и тип системы;
- она не содержит IP-адресов, hostnames, ключей, PSK, токенов, имён peers, container IDs или содержимого конфигураций;
- `result=FAIL`, если хотя бы одна обязательная проверка дала `[FAIL]`;
- `[WARN]` не превращает общий результат в FAIL, но сохраняется в отдельном счётчике;
- exit code doctor остаётся основным сигналом успешности для shell/CI: `0` при отсутствии обязательных FAIL и ненулевой при FAIL.

## Пример

```text
HOMEROUTE_DOCTOR schema=1 type=router pass=20 warn=1 fail=0 result=PASS
```

Числа в примере не относятся к reference-инсталляции.

## Evidence boundary

Structured summary доказывает только итог конкретного запуска doctor. Для расследования WARN/FAIL используется человекочитаемый вывод того же запуска. Публиковать полный вывод в Git следует только после проверки на лишние инфраструктурные данные.
