# Вечерний сбор reference inventory

Цель — получить воспроизводимый read-only снимок эталонного Keenetic и VPS без одновременной работы в двух терминалах и без публикации секретов.

## Правило порядка

Работа выполняется последовательно:

1. Keenetic.
2. Сохранить/передать его вывод.
3. Закрыть или отложить окно Keenetic.
4. VPS.
5. Сохранить/передать его вывод.
6. На ПК обработать оба файла одной командой.

Ни один из preflight-скриптов не должен менять routing, firewall, VPN, Docker containers или установленные пакеты.

## 1. Keenetic

В Entware shell:

```sh
cd /tmp
wget -O homeroute-preflight-router.sh \
  https://raw.githubusercontent.com/OvodokSP/HomeRoute/main/router/preflight-router.sh
chmod 700 homeroute-preflight-router.sh
sh ./homeroute-preflight-router.sh 2>&1 | tee homeroute-router-inventory.txt
```

Если `wget` недоступен, скрипт можно открыть в GitHub и вставить/передать на устройство другим способом. Не устанавливайте новые пакеты только ради preflight.

После выполнения передаётся файл/вывод `homeroute-router-inventory.txt`. Router preflight выдаёт только отдельные безопасные машиночитаемые поля и список package/version; содержимое VPN-конфигов он не читает.

## 2. VPS

После завершения router-сбора:

```sh
cd /tmp
curl -fsSLo homeroute-preflight-vps.sh \
  https://raw.githubusercontent.com/OvodokSP/HomeRoute/main/vps/preflight-vps.sh
chmod 700 homeroute-preflight-vps.sh
sh ./homeroute-preflight-vps.sh 2>&1 | tee homeroute-vps-inventory.txt
```

Если `curl` отсутствует, допустим `wget -O homeroute-preflight-vps.sh <raw-url>`.

По умолчанию скрипт ожидает контейнеры `amnezia-awg2` и `adguard-home`, а AWG-интерфейс внутри AWG2 — `awg0`. При другой схеме имена можно передать через локальные environment variables без сохранения их в Git.

## 3. Обработка на ПК — одна команда

Имея локальную копию репозитория и Python 3:

```sh
python3 scripts/inventory/process_reference.py \
  homeroute-router-inventory.txt \
  homeroute-vps-inventory.txt \
  --out-dir reference-output
```

Команда создаёт:

- `reference-output/router-reference.json` — allowlisted router inventory;
- `reference-output/vps-reference.json` — allowlisted VPS inventory;
- `reference-output/router-packages.json` — package/version из Entware;
- `reference-output/router-reference.md` — готовая Markdown-таблица;
- `reference-output/vps-reference.md` — готовая Markdown-таблица;
- `reference-output/reference-readiness.txt` — список PASS/WARN/BLOCKED для полноты evidence.

Неизвестный `HOMEROUTE_INVENTORY` key блокируется нормализатором вместо автоматической публикации. Полный raw log не копируется в output-dir автоматически.

Если каталог output уже содержит файлы, обработчик откажется перезаписывать их без явного `--force`.

## Readiness не является hardware verdict

`reference-readiness.txt` отвечает только на вопрос: **достаточно ли безопасных полей собрано для анализа требований?**

Он намеренно не выдаёт:

- минимальную RAM;
- рекомендуемый CPU;
- минимальный размер storage;
- статус совместимости другой модели.

Числовые thresholds появляются только после интерпретации фактически измеренного reference evidence.

## Что прислать для первого аудита

Самый простой вариант — прислать мне по очереди два raw-вывода:

1. Keenetic целиком;
2. после его разбора — VPS целиком.

Я сам выполню нормализацию и зафиксирую в Git только безопасные результаты.

Для работы в двух PuTTY-окнах не требуется переключаться туда-сюда: сначала полностью выполняется Keenetic, затем отдельно VPS.

## Что НЕ делать

Во время inventory не нужно:

- перезагружать роутер или VPS;
- перезапускать VPN/Docker containers;
- выполнять `opkg install/update/upgrade`;
- менять firewall/routes/ip rules;
- открывать или копировать VPN-конфиги;
- выводить keys, PSK, passwords, tokens или proxy secrets.
