# Controlled HRNeo live rollback rehearsal

This gate validates the real automatic rollback failure path on the reference router.

The rehearsal is intentionally destructive-but-recoverable: it performs a same-version reinstall of the exact pinned local HRNeo `3.18.3-1` artifact and deliberately fails verification immediately after package postinst. The validator must then restore the full state captured immediately before the rehearsal.

Before forcing the failure, the rehearsal creates a **fresh rescue set** of the current clean state:

- HRNeo package-owned files and exact pinned IPK;
- `/opt/lib/opkg/info/hrneo.*`;
- `/opt/bin/neo` and `rc.unslung`;
- the complete `/opt/lib/opkg/status` database.

The pre-transaction and post-rollback state is checked by `verify-hrneo-live-rescue-state.sh`. That verifier requires byte-level equality for package files, HRNeo opkg-info, side-effect state and global opkg status, requires no `*-opkg` residue, and requires router doctor PASS.

The rollback routine also explicitly removes only the three observed/expected conffile alternates:

- `hrneo.conf-opkg`;
- `domain.conf-opkg`;
- `ip.list-opkg`.

Any other `*-opkg` file causes rollback verification to fail rather than being deleted.

A successful rehearsal therefore means:

- forced post-install failure was reached;
- automatic rollback reported PASS;
- installed package set is unchanged;
- live state exactly matches the fresh rescue again;
- no generated conffile residue remains;
- router doctor passes after rollback.

Until a reference-router run is recorded, the status remains **LIVE PENDING**.
