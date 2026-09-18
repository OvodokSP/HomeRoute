# Router HRNeo conffile cleanup evidence — 2026-09-18

Reference Keenetic cleanup completed successfully after the controlled same-version HRNeo reinstall.

## Result

`router/cleanup-hrneo-opkg-conffiles.sh clean` reported:

- expected artifacts: 3;
- captured artifacts: 3;
- captured bytes: 869;
- removed artifacts: 3;
- already clean: false;
- router doctor: PASS;
- service restart: false;
- package change: false;
- network change: false;
- result: PASS.

The three generated files were:

- `/opt/etc/HydraRoute/hrneo.conf-opkg`;
- `/opt/etc/HydraRoute/domain.conf-opkg`;
- `/opt/etc/HydraRoute/ip.list-opkg`.

Before removal, all three were copied into the local HRNeo rescue set and hashed. The three live conffiles were verified against the pre-reinstall rescue snapshot and were not modified by cleanup.

Final explicit check reported `OPKG_CONFFILE_RESIDUE=none`.

Router doctor completed 26/26 PASS after cleanup. `/opt` had 21.3 MiB available.

## Interpretation

The reference router is clean again after the successful live HRNeo same-version reinstall. The live package transaction and post-transaction cleanup are now validated.

The automatic rollback failure-path remains CI-tested but not live-validated.
