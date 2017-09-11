#!/bin/sh
### BEGIN INIT INFO
# Provides:          hass
# Required-Start:    $local_fs $network $named $time $syslog
# Required-Stop:     $local_fs $network $named $time $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Home\ Assistant
### END INIT INFO

# /etc/init.d Service Script for Home Assistant
# Created with: https://gist.github.com/naholyr/4275302#file-new-service-sh
HASS_HOME="/home/homeassistant/"
CODE_HOME="$HASS_HOME/z-automation/"

PRE_EXEC="python"
RUN_AS="homeassistant"
CONFIG_DIR="/var/opt/relay-control"
PID_FILE="/var/run/relay-control.pid"
BINARY="relay-control.py"
RELAY_FILE="$HOME/relays"

FLAGS="$PID_FILE $RELAY_FILE"
REDIRECT="> $CONFIG_DIR/relay-control.log 2>&1"


start() {
  if [ -f $PID_FILE ] && kill -0 $(cat $PID_FILE) 2> /dev/null; then
    echo 'Service already running' >&2
    return 1
  fi
  echo 'Starting service…' >&2
  local CMD="$PRE_EXEC $BINARY $FLAGS $REDIRECT;"
  su -c "$CMD" $RUN_AS
  echo 'Service started' >&2
}

stop() {
    if [ ! -f "$PID_FILE" ] || ! kill -0 $(cat "$PID_FILE") 2> /dev/null; then
    echo 'Service not running' >&2
    return 1
  fi
  echo 'Stopping service…' >&2
  kill $(cat "$PID_FILE")
  while ps -p $(cat "$PID_FILE") > /dev/null 2>&1; do sleep 1;done;
  echo 'Service stopped' >&2
}

install() {
    echo "Installing Relay Control Daemon (relay-control)"
    echo "999999" > $PID_FILE
    chown $RUN_AS $PID_FILE
    mkdir -p $CONFIG_DIR
    chown $RUN_AS $CONFIG_DIR
}

uninstall() {
  echo -n "Are you really sure you want to uninstall this service? That cannot be undone. [yes|No] "
  local SURE
  read SURE
  if [ "$SURE" = "yes" ]; then
    stop
    rm -fv "$PID_FILE"
    echo "Notice: The config directory has not been removed"
    echo $CONFIG_DIR
    update-rc.d -f relay-control remove
    rm -fv "$0"
    echo "Relay Control Daemon has been removed. Home Assistant is still installed."
  fi
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  install)
    install
    ;;
  uninstall)
    uninstall
    ;;
  restart)
    stop
    start
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|install|uninstall}"
esac
