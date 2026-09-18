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

HL-404 is complete. Router semantic and hook-dependency captures are live PASS. Public reference/gate contracts and local router/VPS bundle tooling are being implemented. Reproduction-only apply engines are still **not implemented**. Remaining router source-level inputs are exact persistence-hook source (or reviewed deterministic replacements) and content-pinned Chur/AWG artifacts; VPS still requires completion of deterministic container/DNS persistence rendering.
