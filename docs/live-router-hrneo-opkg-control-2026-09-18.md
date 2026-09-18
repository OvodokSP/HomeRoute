# Router HRNeo opkg/control rescue evidence — 2026-09-18

Reference Keenetic control-metadata capture completed successfully before any package transaction.

## Result

`router/capture-hrneo-opkg-state.sh` reported:

- installed `hrneo.postinst` SHA-256 matched the pinned source;
- installed `hrneo.conffiles` SHA-256 matched the pinned source;
- maintainer scripts: `postinst` only;
- postinst creates/refreshes the `/opt/bin/neo` symlink;
- postinst contains the guarded `rc.unslung` start-delay patch;
- postinst performs `S99hrneo stop` then `start`;
- no network-mutation pattern was detected;
- no `rm` command pattern was detected;
- current `/opt/bin/neo` target matched `/opt/etc/init.d/S99hrneo`;
- current `rc.unslung` already contained the expected guarded delay line;
- four regular `/opt/lib/opkg/info/hrneo.*` files were captured;
- no opkg-info symlinks were present;
- package change: false;
- service restart: false;
- network change: false;
- result: PASS.

The independent opkg/control rescue verifier also completed PASS.

Router doctor completed 26/26 PASS after capture and the reference `/opt` filesystem still had 21.5 MiB available.

## Remaining package-database boundary

A same-version `opkg` reinstall can also update the global package database at `/opt/lib/opkg/status`. Before the controlled reinstall, HomeRoute must capture and checksum that file so rollback can restore both the HRNeo-specific info records and the package database entry consistently.
