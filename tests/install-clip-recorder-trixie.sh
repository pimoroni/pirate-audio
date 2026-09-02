#!/bin/bash
# Runs as root inside a Debian Trixie arm64 container, stands up enough of a
# Raspberry Pi OS userland to be interesting, then runs clip-recorder/install.sh
# as an unprivileged user and checks what it produced.
#
# Locally: ./tests/run-docker.sh clip-recorder
set -e

SRC="${1:-/src}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends ca-certificates curl sudo > /dev/null

# trusted=yes: the Raspberry Pi archive key self-signs with SHA1, which
# Trixie's sqv policy rejects. Real Raspberry Pi OS ships the keyring package.
echo "deb [trusted=yes] http://archive.raspberrypi.com/debian/ trixie main" \
	> /etc/apt/sources.list.d/raspi.list
apt-get update -qq

mkdir -p /boot/firmware /usr/local/bin
cat > /boot/firmware/config.txt <<'CFG'
[all]
#dtparam=spi=on
dtoverlay=hifiberry-dac
CFG

printf '#!/bin/sh\necho "[stub] raspi-config $*"\nexit 0\n' > /usr/local/bin/raspi-config
chmod +x /usr/local/bin/raspi-config

for group in spi i2c gpio video audio; do
	groupadd -f "$group"
done

useradd -m -s /bin/bash pi
echo "pi ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/pi
chmod 0440 /etc/sudoers.d/pi

cp -r "$SRC" /home/pi/pirate-audio
chown -R pi:pi /home/pi/pirate-audio

su - pi -c "cd /home/pi/pirate-audio/clip-recorder && ./install.sh --no-upgrade"

echo
echo "======== ASSERTIONS ========"

fail=0
check() {
	if eval "$2" > /dev/null 2>&1; then
		echo "  ok   $1"
	else
		echo "  FAIL $1"
		fail=1
	fi
}

check "config.txt enables spi" "grep -qx 'dtparam=spi=on' /boot/firmware/config.txt"
check "config.txt adds the mic overlay" "grep -qx 'dtoverlay=adau7002-simple' /boot/firmware/config.txt"
check "config.txt comments out the DAC overlay" "grep -qx '#dtoverlay=hifiberry-dac' /boot/firmware/config.txt"
check "config.txt backed up" "ls /boot/firmware/config.preinstall-clip-recorder-*.txt"
check ".asoundrc written" "[ -f /home/pi/.asoundrc ]"
check ".asoundrc defines mic_out" "grep -q '^pcm.mic_out' /home/pi/.asoundrc"
check ".asoundrc has no curly quotes" "! grep -q $'\\u201c' /home/pi/.asoundrc"
check "ladspa plugin present" "[ -f /usr/lib/ladspa/inv_filter.so ]"
check "venv created" "[ -x /home/pi/.virtualenvs/pirate-audio/bin/python ]"

VPY=/home/pi/.virtualenvs/pirate-audio/bin/python

# rpi-lgpio refuses to import off a Raspberry Pi unless it's told which one to
# pretend to be. a020d3 is a Raspberry Pi 3 Model B+.
export RPI_LGPIO_REVISION=a020d3

echo
echo "-------- installed versions --------"
su - pi -c "$VPY -m pip list 2>/dev/null" | grep -Ei "^(st7789|sounddevice|fonts|font-roboto|numpy|pillow|spidev)" || true

echo
echo "-------- runtime checks --------"
su - pi -c "RPI_LGPIO_REVISION=$RPI_LGPIO_REVISION $VPY - <<'PY'
import RPi.GPIO
print('RPi.GPIO from', RPi.GPIO.__file__)

import sounddevice, st7789
from fonts.ttf import RobotoMedium
print('st7789', st7789.__version__)
print('imports OK')
PY" || fail=1

echo
echo "-------- --help on the examples --------"
su - pi -c "RPI_LGPIO_REVISION=$RPI_LGPIO_REVISION $VPY /home/pi/pirate-audio/clip-recorder/cliprecord.py --help" || fail=1
su - pi -c "RPI_LGPIO_REVISION=$RPI_LGPIO_REVISION $VPY /home/pi/pirate-audio/clip-recorder/fft.py --help" || fail=1

echo
if [ "$fail" -ne 0 ]; then
	echo "RESULT: FAILURES"
	exit 1
fi
echo "RESULT: PASS"
