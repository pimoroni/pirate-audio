# Pirate Audio Mopidy Setup

## Automatic Setup

We recommend Raspberry Pi OS Trixie (64-bit), starting from a fresh install. Bookworm still works but is no longer what we test against.

Either Desktop or Lite is fine - Lite is the better choice for a standalone player. On Lite you'll need `sudo apt install git` first.

```
git clone https://github.com/pimoroni/pirate-audio
cd pirate-audio/mopidy
./install.sh
```

The installer takes `--force` to answer prompts for you and `--no-upgrade` to skip `apt upgrade`.

Reboot afterwards, since the display and DAC need the `/boot/firmware/config.txt` changes to take effect. Then:

* check the service with `systemctl --user status mopidy`
* open Iris at `http://<your-pi>.local:6680/iris/`
* drop music into `~/Music` and trigger a local scan from Iris

The installer writes uninstall steps to `~/Pimoroni/pirate-audio/uninstall.sh` and backs up your previous `config.txt` to `~/Pimoroni/config-backups/`.

### What it installs

Mopidy runs from a virtual environment at `~/.virtualenvs/mopidy` as a systemd *user* service, so nothing is installed system-wide with `pip`.

The Python packages are version-pinned to the Mopidy 3 stack:

```
mopidy>=3.4.2,<4
pykka>=3.1,<4
setuptools<82
mopidy-iris
mopidy-local<4
mopidy-pidi
mopidy-raspberry-gpio
pidi-display-pil
pidi-display-st7789
```

Mopidy 4 is a breaking release - it swaps `pkg_resources` for `importlib.metadata` and moves to Pykka 4 - and `Mopidy-PiDi`, `Mopidy-Iris` and `Mopidy-Raspberry-GPIO` have not been ported yet. `setuptools` 82 dropped `pkg_resources`, which Mopidy 3 still imports, hence that pin too.

## Manual Setup

### Hardware config

Enable SPI and set up the DAC. `sudo raspi-config` will do SPI under interfacing options, or add all of these to `/boot/firmware/config.txt` yourself:

```
dtparam=spi=on
dtoverlay=hifiberry-dac
dtparam=audio=off
gpio=25=op,dh
```

`dtparam=audio=off` disables onboard audio. Pirate Audio doesn't need it, and with only one sound card present GStreamer is far less likely to pick the wrong output.

### Dependencies

```
sudo apt update
sudo apt install -y \
  gir1.2-gstreamer-1.0 \
  gstreamer1.0-alsa \
  gstreamer1.0-gl \
  gstreamer1.0-gtk3 \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-pulseaudio \
  gstreamer1.0-tools \
  libgstreamer1.0-0 \
  libopenblas0 \
  libopenjp2-7 \
  python3-dev \
  python3-gi \
  python3-gst-1.0 \
  python3-lgpio \
  python3-numpy \
  python3-pil \
  python3-pip \
  python3-rpi-lgpio \
  python3-spidev \
  python3-venv
```

A few of these are less obvious than the rest:

* `python3-rpi-lgpio` replaces `python3-rpi.gpio` with a shim over `lgpio`. `Mopidy-Raspberry-GPIO` still asks for `RPi.GPIO`, and the original doesn't work on Raspberry Pi 5 or on Trixie.
* `libopenblas0` is what a pip-installed NumPy wheel links against. You shouldn't need one, but if pip does pull a wheel this stops the display plugin failing with `libopenblas.so.0: cannot open shared object file`.
* `python3-dev` builds `netifaces`, a `Mopidy-PiDi` dependency with no 64-bit wheel.

### Set up a virtual environment

Recent versions of Raspberry Pi OS won't let you `pip install` into the system Python. `--system-site-packages` lets the environment see the apt-installed NumPy, Pillow, spidev and `RPi.GPIO` shim:

```bash
python3 -m venv --system-site-packages ~/.virtualenvs/mopidy
source ~/.virtualenvs/mopidy/bin/activate
```

### Installing Mopidy, Iris and the Pirate Audio plugins

`mopidy-iris` is optional, but it's a web interface for Mopidy that you'll no doubt find useful.

```
pip install --upgrade \
  "mopidy>=3.4.2,<4" \
  "pykka>=3.1,<4" \
  "setuptools<82" \
  mopidy-iris \
  "mopidy-local<4" \
  mopidy-pidi \
  mopidy-raspberry-gpio \
  pidi-display-pil \
  pidi-display-st7789
```

Iris shells out to its own `system.sh` to restart Mopidy and rescan local files, which needs root. Find the path and grant it:

```
IRIS_SYSTEM_SH=$(python -c "from importlib.metadata import distribution; print(distribution('mopidy-iris').locate_file('mopidy_iris/system.sh'))")
echo "$USER ALL=NOPASSWD: $IRIS_SYSTEM_SH" | sudo tee /etc/sudoers.d/010_mopidy-nopasswd
sudo chmod 0440 /etc/sudoers.d/010_mopidy-nopasswd
```

Use `/etc/sudoers.d/` rather than appending to `/etc/sudoers`, and note the entry names *your* user - the service runs as you, and there is no `mopidy` user when Mopidy is installed this way.

