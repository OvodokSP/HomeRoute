# Архитектура HomeRoute v0.1

## Назначение

HomeRoute документирует интеграцию уже существующих компонентов. Контракт проверенного Telegram-маршрута:

```text
LAN client
→ HRNeo
→ ipset opkgtun0
→ CONNMARK 0x3001
→ ip rule
→ routing table 301
→ default dev opkgtun0
→ AmneziaWG 2.x
→ VPS
→ AWG2
→ Internet
```

## Роли

- **KeeneticOS + Entware/opkg:** среда роутера.
- **HRNeo:** оркестратор policy/selective routing.
- **`opkgtun0`:** выделенный интерфейс клиента AmneziaWG с адресом `/32`.
- **mark `0x3001` и table `301`:** стабильный routing contract v0.1.
- **VPS + AWG2:** серверное завершение AWG-туннеля.
- **AdGuard Home:** DNS для AWG-клиентов с redirect TCP/UDP 53.
- **nfqws:** независимый необязательный слой, не часть AWG-маршрута.
- **tg-ws-proxy:** резервный Telegram-канал.

## Границы baseline

Baseline использует AmneziaWG 2.x. AWG 3.x не внедряется до отдельной проверки совместимости с целевым роутером и KeeneticOS.

Legacy-интерфейсы `Wireguard0`/`nwg0`, policy `HydraRoute`, mark `0xffffaab`, table `4098`, обычный WireGuard peer Keenetic, `WG443_TEST` и дублирующий AWG peer не являются частью Golden State.
