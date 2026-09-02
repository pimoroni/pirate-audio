#!/bin/bash

DATESTAMP=$(date "+%Y-%m-%d-%H-%M-%S")
ASOUND_CONFIG="$HOME/.asoundrc"
VENV_DIR="$HOME/.virtualenvs/pirate-audio"

inform() {
	echo -e "$(tput setaf 6)$1$(tput sgr0)"
}

warning() {
	echo -e "$(tput setaf 1)⚠ WARNING:$(tput sgr0) $1"
}

inform "Removing ladspa-sdk and invada-studio-plugins-ladspa"
sudo apt remove --purge -y ladspa-sdk invada-studio-plugins-ladspa

if [ -f "$ASOUND_CONFIG" ]; then
	inform "Moving $ASOUND_CONFIG to $ASOUND_CONFIG.removed-$DATESTAMP"
	mv "$ASOUND_CONFIG" "$ASOUND_CONFIG.removed-$DATESTAMP"
	warning "You might want to restore a previous backup:"
	ls -1 "$HOME"/.asoundrc*
fi

if [ -d "$VENV_DIR" ]; then
	inform "Leaving the virtual environment at $VENV_DIR in place."
	printf "Remove it with: rm -r %s\n" "$VENV_DIR"
fi

printf "\ndtoverlay=adau7002-simple is still in your config.txt.\n"
printf "Restore a backup from ~/Pimoroni/config-backups/ if you want it gone.\n"
