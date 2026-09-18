# Router live baseline and filesystem canary — 2026-09-18

Reference Keenetic/ported-router validation completed successfully.

## Runtime doctor

`router/doctor-router.sh`:

- pass: 26;
- warn: 0;
- fail: 0;
- result: PASS.

The validated runtime included:

- `opkgtun0` present with IPv4;
- AWG state and latest handshake present;
- HRNeo running;
- PolicyOrder/ipset/mark/table 301 path present;
- FORWARD + MASQUERADE present;
- all six persistence hooks present;
- optional nfqws and reserve tg-ws-proxy running;
- legacy `nwg0`, table 4098, mark `0xffffaab` and legacy HydraRoute ipsets absent.

## Entware/package baseline

Observed architecture:

- `all`;
- `mipsel-3.4`;
- `mipsel-3.4_kn`.

Core package versions:

- `chur-amneziawg 1.0.0-1`;
- `chur-amneziawg-go f4f4c99-1`;
- `chur-amneziawg-tools 1.0.20260223-2`;
- `hrneo 3.18.3-1`.

Observed HRNeo feed:

`https://git.zerrolabs.org/Ground-Zerro/release/pages/keenetic/mipselsf-k3.4`

Observed Chur feed:

`https://ward-sentry.github.io/chur-keenetic/latest/mipsel-3.4`

## Storage

`/opt` is backed by a 46.4 MiB filesystem; during capture 21.9 MiB remained available.

## Live filesystem transaction canary

The dedicated `/opt/tmp/homeroute-live-canary` transaction completed PASS:

- existing file snapshot/modify/restore: PASS;
- transaction-created file removal: PASS;
- unrelated file preservation: PASS;
- leftovers after cleanup: none.

Post-check:

- HRNeo process: running;
- `opkgtun0`: present.

## Safety boundary

No packages were installed/removed/upgraded. No routes, firewall rules, VPN state, feeds, HomeRoute runtime configuration or persistence hooks were changed.
