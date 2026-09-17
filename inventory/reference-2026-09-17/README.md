# HomeRoute reference inventory — 2026-09-17

Это обезличенный reference capture фактически работающего HomeRoute Golden State v0.1.

Сырые PuTTY/SSH-логи в Git не сохраняются. В каталог попали только allowlisted поля inventory и безопасный список `package/version`.

## Router

- Device: Netis N6 v1 AX1800 (operator-confirmed reference device)
- KeeneticOS: 5.00.C.9.0-1 (observed in SSH banner)
- Kernel: Linux 4.9-ndm-5
- Architecture: MIPS / MT7621
- RAM total: 254664 KiB (~248.7 MiB)
- RAM available at capture: 94936 KiB (~92.7 MiB, ~37.3%)
- `/opt` total: 47480 KiB (~46.4 MiB)
- `/opt` free at capture: 22428 KiB (~21.9 MiB, ~47.2%)
- OPKG architectures: `all,mipsel-3.4,mipsel-3.4_kn`
- AWG, HRNeo, nfqws and tg-ws-proxy binaries were present.

The preflight could not obtain model/release through nested `ndmc`; these two safe fields were completed from already-observed operator/banner evidence. No serial, MAC, WAN address or credentials were added.

## VPS

- OS: Ubuntu 26.04
- Kernel: 7.0.0-31-generic
- Architecture: x86_64
- vCPU: 1
- RAM total: 2009924 KiB (~1.92 GiB)
- RAM available at capture: 1336612 KiB (~1.27 GiB, ~66.5%)
- Root filesystem total: 30866836 KiB (~29.44 GiB)
- Root filesystem free at capture: 14153056 KiB (~13.50 GiB, ~45.9%)
- Docker: 29.1.3
- `amnezia-awg2`: running
- `adguard-home`: running
- AWG interface `awg0`: present

## Evidence meaning

This capture proves the current Golden State works on this reference configuration. It does **not** prove that these exact resource values are the physical minimum. Per HomeRoute policy:

- current reference configuration = `Verified baseline`;
- lower resource profile = `Not validated`;
- equal/higher resources with compatible software/tooling = `Expected compatible`;
- another device becomes `Verified` only after clean reproduction.

## Files

- `router-reference.json` — sanitized router inventory;
- `vps-reference.json` — sanitized VPS inventory;
- `router-packages.json` — sanitized Entware package/version snapshot.
