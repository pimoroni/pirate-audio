# Pirate Audio Shairport Sync Setup

Note: This software is currently in beta and subject to change. Hopefully we'll have an easy installer ready soon, but in the mean time read-on if you want to be an early adopter.

## Installing

Shairport Sync support comes in to parts:

* Button control using (shairport-sync-control.py)[../examples/shairport-sync-control.py]
* Album art/track information usiong (Pirate Display)[https://github.com/pimoroni/pidi/pull/3] (BETA)

You must run both of these applications for full Shairport control and display.

Additionally Shairport-Sync must be configured `--with-metadata` and `--with-dbus-interface` like so:

```
./configure --with-metadata --with-dbus-interface --with-ssl=openssl --with-alsa --with-avahi --with-systemd
```