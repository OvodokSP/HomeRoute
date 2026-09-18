# HRNeo package control boundary

Pinned upstream source: `Ground-Zerro/HydraRoute@984ec135dbc3e9fb54e0c8c63a0e2fd829538772`.

For HRNeo `3.18.3-1`, the pinned package control tree contains:

- `conffiles`;
- `control.in`;
- `postinst`.

No `preinst`, `prerm`, or `postrm` exists in that pinned source tree.

The pinned `postinst` SHA-256 is:

`ff4192e0d9532f4df550687625efd698c5bcdc3659cdb40d75517d36f0409c2e`

The pinned `conffiles` SHA-256 is:

`255dc6d5a636b8645d0e306224df597afa1e7529a8b85647c83c14efe6280f5d`

The conffiles are:

- `/opt/etc/HydraRoute/hrneo.conf`;
- `/opt/etc/HydraRoute/domain.conf`;
- `/opt/etc/HydraRoute/ip.list`.

The pinned postinst performs four relevant actions:

1. ensures `/opt/bin/neo -> /opt/etc/init.d/S99hrneo`;
2. conditionally inserts `[ $ACTION = start ] && sleep 10` into `/opt/etc/init.d/rc.unslung`;
3. runs `S99hrneo stop`;
4. runs `S99hrneo start`.

It does not contain an iptables/ipset/ip route mutation command and does not contain an `rm` command.

Before any live package reinstall, HomeRoute requires the installed `hrneo.postinst` and `hrneo.conffiles` hashes to match this pinned boundary, requires the `neo` symlink and `rc.unslung` patch to already be in their expected state, and captures all `/opt/lib/opkg/info/hrneo.*` plus these two side-effect objects into the existing rescue directory.

## Mutable conffile boundary

`hrneo.conf`, `domain.conf`, and `ip.list` are package-declared conffiles and must be treated as mutable user state, not immutable package identity. HomeRoute may retain them in a rescue snapshot for backup/evidence, but a later transaction must not require their bytes to still match that older snapshot. Immediately before `opkg`, the validator captures current hashes for all three and requires the package transaction not to alter them. Automatic rollback restores immutable package/opkg state and preserves the current conffiles rather than copying stale conffile bytes from the long-lived rescue set.
