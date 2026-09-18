# Chur/AmneziaWG runtime source evidence — 2026-09-18

This record separates **reviewed source recipe identity** from **published IPK artifact identity**.

## Upstream repository

Repository:

`ward-sentry/chur-keenetic`

Reviewed commit:

`a445e93b305d439ae1d797a54cee67aff8e36ae2`

Project version at that commit:

`1.0.0`

## Package recipes confirmed at the reviewed commit

### chur-amneziawg

- package version: `1.0.0-1`;
- meta package;
- dependencies: `chur-amneziawg-go`, `chur-amneziawg-tools`.

### chur-amneziawg-go

- package version: `f4f4c99-1`;
- upstream repository: `amnezia-vpn/amneziawg-go`;
- reviewed Chur pin: `f4f4c999267437c3eb909e8d0e5278fb4596d9a7`;
- Chur build uses the short commit `f4f4c99` as package version.

### chur-amneziawg-tools

- package version: `1.0.20260223-2`;
- upstream repository: `amnezia-vpn/amneziawg-tools`;
- reviewed Chur pin: `5d6179a6d0842e98dfb349c28cf1bd8e4b9d1079`;
- upstream archive SHA-256 in the Chur recipe:
  `e79a3c7f2def315d052a3648b49058a268c4b63cdb5e082b696d2a4a0a2367f0`.

## Feed contract

The reviewed upstream documentation explicitly defines:

- mutable normal feed: `.../chur-keenetic/latest/<arch>`;
- versioned release feed: `.../chur-keenetic/1_0_0/<arch>`.

The project build copies generated opkg repositories into both the versioned and `latest` release directories.

## What is verified

- the source recipe and its commit are pinned;
- the three runtime package versions match the versions observed on the reference Keenetic;
- the upstream source pins for AmneziaWG Go/tools are explicit;
- the tools source archive has an upstream SHA-256 in the package recipe;
- a versioned feed mechanism is documented upstream.

## What is NOT verified

HomeRoute has **not independently captured the exact published mipsel-3.4 IPK bytes** for the three Chur runtime packages.

Therefore the following are not yet evidence-backed:

- exact IPK byte sizes;
- exact IPK SHA-256 values;
- Git blob identity of the published IPKs;
- equivalence between a currently downloadable feed artifact and the package bytes installed on the reference router.

The current research environment could verify the source repository but could not independently retrieve the published feed artifacts. This must remain a separate reproduction blocker.

## Reproduction consequence

For HL-502, HomeRoute must not silently install these packages from mutable `latest` and call the result deterministic.

The blocker may be closed by either:

1. independently capturing and pinning the exact versioned-feed IPKs, or
2. exporting the exact installed package artifacts/state through a separately reviewed reproducible mechanism.

Until then:

- source recipe: **PASS**;
- exact Chur IPK artifact identity: **PENDING**.
