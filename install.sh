#!/usr/bin/env bash
# Install / provision the Zlatibor Home Assistant + Z-Wave JS stack.
#
# Architecture (2026):
#   * Home Assistant Core 2023.1.7 in a Python venv at /srv/homeassistant,
#     run by systemd unit home-assistant@homeassistant.service.
#   * Z-Wave JS server (Node) driving the Aeotec Z-Stick, run by
#     systemd unit zwave-js-server.service, listening on ws://localhost:3000.
#     HA's zwave_js integration connects to it (config entry, not YAML).
#   * Heating is a SEPARATE project (Go heating-controller, :8080) — not managed
#     here and intentionally left untouched.
#
# NOTE: 2023.1.7 is the last HA that runs on Debian 11 / Python 3.9. See README
# "Migrating to latest HA" before upgrading.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
HA_VERSION="2023.1.7"
ZWAVEJS_VERSION="1.25.0"   # schema-compatible with HA 2023.1.7 (schema 24)

echo "==> System dependencies"
sudo apt-get update
sudo apt-get install -y python3 python3-dev python3-venv python3-pip \
  bluez libffi-dev libssl-dev libjpeg-dev zlib1g-dev autoconf build-essential \
  libopenjp2-7 libtiff5 libturbojpeg0-dev tzdata ffmpeg liblapack3 liblapack-dev \
  libatlas-base-dev curl git

echo "==> homeassistant user + venv"
id homeassistant &>/dev/null || sudo useradd -rm homeassistant -G dialout,gpio,i2c
sudo mkdir -p /srv/homeassistant
sudo chown homeassistant:homeassistant /srv/homeassistant
sudo -u homeassistant -H bash -c "
  set -e
  cd /srv/homeassistant
  [ -x bin/activate ] || python3 -m venv .
  source bin/activate
  pip install --upgrade pip wheel
  pip install homeassistant==${HA_VERSION}
"

echo "==> Node 20 + zwave-js server ${ZWAVEJS_VERSION}"
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
sudo npm install -g "@zwave-js/server@${ZWAVEJS_VERSION}"

echo "==> Z-Wave JS config + cache"
sudo install -d -o homeassistant -g homeassistant /etc/zwave-js /var/lib/zwave-js/cache
if [ ! -f /etc/zwave-js/config.js ]; then
  echo "!! /etc/zwave-js/config.js missing — create it from zwave-js/config.js.template"
  echo "   and fill the six security keys (openssl rand -hex 16). Aborting."
  exit 1
fi

echo "==> systemd units"
sudo cp "${REPO}/systemd/home-assistant@.service" /etc/systemd/system/
sudo cp "${REPO}/systemd/zwave-js-server.service" /etc/systemd/system/
sudo cp "${REPO}/systemd/zauto-backup.service" "${REPO}/systemd/zauto-backup.timer" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now zwave-js-server.service

echo "==> Deploy HA config (before first HA start, so it never boots on defaults)"
sudo -u homeassistant mkdir -p /home/homeassistant/.homeassistant
sudo cp "${REPO}"/hass-config/*.yaml /home/homeassistant/.homeassistant/
[ -f /home/homeassistant/.homeassistant/secrets.yaml ] || \
  sudo -u homeassistant cp "${REPO}/hass-config/secrets.yaml.example" \
      /home/homeassistant/.homeassistant/secrets.yaml
sudo chown -R homeassistant:homeassistant /home/homeassistant/.homeassistant

echo "==> Start Home Assistant + daily backup timer"
sudo systemctl enable --now home-assistant@homeassistant.service
sudo systemctl enable --now zauto-backup.timer

echo "==> Validate + restart"
sudo -u homeassistant /srv/homeassistant/bin/hass \
  --script check_config -c /home/homeassistant/.homeassistant
sudo systemctl restart home-assistant@homeassistant.service

cat <<'DONE'
Done. Open http://10.92.0.2:8123
Remaining manual steps:
  * Add the Z-Wave JS integration (Settings -> Devices -> Add -> Z-Wave JS,
    URL ws://localhost:3000) if not already present.
  * Fill /home/homeassistant/.homeassistant/secrets.yaml (MessageBird + phone + URL).
  * Register the HA Companion app on your phone and add its service to the
    `alarm_targets` notify group in configuration.yaml.
DONE
