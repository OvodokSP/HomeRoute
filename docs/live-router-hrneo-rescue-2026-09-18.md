# Router HRNeo rescue-set evidence — 2026-09-18

Reference Keenetic rescue capture completed successfully before any package transaction.

## Result

`router/prepare-hrneo-rescue.sh capture` reported:

- package: `hrneo`;
- version: `3.18.3-1`;
- Entware architecture: `mipsel-3.4`;
- regular package-owned files captured: 7;
- symlinks: 0;
- missing package-owned paths: 0;
- pinned artifact SHA-256: `811fe75ee6a566dc0404dfb5943f9a1f6d102459c3b9cbd4d340b5d4f1aeb450`;
- package change: false;
- service restart: false;
- network change: false;
- result: PASS.

The local rescue set was written to:

`/opt/homeroute-backups/hrneo-rescue-20260918T170237Z`

The independent rescue verifier then completed PASS for the same version, architecture, 7 regular files and pinned artifact SHA-256.

## Post-check

Router doctor completed 26/26 PASS after capture.

The reference `/opt` filesystem then had:

- size: 46.4 MiB;
- used: 22.6 MiB;
- available: 21.4 MiB;
- usage: 51%.

## Safety boundary

No package install/remove/upgrade/reinstall occurred. HRNeo was not restarted. AWG, routes, firewall and persistence hooks were not changed.

## Remaining package-transaction boundary

Before a live `opkg` reinstall/rollback test, HomeRoute must also account for the package database/control-script state under `/opt/lib/opkg/info/hrneo.*`, because maintainer scripts can cause service/runtime side effects independently of package-owned data files.
