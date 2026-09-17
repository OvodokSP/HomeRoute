# HomeRoute current state

Snapshot date: 2026-09-17.

This document contains only the current reference state confirmed during the HomeRoute investigation. It is the factual baseline for agents and maintainers.

## VERIFIED — reference installation

- Telegram selective routing uses HRNeo and the dedicated router interface `opkgtun0`.
- Telegram flows receive connmark `0x3001` and are selected by an `ip rule` for routing table `301`.
- Table `301` contains `default dev opkgtun0`.
- `opkgtun0` uses the reference client address `10.8.1.11/32`.
- LAN forwarding and MASQUERADE through `opkgtun0` work.
- The AmneziaWG handshake and traffic transfer work.
- The VPS terminates the tunnel with the AWG2 container; AdGuard Home shares the deployment network.
- TCP and UDP DNS redirection on port 53 for AWG clients is present.
- Persistence hooks restore the working route after a controlled restart and a normal Keenetic reboot.
- A full VPS reboot and a normal Keenetic reboot were completed successfully.

## VERIFIED — component roles

- AmneziaWG 2.x is the current baseline.
- HRNeo owns selective policy routing.
- `nfqws` is an independent optional component.
- `tg-ws-proxy` is retained only as a reserve path.
- Every deployment must use a separate working VPS controlled by that deployment's user.

## DEPRECATED — must remain absent

- `Wireguard0` and runtime interface `nwg0`.
- Routing table `4098` and the former `HydraRoute` policy.
- Legacy mark `0xffffaab`.
- The old ordinary WireGuard peer used by Keenetic.
- `WG443_TEST` rules.
- Duplicate peers using the same client address.

## NOT VALIDATED

- Automated installation on a clean router or VPS.
- Minimum and recommended router CPU, RAM, and storage requirements.
- A complete hardware compatibility matrix.
- Generic Netis flashing instructions for specific models.
- Stable production installers.
- AmneziaWG 3.x on the target Keenetic/KeeneticOS environment.

Claims in the `NOT VALIDATED` section must not be promoted to verified status without recorded evidence.
