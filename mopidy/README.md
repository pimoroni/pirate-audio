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
sudo apt-get install python3-rpi.gpio python3-spidev python3-pip python3-pil python3-numpy
```

### Mopidy with Spotify and Iris

You can now install Mopidy. Both `mopidy-spotify` and `mopidy-iris` are optional. The former adds support for the music streaming service of the same name, and `iris` is a web interface for Mopidy that you'll no doubt find useful.

```
sudo apt install mopidy mopidy-spotify
sudo pip3 install mopidy-iris
```

Iris uses a shell script to perform actions such as restarting Mopidy and scanning for local files (https://github.com/jaedb/Iris/blob/master/mopidy_iris/system.sh), it needs root privileges to do this which can be granted with sudoers like so (assuming your Python is version 3.7, you can find the dist-packages dir with `python3 -m site`):

```
echo "mopidy ALL=NOPASSWD: /usr/local/lib/python3.7/dist-packages/mopidy_iris/system.sh" | sudo tee -a /etc/sudoers
```

### Pirate Display Plugins

Next, install the plugins to get Pirate Audio up and running:

```
sudo pip3 install Mopidy-PiDi pidi-display-pil pidi-display-st7789 mopidy-raspberry-gpio
```

### Config File & Tweaks

To use Mopidy as a service, create a new `mopidy.conf` which you will then populate with custom settings.

```
sudo touch /etc/mopidy/mopidy.conf
```

You should then use `sudo nano` (or `vim` if you prefer) to edit `/etc/mopidy/mopidy.conf` and add the following:

```
[raspberry-gpio]
enabled = true
bcm5 = play_pause,active_low,150
bcm6 = volume_down,active_low,150
bcm16 = next,active_low,150
bcm20 = volume_up,active_low,150

[pidi]
enabled = true
display = st7789

[mpd]
hostname = 0.0.0.0

[http]
hostname = 0.0.0.0

[audio]
mixer_volume = 40
output = alsasink
```

This will set up the plugins required for Pirate Audio and additionally configure Mopidy to use alsa so that audio is output via the DAC. It also changes the hostname for `mpd` and `http` to `0.0.0.0` (bind to all addresses) which makes them both accessible to other devices on your network. You can substitute your devices static IP if you want to use a specific interface.

If you're planning to use Spotify then you should also add the following, inserting your login details, client ID and secret where appropriate:

```
[spotify]
enabled = true 
username = << your username
password = << your password
client_id = << the paragraph below addresses your client_id 
client_secret = << ...and your client secret
```

To retrieve the client ID and secret you can authenticate with Spotify here: https://mopidy.com/ext/spotify/

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
sudo pip3 install --upgrade mopidy-iris Mopidy-PiDi pidi-display-pil pidi-display-st7789 mopidy-raspberry-gpio
```
