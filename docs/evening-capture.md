# Вечерний сбор reference inventory

Цель — получить воспроизводимый read-only снимок эталонного Keenetic и VPS без одновременной работы в двух терминалах и без публикации секретов.

## Правило порядка

Работа выполняется последовательно:

1. Keenetic.
2. Сохранить/передать его вывод.
3. Закрыть или отложить окно Keenetic.
4. VPS.
5. Сохранить/передать его вывод.
6. Нормализовать только безопасные машинные строки.

Ни один из preflight-скриптов не должен менять routing, firewall, VPN, Docker containers или установленные пакеты.

## 1. Keenetic

После попадания этого документа в `main` можно получить актуальный скрипт из публичного репозитория.

В Entware shell:

```sh
cd /tmp
wget -O homeroute-preflight-router.sh \
  https://raw.githubusercontent.com/OvodokSP/HomeRoute/main/router/preflight-router.sh
chmod 700 homeroute-preflight-router.sh
sh ./homeroute-preflight-router.sh 2>&1 | tee homeroute-router-inventory.txt
```

Если `wget` недоступен, скрипт можно открыть в GitHub и вставить/передать на устройство другим способом. Не устанавливайте новые пакеты только ради preflight.

После выполнения передаётся файл/вывод `homeroute-router-inventory.txt`. Перед публикацией в Git следует использовать только обезличенные поля из схемы inventory.

Router preflight также выдаёт отдельные безопасные строки:

```text
HOMEROUTE_PACKAGE name=<package> version=<version>
```

Они нужны только для анализа состава Entware и не означают, что каждый обнаруженный пакет является зависимостью HomeRoute.

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

## 3. Нормализация

На обычном ПК с Python 3 сырой вывод можно превратить в allowlisted JSON:

```sh
python3 scripts/inventory/extract_inventory.py homeroute-router-inventory.txt > router-reference.json
python3 scripts/inventory/extract_inventory.py homeroute-vps-inventory.txt > vps-reference.json
```

Нормализатор принимает только ключи, перечисленные в [`../inventory/schema-v1.md`](../inventory/schema-v1.md). Неизвестный ключ приводит к ошибке вместо автоматической публикации значения.

Отдельный список установленных Entware-пакетов извлекается так:

```sh
python3 scripts/inventory/extract_packages.py \
  homeroute-router-inventory.txt > router-packages.json
```

Для документации JSON можно автоматически отрисовать в Markdown:

```sh
python3 scripts/inventory/render_inventory.py router-reference.json \
  --title "Reference router inventory" \
  --output router-reference.md

python3 scripts/inventory/render_inventory.py vps-reference.json \
  --title "Reference VPS inventory" \
  --output vps-reference.md
```

## Что прислать для анализа

Для первого эталонного аудита полезен полный вывод обоих read-only preflight в чате. В публичный Git после проверки должны попасть только обезличенные результаты, достаточные для доказательства требований и совместимости.

Для работы в двух PuTTY-окнах не требуется переключаться туда-сюда: сначала полностью выполняется блок Keenetic и передаётся его результат, затем отдельно VPS.

## Что НЕ делать

Во время inventory не нужно:

- перезагружать роутер или VPS;
- перезапускать VPN/Docker containers;
- выполнять `opkg install/update/upgrade`;
- менять firewall/routes/ip rules;
- открывать или копировать VPN-конфиги;
- выводить keys, PSK, passwords, tokens или proxy secrets.
