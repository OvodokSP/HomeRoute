# Live isolated restore rehearsal evidence — 2026-09-18

The reference VPS completed the isolated stopped-container restore rehearsal successfully.

## Result

`vps/restore-rehearsal.sh rehearse` reported:

- rescue readiness: PASS;
- AWG backup Docker round-trip: PASS;
- AdGuard backup Docker round-trip: PASS;
- temporary containers started: false;
- temporary network: none;
- live containers touched: false;
- image load: false;
- live restore validated: false;
- final result: PASS.

Post-check confirmed:

- `amnezia-awg2`: running;
- `adguard-home`: running;
- temporary `homeroute-restore-*` containers remaining: none.

## Interpretation

This validates Docker copy/round-trip of the verified AWG and AdGuard backup sets on the live VPS while using the exact locally available rescue images.

It does not validate restoration into the running production service containers. HL-404 therefore remains open.
