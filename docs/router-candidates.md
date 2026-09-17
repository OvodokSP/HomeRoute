# Кандидаты оборудования

Этот список нужен для последующей матрицы совместимости HomeRoute. Он **не является рекомендацией к покупке** и не присваивает статус `Verified` без фактического воспроизведения HomeRoute.

Состояние источников зафиксировано на 2026-09-17. Для портированных устройств отдельно учитывается статус upstream-порта: `Active` означает, что проект Keenetic Ported продолжает выпускать новые версии для модели, но это не означает проверку HomeRoute.

## Native Keenetic

У родных Keenetic не требуется этап портирования прошивки. Ниже — модели с официально опубликованными характеристиками и поддержкой OPKG в спецификации.

| Модель | CPU | RAM | Flash | OPKG | HomeRoute | Источник |
|---|---|---:|---:|---|---|---|
| Keenetic KN-1012 (региональные названия Giga/Hero) | MT7981B, 2×1300 MHz | 512 MB DDR4 | 256 MB | Да | `Unknown` до clean reproduction | https://keenetic.com/en/keenetic-hero |
| Keenetic Hopper KN-3811 | MT7981B, 2×1300 MHz | 512 MB DDR4 | 256 MB | Да | `Unknown` до clean reproduction | https://keenetic.com/en/keenetic-hopper |
| Keenetic Sprinter KN-3711 | MT7981B, 2×1300 MHz | 512 MB DDR4 | 128 MB | Да | `Unknown` до clean reproduction | https://keenetic.com/en/keenetic-sprinter |
| Keenetic Titan KN-1812 | MT7988D, 3×1800 MHz | 1024 MB DDR4 | 256 MB | Да* | `Unknown` до clean reproduction | https://keenetic.com/en/compare/routers?products=keenetic-titan%2Ckeenetic-sprinter |

\* Для финальной compatibility matrix наличие OPKG и конкретная Entware-схема должны быть повторно подтверждены на выбранной модели/версии KeeneticOS; строка здесь фиксирует аппаратный кандидат, а не HomeRoute verdict.

## Keenetic Ported — активные кандидаты

Keenetic Ported прямо предупреждает, что портированные прошивки предоставляются «как есть», не предназначены как гарантированное основное решение и могут не иметь фирменных облачных сервисов. Поэтому здесь фиксируется только upstream evidence и аппаратная база.

| Модель | CPU / arch | RAM | Flash | Entware evidence | Upstream | HomeRoute |
|---|---|---:|---:|---|---|---|
| Netis N6 v1 AX1800 | MT7621AT / MIPS, 880 MHz | 256 MB | 128 MB NAND | Встроенное хранилище для Entware заявлено upstream | Active | `Unknown`; текущий reference-router требует отдельного inventory evidence |
| Xiaomi AX3000T | MT7981B / aarch64, 1300 MHz | 256 MB | 128 MB NAND | Встроенное хранилище ~48.3 MB, Entware заявлен upstream | Active | `Unknown` |
| Redmi AX6S / Xiaomi AX3200 | MT7622B / aarch64, 1350 MHz | 256 MB | 128 MB NAND | Встроенное хранилище ~71.3 MB, Entware заявлен upstream | Active | `Unknown` |
| CMCC RAX3000M/Me | MT7981B / aarch64, 1300 MHz | 512 MB | 128 MB NAND | Архитектура поддерживается текущей Entware-инструкцией Ported | Active | `Unknown` |
| Netis NX32U | MT7981B / aarch64, 1300 MHz | 256 MB | 128 MB NAND | Встроенное хранилище ~70.9 MB, Entware заявлен upstream | Active | `Unknown` |
| Cudy TR3000 | MT7981B / aarch64, 1300 MHz | 512 MB | 128/256 MB NAND | Встроенное хранилище ~70.9/153 MB, Entware заявлен upstream | Active | `Unknown` |
| Cudy WR3000P | MT7981B / aarch64, 1300 MHz | 512 MB | 128 MB NAND | Порт Active; Entware пригодность требует отдельной проверки HomeRoute | Active | `Unknown` |
| Cudy WBR3000UAX | MT7981B / aarch64, 1300 MHz | 512 MB | 128 MB NAND | Порт Active; Entware пригодность требует отдельной проверки HomeRoute | Active | `Unknown` |
| SmartBox Giga | MT7621AT / MIPS, 880 MHz | 256 MB | 128 MB NAND | Порт Active; Entware пригодность требует отдельной проверки HomeRoute | Active | `Unknown` |
| Xiaomi Router 3G | MT7621AT / MIPS, 880 MHz | 256 MB | 128 MB NAND | Порт Active; Entware пригодность требует отдельной проверки HomeRoute | Active | `Unknown` |

### Источники Ported

- Общий статус проекта и список моделей: https://keeneticported.dev/wiki/
- Entware и соответствие архитектур: https://keeneticported.dev/wiki/helpful/entware
- Netis N6: https://keeneticported.dev/wiki/guides/NetisN6
- Xiaomi AX3000T: https://keeneticported.dev/wiki/guides/ax3000t
- Redmi AX6S: https://keeneticported.dev/wiki/guides/ax6s
- CMCC RAX3000M/Me: https://keeneticported.dev/wiki/guides/rax3000me
- Netis NX32U: https://keeneticported.dev/wiki/guides/netis-nx32u
- Cudy TR3000: https://keeneticported.dev/wiki/guides/tr3000
- Cudy WR3000P: https://keeneticported.dev/wiki/guides/WR3000P
- Cudy WBR3000UAX: https://keeneticported.dev/wiki/guides/WBR3000UAX
- SmartBox Giga: https://keeneticported.dev/wiki/guides/smartbox-giga
- Xiaomi Router 3G: https://keeneticported.dev/wiki/guides/xiaomi-3G

## Важные ограничения Ported

- Наличие порта KeeneticOS не равно совместимости HomeRoute.
- Ревизии одного и того же коммерческого названия могут отличаться аппаратно.
- Для Xiaomi AX3000T upstream отдельно предупреждает о несовместимых более новых аппаратных ревизиях/заводских версиях; перед покупкой нужна проверка конкретной ревизии.
- Для Netis NX32U upstream указывает совместимость метода с Netis N6 v2, но не гарантирует полную работоспособность N6 v2.
- Некоторые портированные модели теряют часть аппаратных функций (например, отдельные порты) или облачные функции Keenetic.

## Не включать в короткий пользовательский список пока

Модели со статусом EoL/EoD в Keenetic Ported не должны попадать в основной список «купить сейчас» без отдельной причины. Они могут оставаться в исторической compatibility matrix для уже имеющихся устройств.

Примеры: Xiaomi Router 4/4A, Xiaomi Router 3P, SmartBox Turbo/Pro и другие устройства, для которых upstream прекратил или ограничил развитие порта.

## Следующий шаг

После reference inventory:

1. определить реальные resource thresholds только на основании evidence;
2. отфильтровать этот список по RAM/storage/architecture;
3. проверить наличие нужной Entware/AWG2-side tooling для каждой архитектуры;
4. присвоить `Expected` только моделям, прошедшим документарную проверку;
5. присваивать `Verified` только после фактического clean reproduction HomeRoute.
