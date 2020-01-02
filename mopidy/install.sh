#!/bin/bash

DATESTAMP=`date "+%Y-%m-%d-%H-%M-%S"`
MOPIDY_CONFIG="/etc/mopidy/mopidy.conf"
MOPIDY_SUDOERS="/etc/sudoers.d/010_mopidy-nopasswd"
MOPIDY_SYSTEM_SH="/usr/local/lib/python2.7/dist-packages/mopidy_iris/system.sh"
EXISTING_CONFIG=false
PYTHON_MAJOR_VERSION=2
MOPIDY_VERSION=2.3.1-1
MOPIDY_SPOTIFY_VERSION=3.1.0-0mopidy1
PIP_BIN=pip

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


# Update apt
apt update

# Install dependencies
apt install -y python-rpi.gpio python-spidev python-pip python-pil python-numpy

# Verify python version via pip
inform "Verifying python $PYTHON_MAJOR_VERSION.x version"
PIP_CHECK="$PIP_BIN --version"
VERSION=`$PIP_CHECK | sed s/^.*\(python[\ ]*// | sed s/.$//`
RESULT=$?
if [ "$RESULT" == "0" ]; then
  MAJOR_VERSION=`echo $VERSION | awk -F. {'print $1'}`
  if [ "$MAJOR_VERSION" -eq "$PYTHON_MAJOR_VERSION" ]; then
    success "Found Python $VERSION"
  else
    warning "error: installation requires pip for Python $PYTHON_MAJOR_VERSION.x, Python $VERSION found."
    echo
    exit 1
  fi
else
  warning "error: \`$PIP_CHECK\` failed to execute successfully"
  echo
  exit 1
fi
echo

# Stop mopidy if running
systemctl status mopidy > /dev/null 2>&1
RESULT=$?
if [ "$RESULT" == "0" ]; then
  inform "Stopping Mopidy service..."
  systemctl stop mopidy
fi

# Enable SPI
raspi-config nonint do_spi 0

# Add necessary lines to config.txt (if they don't exist)
add_to_config_text "gpio=25=op,dh" /boot/config.txt
add_to_config_text "dtoverlay=hifiberry-dac" /boot/config.txt

if [ -f "$MOPIDY_CONFIG" ]; then
  inform "Backing up mopidy config to: $MOPIDY_CONFIG.backup-$DATESTAMP"
  cp "$MOPIDY_CONFIG" "$MOPIDY_CONFIG.backup-$DATESTAMP"
  EXISTING_CONFIG=true
fi

# Install apt list for Mopidy, see: https://docs.mopidy.com/en/latest/installation/debian/.
if [ ! -f "/etc/apt/sources.list.d/mopidy.list" ]; then
  inform "Adding Mopidy apt source"
  wget -q -O - https://apt.mopidy.com/mopidy.gpg | apt-key add -
  wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/buster.list
fi

# Install Mopidy and core plugins for Spotify
apt install -y --allow-downgrades mopidy=$MOPIDY_VERSION mopidy-spotify=$MOPIDY_SPOTIFY_VERSION
apt-mark hold mopidy mopidy-spotify

# Install Mopidy Iris web UI
$PIP_BIN install mopidy-iris

# Allow Iris to run its system.sh script for https://github.com/pimoroni/pirate-audio/issues/3
# This script backs Iris UI buttons for local scan and server restart.
if [ ! -f "$MOPIDY_SUDOERS" ]; then
  inform "Adding $MOPIDY_SYSTEM_SH to $MOPIDY_SUDOERS"
  echo "mopidy ALL=NOPASSWD: $MOPIDY_SYSTEM_SH" > $MOPIDY_SUDOERS
fi

# Install support plugins for Pirate Audio
inform "Installing Pirate Audio plugins..."
$PIP_BIN install --upgrade Mopidy-PiDi pidi-display-pil pidi-display-st7789 mopidy-raspberry-gpio

# Reset mopidy.conf to its default state
if [ $EXISTING_CONFIG ]; then
  warning "Resetting $MOPIDY_CONFIG to package defaults."
  inform "Any custom settings have been backed up to $MOPIDY_CONFIG.backup-$DATESTAMP"
  apt install --reinstall -o Dpkg::Options::="--force-confask,confnew,confmiss" mopidy=$MOPIDY_VERSION > /dev/null 2>&1
fi

# Append Pirate Audio specific defaults to mopidy.conf
# Updated to only change necessary values, as per: https://github.com/pimoroni/pirate-audio/issues/1
# Updated to *append* config values to mopidy.conf, as per: https://github.com/pimoroni/pirate-audio/issues/1#issuecomment-557556802
cat <<EOF >> $MOPIDY_CONFIG

[raspberry-gpio]
enabled = true
bcm5 = play_pause,active_low,250
bcm6 = volume_down,active_low,250
bcm16 = next,active_low,250
bcm20 = volume_up,active_low,250

[pidi]
enabled = true
display = st7789

[mpd]
hostname = 0.0.0.0 ; Allow access to mpd from other devices

[http]
hostname = 0.0.0.0 ; Allow access to HTTP/Iris from other devices

[audio]
mixer_volume = 40
output = alsasink device=hw:sndrpihifiberry

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
sudo systemctl restart mopidy

echo ""
success "All done!"
if [ $EXISTING_CONFIG ]; then
  diff $MOPIDY_CONFIG $MOPIDY_CONFIG.backup-$DATESTAMP > /dev/null 2>&1
  RESULT=$?
  if [ ! $RESULT == "0" ]; then
    warning "Mopidy configuration has changed, see summary below and make sure to update $MOPIDY_CONFIG!"
    inform "Your previous configuration was backed up to $MOPIDY_CONFIG.backup-$DATESTAMP"
    diff $MOPIDY_CONFIG $MOPIDY_CONFIG.backup-$DATESTAMP
  else
    echo "Don't forget to edit $MOPIDY_CONFIG with your preferences and/or Spotify config."
  fi
else
  echo "Don't forget to edit $MOPIDY_CONFIG with you preferences and/or Spotify config."
fi
