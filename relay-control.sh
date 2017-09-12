#!/bin/sh
### BEGIN INIT INFO
# Provides:          relay-control
# Required-Start:    $all
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Relay\ Control
### END INIT INFO

# /etc/init.d Service Script for Zlatibor
# Created with: https://gist.github.com/naholyr/4275302#file-new-service-sh
HASS_HOME="/home/homeassistant/"
PI_HOME="/home/pi/"
CODE_HOME="$PI_HOME/z-automation/"
RELAY_DIR="$HASS_HOME/relays"
PRE_EXEC="/usr/bin/python"
RUN_AS="homeassistant"
CONFIG_DIR="/var/opt/relay-control"
PID_FILE="/var/run/relay-control.pid"
BINARY="$CODE_HOME/relay-control.py"
FLAGS="$PID_FILE $RELAY_DIR"
REDIRECT="> $CONFIG_DIR/relay-control.log 2>&1"
SERVICE_NAME="Relay Control"

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
    echo "Installing $SERVICE_NAME Daemon (relay-control)"

    echo "Creating $PID_FILE"
    echo "999999" > $PID_FILE
    chown $RUN_AS $PID_FILE

    echo "Creating relay files in $RELAY_DIR"
    mkdir -p $RELAY_DIR
    chown $RUN_AS $RELAY_DIR
    for i in 0 1 2 3 4 5 6 7; do
       echo "0" > "$RELAY_DIR/$i";
       chown $RUN_AS "$RELAY_DIR/$i"
    done;

    echo "Creating a config dir $CONFIG_DIR"
    mkdir -p $CONFIG_DIR
    chown $RUN_AS $CONFIG_DIR
}

uninstall() {
  echo -n "Are you really sure you want to uninstall this service? That cannot be undone. [yes|No] "
  local SURE
  read SURE
  if [ "$SURE" = "yes" ]; then
    stop

    echo "Removing $PID_FILE"
    rm -fv "$PID_FILE"
    echo "Removing relay files in $RELAY_DIR"
    rm -fv "$RELAY_DIR"
    echo "Notice: The config directory has not been removed"
    echo $CONFIG_DIR
    update-rc.d -f relay-control-daemon remove
    rm -fv "$0"
    echo "$SERVICE_NAME Daemon has been removed. $SERVICE_NAME is still installed."
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
