import signal
import sys
from time import sleep
import os
from contextlib import contextmanager

POLL_PERIOD_SECONDS = 1
DELTA = 0.5

gas_heating_switch = False
electrical_heating_switch = False
gas_heating_on = False
electrical_heating_on = False
relay_dir = None
pid_file = None


@contextmanager
def atomic_write(filepath, binary=False, fsync=False):
    """ Writeable file object that atomically updates a file (using a temporary file).

    :param filepath: the file path to be opened
    :param binary: whether to open the file in a binary mode instead of textual
    :param fsync: whether to force write the file to disk
    """

    tmppath = filepath + '~'
    while os.path.isfile(tmppath):
        tmppath += '~'
    try:
        with open(tmppath, 'wb' if binary else 'w') as file:
            yield file
            if fsync:
                file.flush()
                os.fsync(file.fileno())
        os.rename(tmppath, filepath)
    finally:
        try:
            os.remove(tmppath)
        except (IOError, OSError):
            pass

def relay_state(value):
    return '1' if value == True else '0'

def heating(heating_type, state):
    if heating_type is 'electrical':
        global electrical_heating_on
        electrical_heating_on = state

    if heating_type is 'gas':
        global gas_heating_on
        gas_heating_on = state

    # race condition: pump works before any heating is on
    if gas_heating_on or electrical_heating_on:
        with atomic_write(os.path.join(relay_dir, '0')) as r0:
            r0.write(relay_state(True))

    with atomic_write(os.path.join(relay_dir, '1')) as r1:
            r1.write(relay_state(gas_heating_on))

    with atomic_write(os.path.join(relay_dir, '2')) as r2:
            r2.write(relay_state(electrical_heating_on))

    # race condition: pump is off after heating is turned off
    if not (gas_heating_on or electrical_heating_on):
        with atomic_write(os.path.join(relay_dir, '0')) as r0:
            r0.write(relay_state(False))


def reset_state(pid_file):
    with open(pid_file, "w") as text_file:
        text_file.write("99999999")
    heating('electrical', False)
    heating('gas', False)

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

    global pid_file, relay_dir
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
            assert desired_temperature >= 3

            if current_temperature >= (desired_temperature + DELTA):
                heating("electrical", False)
                heating("gas", False)
            elif current_temperature < (desired_temperature - DELTA):
                if electrical_heating_switch:
                    heating("electrical", True)
                if gas_heating_switch:
                    heating("gas", True)

            if not electrical_heating_switch:
                heating("electrical", False)
            if not gas_heating_switch:
                heating("gas", False)

            sleep(POLL_PERIOD_SECONDS)
            if killer.killed:
                break
    finally:
        reset_state(pid_file)


if __name__ == '__main__':
    main()
