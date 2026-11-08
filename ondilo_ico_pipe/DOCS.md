# Ondilo ICO port forward

Forwards host port `80` to Home Assistant, so an Ondilo ICO probe can be pointed at
Home Assistant instead of at the vendor's cloud.

```
ICO probe --HTTP/80--> host:80 --socat--> homeassistant:8123 --> custom_components/ondilo_ico_local
```

## Why this exists

The probe only ever speaks cleartext HTTP to `app.ondilo.com`, and a URL with no port
means port 80. It can never be told about `:8123`, and a DNS record cannot carry a
port either. Home Assistant OS listens on 8123 and does not publish port 80, so
something has to bridge those two facts. That something is this add-on.

It is deliberately simple: `socat` between two sockets, in the host's network
namespace. It does not parse the ICO protocol, does not store measurements, does not
log request bodies, and does not talk to Home Assistant's API. All of that lives in
the integration, where it can be updated without rebuilding a container.

## Before you install

- Install [Ondilo ICO](https://github.com/H3buss/ondilo-ico-ha) as a Home Assistant
  integration first. Without it this forward has nothing to hand the traffic to, and
  port 80 answers with Home Assistant's own `404`.
- **Protection mode can stay on.** `host_network` is not one of the capabilities the
  Supervisor gates behind it.
- Nothing else on the host may own port 80. The add-on checks and refuses to start,
  with a line in its log saying so.

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `listen_port` | `80` | The host port to take over. The probe dials 80 and only 80, so changing this also means the DNS rewrite no longer helps. |
| `target` | `homeassistant:8123` | Where to send what arrives. `homeassistant` resolves to Home Assistant on the internal network. |

## Checking it worked

From any machine on the LAN:

```bash
curl -i -X POST http://<home-assistant-ip>/proxy/prod/wifi/message -H 'Content-Type: application/json' -d '{}'
curl -s http://<home-assistant-ip>/api/v2/devices/ping/<uuid>
```

A `404` with the body `{"success":false}` is the integration refusing a body that is
not a report, which means the whole path works. `{"value": 0}` from the second one is
the keep-alive route answering. A connection refused, or Home Assistant's login page,
means the forward is not in place.

Then point the DNS rewrite for `app.ondilo.com` at this machine rather than wherever
it goes now, and wait for the probe's next report.

## Removing it

Stop and remove the add-on. Nothing is left behind: no files outside the container, no
state, no certificates. The probe goes back to reporting into whatever `app.ondilo.com`
resolves to.
