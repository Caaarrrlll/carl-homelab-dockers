# Wine Base Image

`caaarrrlll/wine-baseimage:latest`: [Wine](https://gitlab.winehq.org/wine/wine)
on top of `caaarrrlll/debian-slim-baseimage:trixie-latest`, used to run
Windows game servers (currently ARK: Survival Ascended).

## Details

| Item | Value |
|---|---|
| Base | `caaarrrlll/debian-slim-baseimage:trixie-latest` |
| Wine | `winehq-stable` from the official WineHQ Debian repo (Wine 11.x) |
| Architectures | `amd64` + `i386` (multiarch enabled) |
| `PATH` | includes `/opt/wine-stable/bin` |
| Tags | `latest`, plus rollback tags `YYYY-MM-DD` and `sha-<commit>` from CI |

The WineHQ repo key is stored in `/etc/apt/keyrings/winehq-archive.key` and
referenced with `signed-by` (no `apt-key`). Apt lists are cleaned in the same
layer.

## NTSYNC

Wine 11 supports the Linux **NTSYNC** driver for faster Windows-style
synchronisation. Using it needs:

- a host kernel of 6.14 or newer with the module loaded (`modprobe ntsync`;
  Unraid 7.3+),
- the device passed to the container (`--device=/dev/ntsync`),
- `WINENTSYNC=1` in the environment. The ASA image sets this for you when
  its `NTSYNC=1` variable is on.

Debian's own `wine` package (10.0) predates NTSYNC, which is why this image
uses WineHQ. See `HISTORY.md` (2026-11-07) for the background.

## Used by

`caaarrrlll/asa-wine`. A change here rebuilds wine → asa in CI.
