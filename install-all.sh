#!/usr/bin/env bash
PI_HOME="/home/pi/"
CODE_HOME="$PI_HOME/z-automation/"


cp /home/pi/z-automation/relay-control.sh /etc/init.d/relay-control-daemon
cp z-automation/relay-control.sh /etc/init.d/relay-control-daemon
chmod +x /etc/init.d/relay-control-daemon
update-rc.d relay-control-daemon defaults
service relay-control-daemon install