### Config file & tweaks

Create `~/.config/mopidy/mopidy.conf` containing:

```
[raspberry-gpio]
enabled = true
bcm5 = play_pause,active_low,250
bcm6 = volume_down,active_low,250
bcm16 = next,active_low,250
bcm20 = volume_up,active_low,250
bcm24 = volume_up,active_low,250

[file]
enabled = true
media_dirs = /home/pi/Music

[local]
media_dir = /home/pi/Music

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
```

Substitute your own home directory for `/home/pi`.

`hostname = 0.0.0.0` binds `mpd` and `http` to all addresses, making both reachable from other devices on your network. Use your Pi's static IP instead if you'd rather pin them to one interface.

The "Y" button moved from BCM 20 to BCM 24 in January 2020, so both are listed and whichever pin your board doesn't use simply does nothing. `Mopidy-Raspberry-GPIO` also understands `prev`, `play_stop` and `playlist` events if you'd rather remap something.

### Set up the service

Mopidy runs as a systemd user service, so it needs no root privileges - but your user does need access to the display and buttons:

```
sudo usermod -a -G spi,i2c,gpio,video "$USER"
```

Write `~/.config/systemd/user/mopidy.service`:

```
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
WorkingDirectory=/home/pi
ExecStart=/home/pi/.virtualenvs/mopidy/bin/mopidy --config /home/pi/.config/mopidy/mopidy.conf
Restart=on-failure

[Install]
WantedBy=default.target
```

Then enable it. `enable-linger` is what makes it start at boot rather than at login:

```
sudo loginctl enable-linger "$USER"
systemctl --user daemon-reload
systemctl --user enable --now mopidy
systemctl --user status mopidy
```

Note that `systemctl --user` and not `sudo systemctl` is what you want throughout - the service belongs to your user.

## Spotify

Spotify doesn't currently work alongside the Pirate Audio display and buttons, and the installer leaves it out.

The only working Spotify plugin is `mopidy-spotify` 5.x, which requires Mopidy 4. `Mopidy-PiDi` and `Mopidy-Raspberry-GPIO` don't support Mopidy 4 yet, so it's one or the other. The older `mopidy-spotify` 4.x needs `pyspotify`/`libspotify`, which Spotify retired, so that route is a dead end.

If you want Spotify today, install Mopidy 4 and `mopidy-spotify` 5 per https://github.com/mopidy/mopidy-spotify and accept a blank screen and dead buttons. You'll also need `gst-plugin-spotify` built with token-based login, since Spotify retired username and password auth - working notes for that are here: https://gist.github.com/helgibbons/9668655cbbf252ef3d21f1095c9f4ff0

Progress on porting the plugins is tracked in [#17](https://github.com/pimoroni/pirate-audio/issues/17).

For Spotify Connect without Mopidy, see [PiDi Spotify](https://github.com/pimoroni/pidi-spotify) - it displays album art and track info alongside [Raspotify](https://dtcooper.github.io/raspotify/), but can't control playback.

## Updating

`apt` covers the system packages:

```
sudo apt update
sudo apt upgrade
```

The Python side is separate. Activate the virtual environment first, then re-run the `pip install --upgrade` command from above - keep the version pins, or pip will pull Mopidy 4 and the display and buttons will stop working.

Re-running `./install.sh` does the same thing and is safe to repeat; it backs up your `mopidy.conf` and shows you what changed.

## Troubleshooting

Logs first:

```
systemctl --user status mopidy
journalctl --user -u mopidy -n 100
```

**No display, and the log says `pidi/display must be one of 'file', not st7789`.** The `st7789` display plugin failed to import, so `pidi` never registered it. The error that matters is the `Error loading display plugin DisplayST7789` warning further up the log.

**`libopenblas.so.0: cannot open shared object file`.** A pip-installed NumPy wheel with no BLAS to link against. `sudo apt install libopenblas0` fixes it. (See [#120](https://github.com/pimoroni/pirate-audio/issues/120), [#104](https://github.com/pimoroni/pirate-audio/issues/104).)

**Buttons do nothing.** Check `python3-rpi-lgpio` is installed - `RPi.GPIO` proper doesn't work on Raspberry Pi 5 or on Trixie. If only the "Y" button is dead, see the BCM 20 / BCM 24 note above. (See [#112](https://github.com/pimoroni/pirate-audio/issues/112).)

**No album art for local files.** Browse them through **Local** rather than **Files**. The `file` backend serves no images at all, so `pidi` falls back to looking the album up on MusicBrainz. `mopidy-local` extracts embedded art and picks up `album_art_files` (`*.jpg`, `*.jpeg`, `*.png`) next to your tracks, but only for files it has scanned - trigger a scan from Iris, or run `mopidy local scan`. (See [#79](https://github.com/pimoroni/pirate-audio/issues/79).)

**Audio comes out of the wrong device.** Check `dtparam=audio=off` is in `/boot/firmware/config.txt` and that `aplay -l` shows the HifiBerry DAC. With more than one card present, GStreamer's `autoaudiosink` may well pick the other one.
