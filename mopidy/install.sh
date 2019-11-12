#!/bin/bash

# Install apt list for Mopidy, see: https://docs.mopidy.com/en/latest/installation/debian/.
wget -q -O - https://apt.mopidy.com/mopidy.gpg | sudo apt-key add -
sudo wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/buster.list

# Update apt and install Mopidy and core plugins for Spotify and the Iris web UI
sudo apt update
sudo apt install mopidy mopidy-spotify mopidy-iris

# Install support plugins for Pirate Audio
sudo pip install Mopidy-PiDi pidi-display-pil pidi-display-st7789 mopidy-raspberry-gpio

# Populate mopidy.conf with complete list of defaults
mopidy config | sudo tee /etc/mopidy/mopidy.conf

# Set IP for mpd and http to public
sudo sed -i "s/127.0.0.1/0.0.0.0/g" /etc/mopidy/mopidy.conf

# Change to alsa audio sink
sudo sed -i "s/autoaudiosink/alsasink/g" /etc/mopidy/mopidy.conf

# Set mixer_volume to 40
sudo sed -i "s/mixer_volume = $/mixer_volume = 40/g" /etc/mopidy/mopidy.conf

# MAYBE?: Remove the sources.list to avoid any future issues with apt.mopidy.com failing
# sudo rm -f /etc/apt/sources.list.d/mopidy.list