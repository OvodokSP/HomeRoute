# HomeRoute current state

Snapshot date: 2026-09-18.

This document contains only the current reference state confirmed during the HomeRoute investigation. It is the factual baseline for agents and maintainers.

## VERIFIED — reference installation

- Telegram selective routing uses HRNeo and the dedicated router interface `opkgtun0`.
- Telegram flows receive connmark `0x3001` and are selected by an `ip rule` for routing table `301`.
- Table `301` contains `default dev opkgtun0`.
- `opkgtun0` uses the reference client address `10.8.1.11/32`.
- LAN forwarding and MASQUERADE through `opkgtun0` work.
- The AmneziaWG handshake and traffic transfer work.
- The VPS terminates the tunnel with the AWG2 container; AdGuard Home shares the deployment network.
- TCP and UDP DNS redirection on port 53 for AWG clients is present.
- Persistence hooks restore the working route after a controlled restart and a normal Keenetic reboot.
- A full VPS reboot and a normal Keenetic reboot were completed successfully.
- Live router and VPS doctor checks were completed on 2026-09-17; the router FORWARD false-negative was isolated to the checker and fixed with a regression test.
- On 2026-09-18 the router doctor re-ran against the current reference installation and completed 26/26 PASS with no warnings/failures. The Entware architecture remained `mipsel-3.4` (plus `all` and `mipsel-3.4_kn`), core package versions remained `chur-amneziawg 1.0.0-1`, `chur-amneziawg-go f4f4c99-1`, `chur-amneziawg-tools 1.0.20260223-2`, and `hrneo 3.18.3-1`. A dedicated live filesystem transaction canary under `/opt/tmp/homeroute-live-canary` completed PASS and cleaned up fully; HRNeo remained running and `opkgtun0` remained present.
- On 2026-09-18 a live HRNeo rescue set was captured and independently verified before any package transaction: 7 regular package-owned files, no symlinks, no missing package paths, exact pinned `mipsel-3.4` IPK SHA-256 `811fe75ee6a566dc0404dfb5943f9a1f6d102459c3b9cbd4d340b5d4f1aeb450`, and no package/service/network changes. The rescue directory is `/opt/homeroute-backups/hrneo-rescue-20260918T170237Z`. Router doctor remained 26/26 PASS afterwards. The `/opt/lib/opkg/info/hrneo.*` maintainer/control metadata and package side-effect state were then captured and independently verified live: the installed postinst/conffiles hashes matched the pinned source, only postinst was present, the expected `/opt/bin/neo` symlink and guarded `rc.unslung` line were already in place, four regular opkg-info files were saved, and router doctor remained 26/26 PASS. The global `/opt/lib/opkg/status` database was then captured and independently verified: SHA-256 `cb56bc8256435b0a9ccac9d4211b3534cca873d12facdac339bc4fe5596eb2f9`, 18070 bytes, with the saved HRNeo stanza SHA-256 `dd38c71c0f99bf2c8dd2f79564cac679b34a682cfa90658d4507d942c3f4675a`. Router doctor remained 26/26 PASS. The HRNeo rescue set now covers package-owned files, `hrneo.*` opkg info/control state, postinst side effects and the global opkg status database.
- On 2026-09-18 a controlled same-version reinstall of the exact pinned local `hrneo 3.18.3-1` artifact completed live PASS using `opkg --force-reinstall --nodeps install <local-ipk>`. The installed package set remained unchanged, managed files and `hrneo.*` opkg-info still matched the rescue snapshot, postinst side effects remained idempotent, router doctor completed 26/26 PASS, HRNeo was running, and `opkgtun0` remained present. The validation window was 4 seconds. The global opkg status database was rewritten bytewise, which was expected and had been backed up. opkg also created exactly three generated conffile alternates (`hrneo.conf-opkg`, `domain.conf-opkg`, `ip.list-opkg`) because the live conffiles differ from package defaults; the original live conffiles remained unchanged. The three generated alternates were then captured into rescue evidence (869 bytes total), removed, and an explicit post-check confirmed `OPKG_CONFFILE_RESIDUE=none`; router doctor again completed 26/26 PASS. The automatic rollback path was not needed live and therefore remains CI-tested but not live-validated.
- On 2026-09-18 the corrected HRNeo mutable-conffile model passed live validation on the reference Keenetic against rescue `hrneo-rescue-20260918T184554Z`. `domain.conf` had legitimately drifted from the rescue snapshot while `hrneo.conf` and `ip.list` still matched. The updated verifier reported immutable package files PASS, mutable conffiles `present_not_pinned`, opkg-info PASS, side-effect state PASS, global status database PASS, no `*-opkg` residue, and router doctor PASS. Final router doctor again completed 26/26 PASS. This confirms that `hrneo.conf`, `domain.conf`, and `ip.list` must be treated as mutable protected state rather than immutable package identity. The controlled live rollback failure-path rehearsal is ready for retry using this corrected model.
- On 2026-09-18 the controlled HRNeo live rollback failure-path rehearsal completed PASS on the reference Keenetic. A fresh rescue set was captured at `/opt/homeroute-backups/hrneo-rescue-20260918T201739Z`, a deliberate post-install verification failure was triggered after same-version reinstall, automatic rollback completed PASS, independent live-vs-rescue verification confirmed the immutable package/opkg state returned to the fresh rescue while mutable conffiles were preserved, the installed package set was unchanged, no `*-opkg` residue remained, and router doctor completed 26/26 PASS. The rehearsal validation window was 8 seconds. HRNeo remained running and `opkgtun0` remained present. Together with the already completed VPS live filesystem/AWG/AdGuard restore validations, this closes the live backup/restore validation gate for HomeRoute v1.
- On 2026-09-18 the VPS dedicated-filesystem transaction canary completed PASS: an existing file was changed then restored, a transaction-created file was removed, and unrelated state remained unchanged.
- On 2026-09-18 sanitized VPS runtime metadata was captured for AWG2 and AdGuard without reading environment values, IP addresses, port mappings, mount source paths, labels, command lines, config contents, or credentials.
- On 2026-09-18 sanitized container-shape capture verified AWG2 networks `amnezia-dns-net` + `bridge`, its `/lib/modules` bind destination, UDP container port `35404`, and AdGuard's `amnezia-dns-net` attachment plus persistent container-side destinations `/opt/adguardhome/conf` and `/opt/adguardhome/work`. Host paths, host ports, IP addresses and secrets were deliberately not captured.
- The observed AWG2 container has no dedicated persistent bind for `/opt/amnezia/awg`; replacing that container must therefore be preceded by an explicit backup/export of AWG state.
- The official Amnezia client source at commit `de93650a90739b87bb47a632872ea9d0adc9412f` contains AWG Dockerfile/run/configure/start scripts whose container shape matches the observed restart/privileged/module-mount/UDP-port/DNS-network pattern.
- That pinned source recipe is not a deterministic image pin: its Dockerfile still uses `amneziavpn/amneziawg-go:latest`, so exact clean-build provenance remains unverified.
- On 2026-09-18 a real root-only backup of the running AWG2 state completed successfully: 5 files, 40 KiB, checksum verification PASS, backup directories mode 0700, metadata/manifest mode 0600, owner root:root. No container restart, configuration change or restore was performed.
- The AWG restore algorithm was first validated in an isolated filesystem sandbox and later passed a controlled live same-state restore on 2026-09-18: the running container was stopped, a quiescent snapshot was restored and byte-verified, the original container was restarted, and AWG runtime + DNS DNAT post-checks passed within a 6-second validation window.
- Repository tooling can create a root-only rescue archive of the exact Docker image ID used by a running container, with conservative free-space gating, tar validation and SHA256 integrity verification, without loading the image or restarting the container.
- On 2026-09-18 a real AdGuard state backup completed successfully: 6 files, 35060 KiB, checksum verification PASS, with no container restart and no restore.
- On 2026-09-18 the exact running AWG2 image `sha256:37314a32abb8ce2283e087f69e3ef020dd0eac655350313b860d82059c425d2d` was exported to a local rescue archive (12204 KiB) and passed tar/SHA256 verification without loading the image or restarting the container.
- On 2026-09-18 the exact running AdGuard image `sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0` was exported to a local rescue archive (28828 KiB) and passed tar/SHA256 verification without loading the image or restarting the container.
- After these backups the reference root filesystem remained at 54% used with 13 GiB available.
- The AdGuard restore algorithm was first validated in an isolated filesystem sandbox and later passed a controlled live same-state restore on 2026-09-18: current `conf/work` was restored and byte-verified while the container was stopped, the original container was restarted, and real UDP/TCP DNS probes passed within a 10-second validation window.
- The local rescue-set contract consists of four artifacts: AWG state, AdGuard state, exact AWG2 image and exact AdGuard image. Repository tooling can verify all four together without loading images or restoring state.
- The official Amnezia `prepare_host.sh` at the pinned source commit creates `amnezia-dns-net` as a bridge network on subnet `172.29.172.0/24` with host bridge name `amn0`; this network contract is now pinned separately from the AWG container recipe.
- The official Amnezia DNS container uses a fixed `172.29.172.254`, but HomeRoute does not use that upstream DNS role: AdGuard Home is the DNS target. HomeRoute therefore resolves the AdGuard IPv4 from Docker at runtime and does not treat the upstream `.254` address as an AdGuard invariant.
- HomeRoute's desired DNS interception remains TCP/UDP port 53 DNAT inside the AWG2 container. A read-only target resolver and a non-mutating rule renderer are CI-tested.
- On 2026-09-18 the complete four-artifact VPS rescue set re-verified PASS, and dynamic AdGuard target resolution re-verified PASS without exposing the runtime IP.
- The live persistence timer `awg-adguard-dns.timer` is active and enabled; it targets `awg-adguard-dns.service`, whose ExecStart resolves to `/usr/local/sbin/awg-adguard-dns.sh` with SHA256 `96766c14d26edb63877aaf8f2bff5de577e42683b99b86b1b2b7bc382424c2b0`.
- A repeat live preflight with schema 2 confirmed the DNS persistence timer is monotonic: `OnBootUSec=30s`, `OnUnitActiveUSec=1min`, next monotonic elapse SET, last trigger SET, `Persistent=yes`, accuracy `10s`, randomized delay `0`; no realtime next-elapse is expected for this observed schedule.
- A live schema-1 semantic fingerprint of the exact helper SHA confirmed valid shell syntax, Docker inspect/exec, iptables NAT PREROUTING DNAT on dport 53, idempotency check `-C`, rule insertion `-I`, and absence of broad flush, Docker restart/removal, reboot and `rm` patterns.
- A live schema-2 fingerprint of the same helper SHA confirmed a `tcp udp` protocol loop with a protocol variable (`protocol_loop_candidate=true`). The analyzer still did not identify `NetworkSettings.Networks`/`.IPAddress` or literal AdGuard/network names, so the exact target-resolution implementation remains NOT VALIDATED.
- On 2026-09-18 the live read-only restore-readiness gate completed PASS: the complete four-artifact rescue set re-verified, both AWG2 and AdGuard were running, and both current container image IDs exactly matched their saved rescue-image IDs. No image load, container restart, live restore, Docker state change, systemd change, or iptables change was performed.
- On 2026-09-18 the isolated stopped-container restore rehearsal completed PASS on the reference VPS: verified AWG and AdGuard backups were copied into temporary containers created from the exact rescue image IDs with `--network none`, copied back out, and checksum-verified. The temporary containers were never started, both live service containers remained running, and no temporary rehearsal containers remained afterwards.
- On 2026-09-18 controlled live AWG same-state restore validation completed PASS. `amnezia-awg2` was gracefully stopped, a quiescent snapshot of the current AWG state was captured, the same snapshot was copied back into the stopped container and byte-for-byte verified, then the original container was started. `awg0` and TCP/UDP DNS DNAT 53 both passed post-check. The validation window was 6 seconds. AdGuard remained untouched and running; no container recreate/remove or image load occurred.
- On 2026-09-18 controlled live AdGuard same-state restore validation completed PASS. `adguard-home` was gracefully stopped, its current `conf/work` state was captured, copied back into the stopped container and byte-for-byte verified, then the original container was started. Real DNS probes over UDP/53 and TCP/53 both passed. The validation window was 10 seconds. AWG2 remained running and untouched; a final rescue-readiness pass confirmed both current image IDs still match the saved rescue images.

