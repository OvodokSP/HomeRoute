# Entware package baseline

Цель package baseline — определить, какие пакеты действительно необходимы HomeRoute, не превращая текущее содержимое `/opt` эталонного роутера в безусловный список зависимостей.

## Reference snapshot и manifest

Снимок фактически установленной среды:

- `inventory/reference-2026-09-17/router-packages.json`.

Доказуемая классификация:

- `config/router-package-manifest.json`.

CI проверяет, что manifest покрывает **каждый** пакет reference snapshot ровно один раз и что install roots не попадают в `UNCLASSIFIED`, `TRANSITIVE` или `LEGACY`.

## Core install roots

HomeRoute v1 не пытается повторить все 73 пакета reference-router. Для основного рабочего тракта доказаны только два install roots:

```text
chur-amneziawg
hrneo
```

`chur-amneziawg` является upstream meta-package и подтягивает:

- `chur-amneziawg-go`;
- `chur-amneziawg-tools`.

`chur-amneziawg-tools` upstream-метаданными требует:

- `bash`;
- `ip-full`;
- `coreutils-stat`.

HRNeo upstream package metadata требует:

- `libc`;
- `ipset`;
- `iptables`;
- `ip-full`.

Таким образом installer должен передавать `opkg` **install roots**, а не вручную дублировать весь транзитивный dependency graph.

## Optional / reserve profiles

По умолчанию отключены:

- `optional_nfqws` → `nfqws-keenetic`;
- `optional_nfqws_web` → `nfqws-keenetic-web`;
- `reserve_tg_ws_proxy` → `tg-ws-proxy`.

`nfqws-keenetic` остаётся самостоятельным optional layer. Upstream package metadata подтверждает зависимости `iptables` и `busybox`.

Для `nfqws-keenetic-web` upstream repository metadata подтверждает PHP/lighttpd dependency set; эти пакеты классифицированы как optional transitive dependencies и не входят в core install roots.

`ca-certificates` и `wget-ssl` отмечены только как optional bootstrap prerequisites для upstream nfqws repositories. Они не становятся core-пакетами HomeRoute.

## UNCLASSIFIED — это намеренно

Пакет не становится обязательным только потому, что установлен на reference-router. Все пакеты, необходимость которых не доказана upstream metadata или прямым использованием HomeRoute, остаются `UNCLASSIFIED`.

Это относится, например, к диагностическим утилитам, библиотекам других компонентов и исторически установленным пакетам. Installer **не имеет права** устанавливать `UNCLASSIFIED` автоматически.

## Категории

- `CORE` — явный install root основного HomeRoute path;
- `OPTIONAL` — явный install root опционального компонента;
- `RESERVE` — явный install root резервного канала;
- `TRANSITIVE` — доказанная зависимость install root или другой доказанной зависимости;
- `UNCLASSIFIED` — присутствует в reference inventory, но необходимость не доказана;
- `LEGACY` — относится к удалённой/неиспользуемой схеме и не должен входить в installer.

## Platform prerequisites

`KeeneticOS`, `Entware` и `opkg` считаются **предусловиями платформы**, а не пакетами, которые HomeRoute v1 устанавливает сам. Для Netis/ported-сценария установка KeeneticOS и Entware остаётся отдельным этапом setup flow.

## Feed/bootstrap boundary

Классификация пакетов завершена, но live apply всё ещё заблокирован до безопасного provisioning feed-конфигураций и clean-device validation.

HomeRoute не должен выполнять непроверенное `curl | sh` как скрытый bootstrap. Для apply-mode upstream repositories должны быть заданы детерминированно и проверяемо, с возможностью backup/rollback изменённых feed-файлов.

## Сравнение package snapshots

Два извлечённых JSON можно сравнить:

```sh
python3 scripts/inventory/compare_packages.py old-packages.json new-packages.json
```

Инструмент показывает:

- `[ADDED]` — пакет появился;
- `[REMOVED]` — пакет исчез;
- `[VERSION]` — изменилась версия.

Сравнение не делает вывод о необходимости пакета автоматически.

## Acceptance rule для installer

Installer получает package roots только из `config/router-package-manifest.json`.

Core profile на текущем этапе фиксирован как:

```text
chur-amneziawg hrneo
```

Ни один `UNCLASSIFIED`, `LEGACY` или чисто транзитивный пакет не может попасть в install roots без отдельного evidence-backed изменения manifest и успешного CI.
