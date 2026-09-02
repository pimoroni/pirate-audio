#!/bin/bash

CONFIG_FILE=config.txt
CONFIG_DIR="/boot/firmware"
DATESTAMP=$(date "+%Y-%m-%d-%H-%M-%S")
CONFIG_BACKUP=false
APT_HAS_UPDATED=false
RESOURCES_TOP_DIR="$HOME/Pimoroni"
RESOURCES_DIR="$RESOURCES_TOP_DIR/pirate-audio"
UNINSTALLER="$RESOURCES_DIR/uninstall.sh"
VENV_DIR="$HOME/.virtualenvs/mopidy"
PYTHON="$VENV_DIR/bin/python"
MOPIDY_USER=$(whoami)
MOPIDY_CONFIG_DIR="$HOME/.config/mopidy"
MOPIDY_CONFIG="$MOPIDY_CONFIG_DIR/mopidy.conf"
MOPIDY_SUDOERS="/etc/sudoers.d/010_mopidy-nopasswd"
MUSIC_DIR="$HOME/Music"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/mopidy.service"
GITHUB_URL="https://github.com/pimoroni/pirate-audio"
USAGE="./install.sh (--force) (--no-upgrade)"
EXISTING_CONFIG=false
FORCE=false
DO_UPGRADE=true
CMD_ERRORS=false

APT_PACKAGES=(
	gir1.2-gstreamer-1.0
	gstreamer1.0-alsa
	gstreamer1.0-gl
	gstreamer1.0-gtk3
	gstreamer1.0-plugins-bad
	gstreamer1.0-plugins-base
	gstreamer1.0-plugins-good
	gstreamer1.0-plugins-ugly
	gstreamer1.0-pulseaudio
	gstreamer1.0-tools
	libgstreamer1.0-0
	libopenblas0
	libopenjp2-7
	python3-dev
	python3-gi
	python3-gst-1.0
	python3-lgpio
	python3-numpy
	python3-pil
	python3-pip
	python3-rpi-lgpio
	python3-spidev
	python3-venv
)

# Mopidy 4 is a breaking release: it drops pkg_resources for
# importlib.metadata and moves to Pykka 4. Mopidy-PiDi, Mopidy-Iris and
# Mopidy-Raspberry-GPIO have not been ported, so pin the Mopidy 3 stack.
# setuptools >= 82 no longer ships pkg_resources, which Mopidy 3 needs.
PIP_PACKAGES=(
	"mopidy>=3.4.2,<4"
	"pykka>=3.1,<4"
	"setuptools<82"
	"mopidy-iris"
	"mopidy-local<4"
	"mopidy-pidi"
	"mopidy-raspberry-gpio"
	"pidi-display-pil"
	"pidi-display-st7789"
)

CONFIG_TXT=(
	"dtparam=spi=on"
	"dtoverlay=hifiberry-dac"
	"dtparam=audio=off"
	"gpio=25=op,dh"
)

success() {
	echo -e "$(tput setaf 2)$1$(tput sgr0)"
}

inform() {
	echo -e "$(tput setaf 6)$1$(tput sgr0)"
}

warning() {
	echo -e "$(tput setaf 1)⚠ WARNING:$(tput sgr0) $1"
}

fatal() {
	echo -e "$(tput setaf 1)⚠ FATAL:$(tput sgr0) $1"
	exit 1
}

confirm() {
	if $FORCE; then
		true
	else
		read -r -p "$1 [y/N] " response < /dev/tty
		if [[ $response =~ ^(yes|y|Y)$ ]]; then
			true
		else
			false
		fi
	fi
}

check_for_error() {
	if [ $? -ne 0 ]; then
		CMD_ERRORS=true
		warning "^^^ 😬 previous command did not exit cleanly!"
	fi
}

user_check() {
	if [ "$(id -u)" -eq 0 ]; then
		fatal "Script should not be run as root. Try './install.sh'\n"
	fi
}

