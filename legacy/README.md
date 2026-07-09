# Legacy files (retained for history / reference)

These are the pre-2026 implementations. They are **no longer used** and are kept
only so the git history and prior logic remain discoverable.

| File | Replaced by |
|------|-------------|
| `heating.py`, `heating-daemon.sh` | Go **heating-controller** (systemd, GPIO relays, web UI on :8080) — a separate project. |
| `relay-control.py`, `relay-control.py_original_before_bojan`, `relay-control.sh` | Go **heating-controller** (owns the relays). |
| `report-motion.sh` | HA-native alarm: `rest_command.messagebird_sms` + `notify.alarm_targets` in `hass-config/`. |
| `hass-daemon.sh` | systemd unit `systemd/home-assistant@.service` (the init.d `--daemon/--pid-file` flags were removed from HA). |
| `options.xml` | Z-Wave JS (`zwave-js/config.js`); the old OpenZWave options are obsolete. |
| `www/zwavegraph3.js`, `panels/zwavegraph2.html` | Z-Wave JS built-in network view (Settings -> Devices -> Z-Wave JS). |

The old heating/relay/alarm systems wrote flat files under `/home/pi/{heating,relays,alarm}`
and were wired into HA via `command_line` switches/sensors. That whole mechanism
is gone: heating now lives entirely in the heating-controller, and the alarm is
implemented with HA helpers + automations.
