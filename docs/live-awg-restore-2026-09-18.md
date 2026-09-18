# Live AWG same-state restore validation — 2026-09-18

Reference VPS controlled restore validation completed successfully.

## Result

`vps/validate-live-awg-restore.sh validate` reported:

- readiness: PASS;
- quiescent snapshot: PASS;
- stopped-container restore round-trip: PASS;
- container recreated: false;
- image load: false;
- AdGuard touched: false;
- AWG runtime interface: PASS;
- TCP/UDP DNS DNAT 53: PASS;
- validation window: 6 seconds;
- live restore validated: true;
- final result: PASS.

Post-check confirmed:

- `amnezia-awg2`: running;
- `adguard-home`: running.

## Interpretation

This validates the live AWG same-state recovery path on the reference VPS. The running AWG container was gracefully stopped, its quiescent current state was captured, the same state was copied back while stopped and byte-verified, then the original container was started and the runtime interface plus DNS interception were re-verified.

No container recreate/remove or image load occurred. AdGuard was not stopped or modified.

This closes the AWG portion of the VPS live restore validation. AdGuard live restore validation remains pending.
