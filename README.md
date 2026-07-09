# z-automation — Zlatibor home automation

Home Assistant + Z-Wave configuration for the cottage in Zlatibor, running on a
Raspberry Pi 3 at **`10.92.0.2`** (also `10.92.0.101`, `10.12.0.28`).

> Operating/▶change guide for humans **and** agents lives in **[AGENTS.md](AGENTS.md)**
> (Claude Code loads it via `CLAUDE.md`). This README is the project overview.

## Host

| | |
|---|---|
| Board | Raspberry Pi 3 Model B (arm64), ~1 GB RAM |
| OS | Debian 11 (bullseye), **Python 3.9** |
| SSH | `ssh pi@10.92.0.2` |
| Disk | root fs, ~100 GB free |

## Architecture

| Component | What | How it runs |
|-----------|------|-------------|
| **Home Assistant Core** | `2023.1.7` in a venv at `/srv/homeassistant` | systemd `home-assistant@homeassistant.service`, UI on `:8123` |
| **Z-Wave JS server** | Node `@zwave-js/server@1.25.0` driving the Aeotec Z-Stick Gen5 | systemd `zwave-js-server.service`, `ws://localhost:3000` |
| **HA ↔ Z-Wave** | `zwave_js` integration (config entry, not YAML) | connects to the server above |
| **Heating** | Go **heating-controller** — *separate project* | systemd `heating-controller.service`, web UI on `:8080` |

Home Assistant does **not** control heating; it links to the heating-controller UI
via the *Grejanje* sidebar panel and shows its service health. **Never modify the
heating-controller, its config, or its unit.**

> **Version ceiling:** `2023.1.7` is the last HA that runs on this Pi's Python 3.9.
> The config deliberately uses 2023.1-era YAML (`platform: command_line`,
> `platform: systemmonitor`). See *Migrating to latest HA*.

## Z-Wave network

Controller: Aeotec Z-Stick Gen5 at `/dev/serial/by-id/usb-0658_0200-if00`
(= `/dev/ttyACM0`), home id `3323351352`.

| Node | Device | HA device id | Room / role |
|---|---|---|---|
| 1 | Z-Stick Gen5 controller | `d8ff5eca` | — |
| 3 | MultiSensor 6 | `4231661f` | **Dnevna soba suteren** |
| 4 | MultiSensor 6 | `fa80f461` | **Dnevna soba** |
| 5 | MultiSensor 6 | `f8d74a7a` | **Hodnik na spratu** |
| 6 | Home Energy Meter Gen5 | `08539146` | whole-house power |
| 7 | (unknown) | `4e0aa27e` | **dead** — needs physical attention |
| 9 | TKB dual-paddle switch | `af3c7a38` | wall switch |

Rooms are set as **device names** (`name_by_user` in the device registry), so each
unit's entities inherit the room. Security keys live in `/etc/zwave-js/config.js`
(mode 600, gitignored); re-generating them forces re-pairing of secure devices.

### Device → entity map

The `_2` / `_3` suffixes are assigned by HA in interview order and are **not**
consistent across sensor types, so they are pinned down here.

**MultiSensor 6 units** (all entity IDs prefixed `…multisensor_6`):

| Room | Device | Temp | Humidity | Illuminance | UV | Motion |
|------|--------|------|----------|-------------|----|--------|
| Dnevna soba suteren | `4231661f` | `_air_temperature` | `_humidity` | `_illuminance` | `_ultraviolet_2` | `binary…_motion_detection` |
| Dnevna soba | `fa80f461` | `_air_temperature_2` | `_humidity_2` | `_illuminance_2` | `_ultraviolet` | `binary…_motion_detection_2` |
| Hodnik na spratu | `f8d74a7a` | `_air_temperature_3` * | `_humidity_3` * | `_illuminance_3` * | `_ultraviolet_3` * | `binary…_motion_detection_3` * |

\* appear once node 5 completes its interview (see AGENTS.md → "Z-Wave operations").

**Home Energy Meter Gen5** (`08539146`) — aggregate + three clamps, each with W/kWh/V/A
(all prefixed `sensor.home_energy_meter_gen5_electric_consumption`):

