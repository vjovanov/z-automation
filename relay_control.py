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
    0: 20,
    1: 21,
    2: 16,
    3: 26,
    4: 19,
    5: 13,
    6: 6,
    7: 5,
}

for pin in RELAY_GPIO_MAP.values():
    GPIO.setup(pin, GPIO.OUT)


def main():
    switches = [0 for _ in xrange(8)]
    if len(sys.argv) != 2:
        sys.stderr.write("relay_control.py expects a single argument pointing to the folder with relay states.\n")
        sys.exit(1)

    path = sys.argv[1]
    time = 0
    while True:
        print ("---")
        for relay in xrange(8):
            switch_state_file_path = path + os.sep + str(relay)
            content = ""
            try:
                with open(switch_state_file_path, 'r') as content_file:
                    content = content_file.read().strip()
                    value = int(content)
                    switches[relay] = int(value)
            except IOError:
                sys.stderr.write("Can't open the switch file " + switch_state_file_path + ".\n")
            except ValueError:
                sys.stderr.write("Can't read state from a switch " + str(
                    relay) + ": expected 0 or 1." + content + ". Keeping the previous state.\n")

            # setting the relay state according to switch states
            assert switches[relay] == 0 || switches[relay] == 1
            GPIO.output(RELAY_GPIO_MAP[relay], switches[relay])

        sleep(POLL_PERIOD_SECONDS)
        time += 1


if __name__ == '__main__':
    main()
