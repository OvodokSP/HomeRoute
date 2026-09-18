# Установка HomeRoute

Эта страница описывает установку с точки зрения обычного пользователя.

## Текущий статус

Полностью автоматическая чистая установка пока **не выпущена**. Безопасный режим проверки уже готов, но команда, которая сама изменяет роутер или VPS, намеренно заблокирована до контрольного восстановления и первого чистого воспроизведения.

Это означает, что сейчас можно:

- проверить роутер и VPS;
- проверить совместимость;
- увидеть план установки;
- проверить уже работающую систему;
- подготовить всё необходимое для чистой установки.

Но нельзя честно обещать установку одной командой на пустое устройство. Как только этот этап будет подтверждён на чистом стенде, эта страница станет основной пошаговой инструкцией.

## 1. Подготовьте роутер

Нужно:

- KeeneticOS;
- Entware;
- доступ в shell Entware;
- достаточно памяти и свободного места.

Проверка:

```sh
wget -O /tmp/homeroute-preflight-router.sh \
  https://raw.githubusercontent.com/OvodokSP/HomeRoute/main/router/preflight-router.sh
chmod 700 /tmp/homeroute-preflight-router.sh
sh /tmp/homeroute-preflight-router.sh
```

Если скрипт показывает Entware, `opkg`, подходящую архитектуру и достаточный запас ресурсов, можно переходить дальше.

## 2. Посмотрите план установки роутера

```sh
wget -O /tmp/homeroute-router-install.sh \
  https://raw.githubusercontent.com/OvodokSP/HomeRoute/main/router/install.sh
chmod 700 /tmp/homeroute-router-install.sh
sh /tmp/homeroute-router-install.sh plan
```

Режим `plan` ничего не меняет. Он показывает, что HomeRoute ожидает увидеть и какие части ещё требуют установки.

Основные компоненты роутера:

- AmneziaWG;
- HydraRoute Neo;
- служебные зависимости Entware.

`nfqws` не является обязательной частью HomeRoute. `tg-ws-proxy` используется только как резервный канал.

## 3. Подготовьте VPS

Для опорной схемы нужен VPS под вашим управлением. Проверенный проектом уровень — 1 vCPU, около 2 ГБ RAM и 30 ГБ диска.

Проверка:

```sh
curl -fsSLo /tmp/homeroute-preflight-vps.sh \
  https://raw.githubusercontent.com/OvodokSP/HomeRoute/main/vps/preflight-vps.sh
chmod 700 /tmp/homeroute-preflight-vps.sh
sh /tmp/homeroute-preflight-vps.sh
```

## 4. Посмотрите план установки VPS

```sh
curl -fsSLo /tmp/homeroute-vps-install.sh \
  https://raw.githubusercontent.com/OvodokSP/HomeRoute/main/vps/install.sh
chmod 700 /tmp/homeroute-vps-install.sh
sh /tmp/homeroute-vps-install.sh plan
```

Режим `plan` также не меняет систему.

## 5. Что появится после завершения установщика

Итоговая установка будет идти в таком порядке:

1. проверка оборудования и свободного места;
2. резервная копия затрагиваемых файлов и настроек;
3. установка только необходимых пакетов;
4. настройка AmneziaWG;
5. настройка выборочной маршрутизации;
6. проверка маршрутов, DNS и сохранения после перезагрузки;
7. автоматический откат, если проверка не пройдена.

До завершения контрольного теста команда `apply` специально возвращает отказ и не вносит изменений.

## Если HomeRoute уже работает

Не пытайтесь переустанавливать его. Для проверки используйте [инструкцию по работе и диагностике](usage.md).
