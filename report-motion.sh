#!/bin/bash

# Configuration
LOG_FILE="/var/log/report-motion.log"
ALARM_DIR="/home/pi/alarm"

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
}

# Read alarm state files
ALARM_STATE=$(cat "$ALARM_DIR/switch" 2>/dev/null)
LAST_ALARM=$(cat "$ALARM_DIR/last_alarm" 2>/dev/null)
CURRENT_TIME=`/bin/date +%s`
SINCE_LAST_ALARM=`expr $CURRENT_TIME - $LAST_ALARM`
ACCESS_KEY=$1
[ -z "$ACCESS_KEY"  ] && echo "Must pass the access key for the messagebird.com as the first argument." && exit 1;
shift
phone_numbers=( "$@" )
FIRST_NUMBER=${phone_numbers[0]}
[ -z "$FIRST_NUMBER"  ] && echo "Must specify at least one phone number after the key." && exit 1;

# this is also done in the UI, but just in case
if [[ ( "$ALARM_STATE" == 1 ) && "$SINCE_LAST_ALARM" -gt "1800" ]] ; then
  echo $CURRENT_TIME > /home/pi/alarm/last_alarm

  for phone_number in "${phone_numbers[@]}"
    do
     if ! curl -X POST https://rest.messagebird.com/messages \
        -H "Authorization: AccessKey $ACCESS_KEY" \
        -d "recipients=$phone_number" \
        -d "originator=MessageBird" \
        -d "body=Detektovano je kretanje u kuci na Zlatiboru dok je alarm ukljucen! Proveriti na sledecem linku da li je kretanje slucajno i ako nije pozovite policiju (tel: 192): http://212.200.76.10:26681/lovelace/alarm" \
        --fail --silent --show-error; then
        log "Failed to send alert to $phone_number"
     else
        log "Alert successfully sent to $phone_number"
     fi
    done
fi

