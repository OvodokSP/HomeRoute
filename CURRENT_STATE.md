# HomeRoute current state

Snapshot date: 2026-09-18.

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
- Live router and VPS doctor checks were completed on 2026-09-17; the router FORWARD false-negative was isolated to the checker and fixed with a regression test.
- On 2026-09-18 the VPS dedicated-filesystem transaction canary completed PASS: an existing file was changed then restored, a transaction-created file was removed, and unrelated state remained unchanged.
- On 2026-09-18 sanitized VPS runtime metadata was captured for AWG2 and AdGuard without reading environment values, IP addresses, port mappings, mount source paths, labels, command lines, config contents, or credentials.
- On 2026-09-18 sanitized container-shape capture verified AWG2 networks `amnezia-dns-net` + `bridge`, its `/lib/modules` bind destination, UDP container port `35404`, and AdGuard's `amnezia-dns-net` attachment plus persistent container-side destinations `/opt/adguardhome/conf` and `/opt/adguardhome/work`. Host paths, host ports, IP addresses and secrets were deliberately not captured.
- The observed AWG2 container has no dedicated persistent bind for `/opt/amnezia/awg`; replacing that container must therefore be preceded by an explicit backup/export of AWG state.
- The official Amnezia client source at commit `de93650a90739b87bb47a632872ea9d0adc9412f` contains AWG Dockerfile/run/configure/start scripts whose container shape matches the observed restart/privileged/module-mount/UDP-port/DNS-network pattern.
- That pinned source recipe is not a deterministic image pin: its Dockerfile still uses `amneziavpn/amneziawg-go:latest`, so exact clean-build provenance remains unverified.
- On 2026-09-18 a real root-only backup of the running AWG2 state completed successfully: 5 files, 40 KiB, checksum verification PASS, backup directories mode 0700, metadata/manifest mode 0600, owner root:root. No container restart, configuration change or restore was performed.
- The AWG restore algorithm is tested only in an isolated filesystem sandbox, including successful restore, per-file SHA256 verification, forced verification failure and rollback to pre-existing state. Live AWG restore remains unvalidated.

## VERIFIED — component roles and package roots

- AmneziaWG 2.x is the current baseline.
- HRNeo owns selective policy routing.
- `nfqws` is an independent optional component.
- `tg-ws-proxy` is retained only as a reserve path.
- Every deployment must use a separate working VPS controlled by that deployment's user.
- The evidence-backed router core install roots are `chur-amneziawg` and `hrneo`.
- `chur-amneziawg` upstream metadata resolves the AWG userspace/runtime packages; HRNeo upstream metadata resolves its runtime dependencies.
- Optional/reserve package profiles are disabled by default; `UNCLASSIFIED` reference packages are never promoted to install roots automatically.

## VERIFIED — supported floor policy

- The current working router/VPS resource profile is the `Verified baseline` supported floor for v1.
- Less-resourced systems are `Not validated`, not declared incompatible.
- Equal-or-higher resource systems are only `Expected compatible` when the required platform/software architecture is compatible.
- This policy is not a claim about the physical minimum required to run HomeRoute.

## DEPRECATED — must remain absent

- `Wireguard0` and runtime interface `nwg0`.
- Routing table `4098` and the former `HydraRoute` policy.
- Legacy mark `0xffffaab`.
- The old ordinary WireGuard peer used by Keenetic.
- `WG443_TEST` rules.
- Duplicate peers using the same client address.

## NOT VALIDATED

- Automated live apply on a clean router or VPS.
- Full live restore/rollback for real managed router/VPS objects (VPS filesystem transaction and live AWG backup are verified; live AWG restore and router restore remain unvalidated).
- Physical minimum router/VPS resource requirements below the supported floor.
- A complete clean-device-verified hardware compatibility matrix.
- Generic Netis flashing instructions for specific models.
- Stable production installers.
- AmneziaWG 3.x on the target Keenetic/KeeneticOS environment.

Claims in the `NOT VALIDATED` section must not be promoted to verified status without recorded evidence.
