# История изменений

## Unreleased

- Удалён контур development autopilot: GitHub Actions workflow, Codex prompts и Roadmap helper. Обычный Repository quality CI сохранён.
- Зафиксирован live schema-2 preflight DNS persistence: monotonic timer, OnBoot 30s, OnUnitActive 1min, Persistent=yes и exact helper SHA.
- Добавлен sanitized DNS helper analyzer schema 2 для variable/loop patterns без вывода содержимого helper, IP или shell-переменных.
- Первый live helper fingerprint записан как partial evidence без преждевременного повышения dynamic target/TCP+UDP semantics до VERIFIED.
- Добавлен design-only DNS persistence contract и read-only renderer для monotonic timer, dynamic AdGuard target и TCP/UDP DNAT 53; live apply остаётся blocked.
- Уточнён HRNeo integrity boundary: release commit unsigned, GitHub Releases пуст, signing key не найден в main/pinned source commit; SHA-256 всех трёх pinned `.ipk` захвачен и добавлен в verifier, GPG остаётся NOT VERIFIED.
- Live DNS helper schema 2 подтвердил TCP/UDP loop через protocol variable; конкретный target-resolution path остаётся NOT VALIDATED.
- Добавлен read-only VPS restore-readiness gate: rescue-set integrity + current container/image identity, без stop/restart/load/restore.
- Добавлен isolated stopped-container restore rehearsal: temporary containers, network none, no start, backup round-trip + checksum reverify; live services не затрагиваются.
- Live read-only restore-readiness gate прошёл PASS на reference VPS: rescue set повторно проверен, current AWG/AdGuard image IDs совпали с rescue copies; live restore не выполнялся.
- Isolated stopped-container restore rehearsal прошёл live PASS: AWG/AdGuard backup round-trip verified, temporary containers never started, live services remained running.
- Controlled live AWG same-state restore validation прошёл PASS: graceful stop, quiescent snapshot, exact byte round-trip, restart/post-check; `awg0` и DNS DNAT восстановились, validation window 6 секунд.
- Controlled live AdGuard same-state restore validation прошёл PASS: quiescent conf/work snapshot, exact byte round-trip, UDP/TCP DNS probes PASS, validation window 10 секунд; final restore-readiness PASS.
- Router doctor повторно прошёл live 26/26 PASS; подтверждены `mipsel-3.4`, core package versions и feeds. Live filesystem transaction canary на `/opt` прошёл PASS без leftovers, HRNeo/AWG остались рабочими.
- HRNeo rescue set live-capture + verify прошёл PASS: 7 package-owned files, exact pinned `mipsel-3.4` IPK SHA256 verified, post-doctor 26/26 PASS; package/service/network не менялись.
- Opkg/control rescue gate прошёл live PASS: pinned postinst/conffiles hashes matched, 4 `hrneo.*` opkg-info files + `/opt/bin/neo` + `rc.unslung` сохранены и проверены, post-doctor 26/26 PASS.
- Global `/opt/lib/opkg/status` rescue live-capture + verify прошёл PASS: 18070 bytes, SHA256 pinned in evidence, saved HRNeo status stanza verified, post-doctor 26/26 PASS.
- Controlled same-version reinstall exact pinned HRNeo `3.18.3-1` прошёл live PASS: package set unchanged, managed files/opkg-info/side-effects verified, doctor 26/26 PASS, 4s validation window.
- Post-transaction cleanup прошёл live PASS: 3 generated `*-opkg` artifacts (869 bytes) захвачены в evidence и удалены, `OPKG_CONFFILE_RESIDUE=none`, post-doctor 26/26 PASS.
- Rollback-path усилен: автоматический rollback удаляет только три ожидаемых `*-opkg` residue и отказывается при unexpected residue. Первый live rehearsal остановился до package transaction: `domain.conf` успел измениться между fresh rescue и validator preflight. Исправлена модель conffiles: `hrneo.conf`, `domain.conf`, `ip.list` считаются mutable user state; старый rescue не pin'ит их bytes, а validator снимает fresh SHA непосредственно перед `opkg` и требует их неизменности через transaction/rollback.
- Исправленная mutable-conffile модель прошла live PASS на reference Keenetic: immutable package files/opkg-info/side-effects/global status PASS, `domain.conf` отличается от rescue как допустимое mutable state, residue none, final doctor 26/26 PASS.
- Controlled HRNeo live rollback failure-path rehearsal прошёл PASS: fresh rescue, forced postinstall failure, automatic rollback PASS, live state снова совпал с fresh rescue по immutable state, package set unchanged, residue none, final doctor 26/26 PASS, validation window 8s. Live backup/restore gate v1 закрыт.


- Sanitized reference-router semantic capture прошёл live PASS: зафиксированы hashes/size/line-count persistence hooks, package baseline, HRNeo config shape, AWG `/32` + MTU 1324 + one peer/handshake и все routing/firewall invariants без вывода секретов. Добавлен отдельный allow-listed dependency capture для делегирующих hooks перед построением reproduction renderer.

- Allow-listed persistence-hook dependency capture прошёл live PASS: hooks подтверждены как delegation/orchestration layer без direct ip/iptables/ipset mutations; два `/opt/...` dependency targets в Telegram NDM hooks остаются unresolved.
- Добавлен public `router-reference-contract.json` + CI validator и machine-readable `reproduction-gates.json`; stable apply жёстко связан с HL-502.
- Добавлены local-only router/VPS reproduction bundle builders/verifiers, deterministic plan renderers и единый `scripts/reproduction/status.py`; secret-bearing inputs остаются вне Git.
- Подготовлен protected exact-hook export для следующей live-сессии: exact SHA gate + secret/address scan + mode-0600 archive, без вывода source contents.
- Chur upstream source recipe закреплён на commit `a445e93b305d439ae1d797a54cee67aff8e36ae2`; source package versions/pins подтверждены, но published IPK byte identity остаётся PENDING и не подменяется догадкой по filename/latest feed.
- VPS rescue manifest синхронизирован с фактом: AWG/AdGuard live state restore = PASS; exact image load остаётся отдельно NOT VALIDATED.

## 0.2.0 — repository workflow

- Добавлены `AGENTS.md` и `CURRENT_STATE.md` как правила и фактическая точка проекта.
- Roadmap преобразован в машиночитаемый список задач.
- Добавлены dependency-free repository validation и GitHub Actions CI.

## 0.1.0 — bootstrap

- Зафиксировано подтверждённое состояние HomeRoute Golden State v0.1.
- Добавлены русская и английская главные страницы и благодарности upstream-проектам.
- Добавлены reference-конфигурация и данные Telegram IPv4.
- Добавлены read-only diagnostics для роутера и VPS.
- Добавлены безопасные PRE-ALPHA заглушки installers.
