import fcntl
import os
import struct
from time import sleep
import socket
import sys
import signal


def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,
        struct.pack('256s', ifname[:15])
    )[20:24])


# should be enough for all components to go back online
POLL_PERIOD_SECONDS = 180
RESET_POWER_OFF_PERIOD = 6
WLAN_INTERFACE = "wlan0"

RELIABLE_WEBSITES = [
    ("www.google.com", 80),
    ("www.amazon.com", 80),
    ("www.yandex.com", 80),
]


def reset_wifi(relay_dir):
    reset_files = [
        relay_dir + "7",
        relay_dir + "8"
    ]
    for path in reset_files:
        with open(path, "w") as text_file:
            text_file.write("1")

    sleep(RESET_POWER_OFF_PERIOD)

    for path in reset_files:
        with open(path, "w") as text_file:
            text_file.write("0")


def reset_state(pid_file):
    with open(pid_file, "w") as text_file:
        text_file.write("99999999")


class GracefulKiller:
    killed = False

    def __init__(self, pid_file):
        self.pid_file = pid_file
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)

    def exit_gracefully(self, signum, frame):
        self.killed = True
        reset_state(self.pid_file)  # just in case loop break is never reached


def main():
    if len(sys.argv) != 3:
        sys.stderr.write(
            "wifi-reseter.py expects two arguments pointing to the PID file and to the folder with relay states.\n")
        sys.exit(1)

    pid_file = sys.argv[1]
    if not os.path.isfile(pid_file):
        sys.stderr.write("PID file does not exist: " + pid_file)
        sys.exit(1)

    killer = GracefulKiller(pid_file)

    try:
        last_failed = False
        while True:
            all_failed = True
            ip_address = get_ip_address(WLAN_INTERFACE)
            for site_address_port in RELIABLE_WEBSITES:
                s = socket.socket()
                s.bind((ip_address, 0))
                try:
                    s.connect(site_address_port)
                    all_failed = False
                except socket.error as e:
                    print("Can't connect to " + str(site_address_port) + ". Reason: " + str(e))
                finally:
                    s.close()

            if all_failed:
                if last_failed:
                    last_failed = False
                    print("Resetting all routers and sensors: could not reach:\n" + str(RELIABLE_WEBSITES))
                    reset_wifi()
                else:
                    last_failed = True

            sleep(POLL_PERIOD_SECONDS)
            if killer.killed:
                break
    finally:
        reset_state(pid_file)


if __name__ == '__main__':
    main()