os_check() {
	if [ ! -f /etc/os-release ]; then
		warning "Could not read /etc/os-release, assuming a recent Raspberry Pi OS.\n"
		return
	fi
	# shellcheck disable=SC1091
	source /etc/os-release
	case "$VERSION_CODENAME" in
	trixie)
		inform "Detected Raspberry Pi OS Trixie\n"
		;;
	bookworm)
		warning "Detected Raspberry Pi OS Bookworm."
		printf "Bookworm still works, but Trixie is what we test against.\n\n"
		;;
	*)
		warning "Detected ${PRETTY_NAME:-an unknown OS}."
		printf "This installer targets Raspberry Pi OS Trixie. Older releases\n"
		printf "ship Python and GStreamer versions we no longer test against.\n\n"
		if ! confirm "Continue anyway?"; then
			fatal "Aborted.\n"
		fi
		;;
	esac
}

find_config() {
	if [ ! -f "$CONFIG_DIR/$CONFIG_FILE" ]; then
		CONFIG_DIR="/boot"
		if [ ! -f "$CONFIG_DIR/$CONFIG_FILE" ]; then
			fatal "Could not find $CONFIG_FILE!"
		fi
	fi
	inform "Using $CONFIG_FILE in $CONFIG_DIR"
}

do_config_backup() {
	if [ ! $CONFIG_BACKUP == true ]; then
		CONFIG_BACKUP=true
		FILENAME="config.preinstall-pirate-audio-$DATESTAMP.txt"
		inform "Backing up $CONFIG_DIR/$CONFIG_FILE to $CONFIG_DIR/$FILENAME\n"
		sudo cp "$CONFIG_DIR/$CONFIG_FILE" "$CONFIG_DIR/$FILENAME"
		mkdir -p "$RESOURCES_TOP_DIR/config-backups/"
		cp "$CONFIG_DIR/$CONFIG_FILE" "$RESOURCES_TOP_DIR/config-backups/$FILENAME"
		if [ -f "$UNINSTALLER" ]; then
			echo "sudo cp $RESOURCES_TOP_DIR/config-backups/$FILENAME $CONFIG_DIR/$CONFIG_FILE" >> "$UNINSTALLER"
		fi
	fi
}