- On 2026-09-18 a sanitized reference-router semantic capture completed PASS. It confirmed exact persistence-hook identities/hashes, installed core package versions, HRNeo mutable-config hashes/counts with `PolicyOrder=opkgtun0`, AWG runtime shape (`opkgtun0`, `/32`, MTU 1324, one peer, handshake present), and all routing/firewall invariants (table 301 rule/default, `br0 -> opkgtun0` FORWARD, MASQUERADE, mark `0x3001`, ipset `opkgtun0`) without printing keys, peers, endpoints, addresses, rule contents or config contents.
- The follow-up allow-listed persistence-hook dependency capture also completed live PASS. It confirmed that the hook layer is mostly orchestration/delegation, not inline routing mutation: `S98telegram-awg` delegates through AWG/`awg-quick` with start/stop/restart and up/down semantics; `S99hrneo` sources `rc.func` and references HRNeo; the four NDM hooks contain no direct `ip rule`, `ip route`, `iptables` or `ipset` mutation. The two Telegram NDM hooks each contain two `/opt/...` references that remain unclassified by the sanitized capture. Exact hook source therefore remains a reproduction input gate; HomeRoute must not synthesize those files from semantics alone.

## VERIFIED — component roles and package roots

- AmneziaWG 2.x is the current baseline.
- HRNeo owns selective policy routing.
- `nfqws` is an independent optional component.
- `tg-ws-proxy` is retained only as a reserve path.
- Every deployment must use a separate working VPS controlled by that deployment's user.
- The evidence-backed router core install roots are `chur-amneziawg` and `hrneo`.
- HRNeo `3.18.3-1` is now pinned independently of the mutable upstream feed: release repository commit `4811c8d13fa4bd6eaed5080fd49788f5aee20883` contains exact `.ipk` identities for `aarch64-3.10`, `mipsel-3.4`, and `mips-3.4`, recorded by repository path, byte size, and Git blob SHA-1.
- HomeRoute does not claim GPG release verification or exact binary-to-source-commit provenance for those artifacts. A 2026-09-18 re-check found the HydraRoute GitHub Releases API empty, `Neo/RELEASE_SIGNING_KEY.asc` absent from both current `main` and the pinned source commit, and the release-repository commit containing the `.ipk` files marked unsigned. Direct SHA-256 capture of all three pinned `.ipk` files completed after size + Git blob verification: aarch64 `e903e8eb0fd9153d1f181b314d9591bdd5b5953ec8dc42bb9f38aff41c4aca21`, mipsel `811fe75ee6a566dc0404dfb5943f9a1f6d102459c3b9cbd4d340b5d4f1aeb450`, mips `11c881e34d5455662c26ffb3841ba49f712c6e0d2a145a69e61f04fb22abbc62`. Controlled live same-version reinstall, cleanup and forced-failure rollback of the pinned mipsel artifact have since passed on the reference Keenetic.
- `chur-amneziawg` upstream metadata resolves the AWG userspace/runtime packages; HRNeo upstream metadata resolves its runtime dependencies.
- Optional/reserve package profiles are disabled by default; `UNCLASSIFIED` reference packages are never promoted to install roots automatically.

