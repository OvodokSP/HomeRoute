# VPS reproduction bundle

The first clean VPS reproduction reuses the **already verified local rescue contracts** instead of rebuilding images from floating upstream tags.

## Required local artifacts

A reproduction bundle must provide four directories copied from a verified reference rescue set:

1. AWG state backup;
2. AdGuard `conf/work` backup;
3. exact AWG2 Docker image archive;
4. exact AdGuard Docker image archive.

Each artifact keeps its original metadata/checksum files and is re-verified after transfer with the existing HomeRoute verifier.

## Why image archives are preferred for HL-502

The observed upstream recipe still contains floating image inputs. Rebuilding those images today would not prove reproduction of the same runtime bits.

For the first HL-502 run, loading the exact verified image archives is therefore the deterministic path. This does **not** establish a long-term public image distribution mechanism; it only makes the first clean reproduction evidence-backed.

## Local parameters

The target-specific values stay outside Git:

- AdGuard host bind paths;
- AWG published host UDP port;
- any credentials/keys/endpoints embedded in state;
- target host identity/SSH details.

The public repository stores only container-side/runtime invariants.

## Apply boundary

The future VPS `reproduction-apply` must:

- verify all four artifacts before mutation;
- snapshot any pre-existing target state;
- load exact image archives;
- create the reviewed Docker network shape;
- restore state into the target-local paths/container state;
- create AWG2 and AdGuard with reviewed runtime shape;
- install DNS persistence only after helper semantics are fully resolved;
- run VPS doctor and DNS probes;
- rollback managed objects on failed verification.

Stable/general `apply` remains blocked until HL-502 passes.
