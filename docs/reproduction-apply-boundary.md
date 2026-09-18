# Reproduction-only apply boundary

HomeRoute separates two different concepts:

- **reproduction-apply** — an explicitly acknowledged experimental apply path used only to perform the first clean-device reproduction required by HL-502;
- **stable apply** — the normal user-facing live installer, which remains blocked until HL-502 has passed.

This split removes a dependency cycle: a clean reproduction cannot validate an installer if all real apply behavior is prohibited until after that same reproduction.

## Safety boundary

A reproduction-only apply implementation must:

- be unavailable by default;
- require a dedicated explicit ACK distinct from normal installer modes;
- refuse to run unless HL-404 live backup/restore evidence is already marked PASS;
- operate only on a separately agreed test router/VPS or an explicitly accepted destructive test window;
- require all local secret-bearing inputs to exist outside Git;
- create and verify rollback state before the first mutation;
- use pinned package/image identities or locally supplied exact artifacts;
- run doctor/functional post-checks;
- automatically rollback on failed verification when a validated rollback path exists;
- never promote itself to stable/general apply merely because one transaction succeeded.

## Promotion rule

Only a successful HL-502 run with:

- clean initial state;
- no undocumented manual fixes;
- router/VPS doctor PASS before and after reboot;
- end-to-end functional PASS;
- idempotency evidence;
- sanitized reproduction record;

may be used to review whether ordinary `apply` can be enabled.

## Current state

HL-404 is complete. The reproduction-only apply engines are **not implemented yet**. The next implementation input is a sanitized semantic capture of the reference router persistence hooks and runtime shape, followed by the corresponding VPS provisioning contract.
