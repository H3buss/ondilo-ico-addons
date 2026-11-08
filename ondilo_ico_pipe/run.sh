#!/command/with-contenv bashio
#
# Pure byte pipe: host port 80 -> Home Assistant.
#
# The ICO probe only ever speaks HTTP to app.ondilo.com with no port, so it can
# only ever knock on 80, while Home Assistant listens on 8123. Nothing here
# understands the ICO protocol: no parsing, no rewriting, no logging of bodies.
# The protocol lives in the Home Assistant integration, where it can be updated
# without rebuilding this container.
#
# host_network is on in config.yaml so the integration still sees the probe's
# real address instead of a Docker bridge gateway.

LISTEN_PORT=$(bashio::config 'listen_port')
TARGET=$(bashio::config 'target')

bashio::log.info "forwarding :${LISTEN_PORT} -> ${TARGET}"

# Say it out loud when the port is already taken: a silent half-start is the one
# failure mode that leaves a device reporting into nothing.
if ss -ltn "sport = :${LISTEN_PORT}" 2>/dev/null | grep -q LISTEN; then
  bashio::log.error "port ${LISTEN_PORT} is already in use on this host"
  bashio::log.error "stop whatever answers on it, or change listen_port here and the DNS rewrite with it"
  exit 1
fi

# No -d: socat would then log a line per connection, and the probe keeps its
# keep-alive up all day. Nothing logs request bodies, either way: it is a pipe.
socat \
  "TCP-LISTEN:${LISTEN_PORT},fork,reuseaddr,bind=0.0.0.0" \
  "TCP:${TARGET}" &
forward=$!

# The Supervisor stops an app with SIGTERM, and reads a death by the default
# handler as an app that misbehaves. Answer the signal, take the listener down
# with us, and leave exit code 0 behind.
trap 'kill "${forward}" 2>/dev/null; exit 0' TERM INT

status=0
wait "${forward}" || status=$?

# Only reached if socat gave up: with fork it normally does not. S6 restarts the
# service, so keep the reason short and obvious in the add-on log.
bashio::log.error "forward stopped on port ${LISTEN_PORT} (exit ${status}: port taken? target gone?)"
exit 1
