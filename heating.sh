#!/bin/sh
### BEGIN INIT INFO
# Provides:          heating
# Required-Start:    $all
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:
# Description:       Heating\ Control
### END INIT INFO

# /etc/init.d Service Script for Zlatibor
# Created with: https://gist.github.com/naholyr/4275302#file-new-service-sh

# No server running so we can run as PI
PI_HOME="/home/pi/"
CODE_HOME="$PI_HOME/z-automation/"

RUN_AS="pi"
RELAY_DIR="$PI_HOME/relays"
HEATING_DIR="$PI_HOME/heating"
PRE_EXEC="/usr/bin/python3"
CONFIG_DIR="/var/opt/heating"
PID_FILE="/var/run/heating.pid"
BINARY="$CODE_HOME/heating.py"
FLAGS="$PID_FILE $HEATING_DIR $RELAY_DIR"
REDIRECT="> $CONFIG_DIR/heating.log 2>&1"
SERVICE_NAME="Heating Control"
start() {
  if [ -f ${PID_FILE} ] && kill -0 $(cat ${PID_FILE}) 2> /dev/null; then
    /bin/echo 'Service already running' >&2
    return 1
  fi

  /bin/echo "999999" > ${PID_FILE}
  chown $RUN_AS $PID_FILE

  /bin/echo 'Starting service...' >&2
  local CMD="$PRE_EXEC $BINARY $FLAGS $REDIRECT;"
  /bin/su -c "$CMD" ${RUN_AS} &
  /bin/echo 'Service started' >&2
}

stop() {
  if [ ! -f "$PID_FILE" ] || ! kill -0 $(cat "$PID_FILE") 2> /dev/null; then
    /bin/echo 'Service not running' >&2
    return 1
  fi
  /bin/echo 'Stopping service…' >&2
  /bin/kill $(cat "$PID_FILE")
  while ps -p $(cat "$PID_FILE") > /dev/null 2>&1; do sleep 1;done;
  /bin/echo 'Service stopped' >&2
}

install() {
    echo "Installing $SERVICE_NAME Daemon (heating)"

    echo "Creating heating files in $HEATING_DIR"
    mkdir -p $HEATING_DIR
    chown $RUN_AS:homeassistant "$HEATING_DIR"
    echo 0 > $HEATING_DIR/electrical-heating-switch
    chown $RUN_AS:homeassistant "$HEATING_DIR/electrical-heating-switch"
    echo 0 > $PI_HOME/heating/gas-heating-switch
    chown $RUN_AS:homeassistant "$HEATING_DIR/gas-heating-switch"

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
    echo ${CONFIG_DIR}
    update-rc.d -f heating-daemon remove
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
