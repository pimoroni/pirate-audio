Here are some instructions to use the Pirate Audio Headphone Amp (https://shop.pimoroni.com/products/pirate-audio-headphone-amp, PIM482) without any other software.

# Sound

## /boot/config.txt

Edit /boot/config.txt
```
sudo nano /boot/config.txt
```
### Set up audio
Add this to the end of of the file:
```
# Pirate Audio
dtoverlay=hifiberry-dac
gpio=25=op,dh
dtparam=audio=off
```
(Note: The Pirate Audio Headphone Amp is not made by [hifiberry](https://hifiberry.com), but the overlay works.)

If you are on Raspberry Pi Zero, depending on how you use the display, you may want to disable the Raspberry Pi Zero led:
```
# disable led
dtparam=act_led_trigger=none
dtparam=act_led_activelow=on
```
For other Raspberry Pi, please see: 

### Enable i2c and spi
You need to enable i2c and spi. You can do this via `config.txt` or using `raspi-config`. If you want to set this up while you're editing `config.txt`, look for the lines below and remove the `#` from i2c and spi:

```
# Uncomment some or all of these to enable the optional hardware interfaces
dtparam=i2c_arm=on
#dtparam=i2s=on
dtparam=spi=on
```

If you prefer to use `raspi-config`, boot your Raspberry Pi and type
```
sudo raspi-config
```

## Edit asound.conf

Add this to asound.conf
```
pcm.!default  {
 type hw card 0
}
ctl.!default {
 type hw card 0
}
pcm.!default {
        type plug
        slave.pcm “softvol”
}
pcm.softvol {
        type softvol
        slave {
                pcm “dmix”
        }
        control {
                name “Amp”
                card 0
        }
        min_dB -5.0
        max_dB 20.0
        resolution 6
}
```
(Source: https://forums.pimoroni.com/t/volume-for-pirate-audio-headphone-amp-for-raspberry-pi/22058)

# Screen and GPIO

## Install required packages

As per usual, make sure you have the latest Raspian:
```
sudo apt update
sudo apt upgrade
```
Then:
```
sudo apt install python3-rpi.gpio python3-spidev python3-pip python3-pil python3-numpy
sudo pip3 install st7789
```

## Using the GPIO
If you've not used the GPIO much, this script may be helpful: