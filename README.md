# Home Assistant OS app repository: Ondilo ICO

[![Open your Home Assistant instance and show the add app repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FH3buss%2Fondilo-ico-addons)

Or by hand: **Settings → Apps → Install app → ⋮ → Repositories** (older releases:
**Settings → Add-ons → Add-on store → ⋮ → Repositories**), add this URL, then install
**Ondilo ICO port forward**.

## If the repository is listed but shows no app

The Supervisor reads every `config.yaml` it finds and, when one does not validate, skips that app
with a single line in its own log: the repository stays listed, with nothing in it. Three things
cause it, in the order they are worth checking.

- **The Supervisor never fetched the files.** Apps → ⋮ → Repositories → this repository → ⋮ →
  *Rebuild*, then reload the page. This is what you get when the repository was added before it
  had any content in it.
- **Your machine is not in the `arch` list.** An app whose arch list excludes the machine it runs
  on is hidden without a word. This app lists `aarch64` and `amd64`; the architecture Home Assistant
  reports is under **Settings → System**. `armv7` is deliberately not listed: the 2026.11 Supervisor
  still *accepts* it in `config.yaml`, but its builder only knows `aarch64` and `amd64`, so a 32-bit
  install would be shown an app it cannot build. Read that twice before adding it back.
- **The `config.yaml` itself does not validate.** Option types are matched against a grammar where
  ranges are positional (`int(1,65535)`, not `int(min=1, max=65535)`), so a plausible-looking file
  can be quietly refused.

If none of those is it, the Supervisor log has the answer: **Settings → System → Logs**, pick
**Supervisor**, and look for `Can't read` or `Repository parse error`.

## If the install dies during the Docker build

`base name (${BUILD_FROM}) should not be blank`, in the Supervisor log, is not something you broke.
The Supervisor passes `BUILD_FROM` only to an app that ships a `build.yaml`; without that file it
passes `BUILD_VERSION` and `BUILD_ARCH` alone and expects the Dockerfile to name its own base image.
Since 1.1.1 the base is pinned in the `ARG BUILD_FROM=...` line, so the build works with or without a
`build.yaml`, and a `--build-arg` from the Supervisor still overrides it.

A `no matching manifest for linux/arm/v7` on the same screen means the `arch` list promises an
architecture the base image is not published for. That is the one failure this repository would
rather refuse to ship than hand you.

## Why an add-on is needed at all

The ICO probe only ever speaks cleartext HTTP to `app.ondilo.com`, and an HTTP URL
without a port means **port 80**. The probe can never be told about `:8123`, and no
DNS record can carry a port either. Home Assistant on Home Assistant OS listens on
8123 and does not publish host port 80, so one thing has to bridge that gap.

This add-on is that thing, and it is deliberately dumb: it forwards bytes between
host port 80 and Home Assistant. It does not parse the ICO protocol, does not store
measurements, and does not know what a probe is. Every decision about the protocol
lives in the [Ondilo ICO integration](https://github.com/H3buss/ondilo-ico-ha), which
you install separately from the Marketplace.

| Piece | Where it lives | What it knows |
| --- | --- | --- |
| Port forward | this add-on, host port 80 | nothing but two sockets |
| ICO protocol, measurements, cloud forwarding | the integration, inside Home Assistant | everything |

If you would rather not install a home-built add-on, the community **Nginx Proxy
Manager** add-on does the same job from a web form: create a proxy host on port 80
forwarding to `homeassistant:8123`. This add-on exists so the setup needs one click
instead of a form, and so there is no request logging of your measurements anywhere.

## After installing

1. Install the [Ondilo ICO integration](https://github.com/H3buss/ondilo-ico-ha) if you
   have not yet; without it this forward has nothing to hand the traffic to.
2. Start the add-on, confirm the log says `forwarding :80 -> homeassistant:8123` and
   nothing else is using port 80 (the add-on refuses to start, loudly, if it is).
   **Protection mode can stay on**: `host_network` is not one of the capabilities the
   Supervisor hides behind it.
3. Point the DNS rewrite at this machine instead of at a PC, e.g. in dnsmasq:
   `address=/app.ondilo.com/192.168.1.14`
4. Check from any machine on the LAN:

   ```bash
   curl -i -X POST http://<home-assistant-ip>/proxy/prod/wifi/message -H 'Content-Type: application/json' -d '{}'
   curl -s http://<home-assistant-ip>/api/v2/devices/ping/<uuid>
   ```

   `404 {"success":false}` means the integration answered and refused a body that is not
   a report, which is the path working end to end; `{"value": 0}` is the keep-alive route
   answering. A plain nginx or Docker `404 Not Found` page, or a refused connection,
   means the forward is not reaching Home Assistant.
5. Wait for the probe's next report. No certificate, no cloud account change.

`listen_port` only needs changing if something else on the host already owns 80 — in
that case the DNS rewrite cannot help you, because the probe will still dial 80, so
the real fix is to free the port.
