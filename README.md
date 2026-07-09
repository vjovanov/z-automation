# z-automation — Zlatibor home automation

Home Assistant + Z-Wave configuration for the cottage in Zlatibor, running on a
Raspberry Pi 3 (`10.92.0.2`).

## Architecture

| Component | What | How it runs |
|-----------|------|-------------|
| **Home Assistant Core** | `2023.1.7` in a venv at `/srv/homeassistant` | systemd `home-assistant@homeassistant.service`, UI on `:8123` |
| **Z-Wave JS server** | Node `@zwave-js/server@1.25.0` driving the Aeotec Z-Stick Gen5 (`/dev/serial/by-id/usb-0658_0200-if00`) | systemd `zwave-js-server.service`, `ws://localhost:3000` |
| **HA ↔ Z-Wave** | `zwave_js` integration (config entry) | connects to the server above |
| **Heating** | Go **heating-controller** — *separate project* | systemd `heating-controller.service`, web UI on `:8080` |

Home Assistant does **not** control heating; it only links to the heating-controller
UI via the *Grejanje* sidebar panel. Do not manage the heating-controller from here.

> **Version note:** `2023.1.7` is the last HA that runs on this Pi's Python 3.9
> (Debian 11). The config deliberately uses 2023.1-era YAML (`platform: command_line`,
> `platform: systemmonitor`). See *Migrating to latest HA* below.

## Layout

```
hass-config/            # deployed to /home/homeassistant/.homeassistant/
  configuration.yaml    # main config (Z-Wave JS, system sensors, alarm, heating panel)
  customize.yaml        # Serbian friendly names for the live entities
  automations.yaml      # alarm / motion automations
  groups|scripts|scenes.yaml
  secrets.yaml.example  # copy to secrets.yaml (gitignored) and fill in
systemd/                # service units (copied to /etc/systemd/system/)
zwave-js/config.js.template  # -> /etc/zwave-js/config.js (fill security keys)
install.sh              # provision the whole stack
upgrade-hass.sh         # HA upgrade notes (Python 3.9 ceiling)
legacy/                 # retired heating/relay/alarm scripts (see legacy/README.md)
```

## Access

- URL: `http://10.92.0.2:8123` (also reachable on `10.92.0.101` / `10.12.0.28`).
- User: `vjovanov`. LAN-only, HTTP (no external access configured).

## Install / provision

```
sudo ./install.sh
```
Then finish the manual steps it prints (add the Z-Wave JS integration if missing,
fill `secrets.yaml`, register the Companion app).

## Secrets

`hass-config/secrets.yaml` is gitignored. Copy the example and fill:
`messagebird_auth`, `alarm_phone_1`, `alarm_message`, `alarm_reminder_message`.

## Alarm

- Arm/disarm with the **Alarm** toggle (`input_boolean.alarm_armed`).
- Motion while armed → `notify.alarm_targets` (push) + MessageBird SMS, throttled 30 min.
- 48 h with no motion while disarmed → reminder.
- To get phone push: install the **HA Companion app**, log in, then add
  `- service: mobile_app_<device>` to the `alarm_targets` group in `configuration.yaml`.

## Migrating to latest HA

The blocker is Python: current HA needs 3.12+, absent from Debian 11. Options:

1. **Docker (in place, easiest):** install Docker, run
   `ghcr.io/home-assistant/home-assistant:stable` with `--network host`,
   `-v /home/homeassistant/.homeassistant:/config`, and the Z-Stick device mapped;
   bump `@zwave-js/server` to the latest `3.x` (schema must match the new HA).
   Note the Pi 3 (1 GB RAM) is marginal for current HA — add zram/swap.
2. **New hardware (recommended long-term):** Pi 4/5 (≥2 GB) or a mini-PC; clean
   install of latest HA, move the config, move the Z-Stick. Best performance.

After upgrading, migrate `command_line`/`systemmonitor` blocks to their current
top-level formats.
