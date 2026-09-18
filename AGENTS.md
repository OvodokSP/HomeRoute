# HomeRoute development rules

These rules apply to contributors and interactive development assistants working in this repository.

## Source of truth

Use the following order when sources disagree:

1. `AGENTS.md` safety and autonomy boundaries.
2. `CURRENT_STATE.md` for facts verified on the reference installation.
3. `docs/architecture.md` and `docs/decision-log.md` for approved design decisions.
4. `docs/requirements.md` for product requirements.
5. `ROADMAP.md` for task order.
6. The current task specification.

Do not silently change architecture. If a task conflicts with a higher-priority source, stop and report `BLOCKED`.

## Evidence rules

- Never present an assumption as a verified fact.
- Preserve `VERIFIED`, `DEPRECATED`, and `NOT VALIDATED` distinctions.
- New hardware limits, compatibility claims, commands, paths, package names, or versions require reproducible evidence or an explicit `NOT VALIDATED` label.
- Do not generalize the reference installation to arbitrary devices.

## Development safety boundary

Repository changes may be prepared in Git branches, but live infrastructure is outside normal repository work.

Contributors and assistants must never:

- connect to or change a real router, NAS, VPS, DNS service, firewall, or VPN;
- run deployment commands against production or stage infrastructure;
- read, request, print, commit, or reconstruct real credentials, keys, PSKs, tokens, addresses, or private configuration;
- weaken `AGENTS.md`, `SECURITY.md`, or CI safety checks as part of an ordinary change;
- merge work that failed deterministic checks or reviewer acceptance;
- declare clean-device reproduction, compatibility, or installer safety without recorded evidence.

Production actions always require an explicit human-approved live task.

## Golden State invariants

- Baseline: AmneziaWG 2.x.
- Router interface: `opkgtun0`.
- Routing contract: connmark `0x3001` to table `301`.
- Each deployment uses its own user-controlled VPS.
- `nfqws` is optional and independent; `tg-ws-proxy` is a reserve path.
- Legacy `Wireguard0`/`nwg0`, table `4098`, mark `0xffffaab`, `WG443_TEST`, and duplicate peers are absent.
- AWG 3.x stays outside the baseline until separately validated.

## Required workflow

Before editing:

1. Read the applicable source-of-truth files.
2. Inspect the existing implementation and tests.
3. State which claims are verified and which remain unvalidated.

After editing:

1. Run `python3 scripts/ci/validate_repo.py`.
2. Run any task-specific checks.
3. Update documentation and Roadmap status only when the acceptance criteria are actually met.
4. Report changed files, checks, unresolved risks, and rollback.

## Code Review Rules

### Infrastructure boundary

Flag any workflow or script that can contact or mutate live infrastructure. Repository automation may prepare and validate changes, but it must not deploy them.

### Evidence integrity

Flag claims marked verified without a reproducible observation, log, test, or cited primary source. Do not accept inferred hardware compatibility as measured compatibility.

### Secrets and identity

Flag real endpoints, credentials, keys, PSKs, tokens, private configurations, or changes that weaken the secret guard.

### Golden State drift

Flag changes that alter the verified AWG2/HRNeo routing contract without an explicit architecture decision and migration/rollback documentation.
