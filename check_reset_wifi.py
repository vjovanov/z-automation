import socket
import fcntl
import struct
from time import sleep
import socket


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
RESET_FILES = [
    "/home/homeassistant/relays/7",
    "/home/homeassistant/relays/6",
]
RELIABLE_WEBSITES = [
    ("http://www.google.com/", 80),
    ("http://www.amazon.com/", 80),
]


def reset_wifi():
    for path in RESET_FILES:
        with open(path, "w") as text_file:
            text_file.write("1")

    sleep(RESET_POWER_OFF_PERIOD)

    for path in RESET_FILES:
        with open(path, "w") as text_file:
            text_file.write("0")


def main():
    time = 0
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
            except socket.error:
                print("Can't connect to " + str(site_address_port))
            finally:
                s.close()

            if all_failed:
                if last_failed:
                    last_failed = False
                    print("Resetting all routers and sensors: could not reach: " + str(site_address_port))
                    reset_wifi()
                else:
                    last_failed = True

        sleep(POLL_PERIOD_SECONDS)
        time += 1


if __name__ == '__main__':
    main()
