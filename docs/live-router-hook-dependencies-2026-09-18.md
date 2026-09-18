# Reference router hook dependency capture — 2026-09-18

The allow-listed read-only persistence-hook dependency capture completed PASS on the working reference Keenetic.

## Safety boundary

The capture reported:

- read-only mode;
- arbitrary source printing disabled;
- secret values printing disabled;
- only allow-listed booleans/counts and hook identity metadata.

No hook source lines, keys, endpoint values, interface addresses, peer material or configuration contents were printed.

## Captured hook graph

### `/opt/etc/init.d/S98telegram-awg`

- SHA-256: `8165d5be13e57aa13eca8fb38a95bc179e37582f64732bd0e45a013727303504`
- 1101 bytes / 61 lines
- 4 distinct `/opt/...` path references
- references `awg-quick`, AWG and `opkgtun0`
- start/stop/restart and up/down semantics detected
- action/interface variables detected
- sleep detected
- no direct `ip rule`, `ip route`, `iptables` or `ipset` mutation detected

### `/opt/etc/init.d/S99hrneo`

- SHA-256: `cd39a8804b991ae96995746e090a2b46e953930c7c8b89e27f11d4845abe3ceb`
- 222 bytes / 11 lines
- 3 distinct `/opt/...` path references
- sources `rc.func`
- references HRNeo
- no direct network mutation detected
- lifecycle action words were not directly present, consistent with delegation through `rc.func`

### `/opt/etc/ndm/netfilter.d/014-telegram-awg.sh`

- SHA-256: `c6766c421171d06a13ed8b30baa8d586a10a1373fce378f51bb94fdd46eff6f1`
- 118 bytes / 6 lines
- 2 distinct `/opt/...` path references
- no direct network mutation detected
- no recognized direct reference to `S98telegram-awg` or `S99hrneo`

### `/opt/etc/ndm/netfilter.d/015-hrneo.sh`

- SHA-256: `fa01637e206c4c1a40d009a1b656ea9c98e8b94e652b720a9f1b4912af9c7342`
- 169 bytes / 9 lines
- no `/opt/...` path references detected
- references HRNeo
- no direct network mutation detected

### `/opt/etc/ndm/ifstatechanged.d/014-telegram-awg.sh`

- SHA-256: `4eafa3bab0b1a1b439ed7eb4bd0ec85705a56d60730f9a46f0e30aa48930d9d2`
- 161 bytes / 9 lines
- 2 distinct `/opt/...` path references
- conditional `opkgtun0` handling detected
- no direct network mutation detected
- no recognized direct reference to `S98telegram-awg` or `S99hrneo`

### `/opt/etc/ndm/ifstatechanged.d/015-hrneo.sh`

- exact same SHA-256/size/line count as the netfilter HRNeo hook;
- references HRNeo;
- no direct network mutation detected.

## Interpretation

The dependency capture confirms that the persistence layer is mostly delegation/orchestration rather than inline routing/firewall implementation.

The capture is sufficient to formalize the reference contract and renderer gates, but it is **not** sufficient to reconstruct exact hook source from semantics alone. In particular, the two `014-telegram-awg` NDM hooks contain unclassified `/opt/...` references whose exact targets remain unresolved.

HomeRoute therefore must not synthesize those hook bodies from guesses. The reproduction-only router renderer must either:

1. consume a verified exact hook bundle captured from the reference deployment, or
2. wait until the remaining dependency targets are independently identified and a deterministic replacement implementation is reviewed.

This unresolved source-level detail is a renderer gate, not a runtime-health problem; the working reference router remains PASS.
