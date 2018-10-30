#!/usr/bin/env bash

PI_HOME="/home/pi/"
CODE_HOME="$PI_HOME/z-automation/"

mkdir $PI_HOME/heating
echo 0 > $PI_HOME/heating/electrical-heating-switch
echo 0 > $PI_HOME/heating/gas-heating-switch

hassbian-config install razberry
apt install nmap
apt install libudev-dev
apt install vim

# z-wave
wget -q -O - razberry.z-wave.me/install 14 | sudo bash
sudo update-rc.d z-way-server remove

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

