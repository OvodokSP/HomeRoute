# HomeRoute inventory schema v1

Формат предназначен для обезличенного read-only inventory и не заменяет полный диагностический лог.

Каждая машиночитаемая строка имеет вид:

```text
HOMEROUTE_INVENTORY key=value
```

## Общие правила

- `inventory_schema=1` обозначает эту версию схемы.
- `inventory_type` принимает `router` или `vps`.
- Неизвестное или безопасно не определяемое значение записывается как `NOT_VALIDATED`.
- Размеры ресурсов передаются в KiB с суффиксом `_KiB`.
- Пути к исполняемым файлам допустимы; содержимое конфигурационных файлов — нет.
- Hostname, WAN/public IP, SSH-данные, private/public peer keys, PSK, токены, пароли и proxy secrets в схему не входят.
- Неизвестные ключи не должны автоматически попадать в публичный нормализованный inventory.

## Router keys

Обязательные служебные ключи:

- `inventory_schema`
- `inventory_type`
- `uname_machine`
- `ram_total`
- `opt_total`
- `opt_free`
- `opkg_arch`

Допустимые component-path keys:

- `component_awg`
- `component_awg_quick`
- `component_amneziawg_go`
- `component_hrneo`
- `component_nfqws`
- `component_tg_ws_proxy`

## VPS keys

- `inventory_schema`
- `inventory_type`
- `os_id`
- `os_version_id`
- `kernel_release`
- `uname_machine`
- `vcpu_count`
- `ram_total`
- `root_total`
- `root_free`
- `component_docker`
- `docker_version`
- `awg_container_status`
- `adguard_container_status`
- `awg_interface_present`

## Evidence status

Наличие ключа в inventory доказывает только значение, наблюдаемое в момент запуска соответствующего preflight. Оно не доказывает минимальные требования и не переносится автоматически на другие модели или VPS-профили.
