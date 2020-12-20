#!/usr/bin/env bash

PI_HOME="/home/pi/"
CODE_HOME="$PI_HOME/z-automation/"

apt install nmap
apt install libudev-dev
apt install vim
apt install libjpeg-dev zlib1g-dev

# Scripts
pip3 install requests

# GPIO
apt-get install python-rpi.gpio python3-rpi.gpio

# Relays
mkdir -p /var/run
cp "$PI_HOME/z-automation/relay-control.sh" /etc/init.d/relay-control-daemon
chmod +x /etc/init.d/relay-control-daemon
update-rc.d relay-control-daemon defaults
service relay-control-daemon install

# Heating
cp "$PI_HOME/z-automation/heating-daemon.sh" /etc/init.d/heating-daemon
chmod +x /etc/init.d/heating-daemon
update-rc.d heating-daemon defaults
service heating-daemon install

# Home assistant
cp "$PI_HOME/z-automation/hass-daemon.sh" /etc/init.d/hass-daemon
chmod +x /etc/init.d/hass-daemon
update-rc.d hass-daemon defaults
service hass-daemon install


# Alarm
mkdir "$PI_HOME/alarm"
chown pi:homeassistant "$PI_HOME/alarm"
sudo cp "$PI_HOME/z-automation/report-motion.sh" "$PI_HOME/alarm/"
sudo chown pi:homeassistant "$PI_HOME/alarm/report-motion.sh"
sudo echo 0 > "$PI_HOME/alarm/switch"
chown pi:homeassistant "$PI_HOME/alarm/switch"
chmod g+rw "$PI_HOME/alarm/switch"
/bin/date +%s > "$PI_HOME/alarm/last_alarm"
chown pi:homeassistant "$PI_HOME/alarm/last_alarm"
chmod g+rw "$PI_HOME/alarm/last_alarm"
