# Hardware candidates — evidence pool

Снимок источников: **2026-09-17**.

Этот документ — не список рекомендованных или совместимых устройств. Он заранее собирает проверяемые характеристики кандидатов, чтобы после reference inventory не искать их повторно.

Статус HomeRoute для всех моделей ниже остаётся **NOT VALIDATED**, пока модель не пройдёт фактическую проверку по правилам [`compatibility-matrix.md`](compatibility-matrix.md).

## Native Keenetic candidates

| Модель | CPU | RAM | Flash | USB | OPKG evidence | HomeRoute |
|---|---|---:|---:|---|---|---|
| Keenetic Titan KN-1812 | MT7988D, 1800 MHz, 3 cores | 1024 MB DDR4 | 256 MB | USB 3.2 + USB 2.0 | Official product page: supported | NOT VALIDATED |
| Keenetic Giga / Hero KN-1012 | MT7981B, 1300 MHz, 2 cores | 512 MB DDR4 | 256 MB | USB 3.0 + USB 2.0 | Official product page: supported | NOT VALIDATED |
| Keenetic Hopper KN-3811 | MT7981B, 1300 MHz, 2 cores | 512 MB DDR4 | 256 MB | USB 3.0 | Official product page: supported | NOT VALIDATED |
| Keenetic Sprinter KN-3711 | MT7981B, 1300 MHz, 2 cores | 512 MB DDR4 | 128 MB | none | Entware/`/opt` suitability for HomeRoute requires separate validation | NOT VALIDATED |
| Keenetic Peak KN-2710 | MT7622B, 1350 MHz, 2 cores | 512 MB DDR3 | 256 MB | USB 3.0 + USB 2.0 | KeeneticOS Open Package support documented for this device family | NOT VALIDATED |

### Sources

- Titan KN-1812: <https://keenetic.com/en/keenetic-titan>
- Hero KN-1012: <https://keenetic.com/en/keenetic-hero>
- Giga KN-1012 EAEU naming/specification article: <https://blog.keenetic.ru/giga-kn-1012/>
- Hopper KN-3811: <https://keenetic.com/en/keenetic-hopper>
- Hopper OPKG component documentation: <https://support.keenetic.com/hopper/kn-3811/en/42407-opkg-component-description.html>
- Sprinter KN-3711: <https://keenetic.com/en/keenetic-sprinter>
- Peak KN-2710 hardware reference: <https://docs.help.keenetic.com/cli/3.1/ru/cli_manual_kn-2710_ru.pdf>
- Peak/KeeneticOS Open Package component description: <https://support.keenetic.com/peak/kn-2710/en/16327-os-component-description.html>

## Compatible-device / port candidate

### Netis N6

Manufacturer hardware specification:

- MT7621A dual-core 880 MHz;
- 256 MB RAM;
- 128 MB ROM/flash;
- USB 3.0;
- five Gigabit Ethernet ports total (1 WAN + 4 LAN).

A community-maintained KeeneticOS port is documented as active by the Keenetic Ported Wiki. This evidence proves existence of a community port, **not** official Keenetic support and **not** HomeRoute compatibility. Community reports also exist for running Keenetic-oriented packages on N6, but those reports are not treated as HomeRoute verification.

Sources:

- Netis product specification: <https://www.netis.ua/products/N6.html>
- OpenWrt hardware database cross-check: <https://openwrt.org/toh/hwdata/netis/netis_n6>
- Keenetic Ported Wiki: <https://keen-prt.github.io/wiki/guides/NetisN6>
- Community package reports: <https://github.com/nfqws/nfqws2-keenetic/discussions/1>

HomeRoute status: **NOT VALIDATED pending reference inventory/reproduction evidence**.

## Why there is no recommendation yet

До получения reference inventory неизвестны доказанные нижние границы по RAM/storage и точные package/dependency requirements HomeRoute. Поэтому наличие большего объёма RAM/flash или OPKG-функции само по себе не переводит модель в категории «Достаточно» или «Рекомендуется».

После reference inventory этот evidence pool будет сопоставлен с [`hardware-requirements.md`](hardware-requirements.md). В публичную compatibility matrix попадут только статусы, которые можно обосновать наблюдениями или воспроизводимыми тестами.
