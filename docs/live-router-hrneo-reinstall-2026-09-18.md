# Router HRNeo controlled reinstall evidence — 2026-09-18

Reference Keenetic controlled same-version reinstall completed successfully.

## Transaction

The exact pinned local HRNeo artifact `3.18.3-1` for `mipsel-3.4` was installed with the validated opkg command form:

`opkg --force-reinstall --nodeps install <local-pinned-ipk>`

The package postinst performed its expected brief HRNeo stop/start.

## Result

`router/validate-hrneo-reinstall.sh validate` reported:

- package: `hrneo`;
- version: `3.18.3-1`;
- installed package set unchanged: true;
- managed files match rescue: true;
- HRNeo opkg-info match rescue: true;
- postinst side-effect state idempotent: true;
- global opkg status database byte-identical: false;
- router doctor: PASS;
- validation window: 4 seconds;
- rollback: NOT_NEEDED;
- live package transaction validated: true;
- result: PASS.

The final router doctor completed 26/26 PASS. HRNeo was running and `opkgtun0` remained present.

## Expected conffile behavior observed

opkg preserved the three locally modified conffiles and wrote the package defaults beside them as:

- `/opt/etc/HydraRoute/hrneo.conf-opkg`;
- `/opt/etc/HydraRoute/domain.conf-opkg`;
- `/opt/etc/HydraRoute/ip.list-opkg`.

The original live conffiles remained unchanged, as confirmed by the validator's managed-file comparison against the pre-transaction rescue set.

These three generated `*-opkg` files are treated as transaction residue and must be captured by hash and removed explicitly before the reference state is considered clean again.

## Safety note

Automatic rollback was not needed on the live reference router, so the live rollback failure path remains unexercised. The rollback contract is CI-tested but is not yet promoted to live PASS.
