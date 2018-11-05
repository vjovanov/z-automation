import signal
import sys
from time import sleep

import os

POLL_PERIOD_SECONDS = 1
DELTA = 0.5
GAS_DELTA = 1.5

def reset_state(pid_file):
    with open(pid_file, "w") as text_file:
        text_file.write("99999999")

def heating(type, state):
    print(type + ": " + state)

class GracefulKiller:
    killed = False

    def __init__(self, pid_file, relay_dir):
        self.pid_file = pid_file
        self.relay_dir = relay_dir
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)

    # noinspection PyUnusedLocal
    def exit_gracefully(self, signum, frame):
        self.killed = True
        reset_state(self.pid_file)

gas_heating_switch = False
electrical_heating_switch = False
gas_heating_on = False
electrical_heating_on = False
desired_temperature = -1.0
current_temperature = -1.0

def read_state(relay_dir, thermostat_dir):
    global gas_heating_switch, electrical_heating_switch, desired_temperature, current_temperature, electrical_heating_on, gas_heating_on
    with open(os.path.join(thermostat_dir, 'gas-heating-switch'), 'r') as content_file:
        gas_heating_switch = int(content_file.read()) == 1

    with open(os.path.join(thermostat_dir, 'electrical-heating-switch'), 'r') as content_file:
        electrical_heating_switch = int(content_file.read()) == 1

    with open(os.path.join(thermostat_dir, 'desired-temperature'), 'r') as content_file:
        desired_temperature = float(content_file.read())

    with open(os.path.join(thermostat_dir, 'current-temperature'), 'r') as content_file:
        current_temperature = float(content_file.read())

    with open(os.path.join(relay_dir, '1'), 'r') as content_file:
        gas_heating_on = int(content_file.read()) == 1

    with open(os.path.join(relay_dir, '2'), 'r') as content_file:
        electrical_heating_on = int(content_file.read()) == 1


def main():
    if len(sys.argv) != 4:
        sys.stderr.write(
            "heating.py expects three arguments pointing to the PID file, to the relay dir, and to the folder with "
            "thermostat data.\n")
        sys.exit(1)

    pid_file = sys.argv[1]
    relay_dir = sys.argv[3]
    if not os.path.isdir(relay_dir):
        sys.stderr.write(
            "Relay dir " + relay_dir + " is not a directory.")

    thermostat_dir = sys.argv[2]
    if not os.path.isdir(relay_dir):
        sys.stderr.write(
            "Thermostat dir " + thermostat_dir + " is not a directory.")

    killer = GracefulKiller(pid_file, relay_dir)
    try:
        with open(pid_file, "w") as text_file:
            text_file.write(str(os.getpid()))

        while True:
            read_state(relay_dir, thermostat_dir)
            assert GAS_DELTA > DELTA
            assert desired_temperature >= 3

            # verify state is correct
            print(current_temperature, desired_temperature, "gas: " + "(" + str(gas_heating_switch) + "," + str(gas_heating_on) + ")", "el: (" + str(electrical_heating_switch) + "," + str(electrical_heating_on) + ")")

            if current_temperature > (desired_temperature + DELTA):
                heating("electrical", "off")
                heating("gas", "off")

            if (desired_temperature - DELTA) < current_temperature <= (desired_temperature + DELTA):
                if electrical_heating_switch and electrical_heating_on:
                    # Keep the house in balance with electrical heating
                    heating("electrical", "on")
                else:
                    heating("electrical", "off")

                if gas_heating_switch and not electrical_heating_switch and gas_heating_on:
                    heating("gas", "on")
                else:
                    heating("gas", "off")

            if (desired_temperature - GAS_DELTA) >= current_temperature > (desired_temperature - GAS_DELTA):
                if electrical_heating_switch:
                    # Keep the house in balance with electrical heating
                    heating("electrical", "on")
                    heating("gas", "off")
                else:
                    heating("electrical", "off")

                    # If electrical is off use the gas heating
                    if gas_heating_switch:
                        heating("gas", "on")
                    else:
                        heating("gas", "off")

            if (desired_temperature - GAS_DELTA) >= current_temperature:
                if electrical_heating_switch:
                    heating("electrical", "on")
                else:
                    heating("electrical", "off")
                if gas_heating_switch:
                    heating("gas", "on")
                else:
                    heating("gas", "off")

            sleep(POLL_PERIOD_SECONDS)
            if killer.killed:
                break
    finally:
        reset_state(pid_file)


if __name__ == '__main__':
    main()
