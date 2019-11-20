#!/bin/bash

function add_to_config_text {
    CONFIG_LINE="$1"
    CONFIG="$2"
    sed -i "s/^#$CONFIG_LINE/$CONFIG_LINE/" $CONFIG
    if ! grep -q "$CONFIG_LINE" $CONFIG; then
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
apt install -y python-rpi.gpio python-spidev python-pip python-pil python-numpy

# Install Mopidy and core plugins for Spotify
apt install -y mopidy mopidy-spotify

# Install Mopidy Iris web UI
pip install mopidy-iris

# Allow Iris to run its system.sh script for https://github.com/pimoroni/pirate-audio/issues/3
# This script backs Iris UI buttons for local scan and server restart.
echo "mopidy ALL=NOPASSWD: /usr/local/lib/python2.7/dist-packages/mopidy_iris/system.sh" >> /etc/sudoers

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

usermod -a -G spi,i2c,gpio,video mopidy

sudo systemctl enable mopidy
sudo systemctl start mopidy
