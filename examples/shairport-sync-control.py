#!/usr/bin/env python3

import signal

import dbus
import RPi.GPIO as GPIO

"""
This example demonstrates using Shairport Sync's DBus interface and the buttons on Pirate Audio to control your music.

Play/Pause, Next and volume control are supported.

You *must* compile Shairport Sync with DBus support for this to work.

I compiled with:

    ./configure --with-metadata --with-dbus-interface --with-ssl=openssl --with-alsa --with-avahi --with-systemd

You must also have `dbus-python` installed:

    python3 -m pip install dbus-python

Controls can be a little slow- there's a lot going on here. Be patient!

Check out the experimental PiDi plugins for Metadata/Album art display on Pirate Audio: https://github.com/pimoroni/pidi/pull/3
"""

BUTTONS = [5, 6, 16, 24]
LABELS = ["A", "B", "X", "Y"]


bus = dbus.SystemBus()

proxy = bus.get_object("org.gnome.ShairportSync", "/org/gnome/ShairportSync")

interface = dbus.Interface(
    proxy, dbus_interface="org.gnome.ShairportSync.RemoteControl"
)

shairport_playpause = interface.get_dbus_method("PlayPause")
shairport_next = interface.get_dbus_method("Next")
shairport_volumeup = interface.get_dbus_method("VolumeUp")
shairport_volumedown = interface.get_dbus_method("VolumeDown")


def handle_button(pin):
    label = LABELS[BUTTONS.index(pin)]

    if label == "X":
        shairport_next()
        print("RemoteControl: Next")
    if label == "Y":
        shairport_volumeup()
        print("RemoteControl: VolumeUp")
    if label == "A":
        shairport_playpause()
        print("RemoteControl: PlayPause")
    if label == "B":
        shairport_volumedown()
        print("RemoteControl: VolumeDown")


GPIO.setmode(GPIO.BCM)

for pin in BUTTONS:
    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    GPIO.add_event_detect(pin, GPIO.FALLING, handle_button, bouncetime=250)


signal.pause()
