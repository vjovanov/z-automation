#!/usr/bin/env bash
# Upgrade Home Assistant Core within the existing venv.
#
# CEILING: this box is Debian 11 (Python 3.9). HA 2023.1.x is the LAST release
# that supports Python 3.9 — you cannot pip-upgrade past it here. Trying to will
# fail on the Python version requirement.
#
# To run a newer HA you must first get a newer Python (3.12+). See the README
# section "Migrating to latest HA" (Docker, or new hardware). Do NOT attempt a
# blind `pip install --upgrade homeassistant` — it will break this install.
set -euo pipefail

echo "Current HA: $(/srv/homeassistant/bin/hass --version 2>/dev/null || echo unknown)"
echo "Python:     $(/srv/homeassistant/bin/python3 --version)"
echo
echo "This host is pinned to HA 2023.1.7 (Python 3.9 ceiling)."
echo "See README 'Migrating to latest HA' to move to a current release."
