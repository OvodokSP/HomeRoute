# Router HRNeo live rollback rehearsal evidence — 2026-09-18

Reference Keenetic completed the controlled HRNeo live rollback failure-path rehearsal successfully.

## Rehearsal result

`router/rehearse-hrneo-rollback.sh rehearse` reported:

- schema: 1;
- mode: rehearse;
- package: `hrneo`;
- version: `3.18.3-1`;
- fresh rescue: PASS;
- forced postinstall failure: true;
- automatic rollback: PASS;
- live state matches fresh rescue: true;
- installed package set unchanged: true;
- conffile residue: none;
- router doctor: PASS;
- validation window: 8 seconds;
- rescue directory: `/opt/homeroute-backups/hrneo-rescue-20260918T201739Z`;
- live rollback validated: true;
- result: PASS.

## Final state

After the forced failure and automatic rollback:

- router doctor completed 26/26 PASS;
- `hrneo 3.18.3-1` remained installed;
- HRNeo process was running;
- `opkgtun0` remained present;
- no `*-opkg` conffile residue remained;
- `/opt` had 20.3 MiB available.

## Interpretation

The reference router now has live evidence for the complete HRNeo package transaction lifecycle:

- full rescue capture;
- controlled same-version reinstall;
- post-transaction cleanup;
- mutable-conffile protection;
- forced post-install failure;
- automatic rollback;
- independent post-rollback verification.

Together with the previously completed VPS live restore validations, this closes the live backup/restore validation gate for HomeRoute v1.
