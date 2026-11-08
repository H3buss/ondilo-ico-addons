# The Supervisor passes BUILD_FROM only when the app ships a build.yaml. Without
# one it says so in plain words (supervisor/apps/build.py: "without build config,
# Dockerfile should specify it") and runs the build with BUILD_VERSION and
# BUILD_ARCH alone -- docker then dies on "base name (${BUILD_FROM}) should not be
# blank". So the default lives here, and it is the very image the Supervisor falls
# back to itself, pinned to the release that fallback ships: multi-arch
# (amd64/arm64), Alpine 3.24, io.hass.base.name=alpine. A build.yaml or an explicit
# --build-arg still overrides it.
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.24-2026.11.0
FROM ${BUILD_FROM}

# socat is the whole product. iproute2 gives run.sh a way to say out loud that
# the port is taken instead of dying quietly. The base image is Alpine; the
# second branch is there so the build cannot silently half-succeed if that ever
# changes under us.
RUN if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache socat iproute2; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update \
      && apt-get install -y --no-install-recommends socat iproute2 \
      && rm -rf /var/lib/apt/lists/*; \
    else \
      echo "no supported package manager in the base image" >&2; \
      exit 1; \
    fi

# Executed by S6 as a supervised service. chmod is explicit because git does not
# always carry the executable bit across platforms.
COPY run.sh /etc/services.d/ico_pipe/run
RUN chmod a+x /etc/services.d/ico_pipe/run
