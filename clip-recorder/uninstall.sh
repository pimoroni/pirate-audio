#!/bin/bash
DATESTAMP=`date "+%Y-%m-%d-%H-%M-%S"`
ASOUND_CONFIG=$HOME/.asoundrc

success() {
	echo -e "$(tput setaf 2)$1$(tput sgr0)"
}

inform() {
	echo -e "$(tput setaf 6)$1$(tput sgr0)"
}

warning() {
	echo -e "$(tput setaf 1)$1$(tput sgr0)"
}

inform "Removing pulseaudio ladspa-sdk invada-studio-plugins-ladspa"
sudo apt remove --purge pulseaudio ladspa-sdk invada-studio-plugins-ladspa

inform "Moving $ASOUND_CONFIG to $ASOUND_CONIFIG-$DATESTAMP"
mv "$ASOUND_CONFIG $ASOUND_CONIFIG-$DATESTAMP"
warning "You might want to restore a previous backup:"
ls $HOME/.asoundrc* -1

