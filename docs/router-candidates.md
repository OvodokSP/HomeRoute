# Кандидаты оборудования

Этот список используется для предварительной фильтрации оборудования относительно verified baseline HomeRoute. `Expected` означает теоретически совместимую конфигурацию, а не фактический тест на конкретной модели.

Состояние источников зафиксировано на 2026-09-17. Для ported-устройств статус upstream-порта и статус HomeRoute оцениваются отдельно.

## Текущий supported floor

Reference-router: **Netis N6 v1 AX1800**, MT7621AT/MIPS 880 MHz class, 256 MB RAM, 128 MB NAND, рабочий KeeneticOS port + Entware. Эта конфигурация считается `Verified baseline`.

Правило первой версии:

- ниже baseline по существенному ресурсу → `Not validated`;
- равно или выше baseline + подтверждённая совместимая программная среда → `Expected`;
- текущая reference-конфигурация → `Verified baseline`;
- другая модель после clean reproduction → `Verified`.

## Native Keenetic

У native Keenetic не требуется этап портирования прошивки. Все перечисленные ниже модели ресурсно выше reference-router и имеют официально заявленный OPKG. Поэтому они относятся к `Expected` при условии доступности обязательных HomeRoute/AWG2-side компонентов для их архитектуры.

| Модель | CPU | RAM | Flash | OPKG | Resource vs baseline | HomeRoute | Источник |
|---|---|---:|---:|---|---|---|---|
| Keenetic KN-1012 (региональные названия Giga/Hero) | MT7981B, 2×1300 MHz | 512 MB DDR4 | 256 MB | Да | Выше | `Expected` | https://keenetic.com/en/keenetic-hero |
| Keenetic Hopper KN-3811 | MT7981B, 2×1300 MHz | 512 MB DDR4 | 256 MB | Да | Выше | `Expected` | https://keenetic.com/en/keenetic-hopper |
| Keenetic Sprinter KN-3711 | MT7981B, 2×1300 MHz | 512 MB DDR4 | 128 MB | Да | Выше по RAM/CPU, flash = baseline | `Expected` | https://keenetic.com/en/keenetic-sprinter |
| Keenetic Titan KN-1812 | MT7988D, 3×1800 MHz | 1024 MB DDR4 | 256 MB | Да* | Выше | `Expected` | https://keenetic.com/en/compare/routers?products=keenetic-titan%2Ckeenetic-sprinter |

\* Для окончательного `Verified` наличие нужной Entware/AWG2-side tooling должно быть подтверждено clean reproduction на выбранной модели/версии KeeneticOS.

## Keenetic Ported — активные кандидаты

Keenetic Ported предоставляет прошивки «как есть», поэтому `Expected` здесь означает только: ресурсы не ниже baseline + upstream-порт активен + имеется достаточное документарное основание ожидать рабочий Entware-контур.

| Модель | CPU / arch | RAM | Flash | Entware evidence | Upstream | Resource vs baseline | HomeRoute |
|---|---|---:|---:|---|---|---|---|
| Netis N6 v1 AX1800 | MT7621AT / MIPS, 880 MHz | 256 MB | 128 MB NAND | Рабочий текущий Entware | Active | Baseline | `Verified baseline` |
| Xiaomi AX3000T | MT7981B / aarch64, 1300 MHz | 256 MB | 128 MB NAND | Встроенное хранилище ~48.3 MB, Entware заявлен upstream | Active | Не ниже | `Expected` |
| Redmi AX6S / Xiaomi AX3200 | MT7622B / aarch64, 1350 MHz | 256 MB | 128 MB NAND | Встроенное хранилище ~71.3 MB, Entware заявлен upstream | Active | Не ниже | `Expected` |
| CMCC RAX3000M/Me | MT7981B / aarch64, 1300 MHz | 512 MB | 128 MB NAND | Архитектура поддерживается текущей Entware-инструкцией Ported | Active | Выше по RAM/CPU | `Expected` |
| Netis NX32U | MT7981B / aarch64, 1300 MHz | 256 MB | 128 MB NAND | Встроенное хранилище ~70.9 MB, Entware заявлен upstream | Active | Не ниже | `Expected` |
| Cudy TR3000 | MT7981B / aarch64, 1300 MHz | 512 MB | 128/256 MB NAND | Встроенное хранилище ~70.9/153 MB, Entware заявлен upstream | Active | Выше | `Expected` |
| Cudy WR3000P | MT7981B / aarch64, 1300 MHz | 512 MB | 128 MB NAND | Entware-пригодность требует отдельной проверки | Active | Выше по RAM/CPU | `Not validated` |
| Cudy WBR3000UAX | MT7981B / aarch64, 1300 MHz | 512 MB | 128 MB NAND | Entware-пригодность требует отдельной проверки | Active | Выше по RAM/CPU | `Not validated` |
| SmartBox Giga | MT7621AT / MIPS, 880 MHz | 256 MB | 128 MB NAND | Entware-пригодность требует отдельной проверки | Active | = baseline | `Not validated` |
| Xiaomi Router 3G | MT7621AT / MIPS, 880 MHz | 256 MB | 128 MB NAND | Entware-пригодность требует отдельной проверки | Active | = baseline | `Not validated` |

## Как читать `Expected`

`Expected` — это именно та категория, которую HomeRoute использует для «теоретически должно работать»:

- железо не слабее текущей рабочей точки;
- программная платформа документарно выглядит совместимой;
- но конкретная модель ещё не проходила полный HomeRoute clean reproduction.

`Expected` не повышается до `Verified` только на основании более мощного CPU или большего объёма RAM/flash.

## Источники Ported

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

- Наличие порта KeeneticOS не равно фактической проверке HomeRoute.
- Ревизии одного коммерческого названия могут отличаться аппаратно.
- Для Xiaomi AX3000T upstream отдельно предупреждает о несовместимых более новых аппаратных ревизиях/заводских версиях; перед покупкой нужна проверка конкретной ревизии.
- Для Netis NX32U upstream указывает совместимость метода с Netis N6 v2, но не гарантирует полную работоспособность N6 v2.
- Некоторые ported-модели могут терять часть аппаратных или облачных функций.

## Не включать в короткий пользовательский список пока

Модели со статусом EoL/EoD в Keenetic Ported не должны попадать в основной список «купить сейчас» без отдельной причины. Они могут оставаться в исторической compatibility matrix для уже имеющихся устройств.

Примеры: Xiaomi Router 4/4A, Xiaomi Router 3P, SmartBox Turbo/Pro и другие устройства, для которых upstream прекратил или ограничил развитие порта.

## Следующий шаг

Reference inventory теперь нужен не для того, чтобы разрешить вообще публиковать требования, а для их уточнения: измерить реальный запас RAM/storage, зафиксировать версии пакетов и со временем подтвердить или снизить supported floor на более слабом железе.
