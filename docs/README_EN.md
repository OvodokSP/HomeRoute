# HomeRoute

[Русская версия](../README.md)

HomeRoute is a reproducible method for building and recovering home network infrastructure. It integrates documentation, diagnostics, and automation around existing solutions; it is not a new VPN or DPI-bypass implementation and does not replace upstream projects.

It is intended to help users recreate a setup after replacing or reflashing a router, move it to another home or compatible device, and use a separate user-owned VPS for each deployment.

## High-level architecture

The verified **HomeRoute Golden State v0.1** Telegram path is:

```text
LAN client → HRNeo → ipset opkgtun0 → CONNMARK 0x3001
→ ip rule → routing table 301 → default dev opkgtun0
→ AmneziaWG 2.x → VPS → AWG2 → Internet
```

HRNeo orchestrates selective routing, `opkgtun0` is the dedicated AWG interface, and the user's VPS terminates the tunnel. `nfqws` is an independent optional layer; `tg-ws-proxy` is retained as a reserve path.

## v0.1 status

The reference state survived both a Keenetic reboot and a full VPS reboot. AWG2 recovery, HRNeo selective routing, routing/NAT rules, TCP/UDP DNS redirection, and legacy cleanup were verified.

Clean-device reproduction, hardware requirements, and real installers are not validated yet. Installer scripts are safe PRE-ALPHA placeholders. AmneziaWG 2.x remains the baseline; AWG 3.x is not currently adopted.

## Documents

- [Architecture (Russian)](architecture.md)
- [Requirements (Russian)](requirements.md)
- [Security (Russian)](../SECURITY.md)
- [Acknowledgements](ACKNOWLEDGEMENTS_EN.md)
- [Current status (Russian)](../STATUS.md)
