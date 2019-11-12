# Pirate Audio Mopidy Setup


## Automatic Setup

You'll need a fresh install of Raspbian Buster.

If you're setting up Mopidy on an existing system you might want to choose the step-by-step manual install instead.

The provided `install.sh` script executes the manual steps for you.

If you're running Raspbian Buster Lite you might first need to `sudo apt install git`.

```
git clone https://github.com/pimoroni/pirate-audio
cd pirate-audio/mopidy
sudo ./install.sh
```

## Manual Setup

First, make sure you have SPI enabled on your Raspberry Pi. You can run `sudo raspi-config` and set this up in interfacing options, or add `dtparam=spi=on` to your `/boot/config.txt`.

Double check you have the lines `dtoverlay=hifiberry-dac` and `gpio=25=op,dh` in your `/boot/config.txt` since these enable the DAC for audio output.

### Mopidy Apt List

First you'll need to install Mopidy's package source as detailed in the installation instructions: https://docs.mopidy.com/en/latest/installation/debian/.

```
wget -q -O - https://apt.mopidy.com/mopidy.gpg | sudo apt-key add -
sudo wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/buster.list
```

### Dependencies

Next, update apt and install the necessary dependencies:

```
sudo apt update
sudo apt-get install python-rpi.gpio python-spidev python-pip python-imaging python-numpy
```

### Mopidy with Spotify and Iris

You can now install Mopidy. Both `mopidy-spotify` and `mopidy-iris` are optional. The former adds support for the music streaming service of the same name, and `iris` is a web interface for Mopidy that you'll no doubt find useful.

```
sudo apt install mopidy mopidy-spotify mopidy-iris
```

### Pirate Display Plugins

Next, install the plugins to get Pirate Audio up and running:

```
sudo pip install Mopidy-PiDi pidi-display-pil pidi-display-st7789 mopidy-raspberry-gpio
```

### Config File & Tweaks

To use Mopidy as a service, create a new `mopidy.conf` populated with the default settings:

```
mopidy config | sudo tee /etc/mopidy/mopidy.conf
```

This replaces the default `mopidy.conf` with one that configures `Mopidy-PiDi` and `mopidy-raspberry-gpio` properly.

These 3 commands will tweak some Mopidy settings, you can alternatively use `sudo nano` to edit `/etc/mopidy/mopidy.conf` and change things to your preference:

```
# Set IP for mpd and http (iris) to public
sudo sed -i "s/127.0.0.1/0.0.0.0/g" /etc/mopidy/mopidy.conf

# Change to alsa audio sink
sudo sed -i "s/autoaudiosink/alsasink/g" /etc/mopidy/mopidy.conf

# Set mixer_volume to 40
sudo sed -i "s/mixer_volume = $/mixer_volume = 40/g" /etc/mopidy/mopidy.conf
```

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


## Updating

Whether you used the step-by-step instructions or auto-installer, Mopidy and its associated plugins can be updated with `pip` and `apt` on your system.

Using `apt` you can update all system packages including Mopidy in two steps:

```
sudo apt update
sudo apt upgrade
```

The Mopidy plugins installed via Python's `pip` have to be updated separately:

```
sudo pip install --upgrade mopidy-iris Mopidy-PiDi pidi-display-pil pidi-display-st7789 mopidy-raspberry-gpio
```