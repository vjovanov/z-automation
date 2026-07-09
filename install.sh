#!/usr/bin/env bash
# ============================================================================
# End-to-end provisioner for the Zlatibor Home Assistant + Z-Wave JS stack.
#
# Takes a bare Debian 11 (Raspberry Pi, Python 3.9) box to a fully working HA:
#   system deps -> homeassistant user + venv + HA Core -> Node + zwave-js-server
#   -> Z-Wave security keys -> systemd units (HA, Z-Wave, daily backup)
#   -> deploy HA config -> admin user + skip onboarding -> inject the zwave_js /
#   met / speedtest config entries -> start + health-check.
#
# IDEMPOTENT: safe to re-run. Every mutating step is guarded and skips if already
# done, so it will not clobber an existing network, user, keys, or secrets.
#
# Does **NOT** touch the heating-controller (separate Go project on :8080).
#
# Usage:
#   sudo -v && ./install.sh                 # interactive-ish (uses defaults)
#   HA_PASS='s3cret' ./install.sh           # also create the admin login
#   HA_USER=vjovanov LAT=43.7321 LON=19.7054 ELEV=981 SITE_NAME=Zlatibor ./install.sh
#
# NOTE: 2023.1.7 is the last HA that runs on Debian 11 / Python 3.9. See README
# "Migrating to latest HA" before changing HA_VERSION.
# ============================================================================
set -euo pipefail

# ---- Tunables (all env-overridable) ----------------------------------------
HA_VERSION="${HA_VERSION:-2023.1.7}"
ZWAVEJS_VERSION="${ZWAVEJS_VERSION:-1.25.0}"   # schema-compatible with HA 2023.1.7
ZSTICK_DEV="${ZSTICK_DEV:-/dev/serial/by-id/usb-0658_0200-if00}"
HA_USER="${HA_USER:-vjovanov}"
HA_PASS="${HA_PASS:-}"                         # empty => leave onboarding to the browser
SITE_NAME="${SITE_NAME:-Zlatibor}"
LAT="${LAT:-43.7321}"; LON="${LON:-19.7054}"; ELEV="${ELEV:-981}"
INJECT_ENTRIES="${INJECT_ENTRIES:-1}"          # 1 => inject zwave_js/met/speedtest entries

REPO="$(cd "$(dirname "$0")" && pwd)"
HA_HOME="/home/homeassistant"
HA_DIR="${HA_HOME}/.homeassistant"
VENV="/srv/homeassistant"
HA="${VENV}/bin/hass"
PY="${VENV}/bin/python3"
STORAGE="${HA_DIR}/.storage"

log(){ echo; echo "==> $*"; }
have(){ command -v "$1" &>/dev/null; }

# ---- 0. Preflight ----------------------------------------------------------
log "Preflight"
[ "$(id -u)" -ne 0 ] || { echo "Run as a normal user with sudo, not as root."; exit 1; }
sudo -v || { echo "This script needs sudo."; exit 1; }
echo "Host: $(uname -m) | $(. /etc/os-release; echo "$PRETTY_NAME") | python3 $(python3 -V 2>&1 | awk '{print $2}')"

# ---- 1. System dependencies ------------------------------------------------
log "System dependencies"
sudo apt-get update
sudo apt-get install -y python3 python3-dev python3-venv python3-pip \
  bluez libffi-dev libssl-dev libjpeg-dev zlib1g-dev autoconf build-essential \
  libopenjp2-7 libtiff5 libturbojpeg0-dev tzdata ffmpeg liblapack3 liblapack-dev \
  libatlas-base-dev curl git openssl

# ---- 2. homeassistant user + venv + HA Core --------------------------------
log "homeassistant user + venv + HA ${HA_VERSION}"
id homeassistant &>/dev/null || sudo useradd -rm homeassistant -G dialout,gpio,i2c
sudo mkdir -p "$VENV"
sudo chown homeassistant:homeassistant "$VENV"
sudo -u homeassistant -H bash -c "
  set -e
  cd '$VENV'
  [ -x bin/activate ] || python3 -m venv .
  source bin/activate
  pip install --upgrade pip wheel
  pip show homeassistant 2>/dev/null | grep -q 'Version: ${HA_VERSION}' \
    || pip install 'homeassistant==${HA_VERSION}'
