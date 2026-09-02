# Pirate Audio Examples

Small, standalone examples for building your own Pirate Audio application. None of these need Mopidy.

* [rainbow.py](rainbow.py) - set up the LCD and push a PIL image to it
* [buttons.py](buttons.py) - read the four buttons and work out which was pressed
* [backlight-pwm.py](backlight-pwm.py) - vary the backlight brightness with PWM
* [shairport-sync-control.py](shairport-sync-control.py) - drive Shairport Sync over DBus with the buttons

## Dependencies

```
sudo apt update
sudo apt install python3-rpi-lgpio python3-spidev python3-pil python3-numpy python3-pip python3-venv
python3 -m venv --system-site-packages ~/.virtualenvs/pirate-audio
source ~/.virtualenvs/pirate-audio/bin/activate
pip install st7789
```

Install `python3-rpi-lgpio` rather than `python3-rpi.gpio` - it provides the same `RPi.GPIO` API on top of `lgpio`, and the original doesn't work on Raspberry Pi 5 or on Raspberry Pi OS Trixie.

`shairport-sync-control.py` additionally needs `sudo apt install python3-dbus`.

You'll also need `dtparam=spi=on` and the DAC overlay in `/boot/firmware/config.txt` - see the [top-level README](../README.md#installation).

## Running them

```
source ~/.virtualenvs/pirate-audio/bin/activate
python rainbow.py
```

The buttons are BCM 5, 6, 16 and 24 (A, B, X, Y). Boards made before 23 January 2020 used BCM 20 in place of BCM 24 for "Y".

For many more display examples, see the [st7789 Python library](https://github.com/pimoroni/st7789-python/tree/main/examples).
