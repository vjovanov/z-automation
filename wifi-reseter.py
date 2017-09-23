import os
from time import sleep
import socket
import sys
import signal
import fcntl
import struct


def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', bytes(ifname[:15], 'utf-8'))
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

RESET_RELAYS = [5, 6]

def reset_wifi(relay_dir):
    reset_files = [ relay_dir + "/" + str(i) for i in RESET_RELAYS ]
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

    # noinspection PyUnusedLocal
    def exit_gracefully(self, signum, frame):
        self.killed = True
        reset_state(self.pid_file)  # just in case loop break is never reached


def main():
    if len(sys.argv) != 3:
        sys.stderr.write(
            "wifi-reseter.py expects two arguments pointing to the PID file and to the folder with relay states.\n")
        sys.exit(1)

    pid_file = sys.argv[1]
    relay_dir = sys.argv[2]
    if not os.path.isdir(relay_dir):
        sys.stderr.write(
            "Relay dir " + relay_dir + " is not a directory.")
    killer = GracefulKiller(pid_file)
    try:
        last_failed = False
        while True:
            with open(pid_file, "w") as text_file:
                text_file.write(str(os.getpid()))
            all_failed = True
            for site_address_port in RELIABLE_WEBSITES:
                s = socket.socket()
                try:
                    ip_address = get_ip_address(WLAN_INTERFACE)
                    s.bind((ip_address, 0))
                    s.connect(site_address_port)
                    all_failed = False
                    last_failed = False
                except socket.error as e:
                    print("Can't connect to " + str(site_address_port) + ". Reason: " + str(e))
                finally:
                    s.close()

            if all_failed:
                if last_failed:
                    last_failed = False
                    print("Resetting all routers and sensors: could not reach:\n" + str(RELIABLE_WEBSITES))
                    reset_wifi(relay_dir)
                else:
                    last_failed = True

            sleep(POLL_PERIOD_SECONDS)
            if killer.killed:
                break
    finally:
        reset_state(pid_file)


if __name__ == '__main__':
    main()