| Reading | Whole-house | Clamp 1 | Clamp 2 | Clamp 3 |
|---------|-------------|---------|---------|---------|
| Power (W) | `_w` | `_w_2` | `_w_2_2` | `_w_3` |
| Energy (kWh) | `_kwh` | `_kwh_2` | `_kwh_2_2` | `_kwh_3` |
| Voltage (V) | `_v` | `_v_2` | `_v_2_2` | `_v_3` |
| Current (A) | `_a` | `_a_2` | `_a_2_2` | `_a_3` |

**Dual Paddle Wall Switch** (`af3c7a38`) — `switch.dual_paddle_wall_switch`.

## Layout

```
hass-config/            # deployed to /home/homeassistant/.homeassistant/
  configuration.yaml    # main config (Z-Wave JS, system + template sensors, alarm, heating)
  ui-lovelace.yaml      # dashboard (Lovelace YAML mode): Pregled/Kuća/Energija/Sistemi/Grafikoni
  customize.yaml        # Serbian friendly names (energy + system)
  automations.yaml      # alarm / motion automations
  groups|scripts|scenes.yaml
  secrets.yaml.example  # copy to secrets.yaml (gitignored) and fill in
systemd/                # service units (copied to /etc/systemd/system/)
zwave-js/config.js.template  # -> /etc/zwave-js/config.js (fill security keys)
install.sh              # provision the whole stack
upgrade-hass.sh         # HA upgrade notes (Python 3.9 ceiling)
legacy/                 # retired heating/relay/alarm scripts (see legacy/README.md)
AGENTS.md / CLAUDE.md   # operating + safe-change guide
```

Runtime-only state (NOT in git, see `.gitignore`): `.storage/` (config entries for
zwave_js/met/speedtest, device & entity registries, auth), `secrets.yaml`,
`*.db*`, `/etc/zwave-js/config.js`.

## Dashboard

Lovelace runs in **YAML mode** (`ui-lovelace.yaml`, version-controlled). Views:
Pregled (weather + summary + heating), Kuća (per-room MultiSensors), Energija
(energy meter), Sistemi (alarm, heating service, internet/speedtest, Pi), Grafikoni
(history). Editing is via the file, not the UI. Weather comes from **Met.no**, with
`Spoljna temperatura/vlažnost`, `Vazdušni pritisak`, `Brzina vetra`, and
`Prosečna temperatura` provided as `template:` sensors.

## Access

- URL: `http://10.92.0.2:8123` (LAN-only, HTTP; no external access configured).
- Login user: `vjovanov`. Reset password with
  `sudo -u homeassistant /srv/homeassistant/bin/hass --script auth --config /home/homeassistant/.homeassistant change_password vjovanov <new>`
  then **restart HA** (running instance caches the old hash).

## Install / provision

```
sudo ./install.sh
```
Then finish the printed manual steps (add the Z-Wave JS integration if missing,
fill `secrets.yaml`, register the Companion app).

## Alarm

- Arm/disarm via the **Alarm** toggle (`input_boolean.alarm_armed`).
- Motion while armed → `notify.alarm_targets` (push) + MessageBird SMS, throttled 30 min.
- 48 h with no motion while disarmed → reminder.
- Needs: `secrets.yaml` filled (`messagebird_auth`, `alarm_phone_1`, `alarm_message`,
  `alarm_reminder_message`) and the **HA Companion app** registered, then add
  `- service: mobile_app_<device>` to the `alarm_targets` group in `configuration.yaml`.

## Backups

Pre-change config snapshots are kept at `/home/homeassistant/ha-backup-<timestamp>/`
(includes `.storage`). Take one before risky edits.

## Migrating to latest HA

Blocker: current HA needs Python 3.12+, absent from Debian 11. Options:

1. **Docker (in place):** run `ghcr.io/home-assistant/home-assistant:stable` with
   `--network host`, `-v /home/homeassistant/.homeassistant:/config`, the Z-Stick
   device mapped; bump `@zwave-js/server` to latest `3.x` (schema must match).
   The Pi 3 (1 GB) is marginal — add zram/swap.
2. **New hardware (recommended):** Pi 4/5 (≥2 GB) or mini-PC; clean install of latest
   HA, move the config, move the Z-Stick.

After upgrading, migrate the `command_line`/`systemmonitor` blocks to their current
top-level formats.
