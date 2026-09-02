#!/bin/bash
# Runs as root inside a Debian Trixie arm64 container, stands up enough of a
# Raspberry Pi OS userland to be interesting, then runs mopidy/install.sh as an
# unprivileged user and checks what it produced.
#
# Locally: ./tests/run-docker.sh
set -e

SRC="${1:-/src}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends ca-certificates curl gnupg sudo procps > /dev/null

# trusted=yes: the Raspberry Pi archive key self-signs with SHA1, which
# Trixie's sqv policy rejects. Real Raspberry Pi OS ships the keyring package.
echo "deb [trusted=yes] http://archive.raspberrypi.com/debian/ trixie main" \
	> /etc/apt/sources.list.d/raspi.list
apt-get update -qq

# Pi bits the installer expects but a container has no business providing
mkdir -p /boot/firmware /usr/local/bin
cat > /boot/firmware/config.txt <<'CFG'
[all]
#dtparam=spi=on
dtparam=i2c_arm=on
CFG

for cmd in raspi-config systemctl loginctl; do
	printf '#!/bin/sh\necho "[stub] %s $*"\nexit 0\n' "$cmd" > "/usr/local/bin/$cmd"
	chmod +x "/usr/local/bin/$cmd"
done

for group in spi i2c gpio video audio; do
	groupadd -f "$group"
done

useradd -m -s /bin/bash pi
echo "pi ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/pi
chmod 0440 /etc/sudoers.d/pi

cp -r "$SRC" /home/pi/pirate-audio
chown -R pi:pi /home/pi/pirate-audio

su - pi -c "cd /home/pi/pirate-audio/mopidy && ./install.sh --force --no-upgrade"

echo
echo "======== SECOND RUN (idempotency) ========"
su - pi -c "cd /home/pi/pirate-audio/mopidy && ./install.sh --force --no-upgrade"

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

for line in "dtparam=spi=on" "dtoverlay=hifiberry-dac" "dtparam=audio=off" "gpio=25=op,dh"; do
	check "config.txt has $line" "grep -qx '$line' /boot/firmware/config.txt"
done
for line in "dtparam=spi=on" "dtoverlay=hifiberry-dac" "dtparam=audio=off" "gpio=25=op,dh"; do
	check "config.txt has exactly one $line" "[ \$(grep -cx '$line' /boot/firmware/config.txt) -eq 1 ]"
done
check "second run did not double up the sudoers entry" "[ \$(wc -l < /etc/sudoers.d/010_mopidy-nopasswd) -eq 1 ]"
check "config.txt backed up" "ls /boot/firmware/config.preinstall-pirate-audio-*.txt"
check "venv created" "[ -x /home/pi/.virtualenvs/mopidy/bin/mopidy ]"
check "mopidy.conf written" "[ -f /home/pi/.config/mopidy/mopidy.conf ]"
check "mopidy.conf selects st7789" "grep -q '^display = st7789' /home/pi/.config/mopidy/mopidy.conf"
check "service unit written" "[ -f /home/pi/.config/systemd/user/mopidy.service ]"
check "service unit points at venv" "grep -q 'ExecStart=/home/pi/.virtualenvs/mopidy/bin/mopidy' /home/pi/.config/systemd/user/mopidy.service"
check "iris sudoers written" "[ -f /etc/sudoers.d/010_mopidy-nopasswd ]"
check "iris sudoers names the login user" "grep -q '^pi ALL=NOPASSWD:' /etc/sudoers.d/010_mopidy-nopasswd"
check "iris system.sh path resolves" "test -f \$(awk -F': ' '{print \$2}' /etc/sudoers.d/010_mopidy-nopasswd)"
check "uninstaller written" "[ -f /home/pi/Pimoroni/pirate-audio/uninstall.sh ]"
check "music dir created" "[ -d /home/pi/Music ]"

VPY=/home/pi/.virtualenvs/mopidy/bin/python

echo
echo "-------- installed versions --------"
su - pi -c "$VPY -m pip list 2>/dev/null" | grep -Ei "^(mopidy|pykka|setuptools|st7789|numpy|pillow|spidev|netifaces|gpiod|gpiodevice|pidi)" || true

echo
echo "-------- runtime checks --------"
su - pi -c "$VPY - <<'PY'
import sys

import pkg_resources

print('python', sys.version.split()[0])

import mopidy
print('mopidy', mopidy.__version__)

names = {}
for ep in pkg_resources.iter_entry_points('pidi.plugin.display'):
    names[ep.name] = ep
print('pidi display plugins:', sorted(names))
assert 'DisplayST7789' in names, 'DisplayST7789 entry point missing'

plugin = names['DisplayST7789'].resolve()
print('resolved:', plugin)

import mopidy_pidi, mopidy_raspberry_gpio, mopidy_iris, mopidy_local
print('plugins import OK')

from mopidy_pidi import Extension
choices = Extension().get_config_schema()['display']._choices
print('pidi display choices:', sorted(choices))
assert 'st7789' in choices, 'st7789 missing from the pidi display choices'
PY" || fail=1

echo
if [ "$fail" -ne 0 ]; then
	echo "RESULT: FAILURES"
	exit 1
fi
echo "RESULT: PASS"
