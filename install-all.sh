#!/usr/bin/env bash

PI_HOME="/home/pi/"
CODE_HOME="$PI_HOME/z-automation/"


cp "$PI_HOME/z-automation/relay-control.sh" /etc/init.d/relay-control-daemon
chmod +x /etc/init.d/relay-control-daemon
update-rc.d relay-control-daemon defaults
service relay-control-daemon install

cp "$PI_HOME/z-automation/wifi-reseter.sh" /etc/init.d/wifi-reseter-daemon
chmod +x /etc/init.d/wifi-reseter-daemon
update-rc.d wifi-reseter-daemon defaults
service wifi-reseter-daemon install


cp "$PI_HOME/z-automation/hass-daemon.sh"  /etc/init.d/hass-daemon
chmod +x /etc/init.d/hass-daemon
update-rc.d hass-daemon defaults
service hass-daemon install
