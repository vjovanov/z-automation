import sys

POLL_PERIOD_SECONDS = 0.2
try:
    import RPi.GPIO as GPIO
except RuntimeError:
    print("Error importing RPi.GPIO!  This is probably because you need superuser privileges.\n" +
          "  You can achieve this by using 'sudo' to run your script")

from time import sleep
import os

GPIO.setmode(GPIO.BCM)

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

for pin in RELAY_GPIO_MAP.values():
    GPIO.setup(pin, GPIO.OUT)


def main():
    switches = [0 for _ in xrange(len(RELAY_GPIO_MAP))]
    if len(sys.argv) != 2:
        sys.stderr.write("relay_control.py expects a single argument pointing to the folder with relay states.\n")
        sys.exit(1)

    path = sys.argv[1]
    time = 0
    while True:
        for relay in xrange(len(RELAY_GPIO_MAP)):
            switch_state_file_path = path + os.sep + str(relay)
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
            GPIO.output(RELAY_GPIO_MAP[relay], switches[relay])

        sleep(POLL_PERIOD_SECONDS)
        time += 1


if __name__ == '__main__':
    main()
