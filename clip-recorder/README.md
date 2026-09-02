# Pirate Audio Dual Mic Recording Utility

## Automatic Setup

We recommend Raspberry Pi OS Trixie, starting from a fresh install.

```
git clone https://github.com/pimoroni/pirate-audio
cd pirate-audio/clip-recorder
./install.sh
```

This enables SPI, sets up the microphone overlay and ALSA config, and installs the Python dependencies into a virtual environment at `~/.virtualenvs/pirate-audio`. Reboot afterwards.

Then test the microphones:

```
arecord -Dmic_out -c2 -r48000 -fS32_LE -twav -d5 -R10000 -Vstereo test.wav
```

The ASCII VU meter should correspond to what the microphones are picking up.

And run an example:

```
source ~/.virtualenvs/pirate-audio/bin/activate
python cliprecord.py
```

Both `cliprecord.py` and `fft.py` take `--input-device`, `--output-device` and `--samplerate`. If playback fails with `ValueError: No output device matching 'default'`, list your devices with `aplay -L` and pass one:

```
python cliprecord.py --output-device sysdefault
```

`--samplerate` has to match the `rate` in your `~/.asoundrc`, or you'll record silence.

## Manual Setup

### Pre-requisites

Install the LADSPA plugins. LADSPA support itself is built into `alsa-lib`, so there's nothing else to add:

```
sudo apt install ladspa-sdk invada-studio-plugins-ladspa
```

### Basic Audio Config

Dual Mic needs some config to enable the microphone and boost the input gain.

Add the following to `/boot/firmware/config.txt` to enable Dual Mic as an audio input:

```
dtparam=spi=on
dtoverlay=adau7002-simple
```

Dual Mic is input-only, so if you've previously set up a Pirate Audio output board, comment out `dtoverlay=hifiberry-dac` while you're in there.

The following config uses a LADSPA plugin (Invada High-Pass Stereo Filter) to remove DC bias and amplify the input from the microphone.

Add it to `~/.asoundrc` or `/etc/asound.conf`:

```
pcm.mic_hw {
    type hw
    card adau7002
    format S32_LE
    rate 48000
    channels 2
}
pcm.mic_rt {
    type route
    slave.pcm mic_hw
    ttable.0.0 1
    ttable.0.1 0
    ttable.1.0 0
    ttable.1.1 1
}
pcm.mic_plug {
    type plug
    slave.pcm mic_rt
}
pcm.mic_filter {
    type ladspa
    slave.pcm mic_plug
    path "/usr/lib/ladspa"
    plugins [
    {
        label invada_hp_stereo_filter_module_0_1
        input {
            controls [
                50   # Cut off frequency (Hz)
                30   # Gain (dB)
                1    # Soft Clip (on/off)
            ]
        }
    }
    ]
}
pcm.mic_out {
    type plug
    slave.pcm mic_filter
}
```

The device for recording is `mic_out`, and `mic_hw` is the raw, unfiltered input.

### Enable SPI

```
sudo raspi-config nonint do_spi 0
```

### Install the Python dependencies

```
sudo apt install \
  invada-studio-plugins-ladspa \
  ladspa-sdk \
  libopenblas0 \
  libportaudio2 \
  python3-dev \
  python3-numpy \
  python3-pil \
  python3-pil.imagetk \
  python3-pip \
  python3-rpi-lgpio \
  python3-spidev \
  python3-venv
```

`python3-rpi-lgpio` replaces `python3-rpi.gpio` with a shim over `lgpio`. The examples use the `RPi.GPIO` API, and the original doesn't work on Raspberry Pi 5 or on Trixie.

Recent versions of Raspberry Pi OS won't let you `pip install` into the system Python, so use a virtual environment:

```
python3 -m venv --system-site-packages ~/.virtualenvs/pirate-audio
source ~/.virtualenvs/pirate-audio/bin/activate
pip install fonts font-roboto st7789 sounddevice
```

### Run

```
python cliprecord.py
```
