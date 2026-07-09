# AGENTS.md — operating & safe-change guide for z-automation

This repo configures Home Assistant + Z-Wave for the Zlatibor cottage on a
Raspberry Pi 3 at `10.92.0.2` (`ssh pi@10.92.0.2`). Read this before changing
anything. Project overview: [README.md](README.md).

## Golden rules

1. **Never touch the `heating-controller`** (Go app, systemd `heating-controller.service`,
   `:8080`, `/etc/heating-controller/`). It is a separate, parallel system that owns
   heating and the GPIO relays. HA only *links* to it.
2. **HA is pinned to 2023.1.7** — the last release that runs on this box's **Python 3.9**
   (Debian 11). Do **not** `pip install --upgrade homeassistant`; it will break. Use
   2023.1-era YAML (`platform: command_line`, `platform: systemmonitor`). See README
   "Migrating to latest HA".
3. **Always `check_config` before restarting**, and **back up `.storage` before editing it**.
4. **Editing `.storage/*` requires HA stopped** — the running instance caches these and
   rewrites them on shutdown, clobbering your edit.
5. **Secrets never go in git** (`secrets.yaml`, `/etc/zwave-js/config.js` are gitignored).

## Key paths & services

| Thing | Path / name |
|---|---|
| HA config (live) | `/home/homeassistant/.homeassistant/` |
| HA venv | `/srv/homeassistant/` (`bin/hass`, `bin/python3`) |
| HA service | `home-assistant@homeassistant.service` (port 8123, user `vjovanov`) |
| Z-Wave JS server | `zwave-js-server.service` → `ws://localhost:3000` |
| Z-Wave JS driver config | `/etc/zwave-js/config.js` (security keys, mode 600) |
| Z-Wave JS cache | `/var/lib/zwave-js/cache/` |
| Z-Stick device | `/dev/serial/by-id/usb-0658_0200-if00` |
| Repo checkout | `/home/pi/c/z-automation` |
| Backups | `/home/homeassistant/ha-backup-<timestamp>/` |

## Deploy a config change

```bash
# 1. Edit files in the repo's hass-config/ (this repo).
# 2. Copy to the live config, owned by homeassistant:
sudo install -o homeassistant -g homeassistant -m 644 hass-config/<f>.yaml \
     /home/homeassistant/.homeassistant/<f>.yaml
# 3. Validate (exit 0 = OK):
sudo -u homeassistant /srv/homeassistant/bin/hass --script check_config \
     -c /home/homeassistant/.homeassistant
# 4. Restart + verify:
sudo systemctl restart home-assistant@homeassistant.service
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8123/    # expect 200
```
Logs: `sudo tail -f /home/homeassistant/.homeassistant/home-assistant.log`
or `journalctl -u home-assistant@homeassistant -f`.
`ui-lovelace.yaml` is **not** validated by `check_config`; sanity-check with
`python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' ui-lovelace.yaml`.

## Adding an integration without the UI (config-entry injection)

Used for `zwave_js`, `met`, `speedtestdotnet`. **Stop HA first.** Append an entry to
`/home/homeassistant/.homeassistant/.storage/core.config_entries` (match the existing
schema: `entry_id`, `version`, `domain`, `title`, `data`, `options`, `source`,
`unique_id`, ...), then start HA. Prefer the UI when a browser session is available.

## Rename a device / entity

Set `name_by_user` in `.storage/core.device_registry` (device) or
`.storage/core.entity_registry` (entity). **Stop HA, edit, start.** zwave_js entities
use `has_entity_name`, so a device rename cascades to all its entities.

## Z-Wave operations

Enumerate nodes / read values (server speaks the JSON protocol on :3000):
```bash
node - <<'EOF'   # connect, send {command:"start_listening"}, read result.state.nodes
EOF
```
(See git history for the small `ws` dump scripts.) Re-interview a node:
`{command:"node.refresh_info", nodeId:<n>}`. Battery nodes (the MultiSensors)
interview only while awake — press the unit's action button to wake it.

## Git / push

Remote is `git@github.com:vjovanov/z-automation` over SSH. The Pi pushes with the
`pi` user's key (`~/.ssh/id_rsa`), authorized as a repo **deploy key (write)**.
`GIT_SSH_COMMAND="ssh -o BatchMode=yes" git push origin master`.

## Verification checklist after changes

- `check_config` exit 0; HA HTTP 200; no `ERROR` in the log.
- Expected entities exist (query the recorder DB read-only, or the states UI).
- `systemctl show home-assistant@homeassistant -p NRestarts` stays 0 (no crash loop).
- Z-Wave: `zwave-js-server.service` running; nodes Alive in a state dump.
