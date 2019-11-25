#!/bin/bash

DATESTAMP=`date "+%Y-%M-%d-%H-%M-%S"`
MOPIDY_CONFIG="/etc/mopidy/mopidy.conf"

function add_to_config_text {
    CONFIG_LINE="$1"
    CONFIG="$2"
    sed -i "s/^#$CONFIG_LINE/$CONFIG_LINE/" $CONFIG
    if ! grep -q "$CONFIG_LINE" $CONFIG; then
		printf "$CONFIG_LINE\n" >> $CONFIG
    fi
}

success() {
	echo -e "$(tput setaf 2)$1$(tput sgr0)"
}

inform() {
	echo -e "$(tput setaf 6)$1$(tput sgr0)"
}

warning() {
	echo -e "$(tput setaf 1)$1$(tput sgr0)"
}

# Enable SPI
raspi-config nonint do_spi 0

# Add necessary lines to config.txt (if they don't exist)
add_to_config_text "gpio=25=op,dh" /boot/config.txt
add_to_config_text "dtoverlay=hifiberry-dac" /boot/config.txt

# Install apt list for Mopidy, see: https://docs.mopidy.com/en/latest/installation/debian/.
if [ ! -f "/etc/apt/sources.list.d/mopidy.list" ]; then
  inform "Adding Mopidy apt source"
  wget -q -O - https://apt.mopidy.com/mopidy.gpg | apt-key add -
  wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/buster.list
fi

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
inform "Adding /usr/local/lib/python2.7/dist-packages/mopidy_iris/system.sh to /etc/sudoers"
echo "mopidy ALL=NOPASSWD: /usr/local/lib/python2.7/dist-packages/mopidy_iris/system.sh" >> /etc/sudoers

# Install support plugins for Pirate Audio
pip install Mopidy-PiDi pidi-display-pil pidi-display-st7789 mopidy-raspberry-gpio

if [ -f "$MOPIDY_CONFIG" ]; then
  inform "Backing up mopidy config to: $MOPIDY_CONFIG.backup-$DATESTAMP"
  cp "$MOPIDY_CONFIG" "$MOPIDY_CONFIG.backup-$DATESTAMP"
fi

# Populate mopidy.conf with complete list of defaults
# Updated to only change necessary values, as per: https://github.com/pimoroni/pirate-audio/issues/1
# Updated to *append* config values to mopidy.conf, as per: https://github.com/pimoroni/pirate-audio/issues/1#issuecomment-557556802
cat <<EOF >> $MOPIDY_CONFIG

[raspberry-gpio]
enabled = true
bcm5 = play_pause,active_low,150
bcm6 = volume_down,active_low,150
bcm16 = next,active_low,150
bcm20 = volume_up,active_low,150

[pidi]
enabled = true
display = st7789

[mpd]
hostname = 0.0.0.0 ; Allow access to mpd from other devices

[http]
hostname = 0.0.0.0 ; Allow access to HTTP/Iris from other devices

[audio]
mixer_volume = 40
output = alsasink

[spotify]
enabled = false
username =       ; Must be set.
password =       ; Must be set.
client_id =      ; Must be set.
client_secret =  ; Must be set.
EOF

# MAYBE?: Remove the sources.list to avoid any future issues with apt.mopidy.com failing
# rm -f /etc/apt/sources.list.d/mopidy.list

usermod -a -G spi,i2c,gpio,video mopidy

sudo systemctl enable mopidy
sudo systemctl start mopidy

echo ""
success "All done!"
echo "Don't forget to edit $MOPIDY_CONFIG with you preferences and/or Spotify config."