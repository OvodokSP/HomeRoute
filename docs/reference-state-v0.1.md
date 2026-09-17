# HomeRoute Golden State v0.1

Это фактически проверенное состояние после reboot Keenetic и полного reboot VPS, а не предполагаемая архитектура.

## Keenetic

Подтверждены KeeneticOS, Entware/opkg, HRNeo, интерфейс `opkgtun0` с AWG client address `/32`, mark `0x3001`, table `301`, маршрут `default dev opkgtun0`, FORWARD из LAN, MASQUERADE, persistence hooks и Telegram IPv4 networks в одноимённом ipset. `nfqws` работает независимо, `tg-ws-proxy` сохраняется как резерв.

## VPS

Подтверждены Linux, Docker, контейнер AWG2, AdGuard Home, DNS redirect TCP/UDP 53 для AWG-клиентов и автоматическое восстановление после reboot.

## Отсутствующий legacy

В Golden State отсутствуют `Wireguard0`, `nwg0`, policy `HydraRoute`, mark `0xffffaab`, table `4098`, прежний обычный WireGuard peer Keenetic, `WG443_TEST` и дублирующий AWG peer для одного client IP.

## Ограничения

Состояние ещё не воспроизведено на чистом устройстве. Автоматические installers не валидированы. Reference-набор адресов со временем должен проверяться.
