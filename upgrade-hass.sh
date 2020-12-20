#! /bin/sh

set -x

su -l homeassistant

source /srv/homeassistant/bin/activate

pip3 install --upgrade homeassistant
