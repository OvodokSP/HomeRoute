# Reproduction development continuity — 2026-09-18

This is the handoff checkpoint for continuing HomeRoute without repeating completed live validation.

## Do not repeat

The following gates are already evidence-backed PASS:

- reference router/VPS doctor;
- router reboot persistence;
- VPS reboot persistence;
- router filesystem transaction canary;
- VPS filesystem transaction canary;
- AWG state backup and controlled live same-state restore;
- AdGuard state backup and controlled live same-state restore;
- exact running Docker image rescue export/verify;
- HRNeo exact artifact capture;
- HRNeo full package/opkg/status rescue;
- HRNeo controlled same-version reinstall;
- HRNeo generated conffile cleanup;
- mutable HRNeo conffile model;
- forced post-install automatic HRNeo rollback;
- sanitized router semantic capture;
- allow-listed router persistence-hook dependency capture.

HL-404 (live backup/restore validation) is complete.

## Current development model

Stable `apply` remains disabled until HL-502.

The repository now separates:

- public reference contracts;
- public machine-readable reproduction gates;
- local ignored router/VPS reproduction bundles;
- plan renderers;
- future explicit `reproduction-apply`;
- stable/general `apply` promotion after HL-502 only.

## Router blockers

### 1. Exact hook source bundle

Semantic/dependency fingerprints are live PASS, but semantics alone cannot reconstruct the six persistence hook files safely.

Prepared next live tool:

`router/export-reference-hooks.sh`

It:

- verifies all six current hook SHA-256 identities;
- runs shell syntax checks;
- refuses obvious credential/endpoint/IP-literal content;
- writes a mode-0600 local tar under `/opt/tmp`;
- prints only archive path/size/SHA, not source contents.

When the user returns, this is the next Keenetic interaction. The resulting archive should be copied off the router and supplied as a file for review; do not paste hook contents manually unless specifically needed.

### 2. Exact Chur/AWG IPK artifact identity

Source recipe evidence is PASS at upstream commit:

`ward-sentry/chur-keenetic@a445e93b305d439ae1d797a54cee67aff8e36ae2`

Confirmed source/package versions match the reference router, but HomeRoute has not independently pinned the published IPK bytes.

Do not replace this with a guess based on filename or mutable `latest` feed.

## VPS blockers

The four exact rescue artifacts can form a local VPS reproduction bundle.

Remaining implementation blockers:

- target-local host paths/port inputs;
- complete deterministic container creation renderer;
- complete DNS helper target-resolution semantics;
- reproduction-only apply engine.

## Useful commands on a development machine

Current gate status:

```sh
python3 scripts/reproduction/status.py
```

Router plan:

```sh
python3 scripts/reproduction/render_router_plan.py
```

VPS plan:

```sh
python3 scripts/reproduction/render_vps_plan.py
```

Bundle builders/verifiers operate only on ignored local input directories under `reproduction/local/`.

## Promotion rule

No item is promoted to PASS from inference. Stable apply remains blocked until a real HL-502 run completes with clean initial state, no undocumented fixes, doctor PASS before/after reboot, functional PASS, idempotency evidence and sanitized reproduction record.
