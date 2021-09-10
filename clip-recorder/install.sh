#!/bin/bash
DATESTAMP=`date "+%Y-%m-%d-%H-%M-%S"`
ASOUND_CONFIG=$HOME/.asoundrc



function add_to_config_text {
    CONFIG_LINE="$1"
    CONFIG="$2"
    sudo sed -i "s/^#$CONFIG_LINE/$CONFIG_LINE/" $CONFIG
    if ! grep -q "$CONFIG_LINE" $CONFIG; then
		printf "$CONFIG_LINE\n" | sudo tee -a $CONFIG
    fi
}

function remove_from_config_text {
    CONFIG_LINE="$1"
    CONFIG="$2"
    if grep -qq "^$CONFIG_LINE" $CONFIG; then
	warning "Commenting out $CONFIG_LINE in $CONFIG";
	sudo sed -i "s/^$CONFIG_LINE/#$CONFIG_LINE/" $CONFIG
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

if [ $(id -u) -eq 0 ]; then
	inform "This script should not be run as root!";
	inform "Try: $0";
	exit 1
fi

inform "Enabling SPI"
sudo raspi-config nonint do_spi 0

inform "Installing dependencies" 
sudo apt update
sudo apt install -y ladspa-sdk invada-studio-plugins-ladspa
sudo apt install -y pulseaudio python3-pip python3-rpi.gpio python3-spidev python3-numpy python3-pil python3-pil.imagetk libportaudio2
sudo python3 -m pip install fonts font-roboto ST7789 sounddevice

remove_from_config_text "dtoverlay=hifiberry-dac" /boot/config.txt

inform "Adding dtoverlay=adau7002-simple to /boot/config.txt" 
add_to_config_text "dtoverlay=adau7002-simple" /boot/config.txt

if [ -f "$ASOUND_CONFIG" ]; then
    warning "Backing up $ASOUND_CONFIG to $ASOUND_CONFIG-$DATESTAMP"
    cp $ASOUND_CONFIG "$ASOUND_CONFIG-$DATESTAMP"
fi

inform "Creating $ASOUND_CONFIG"
cat > $ASOUND_CONFIG <<EOF
pcm.mic_hw{
    type hw
    card adau7002
    format S32_LE
    rate 48000
    channels 2
}
pcm.mic_rt{
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
    path "/usr/lib/ladspa";
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
