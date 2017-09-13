import sys
import signal

POLL_PERIOD_SECONDS = 0.2
try:
    # noinspection PyUnresolvedReferences
    import RPi.GPIO as GPIO
except RuntimeError:
    print("Error importing RPi.GPIO!  This is probably because you need superuser privileges.\n" +
          "  You can achieve this by using 'sudo' to run your script")

from time import sleep
import os

RELAY_GPIO_MAP = {
    0: 5,
    1: 6,
    2: 13,
    3: 19,
    4: 26,
    5: 16,
    6: 21,
    7: 20,
}


def setup_gpio():
    GPIO.setmode(GPIO.BCM)
    for pin in RELAY_GPIO_MAP.values():
        GPIO.setup(pin, GPIO.OUT)


def reset_state(pid_file):
    for relay in iter(range(len(RELAY_GPIO_MAP))):
        GPIO.output(RELAY_GPIO_MAP[relay], 0)
    GPIO.cleanup()
    with open(pid_file, "w") as text_file:
        text_file.write("99999999")


class GracefulKiller:
    killed = False

    def __init__(self, pid_file):
        self.pid_file = pid_file
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)

    # noinspection PyUnusedLocal
    def exit_gracefully(self, signum, frame):
        self.killed = True
        reset_state(self.pid_file)  # just in case normal break is never reached


def main():
    if len(sys.argv) != 3:
        sys.stderr.write(
            "relay-control.py expects two arguments pointing to the PID file and to the folder with relay states.\n")
        sys.exit(1)

    pid_file = sys.argv[1]
    relay_dir = sys.argv[2]
    if not os.path.isdir(relay_dir):
        sys.stderr.write(
            "Relay dir " + relay_dir + " is not a directory")

    killer = GracefulKiller(pid_file)
    try:
        setup_gpio()
        switches = [0 for _ in iter(range(len(RELAY_GPIO_MAP)))]
        with open(pid_file, "w") as text_file:
            text_file.write(str(os.getpid()))

        while True:
            for relay in iter(range(len(RELAY_GPIO_MAP))):
                switch_state_file_path = relay_dir + os.sep + str(relay)
                content = ""
                try:
                    with open(switch_state_file_path, 'r') as content_file:
                        content = content_file.read().strip()
                        value = int(content)
                        if value == 0 or value == 1:
                            switches[relay] = value
                        else:
                            sys.stderr.write("For switch " + str(
                                relay) + " expected 0 or 1 but found " + str(value) + ". Keeping the previous state.\n")
                except IOError:
                    sys.stderr.write("Can't open the switch file " + switch_state_file_path + ".\n")
                except ValueError:
                    sys.stderr.write("Can't read state from the switch " + str(
                        relay) + ": expected a number 0 or 1. Found " + content + ". Keeping the previous state.\n")

                # setting the relay state according to switch states
                assert switches[relay] == 0 or switches[relay] == 1

                # make sure the pump is running if the heating is on
                if (relay == 1 or relay == 2) and switches[relay] == 1:
                    assert switches[0] == 1

                GPIO.output(RELAY_GPIO_MAP[relay], switches[relay])

            sleep(POLL_PERIOD_SECONDS)
            if killer.killed:
                break
    finally:
        reset_state(pid_file)


if __name__ == '__main__':
    main()
