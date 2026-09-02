# Pirate Audio

Pirate Audio is a range of audio output boards for the Raspberry Pi.

Each board includes an ST7789 240x240 pixel LCD display, four buttons and some form of audio output (except for the Pirate Audio: Dual Mic which offers two microphones instead of audio output).

We recommend Raspberry Pi OS Trixie, either Desktop or Lite. Bookworm still works but is no longer what we test against.

## Hardware

* st7789 display (see [Python library](https://github.com/pimoroni/st7789-python))
* four buttons, active low connected to BCM 5, 6, 16, and 24 (A, B, X, Y respectively)

Boards made before 23 January 2020 wired the "Y" button to BCM 20 rather than BCM 24, to avoid a conflict with PCM data-input. If your "Y" button does nothing, try BCM 20.

## Installation

You'll need to add the following lines to `/boot/firmware/config.txt` to get audio and the display up and running:

```
dtparam=spi=on
dtoverlay=hifiberry-dac
gpio=25=op,dh
```

You should also disable onboard audio. Pirate Audio doesn't need it, and with only one sound card present applications are far less likely to pick the wrong output:

```
dtparam=audio=off
```

And for Dual Mic, you'll need:
```
dtoverlay=adau7002-simple
```
(See [Clip Recorder](./clip-recorder) for further example of use.)

If you want to have the LCD accessible via a Frame Buffer (`/dev/fb0`/`/dev/fb1`) add:

```
# Uncomment the following
dtparam=spi=on

# Add this
dtoverlay=fbtft,spi0-1,speed=80000000,st7789v,height=240,width=240,dc_pin=9,led_pin=13
```

## Using With Mopidy

We've created plugins to get you up and running with Pirate Audio and Mopidy.

These will give you album art display, volume, play/pause and skip control.

See [mopidy](./mopidy) for an installer and step-by-step instructions.

## Using with Spotify Connect

If you want to display album art and track information on your Pirate Audio LCD then check out [PiDi Spotify](https://github.com/pimoroni/pidi-spotify).

Note: PiDi Spotify is currently in beta, does not work alongside [Mopidy](https://mopidy.com/), and can't control playback. If you want to smush track information into Mopidy from [Raspotify](https://dtcooper.github.io/raspotify/) see: https://github.com/pimoroni/pirate-audio/issues/17

Spotify inside Mopidy currently needs Mopidy 4, which the Pirate Audio plugins don't support yet - see the [Mopidy README](./mopidy/README.md#spotify).

## Build Your Own

If you're planning to build your own application you'll find some inspiration in [examples](./examples).

But first you'll need some dependencies:

```
sudo apt update
sudo apt install python3-rpi-lgpio python3-spidev python3-pip python3-pil python3-numpy python3-venv
```

`python3-rpi-lgpio` provides the `RPi.GPIO` API on top of `lgpio`. Install this rather than `python3-rpi.gpio`, which doesn't work on Raspberry Pi 5 or on Raspberry Pi OS Trixie.

Recent versions of Raspberry Pi OS won't let you `pip install` into the system Python, so set up a virtual environment for the st7789 library:

```
python3 -m venv --system-site-packages ~/.virtualenvs/pirate-audio
source ~/.virtualenvs/pirate-audio/bin/activate
pip install st7789
```

For more display examples see the [st7789 Python library examples](https://github.com/pimoroni/st7789-python/tree/main/examples).

For more help with using the Pirate Audio Headphone Amp, see [build your own](build%20your%20own/README.md).

## Elsewhere

Projects that aren't ours, but that people have found useful:

* [pirate-mp3](https://github.com/Gadgetoid/pirate-mp3) - a standalone local MP3 player, no Mopidy
* [pirate-audio-helpers](https://github.com/thoughtfix/pirate-audio-helpers) - bootstrap scripts and a couple of games
