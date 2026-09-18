# HRNeo mutable conffile live validation — 2026-09-18

Reference Keenetic validated the corrected mutable-conffile model against rescue set:

`/opt/homeroute-backups/hrneo-rescue-20260918T184554Z`

## Hash comparison

- `hrneo.conf`: live == rescue
- `ip.list`: live == rescue
- `domain.conf`: live != rescue

Observed SHA-256:

- hrneo.conf: `2ff73835b812249222b86637a563de640aac48cd5bf55423487bf59ee47df77f`
- domain.conf live: `353057ff67e0d26492f0f990f42b04705fef0ed4c46fb6e399ab8f9ff3cb5350`
- domain.conf rescue: `50276055b1bc15c55e14d90b862077a30b40054daebb5f86a7b651e5b787f7ee`
- ip.list: `5f9d50cee903da929966e1ce88cae995da1c5a670e219513a93246970d46fb53`

## Corrected live-vs-rescue result

`verify-hrneo-live-rescue-state.sh` reported:

- immutable package files: PASS
- mutable conffiles: present_not_pinned
- opkg info: PASS
- side-effect state: PASS
- status database: PASS
- conffile residue: none
- router doctor: PASS
- result: PASS

Final router doctor: 26/26 PASS.

## Interpretation

The reference router confirms the corrected boundary: package-declared conffiles are mutable protected state and must not be pinned to an older rescue snapshot. Immutable HRNeo/opkg state remains fully verified against rescue.

The next pending gate is the controlled live rollback failure-path rehearsal using the corrected model.
