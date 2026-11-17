# Debian Slim Base Image

`caaarrrlll/debian-slim-baseimage:trixie-latest`: a minimal Debian base used
by the Wine and ARK: Survival Ascended images in this repo.

## Details

| Item | Value |
|---|---|
| Base | `debian:trixie-slim` (Debian 13, current stable) |
| Tags | `trixie-latest`, plus rollback tags `trixie-YYYY-MM-DD` and `trixie-sha-<commit>` from CI |
| Locale | `en_US.UTF-8` (`LANG`, `LANGUAGE`, `LC_ALL`) |
| Extra apt components | `contrib`, `non-free`, `non-free-firmware` |

## Packages

Installed with `--no-install-recommends`; apt lists are cleaned in the same
layer:

- `wget`
- `locales`
- `procps`
- `ca-certificates` (reinstalled so the CA bundle is fresh)

The build also runs `apt-get upgrade`, and CI builds without cache, so each
rebuild picks up the latest Debian point-release updates.

## Used by

`caaarrrlll/wine-baseimage` → `caaarrrlll/asa-wine`. A change here rebuilds
the whole chain in CI (debian → wine → asa).
