# Reference router semantic capture — 2026-09-18

The sanitized read-only reference capture completed PASS on the working Keenetic.

## Persistence hook identities

- `/opt/etc/init.d/S98telegram-awg`
  - SHA-256: `8165d5be13e57aa13eca8fb38a95bc179e37582f64732bd0e45a013727303504`
  - 1101 bytes / 61 lines
  - executable, valid shell
  - references AWG / `awg-quick`
  - contains service start/stop semantics
- `/opt/etc/init.d/S99hrneo`
  - SHA-256: `cd39a8804b991ae96995746e090a2b46e953930c7c8b89e27f11d4845abe3ceb`
  - 222 bytes / 11 lines
  - executable, valid shell
  - references HRNeo
- `/opt/etc/ndm/netfilter.d/014-telegram-awg.sh`
  - SHA-256: `c6766c421171d06a13ed8b30baa8d586a10a1373fce378f51bb94fdd46eff6f1`
  - 118 bytes / 6 lines
  - executable, valid shell
- `/opt/etc/ndm/netfilter.d/015-hrneo.sh`
  - SHA-256: `fa01637e206c4c1a40d009a1b656ea9c98e8b94e652b720a9f1b4912af9c7342`
  - 169 bytes / 9 lines
  - executable, valid shell
  - references HRNeo
- `/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh`
  - SHA-256: `4eafa3bab0b1a1b439ed7eb4bd0ec85705a56d60730f9a46f0e30aa48930d9d2`
  - 161 bytes / 9 lines
  - executable, valid shell
  - references `opkgtun0`
- `/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh`
  - same SHA-256 as the netfilter HRNeo hook
  - 169 bytes / 9 lines
  - executable, valid shell
  - references HRNeo

No hook contents, secrets, endpoints, addresses, peers or keys were printed.

## HRNeo mutable configuration shape

- `hrneo.conf` SHA-256: `2ff73835b812249222b86637a563de640aac48cd5bf55423487bf59ee47df77f`
- `domain.conf` SHA-256: `353057ff67e0d26492f0f990f42b04705fef0ed4c46fb6e399ab8f9ff3cb5350`
- `ip.list` SHA-256: `5f9d50cee903da929966e1ce88cae995da1c5a670e219513a93246970d46fb53`
- active non-comment/non-empty lines: 8 / 10 / 9
- `PolicyOrder=opkgtun0`: confirmed
- contents printed: false

## Package baseline

- `chur-amneziawg 1.0.0-1`
- `chur-amneziawg-go f4f4c99-1`
- `chur-amneziawg-tools 1.0.20260223-2`
- `hrneo 3.18.3-1`

All four packages were reported installed.

## AWG runtime shape

- interface: `opkgtun0`
- interface present: true
- address prefix: `/32`
- MTU: `1324`
- peers: 1
- recorded handshake: true
- addresses/peers/endpoints/keys printed: false

## Routing/firewall runtime invariants

All captured invariants were true:

- ip rule -> table 301;
- table 301 default -> `opkgtun0`;
- FORWARD `br0 -> opkgtun0`;
- MASQUERADE via `opkgtun0`;
- mark `0x3001`;
- ipset `opkgtun0`.

## Remaining reproduction input

The semantic capture proves the final runtime shape but not the delegation graph of the small persistence hooks. The next sanitized capture is limited to allow-listed dependency/action markers and does not print arbitrary source lines or values.
