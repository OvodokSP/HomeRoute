# Live AdGuard same-state restore validation — 2026-09-18

Reference VPS controlled restore validation completed successfully.

## Result

`vps/validate-live-adguard-restore.sh validate` reported:

- readiness: PASS;
- quiescent snapshot: PASS;
- stopped-container restore round-trip: PASS;
- container recreated: false;
- image load: false;
- AWG touched: false;
- AdGuard configuration present: PASS;
- AWG DNS redirect: PASS;
- DNS UDP/53 probe: PASS;
- DNS TCP/53 probe: PASS;
- validation window: 10 seconds;
- live restore validated: true;
- final result: PASS.

Post-check confirmed:

- `amnezia-awg2`: running;
- `adguard-home`: running.

A final read-only restore-readiness check also passed: the four-artifact rescue set remained valid and both current image IDs still matched the saved rescue images.

## Interpretation

This validates the live AdGuard same-state recovery path on the reference VPS. The running AdGuard container was gracefully stopped, its quiescent current `conf/work` state was captured, the same state was copied back while stopped and byte-verified, then the original container was started. Real DNS responses were observed over UDP/53 and TCP/53.

AWG remained running and was not modified. No container recreate/remove or image load occurred.

Together with the previously validated AWG restore, the VPS service-state portion of HL-404 is now verified. Router/Keenetic live backup/restore validation remains pending.
