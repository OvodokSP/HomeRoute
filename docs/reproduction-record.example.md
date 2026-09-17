# Clean reproduction record — EXAMPLE

> Шаблон. Не относится к реальной установке. Не добавляйте credentials, keys, PSK, tokens, public infrastructure addresses или private configs.

## Run identity

- Run ID: `EXAMPLE`
- Date: `YYYY-MM-DD`
- HomeRoute commit/tag: `EXAMPLE`
- Device type: `Native Keenetic | Compatible KeeneticOS port`
- Router model: `NOT VALIDATED`
- Firmware: `NOT VALIDATED`
- VPS profile: `sanitized inventory reference`

## Clean-state evidence

- Router clean-state relative to HomeRoute: `PASS | FAIL | BLOCKED`
- VPS clean-state relative to HomeRoute: `PASS | FAIL | BLOCKED`
- Hidden prior HomeRoute state excluded: `PASS | FAIL | BLOCKED`

## Inventory

- Router inventory reference: `NOT VALIDATED`
- VPS inventory reference: `NOT VALIDATED`

## Plan

- Router plan: `PASS | FAIL | BLOCKED`
- VPS plan: `PASS | FAIL | BLOCKED`
- Unknown required dependencies: `NONE | LIST WITHOUT SECRETS`

## Backup gate

- Router backup prepared: `PASS | FAIL | NOT RUN`
- VPS backup prepared: `PASS | FAIL | NOT RUN`
- Rollback target unambiguous: `PASS | FAIL | NOT RUN`

## Apply

- Router apply version/status: `NOT IMPLEMENTED`
- VPS apply version/status: `NOT IMPLEMENTED`
- Undocumented manual fixes used: `NO`

## Verification before reboot

- Router doctor exit/result: `NOT RUN`
- VPS doctor exit/result: `NOT RUN`
- End-to-end functional scenario: `NOT RUN`

## Reboot persistence

- Router reboot + doctor: `NOT RUN`
- VPS reboot + doctor: `NOT RUN`
- End-to-end after both reboots: `NOT RUN`

## Idempotency

- Second plan: `NOT RUN`
- Second apply / NO CHANGE evidence: `NOT RUN`

## Rollback evidence

- Rollback test reference: `NOT RUN`
- Unrelated state preserved: `NOT RUN`

## Final decision

- Result: `BLOCKED`
- Reason: `Example template only`
- Secrets/public private configuration committed: `NO`
