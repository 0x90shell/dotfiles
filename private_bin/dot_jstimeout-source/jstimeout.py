#!/usr/bin/env -S python3 -u
# Original POC — CPU bug on line 120 (select timeout=0 causes busy-wait spin loop), other bugs may exist. See jstimeout.go for prod.

'''
Script to automatically disable the bluetooth gamepad when
there is no activity for a specified time. It matches /dev/input
with bluetooth mac addresses for DS3 controllers to force a BT disconnect.
This is necessary, because DS3 timeout cannot be configured without a PS3
due to a proprietary timeout implementation by Sony.

use -m or --maxidletime command to set idle time between 1s and 10800s (3h)
the default is 3600s (1h)
Modify specfic_names list to include any other controllers that need monitoring.

Мake the script executable and add it to autorun in desktop mode
or better yet a systemctl service to recover it if it crashes.

################################################################
######                 Service Setup                      ######
################################################################
------
File |
------
[Unit]
Description=jstimeout daemon
After=network.target auditd.service

[Service]
ExecStartPre=/bin/sleep 10
Type=idle
ExecStart=/home/gandalf/bin/jstimeout
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target

----------
Commands |
----------
systemctl daemon-reload
systemctl enable --user jstimeout.service
systemctl start --user jstimeout.service

'''

import struct
from datetime import datetime as dt
import sys
import os
import select
import time
from threading import Thread, Event
import argparse

specific_names = ["Sony PLAYSTATION(R)3 Controller", "Sony Computer Entertainment Wireless Controller"]
running_threads = {}


def parse_arguments():
    parser = argparse.ArgumentParser(description="Bluetooth gamepad idle disconnect script.")
    parser.add_argument('-m', '--maxidletime', type=int, default=3600,
                        help='Maximum idle time in seconds before disconnecting. Must be between 1 and 10800 seconds.')
    args = parser.parse_args()
    if not (1 <= args.maxidletime <= 10800):
        print("Error: maxidletime must be a number between 1 and 10800 seconds.")
        sys.exit(1)
    return args.maxidletime


def parse_input_devices(specific_names):
    devices = []
    current_device = {}
    try:
        with open("/proc/bus/input/devices", "r") as f:
            for line in f:
                line = line.strip()
                if line.startswith("N: Name="):
                    device_name = line.split('=')[1].strip('"')
                    current_device['name'] = device_name
                elif line.startswith("U: Uniq="):
                    uniq = line.split('=')[1].strip()
                    current_device['uniq'] = uniq
                elif line.startswith("H: Handlers="):
                    handlers = line.split('=')[1].strip().split()
                    current_device['handlers'] = handlers
                elif line == "":  # blank lines separate device blocks in procfs
                    if ('name' in current_device and 
                        current_device['name'] in specific_names and
                        'uniq' in current_device and
                        any("js" in handler for handler in current_device['handlers'])):
                        devices.append(current_device)
                    current_device = {}

        return devices
    except FileNotFoundError:
        print("Error: Unable to open /proc/bus/input/devices. Are you running this on a system with /proc available?")
        return []


def input_checker(dev, uniq_and_dev, device_event):
    try:
        while os.path.exists(dev):
            # retry opening the device after a brief delay
            while True:
                time.sleep(1)
                EVENT_SIZE = struct.calcsize("llHHI")  # Linux input_event: timeval + type + code + value
                file = open(dev, "rb")
                break
            while True:
                r, w, e = select.select([file], [], [], 0)
                if file in r:
                    try:
                        event = file.read(EVENT_SIZE)
                        struct.unpack("llHHI", event)
                        device_event.set()
                        # commenting out to de-clutter journalctl logs
                        # print(f"movement detected for {uniq_and_dev}")
                    except:
                        break
                else:
                    pass
    finally:
        if uniq_and_dev in running_threads:
            del running_threads[uniq_and_dev]


def timer(devid, maxidletime, dev, uniq_and_dev, device_event):
    currtime = dt.now()
    prevtime = currtime
    try:
        while True:
            time.sleep(1)
            currtime = dt.now()
            if os.path.exists(dev):
                if device_event.is_set():
                    # commenting out to de-clutter journalctl logs
                    # print(f"date updated for {uniq_and_dev}")
                    prevtime = currtime
                    device_event.clear()

                if (currtime - prevtime).total_seconds() >= maxidletime:
                    print(f"Device {uniq_and_dev} has been idle for {maxidletime} seconds, disconnecting...")
                    # devid is the BT MAC from the procfs "uniq" field
                    os.system(f"echo disconnect {devid} | bluetoothctl")
                    time.sleep(1)
                    os.system("echo exit | bluetoothctl")
                    sys.exit()  # intentionally kills the whole process
            else:
                sys.exit()
    finally:
        if uniq_and_dev in running_threads:
            del running_threads[uniq_and_dev]


def start_threads_for_devices(devices, maxidletime):
    global running_threads

    for device in devices:
        for handler in device['handlers']:
            if handler.startswith('js'):
                dev_path = f"/dev/input/{handler}"
                uniq_and_dev = (device['uniq'], dev_path)

                if uniq_and_dev not in running_threads:
                    print(f"Starting threads for device: {device['name']} (Handler: {dev_path}, Uniq: {device['uniq']})")
                    device_event = Event()
                    t1 = Thread(target=input_checker, args=(dev_path, uniq_and_dev, device_event))
                    t1.start()
                    t2 = Thread(target=timer, args=(device['uniq'], maxidletime, dev_path, uniq_and_dev, device_event))
                    t2.start()
                    running_threads[uniq_and_dev] = {'input_checker': t1, 'timer': t2}


def query_devices_periodically(maxidletime):
    global running_threads
    while True:
        devices = parse_input_devices(specific_names)
        if devices:
            start_threads_for_devices(devices, maxidletime)
        else:
            # commented out to minimize journalctl clutter
            # print(f"No devices found matching names: {specific_names}")
            pass  # nop cause not printing

        time.sleep(5)


if __name__ == "__main__":
    maxidletime = parse_arguments()
    print(f"Starting Joystick Idle Monitoring w/ Idle Cutoff of {maxidletime / 60} minutes")
    query_devices_periodically(maxidletime)