"

# ---- 3. Node 20 + zwave-js server ------------------------------------------
log "Node 20 + @zwave-js/server ${ZWAVEJS_VERSION}"
if ! have node; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
if ! have zwave-server || ! zwave-server --version 2>/dev/null | grep -q "$ZWAVEJS_VERSION"; then
  sudo npm install -g "@zwave-js/server@${ZWAVEJS_VERSION}"
fi

# ---- 4. Z-Wave JS security keys + cache ------------------------------------
log "Z-Wave JS config + cache"
sudo install -d -o homeassistant -g homeassistant /etc/zwave-js /var/lib/zwave-js/cache
if [ -f /etc/zwave-js/config.js ]; then
  echo "config.js already present — keeping existing keys (secure devices stay paired)."
else
  echo "Generating FRESH security keys. (A brand-new network — any previously"
  echo "secure-included devices would need re-pairing. Fine for a clean install.)"
  sudo "$PY" - "$REPO/zwave-js/config.js.template" <<'PYEOF'
import sys, re, secrets
tpl = open(sys.argv[1]).read()
out = re.sub(r"REPLACE_32_HEX_CHARS", lambda m: secrets.token_hex(16), tpl)
open("/etc/zwave-js/config.js", "w").write(out)
PYEOF
  sudo chown homeassistant:homeassistant /etc/zwave-js/config.js
  sudo chmod 600 /etc/zwave-js/config.js
fi

# ---- 5. systemd units (HA, Z-Wave server, daily backup) --------------------
log "systemd units"
sudo cp "${REPO}/systemd/home-assistant@.service" /etc/systemd/system/
sudo cp "${REPO}/systemd/zwave-js-server.service" /etc/systemd/system/
sudo cp "${REPO}/systemd/zauto-backup.service" "${REPO}/systemd/zauto-backup.timer" /etc/systemd/system/
# Point the Z-Wave unit at this host's stick path if overridden.
if [ "$ZSTICK_DEV" != "/dev/serial/by-id/usb-0658_0200-if00" ]; then
  sudo sed -i "s#/dev/serial/by-id/usb-0658_0200-if00#${ZSTICK_DEV}#" \
    /etc/systemd/system/zwave-js-server.service
fi
sudo systemctl daemon-reload
sudo systemctl enable --now zwave-js-server.service

