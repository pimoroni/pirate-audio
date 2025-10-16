# Pirate Audio Mopidy Setup

## Automatic Setup

You'll need to be running Raspberry Pi OS Bookworm or later, and we recommend starting with a fresh install.

If you're setting up Mopidy on an existing system you might want to choose the step-by-step manual install instead.

The provided install.sh script executes the manual steps for you.

If you're running the Lite version of Raspberry Pi OS you might first need to `sudo apt install git`.

```
git clone https://github.com/pimoroni/pirate-audio
cd pirate-audio/mopidy
./install.sh
```

Note that due to Spotify discontinuing their API, the `mopidy-spotify` plugin currently requires manual installation: https://github.com/mopidy/mopidy-spotify

If you want the Mopidy service to start when the Pi boots (rather than when the user logs in), try running `sudo loginctl enable-linger`.

## Manual Setup

First, make sure you have SPI enabled on your Raspberry Pi. You can run `sudo raspi-config` and set this up in interfacing options, or add `dtparam=spi=on` to your `/boot/firmware/config.txt`.

Double check you have the lines `dtoverlay=hifiberry-dac` and `gpio=25=op,dh` in your `/boot/firmware/config.txt` since these enable the DAC for audio output.

### Dependencies

Next, update apt and install the necessary dependencies:

```
sudo apt update
sudo apt install -y \
  python3-spidev \
  python3-pip \
  python3-pil \
  python3-numpy \
  python3-lgpio \
  python3-virtualenvwrapper \
  virtualenvwrapper \
  libopenjp2-7 \
  python3-gi \
  libgstreamer1.0-0 \
  libgstreamer1.0-dev \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-tools \
  gstreamer1.0-gl \
  gstreamer1.0-gtk3 \
  python3-gst-1.0 \
  gir1.2-gstreamer-1.0 \
  gstreamer1.0-pulseaudio \
  gstreamer1.0-alsa
```

### Set up virtual environment

Recent versions of Raspberry Pi OS require you to install Python packages into a virtual environment. You can set up and activate one with:

``` bash
python3 -m venv --system-site-packages $HOME/.virtualenvs/mopidy
source ~/.virtualenvs/mopidy/bin/activate
```

### Installing Mopidy and Iris

You can now install Mopidy. `mopidy-iris`  is optional - it is a web interface for Mopidy that you'll no doubt find useful.

```
pip3 install mopidy mopidy-iris
```

Iris uses a shell script to perform actions such as restarting Mopidy and scanning for local files (https://github.com/jaedb/Iris/blob/master/mopidy_iris/system.sh), it needs root privileges to do this which can be granted with sudoers like so (assuming your Python is version 3.7, you can find the dist-packages dir with `python3 -m site`):

```
echo "mopidy ALL=NOPASSWD: /usr/local/lib/python3.7/dist-packages/mopidy_iris/system.sh" | sudo tee -a /etc/sudoers
```

### Pirate Display Plugins

Next, install the plugins to get Pirate Audio up and running:

```
pip3 install Mopidy-PiDi pidi-display-pil pidi-display-st7789 mopidy-raspberry-gpio
```

### Config File & Tweaks

To use Mopidy as a service, create a new `mopidy.conf` which you will then populate with custom settings.

```
sudo touch ~/.config/mopidy/mopidy.conf
```

You should then use `sudo nano` (or `vim` if you prefer) to edit `~/.config/mopidy/mopidy.conf` and add the following:

```
[raspberry-gpio]
enabled = true
bcm5 = play_pause,active_low,250
bcm6 = volume_down,active_low,250
bcm16 = next,active_low,250
bcm20 = volume_up,active_low,250
bcm24 = volume_up,active_low,250

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

This will set up the plugins required for Pirate Audio and additionally configure Mopidy to use alsa so that audio is output via the DAC. It also changes the hostname for `mpd` and `http` to `0.0.0.0` (bind to all addresses) which makes them both accessible to other devices on your network. You can substitute your devices static IP if you want to use a specific interface.

If you're planning to use Spotify then you should also add the following, inserting your client ID and secret where appropriate:

```
[spotify]
enabled = true 
client_id = << the paragraph below addresses your client_id 
client_secret = << ...and your client secret
```

Note that the `mopidy-spotify` plugin currently requires manual installation: https://github.com/mopidy/mopidy-spotify

To retrieve the client ID and secret you can authenticate with Spotify here: https://mopidy.com/ext/spotify/.

### Set Up The Service

Finally you'll need to make some changes to the `mopidy` user so it has access to Pirate Audio:

```
sudo usermod -a -G spi,i2c,gpio,video mopidy
```

And then you can enable and start the `mopidy` service:

```
sudo systemctl enable mopidy
sudo systemctl start mopidy
```

To check if everything is running correctly, try:

```
sudo systemctl status mopidy
```

If you want the Mopidy service to start when the Pi boots (rather than when the user logs in), try running `sudo loginctl enable-linger`.


## Updating

Whether you used the step-by-step instructions or auto-installer, Mopidy and its associated plugins can be updated with `pip` and `apt` on your system.

Using `apt` you can update all system packages including Mopidy in two steps:

```
sudo apt update
sudo apt upgrade
```

The software installed via Python's `pip` has to be updated separately:

After activating your virtual environment:

```
pip3 install --upgrade mopidy mopidy-iris Mopidy-PiDi pidi-display-pil pidi-display-st7789 mopidy-raspberry-gpio
```
