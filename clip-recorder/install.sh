#!/bin/bash

CONFIG_FILE=config.txt
CONFIG_DIR="/boot/firmware"
DATESTAMP=$(date "+%Y-%m-%d-%H-%M-%S")
CONFIG_BACKUP=false
APT_HAS_UPDATED=false
ASOUND_CONFIG="$HOME/.asoundrc"
RESOURCES_TOP_DIR="$HOME/Pimoroni"
VENV_DIR="$HOME/.virtualenvs/pirate-audio"
PYTHON="$VENV_DIR/bin/python"
GITHUB_URL="https://github.com/pimoroni/pirate-audio"
USAGE="./install.sh (--no-upgrade)"
DO_UPGRADE=true
CMD_ERRORS=false

APT_PACKAGES=(
	invada-studio-plugins-ladspa
	ladspa-sdk
	libopenblas0
	libportaudio2
	python3-dev
	python3-numpy
	python3-pil
	python3-pil.imagetk
	python3-pip
	python3-rpi-lgpio
	python3-spidev
	python3-venv
)

PIP_PACKAGES=(
	font-roboto
	fonts
	sounddevice
	st7789
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
		FILENAME="config.preinstall-clip-recorder-$DATESTAMP.txt"
		inform "Backing up $CONFIG_DIR/$CONFIG_FILE to $CONFIG_DIR/$FILENAME\n"
		sudo cp "$CONFIG_DIR/$CONFIG_FILE" "$CONFIG_DIR/$FILENAME"
		mkdir -p "$RESOURCES_TOP_DIR/config-backups/"
		cp "$CONFIG_DIR/$CONFIG_FILE" "$RESOURCES_TOP_DIR/config-backups/$FILENAME"
	fi
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

remove_from_config_text() {
	CONFIG_LINE="$1"
	if grep -q "^$CONFIG_LINE" "$CONFIG_DIR/$CONFIG_FILE"; then
		do_config_backup
		inform "Commenting out $CONFIG_LINE in $CONFIG_DIR/$CONFIG_FILE"
		sudo sed -i "s/^$CONFIG_LINE/#$CONFIG_LINE/" "$CONFIG_DIR/$CONFIG_FILE"
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
	fi
}

pip_pkg_install() {
	# A null Keyring prevents pip stalling in the background
	PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring "$PYTHON" -m pip install --upgrade "$@"
	check_for_error
}

while [[ $# -gt 0 ]]; do
	K="$1"
	case $K in
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

printf "Pirate Audio: Dual Mic Clip Recorder Installer\n\n"

user_check
find_config

printf "\n"

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

pip_pkg_install "${PIP_PACKAGES[@]}"

printf "\n"

sudo raspi-config nonint do_spi 0

# Dual Mic is an input-only board, so the DAC overlay has no business here
remove_from_config_text "dtoverlay=hifiberry-dac"

add_to_config_text "dtparam=spi=on"
add_to_config_text "dtoverlay=adau7002-simple"

printf "\n"

if [ -f "$ASOUND_CONFIG" ]; then
	inform "Backing up $ASOUND_CONFIG to $ASOUND_CONFIG.backup-$DATESTAMP"
	cp "$ASOUND_CONFIG" "$ASOUND_CONFIG.backup-$DATESTAMP"
fi

inform "Creating $ASOUND_CONFIG"

# The Invada high-pass filter strips DC bias and lifts the very quiet
# microphone input to a usable level. LADSPA support is built into alsa-lib.
cat > "$ASOUND_CONFIG" <<'EOF'
pcm.mic_hw {
    type hw
    card adau7002
    format S32_LE
    rate 48000
    channels 2
}
pcm.mic_rt {
    type route
    slave.pcm mic_hw
    ttable.0.0 1
    ttable.0.1 0
    ttable.1.0 0
    ttable.1.1 1
}
pcm.mic_plug {
    type plug
    slave.pcm mic_rt
}
pcm.mic_filter {
    type ladspa
    slave.pcm mic_plug
    path "/usr/lib/ladspa"
    plugins [
    {
        label invada_hp_stereo_filter_module_0_1
        input {
            controls [
                50   # Cut off frequency (Hz)
                30   # Gain (dB)
                1    # Soft Clip (on/off)
            ]
        }
    }
    ]
}
pcm.mic_out {
    type plug
    slave.pcm mic_filter
}
EOF

printf "\n"

inform "Adding $(whoami) to the spi, i2c, gpio and audio groups"
sudo usermod -a -G spi,i2c,gpio,audio "$(whoami)"
check_for_error

printf "\n"

if [ "$CMD_ERRORS" = true ]; then
	warning "One or more setup commands appear to have failed."
	printf "Make sure your OS is up to date and try re-running this installer.\n"
	printf "If things still don't work, report this or find help at %s.\n\n" "$GITHUB_URL"
else
	success "All done!"
fi

printf "Reboot, then test the microphones with:\n"
printf "  arecord -Dmic_out -c2 -r48000 -fS32_LE -twav -d5 -R10000 -Vstereo test.wav\n\n"
printf "Run the examples with:\n"
printf "  source %s/bin/activate\n" "$VENV_DIR"
printf "  python cliprecord.py\n\n"

if [ "$CMD_ERRORS" = true ]; then
	exit 1
else
	exit 0
fi
