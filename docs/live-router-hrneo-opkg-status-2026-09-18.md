# Router HRNeo global opkg status rescue evidence — 2026-09-18

Reference Keenetic global opkg package-database capture completed successfully before any package transaction.

## Result

`router/capture-hrneo-opkg-status.sh` reported:

- package: `hrneo`;
- version: `3.18.3-1`;
- saved global opkg status SHA-256: `cb56bc8256435b0a9ccac9d4211b3534cca873d12facdac339bc4fe5596eb2f9`;
- saved global opkg status size: 18070 bytes;
- saved HRNeo status-stanza SHA-256: `dd38c71c0f99bf2c8dd2f79564cac679b34a682cfa90658d4507d942c3f4675a`;
- package change: false;
- service restart: false;
- network change: false;
- result: PASS.

The independent verifier completed PASS for the same status database and HRNeo stanza.

Router doctor completed 26/26 PASS after capture. `/opt` had 21.5 MiB available.

The rescue set at `/opt/homeroute-backups/hrneo-rescue-20260918T170237Z` now covers package-owned files, HRNeo opkg-info/control state, postinst side-effect state and the global opkg status database.

No package reinstall has been executed yet.
