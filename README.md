# Pirate Audio

Pirate Audio is a range of audio output boards for the Raspberry Pi.

Each board includes an ST7789 240x240 pixel LCD display, four buttons and some form of audio output.


## Hardware

* st7789 display - https://github.com/pimoroni/st7789-python
* four buttons, active low connected to BCM 5, 6, 16, and 20

## Using With Mopidy

We've created plugins to get you up and running with Pirate Audio and Mopidy.

These will give you album art display, volume, play/pause and skip control.

## Build Your Own

If you're planning to build your own application you'll find some inspiration in examples.

But first you'll need some dependencies:

```
sudo apt-get update
sudo apt-get install python-rpi.gpio python-spidev python-pip python-imaging python-numpy
```

And then you'll need the st7789 library:

```
sudo pip install st7789
```

For more display examples see: https://github.com/pimoroni/st7789-python/tree/master/examples
