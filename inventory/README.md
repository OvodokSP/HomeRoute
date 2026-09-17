# Reference inventories

Каталог предназначен для обезличенных результатов inventory, которые можно безопасно хранить в публичном репозитории и использовать как evidence при формировании требований HomeRoute.

## Разрешено хранить

- модель и аппаратную архитектуру после подтверждения;
- версии ОС и компонентов;
- размеры RAM/storage и свободный ресурс;
- opkg architecture;
- безопасный список необходимых пакетов;
- пути бинарников и hooks;
- результаты read-only проверок без секретов.

## Не хранить

- private keys;
- PSK;
- passwords;
- API/access tokens;
- SSH credentials;
- proxy secrets;
- полные WG/AWG/VPN configurations;
- backup-архивы с приватными данными;
- реальные публичные WAN/VPS адреса, если они не нужны для доказательства совместимости;
- персональные идентификаторы пользователей или устройств.

Перед публикацией inventory необходимо просмотреть на предмет секретов и лишних инфраструктурных данных.

## Schema v1

Разрешённые машиночитаемые поля описаны в [`schema-v1.md`](schema-v1.md). Нормализатор `scripts/inventory/extract_inventory.py` отклоняет неизвестные ключи вместо их автоматической публикации.

Примеры описывают только формат и не относятся к реальной инфраструктуре:

- [`router-reference.example.txt`](router-reference.example.txt)
- [`vps-reference.example.txt`](vps-reference.example.txt)

## Рекомендуемый поток

1. Запустить соответствующий read-only preflight.
2. Сохранить сырой вывод вне Git.
3. Нормализовать только allowlisted строки:

   ```sh
   python3 scripts/inventory/extract_inventory.py raw.txt > sanitized.json
   ```

4. Проверить полученный JSON вручную перед публикацией.
5. При повторном измерении сравнить снимки:

   ```sh
   python3 scripts/inventory/compare_inventory.py old.json new.json --strict-type
   ```

6. Интерпретировать изменения по правилам [`../docs/inventory-evidence.md`](../docs/inventory-evidence.md), а не превращать отдельное наблюдение в общий hardware requirement.