## VERIFIED — supported floor policy

- The current working router/VPS resource profile is the `Verified baseline` supported floor for v1.
- Less-resourced systems are `Not validated`, not declared incompatible.
- Equal-or-higher resource systems are only `Expected compatible` when the required platform/software architecture is compatible.
- This policy is not a claim about the physical minimum required to run HomeRoute.

## DEPRECATED — must remain absent

- `Wireguard0` and runtime interface `nwg0`.
- Routing table `4098` and the former `HydraRoute` policy.
- Legacy mark `0xffffaab`.
- The old ordinary WireGuard peer used by Keenetic.
- `WG443_TEST` rules.
- Duplicate peers using the same client address.

## NOT VALIDATED

- Exact live DNS helper target-resolution implementation (schema-2 confirms TCP/UDP loop, but target source remains unresolved by sanitized analysis).
- Automated live apply on a clean router or VPS.
- Stable clean-device installer apply on real managed router/VPS objects. Live backup/restore and router HRNeo reinstall/rollback are verified; the remaining gap is clean-device provisioning/reproduction rather than restore validation.
- Physical minimum router/VPS resource requirements below the supported floor.
- A complete clean-device-verified hardware compatibility matrix.
- Generic Netis flashing instructions for specific models.
- Stable production installers.
- AmneziaWG 3.x on the target Keenetic/KeeneticOS environment.

Claims in the `NOT VALIDATED` section must not be promoted to verified status without recorded evidence.
