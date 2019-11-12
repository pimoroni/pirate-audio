#!/bin/bash

function add_to_config_text {
    CONFIG_LINE = "$1"
    CONFIG = "$2"
    sed -i "s/^#$CONFIG_LINE/$CONFIG_LINE/" $CONFIG
    if ! grep -q "$CONFIG_LINE1" $CONFIG; then
		printf "$CONFIG_LINE\n" >> $CONFIG
    fi
}

# Enable SPI
raspi-config nonint do_spi 0

# Add necessary lines to config.txt (if they don't exist)
add_to_config_text "gpio=25=op,dh" /boot/config.txt
add_to_config_text "dtoverlay=hifiberry-dac" /boot/config.txt

# Install apt list for Mopidy, see: https://docs.mopidy.com/en/latest/installation/debian/.
wget -q -O - https://apt.mopidy.com/mopidy.gpg | apt-key add -
wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/buster.list

# Update apt
apt update

# Install dependencies
apt-get install python-rpi.gpio python-spidev python-pip python-imaging python-numpy

# install Mopidy and core plugins for Spotify and the Iris web UI
apt install mopidy mopidy-spotify mopidy-iris

# Install support plugins for Pirate Audio
pip install Mopidy-PiDi pidi-display-pil pidi-display-st7789 mopidy-raspberry-gpio

# Populate mopidy.conf with complete list of defaults
mopidy config > /etc/mopidy/mopidy.conf

# Set IP for mpd and http to public
sed -i "s/127.0.0.1/0.0.0.0/g" /etc/mopidy/mopidy.conf

# Change to alsa audio sink
sed -i "s/autoaudiosink/alsasink/g" /etc/mopidy/mopidy.conf

# Set mixer_volume to 40
sed -i "s/mixer_volume = $/mixer_volume = 40/g" /etc/mopidy/mopidy.conf

# MAYBE?: Remove the sources.list to avoid any future issues with apt.mopidy.com failing
# rm -f /etc/apt/sources.list.d/mopidy.list