apt_pkg_install() {
	PACKAGES_NEEDED=()
	PACKAGES_IN=("$@")
	for ((i = 0; i < ${#PACKAGES_IN[@]}; i++)); do
		PACKAGE="${PACKAGES_IN[$i]}"
		if [ "$PACKAGE" == "" ]; then continue; fi
		printf "Checking for %s\n" "$PACKAGE"
		if ! dpkg -L "$PACKAGE" > /dev/null 2>&1; then
			PACKAGES_NEEDED+=("$PACKAGE")
		fi
	done
	PACKAGES="${PACKAGES_NEEDED[*]}"
	if ! [ "$PACKAGES" == "" ]; then
		printf "\n"
		inform "Installing missing packages: $PACKAGES"
		if [ "$APT_HAS_UPDATED" = false ]; then
			sudo apt update
			APT_HAS_UPDATED=true
		fi
		# shellcheck disable=SC2086
		sudo apt install -y $PACKAGES
		check_for_error
		if [ -f "$UNINSTALLER" ]; then
			echo "sudo apt remove -y $PACKAGES" >> "$UNINSTALLER"
		fi
	fi
}

pip_pkg_install() {
	# A null Keyring prevents pip stalling in the background
	PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring "$PYTHON" -m pip install --upgrade "$@"
	check_for_error
}

add_to_config_text() {
	CONFIG_LINE="$1"
	do_config_backup
	sudo sed -i "s/^#$CONFIG_LINE/$CONFIG_LINE/" "$CONFIG_DIR/$CONFIG_FILE"
	if ! grep -q "^$CONFIG_LINE" "$CONFIG_DIR/$CONFIG_FILE"; then
		inform "Adding $CONFIG_LINE to $CONFIG_DIR/$CONFIG_FILE"
		printf "%s\n" "$CONFIG_LINE" | sudo tee --append "$CONFIG_DIR/$CONFIG_FILE"
	fi
}

while [[ $# -gt 0 ]]; do
	K="$1"
	case $K in
	-f|--force)
		FORCE=true
		shift
		;;
	-n|--no-upgrade)
		DO_UPGRADE=false
		shift
		;;
	*)
		printf "Unrecognised option: %s\n" "$1"
		printf "Usage: %s\n" "$USAGE"
		exit 1
		;;
	esac
done

printf "Pirate Audio: Mopidy Installer\n\n"

user_check
os_check
find_config

printf "\n"

mkdir -p "$RESOURCES_DIR"

cat << EOF > "$UNINSTALLER"
printf "It's recommended you run these steps manually.\n"
printf "If you want to run the full script, open it in\n"
printf "an editor and remove 'exit 1' from below.\n"
exit 1
systemctl --user disable --now mopidy
rm -f $SERVICE_FILE
sudo rm -f $MOPIDY_SUDOERS
rm -rf $VENV_DIR
EOF

inform "Updating apt and installing dependencies"
sudo apt update
APT_HAS_UPDATED=true

if $DO_UPGRADE; then
	sudo apt upgrade -y
	check_for_error
fi

apt_pkg_install "${APT_PACKAGES[@]}"

printf "\n"

if [ ! -f "$VENV_DIR/bin/activate" ]; then
	inform "Creating a virtual Python environment in $VENV_DIR"
	mkdir -p "$VENV_DIR"
	/usr/bin/python3 -m venv --system-site-packages "$VENV_DIR"
	check_for_error
else
	inform "Using the existing virtual Python environment in $VENV_DIR"
fi

if [ ! -f "$PYTHON" ]; then
	fatal "Python not found in $VENV_DIR!\n"
fi

printf "\n"

if systemctl --user is-active --quiet mopidy; then
	inform "Stopping the Mopidy service"
	systemctl --user stop mopidy
	printf "\n"
fi

sudo raspi-config nonint do_spi 0

for ((i = 0; i < ${#CONFIG_TXT[@]}; i++)); do
	add_to_config_text "${CONFIG_TXT[$i]}"
done

printf "\n"

if [ -f "$MOPIDY_CONFIG" ]; then
	inform "Backing up $MOPIDY_CONFIG to $MOPIDY_CONFIG.backup-$DATESTAMP"
	cp "$MOPIDY_CONFIG" "$MOPIDY_CONFIG.backup-$DATESTAMP"
	EXISTING_CONFIG=true
	printf "\n"
fi

inform "Installing Mopidy, Iris and the Pirate Audio plugins. Please wait..."
pip_pkg_install "${PIP_PACKAGES[@]}"

printf "\n"

# Iris shells out to its own system.sh to restart Mopidy and rescan local
# files, which needs root. See https://github.com/pimoroni/pirate-audio/issues/3
IRIS_SYSTEM_SH=$("$PYTHON" - <<'EOF'
from importlib.metadata import PackageNotFoundError, distribution

try:
    print(distribution("mopidy-iris").locate_file("mopidy_iris/system.sh"))
except PackageNotFoundError:
    pass
EOF
)

if [ ! -f "$IRIS_SYSTEM_SH" ]; then
	warning "Could not find Iris's system.sh, skipping $MOPIDY_SUDOERS"
else
	inform "Allowing $MOPIDY_USER to run $IRIS_SYSTEM_SH as root"
	echo "$MOPIDY_USER ALL=NOPASSWD: $IRIS_SYSTEM_SH" | sudo tee "$MOPIDY_SUDOERS" > /dev/null
	sudo chmod 0440 "$MOPIDY_SUDOERS"
	if ! sudo visudo -c -f "$MOPIDY_SUDOERS" > /dev/null; then
		warning "$MOPIDY_SUDOERS failed validation, removing it"
		sudo rm -f "$MOPIDY_SUDOERS"
	fi
fi

printf "\n"

inform "Configuring Mopidy"

mkdir -p "$MOPIDY_CONFIG_DIR"
mkdir -p "$MUSIC_DIR"

# Only the settings Pirate Audio needs, as per
# https://github.com/pimoroni/pirate-audio/issues/1
cat <<EOF > "$MOPIDY_CONFIG"
[raspberry-gpio]
enabled = true
bcm5 = play_pause,active_low,250
bcm6 = volume_down,active_low,250
bcm16 = next,active_low,250
# "Y" moved from BCM 20 to BCM 24 in January 2020. Both are listed so either
# board revision works; the unused pin does nothing.
bcm20 = volume_up,active_low,250
bcm24 = volume_up,active_low,250

[file]
enabled = true
media_dirs = $MUSIC_DIR
show_dotfiles = false
excluded_file_extensions =
  .directory
  .html
  .jpeg
  .jpg
  .log
  .nfo
  .pdf
  .png
  .txt
  .zip
follow_symlinks = false
metadata_timeout = 1000

[local]
media_dir = $MUSIC_DIR

[pidi]
enabled = true
display = st7789
rotation = 90

[mpd]
hostname = 0.0.0.0

[http]
hostname = 0.0.0.0

[audio]
mixer_volume = 40

[spotify]
enabled = false
client_id =
client_secret =
EOF

printf "\n"

inform "Adding $MOPIDY_USER to the spi, i2c, gpio and video groups"
sudo usermod -a -G spi,i2c,gpio,video "$MOPIDY_USER"
check_for_error

printf "\n"

inform "Installing the Mopidy user service"

mkdir -p "$SERVICE_DIR"

cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Mopidy music server
After=avahi-daemon.service
After=dbus.service
After=network-online.target
Wants=network-online.target
After=nss-lookup.target
After=remote-fs.target
After=sound.target

[Service]
WorkingDirectory=$HOME
ExecStart=$VENV_DIR/bin/mopidy --config $MOPIDY_CONFIG
Restart=on-failure

[Install]
WantedBy=default.target
EOF

# Without linger the service only runs while the user is logged in
sudo loginctl enable-linger "$MOPIDY_USER"
check_for_error

systemctl --user daemon-reload
systemctl --user enable mopidy
systemctl --user restart mopidy
check_for_error

printf "\n"

if [ "$CMD_ERRORS" = true ]; then
	warning "One or more setup commands appear to have failed."
	printf "This might prevent things from working properly.\n"
	printf "Make sure your OS is up to date and try re-running this installer.\n"
	printf "If things still don't work, report this or find help at %s.\n\n" "$GITHUB_URL"
else
	success "All done!"
fi

printf "Check on Mopidy with: systemctl --user status mopidy\n"
printf "Iris is at: http://%s.local:6680/iris/\n" "$(hostname)"
printf "Drop music into %s and rescan it from Iris.\n" "$MUSIC_DIR"
printf "Find uninstall steps in %s\n\n" "$UNINSTALLER"

if [ "$EXISTING_CONFIG" = true ]; then
	if ! diff "$MOPIDY_CONFIG" "$MOPIDY_CONFIG.backup-$DATESTAMP" > /dev/null 2>&1; then
		warning "Your Mopidy configuration has changed!"
		inform "Your previous configuration is at $MOPIDY_CONFIG.backup-$DATESTAMP"
		diff "$MOPIDY_CONFIG" "$MOPIDY_CONFIG.backup-$DATESTAMP"
		printf "\n"
	fi
fi

printf "Reboot for the changes to %s/%s to take effect.\n\n" "$CONFIG_DIR" "$CONFIG_FILE"

if [ "$CMD_ERRORS" = true ]; then
	exit 1
else
	exit 0
fi
