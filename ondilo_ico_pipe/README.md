# Ondilo ICO port forward

One job: bytes arriving on host port **80** are handed to Home Assistant on
`homeassistant:8123`, and answers go back the same way. Pure TCP, no HTTP parsing.

## Why

The ICO probe dials `app.ondilo.com` with no port in the URL, so it always connects to
port 80. Home Assistant listens on 8123. On Home Assistant OS an integration cannot
own host port 80 by itself, so this small forward is what lets the probe talk to the
integration directly, with no PC in the path.

## Configuration

| Option | Default | Meaning |
| --- | --- | --- |
| `listen_port` | `80` | host port the probe connects to |
| `target` | `homeassistant:8123` | where bytes are forwarded |

`host_network` is enabled so the integration sees the probe's real LAN address rather
than a Docker bridge gateway; without it every report would arrive from one shared
source address. Home Assistant's **protection mode can stay on**: `host_network` is not
one of the capabilities the Supervisor keeps behind that switch.

## Build

The Supervisor builds the image from its own base image (`ARG BUILD_FROM`), so no image
needs to be published anywhere. The container runs under S6 overlay, which is why
`config.yaml` says `init: false` — with Docker's init in front of it, S6 never starts and
the container would sit there silently forwarding nothing. `run.sh` is installed as an
S6 service, watches its own child, and exits non-zero with a line in the log if the port
is taken or the forward dies, rather than looking healthy while useless.

## What it is not

It is not a proxy that rewrites paths, and it holds no state. Update the integration
to change protocol behaviour — this container never needs to change with it.

## Verifying

From another machine:

```bash
curl -i -X POST http://<home-assistant-ip>/proxy/prod/wifi/message -H 'Content-Type: application/json' -d '{}'
curl -s http://<home-assistant-ip>/api/v2/devices/ping/<uuid>
```

`404 {"success":false}` is the integration refusing a body that is not a report, and
`{"value": 0}` is it answering the probe's keep-alive: both mean bytes are reaching Home
Assistant. A web-server style `404 Not Found` page, or a refused connection, means they
are not.

The add-on refuses to start when the port is already taken and prints which port it
wanted, rather than running half-alive.
