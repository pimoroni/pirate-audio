# Pirate Audio Dual Mic Recording Utility

## Installing

### Pre-requisites

Install the LADSPA plugins:

```
sudo apt install ladspa-sdk invada-studio-plugins-ladspa
```

### Basic Audio Config

Dual Mic needs some config to enable the microphone and boost the input gain.

Add the following to `/boot/config.txt` to enable Dual Mic as an audio input:

```
dtoverlay=adau7002-simple
```

The following config uses a LADSPA plugin (Invada High-Pass Stero Filter) to remove DC bias and amplify the input from the microphone.

Add it to `~/.asoundrc` or `/etc/asound.conf`:

```
pcm.mic_hw{
    type hw
    card adau7002
    format S32_LE
    rate 48000
    channels 2
}
pcm.mic_rt{
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
    path "/usr/lib/ladspa";
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

To test the microphone setup, use `arecord` like so:

```
arecord -Dmic_out -c2 -r48000 -fS32_LE -twav -d5 -R10000 -Vstereo test.wav
```

The ASCII VU meter should correspond to what the microphone is picking up.

## Preparing to run these examples

### Install Pulseaudio

Pulse audio supplies an "upmix" output device which allows `cliprecord.py` to play back lower samplerate (smaller) recording without handling resampling.

```
sudo apt install pulseaudio
```

### Enable SPI

```
sudo raspi-config nonint do_spi 0
```

### Install for Python 3

```
sudo apt install python3-pip python3-rpi.gpio python3-spidev python3-numpy python3-pil python3-pil.imagetk libportaudio2
sudo python3 -m pip install fonts font-roboto ST7789 sounddevice
```

### Run

```
python3 cliprecord.py
```