# ---- 6. Deploy HA config (BEFORE first HA start, so it never boots on defaults)
log "Deploy HA config"
sudo -u homeassistant mkdir -p "$HA_DIR"
sudo cp "${REPO}"/hass-config/*.yaml "$HA_DIR"/
[ -f "${HA_DIR}/secrets.yaml" ] || \
  sudo -u homeassistant cp "${REPO}/hass-config/secrets.yaml.example" "${HA_DIR}/secrets.yaml"
sudo chown -R homeassistant:homeassistant "$HA_DIR"

# ---- 7. Admin user + skip onboarding (only if HA_PASS given and no user yet)
if [ -n "$HA_PASS" ]; then
  log "Home Assistant admin user '${HA_USER}' + onboarding"
  sudo systemctl stop home-assistant@homeassistant.service 2>/dev/null || true
  if sudo -u homeassistant "$HA" --script auth --config "$HA_DIR" list 2>/dev/null | grep -qx "$HA_USER"; then
    echo "User '${HA_USER}' already exists — leaving it (and onboarding) untouched."
  else
    sudo -u homeassistant "$HA" --script auth --config "$HA_DIR" add "$HA_USER" "$HA_PASS"
    # Promote to owner + admin, and mark onboarding complete.
    sudo "$PY" - "$STORAGE" "$HA_USER" <<'PYEOF'
import sys, json, os
storage, username = sys.argv[1], sys.argv[2]
auth_p = os.path.join(storage, "auth")
a = json.load(open(auth_p)); d = a["data"]
uid = next(c["user_id"] for c in d["credentials"]
           if c.get("auth_provider_type") == "homeassistant"
           and c.get("data", {}).get("username") == username)
for u in d["users"]:
    if u["id"] == uid:
        u["is_owner"] = True; u["is_active"] = True
        u["group_ids"] = ["system-admin"]
json.dump(a, open(auth_p, "w"), indent=2)
onboarding = {"version": 4, "minor_version": 1, "key": "onboarding",
              "data": {"done": ["user", "core_config", "analytics", "integration"]}}
json.dump(onboarding, open(os.path.join(storage, "onboarding"), "w"), indent=2)
print("  promoted", username, "to owner/admin; onboarding marked done")
PYEOF
    sudo chown -R homeassistant:homeassistant "$STORAGE"
  fi
else
  echo "  (HA_PASS not set — first login/onboarding will be done in the browser.)"
fi

# ---- 8. Inject config entries: zwave_js / met / speedtest (if absent) -------
if [ "$INJECT_ENTRIES" = "1" ]; then
  log "Inject config entries (zwave_js, met=${SITE_NAME}, speedtestdotnet)"
  sudo systemctl stop home-assistant@homeassistant.service 2>/dev/null || true
  sudo "$PY" - "$STORAGE" "$SITE_NAME" "$LAT" "$LON" "$ELEV" <<'PYEOF'
import sys, json, os, secrets
storage, name, lat, lon, elev = sys.argv[1:6]
lat, lon, elev = float(lat), float(lon), float(elev)
path = os.path.join(storage, "core.config_entries")
if not os.path.exists(path):
    # HA writes this on first start; if it isn't here yet, start HA once then re-run.
    print("  core.config_entries not present yet — skip (start HA once, then re-run)."); raise SystemExit
c = json.load(open(path)); entries = c["data"]["entries"]
have = {e["domain"] for e in entries}
def base(domain, title):
    return {"entry_id": secrets.token_hex(16), "version": 1, "domain": domain,
            "title": title, "data": {}, "options": {},
            "pref_disable_new_entities": False, "pref_disable_polling": False,
            "source": "user", "unique_id": None, "disabled_by": None}
added = []
if "zwave_js" not in have:
    e = base("zwave_js", "Z-Wave JS")
    e["data"] = {"url": "ws://localhost:3000", "use_addon": False,
                 "integration_created_addon": False}
    entries.append(e); added.append("zwave_js")
if "met" not in have:
    e = base("met", name)
    e["data"] = {"name": name, "latitude": lat, "longitude": lon, "elevation": elev}
    e["unique_id"] = f"{lat}-{lon}"
    entries.append(e); added.append("met")
if "speedtestdotnet" not in have:
    entries.append(base("speedtestdotnet", "Speedtest.net")); added.append("speedtestdotnet")
json.dump(c, open(path, "w"), indent=2)
print("  injected:", added or "nothing (all present)")
PYEOF
  sudo chown -R homeassistant:homeassistant "$STORAGE"
fi

# ---- 9. Start Home Assistant + daily backup timer --------------------------
log "Start Home Assistant + backup timer"
sudo systemctl enable --now home-assistant@homeassistant.service
sudo systemctl enable --now zauto-backup.timer

# ---- 10. Validate + health check -------------------------------------------
log "Validate + health check"
sudo -u homeassistant "$HA" --script check_config -c "$HA_DIR"
for i in $(seq 1 40); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8123/ 2>/dev/null || true)
  [ "$code" = "200" ] || [ "$code" = "302" ] && { echo "HA up (HTTP $code)"; break; }
  sleep 3
done

cat <<DONE

============================================================================
Done. Open http://10.92.0.2:8123  (user: ${HA_USER})

Remaining MANUAL steps (cannot be safely automated):
  1. Fill ${HA_DIR}/secrets.yaml with the real MessageBird key, phone,
     and public alarm URL, then restart HA.
  2. On your phone: install the HA Companion app, log in to this server, then
     add its  '- service: mobile_app_<device>'  to the alarm_targets notify
     group in configuration.yaml and restart.
  3. (Fresh Z-Wave network only) Include your devices and name each by room
     (device registry) — see AGENTS.md "Z-Wave operations" / "Rename a device".

Heating is the separate heating-controller project (:8080) — not installed here.
============================================================================
DONE
