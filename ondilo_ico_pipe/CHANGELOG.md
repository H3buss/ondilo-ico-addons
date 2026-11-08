# Changelog

## 1.1.1

- **The build died with `base name (${BUILD_FROM}) should not be blank`.** The Supervisor passes
  `BUILD_FROM` only to an app that ships a `build.yaml`. Without one it passes `BUILD_VERSION` and
  `BUILD_ARCH` alone and expects the Dockerfile to name its own base image, which ours did not. The
  default is now pinned in the `ARG BUILD_FROM=...` line: the build works with or without a
  `build.yaml`, and a `--build-arg` from the Supervisor still wins.
- `armv7` is off the `arch` list, which retracts the 1.1.0 bullet below. The 2026.11 Supervisor still
  *validates* `armv7` in `config.yaml`, but its builder knows two architectures, `aarch64` and
  `amd64`, and the base image publishes two platforms. Listing `armv7` shows a 32-bit machine an app
  it can install and then cannot build.

## 1.1.0

- **The add-on was invisible in the store.** `schema: listen_port` was declared `int(min=1, max=65535)`,
  and that spelling does not exist in the Supervisor's schema grammar: ranges there are positional,
  `int(1,65535)`, `str(1,32)`, `float(0.0,10.5)`. An add-on whose config does not validate is skipped
  with one warning line in the Supervisor log, so the repository stayed listed and the app was never
  shown. It is now declared with the Supervisor's own `port` type, which enforces 1-65535 for us.
- `armv7` joins `aarch64` and `amd64`. The Supervisor hides an app whose arch list does not cover the
  machine it runs on, and says nothing while doing it; a 32-bit Raspberry Pi saw an empty repository.
  Retracted in 1.1.1, see above.

## 1.0.0

First release.

- `socat` from `:80` on the host to `homeassistant:8123`, running in the host's network namespace so
  Home Assistant still sees the probe's real address — the receiver logs it, and it is what the
  `last seen` of your probe will show.
- Two options: the port to take, and where to send it. Defaults are `80` and `homeassistant:8123`,
  which is what the Ondilo probe needs — its firmware carries `80` as a literal, so nothing else can
  be offered to it.
- Refuses to start when something already holds that port, and says which, in the add-on log, rather
  than starting an app that forwards nothing.
- Home Assistant's protection mode can stay on: host networking is not one of the capabilities that
  switch hides.
