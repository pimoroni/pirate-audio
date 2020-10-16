#!/usr/bin/env python3
import math
import time
# import tkinter
import pathlib
import numpy
from PIL import Image, ImageTk, ImageDraw, ImageFont

from fonts.ttf import RobotoMedium
import RPi.GPIO as GPIO
from ST7789 import ST7789
import sounddevice
import wave

WIDTH = 480
HEIGHT = 480

COLOR_WHITE = (255, 255, 255)
COLOR_RED = (232, 56, 58)
COLOR_GREEN = (47, 173, 102)
COLOR_YELLOW = (242, 146, 0)

BUTTON_RECORD = (0, 0, 50, 50)
BUTTON_PLAY = (390, 0, 460, 50)
BUTTON_DELETE = (390, 230, 460, 280)
BUTTON_NEXT = (0, 230, 50, 280)

BUTTONS = [5, 6, 16, 24]
LABELS = ["A", "B", "X", "Y"]


def transparent(color, opacity=0.2):
    opacity = int(255 * opacity)
    r, g, b = color
    return r, g, b, opacity

class Recordamajig:
    def __init__(self, device="mic_out", output_device="upmix", samplerate=16000):
        self._state = "initial"
        self._clip = 1

        self._vu_left = 0
        self._vu_right = 0
        self._graph = [0 for _ in range(44)]
        self._fft = [0 for _ in range(10)]
        self._indata = numpy.empty((0, 2))

        self._device = device
        self._samplerate = samplerate

        self._image = Image.new("RGBA", (480, 480), (0, 0, 0, 0))
        self._draw = ImageDraw.Draw(self._image)

        self._background = Image.open(pathlib.Path("background.png"))

        self._font = ImageFont.truetype(RobotoMedium, size=62)
        self._font_small = ImageFont.truetype(RobotoMedium, size=47)
        self._font_tiny = ImageFont.truetype(RobotoMedium, size=28)

        self._stream = sounddevice.InputStream(
            device=self._device,  # adau7002",
            dtype="int16",
            channels=2,
            samplerate=self._samplerate,
            callback=self.audio_callback
        )

        self._stream.start()

    def audio_callback(self, indata, frames, time, status):
        self._vu_left = numpy.average(numpy.abs(indata[:,0])) / 65535.0 * 5
        self._vu_right = numpy.average(numpy.abs(indata[:,1])) / 65535.0 * 5

        self._graph.append(min(1.0, max(self._vu_left, self._vu_right)))
        self._graph = self._graph[-44:]
 
        self._indata = numpy.concatenate((self._indata, indata))
        if len(self._indata) >= self._samplerate:
            self._indata = self._indata[-self._samplerate:]
            self.calculate_fft()

    def calculate_fft(self):
        fft = numpy.abs(numpy.fft.fft(self._indata[:,0])) / self._samplerate
        fft = fft[range(2000)]
 
        self._fft = numpy.mean(fft.reshape(-1, 2000 // 10), axis=1)
        #print(self._fft)

    def draw_text(self, x, y, text, font, w=480, h=None, alignment="left", vertical_alignment="top", color=COLOR_WHITE):
        tw, th = self._draw.textsize(text, font=font)
        if h is None:
            h = th
        if alignment == "center":
            x += w // 2
            x -= tw // 2
        if vertical_alignment == "center":
            y += h // 2
            y -= th // 2
        self._draw.text((x, y), text, color, font=font)

    @property
    def running(self):
        return not self._stream.stopped and self._stream.active

    def render(self):
        # Clear the canvas
        self._draw.rectangle((0, 0, 480, 480), (0, 0, 0, 0))

        bar_x = 0
        bar_y = 0
        bar_color = COLOR_WHITE

        for bar in range(10):
            scale = min(1.0, self._fft[bar] / 100.0)
            bar_w = 24
            bar_h = 480 * scale
            bar_h = max(2, bar_h)
            if bar_h % 1:
                bar_h += 1
            bar_y = 240
            bar_y -= (bar_h // 2)
            self._draw.rectangle((bar_x, bar_y, bar_x + bar_w - 1, bar_y + bar_h - 1), bar_color)
            bar_x += 48

        """
        bar_x = 20

        for bar in range(44):
            scale = self._graph[bar]
            bar_w = 5
            bar_h = 480 * scale
            bar_h = max(2, bar_h)
            if bar_h % 1:  # Odd height bars wont look gud!
                bar_h += 1
            bar_y = (240)  # Middle of bar graph
            bar_y -= (bar_h // 2)
            self._draw.rectangle((bar_x, bar_y, bar_x + bar_w - 1, bar_y + bar_h - 1), bar_color)
            bar_x += 10  # 5px bar, 5px gap
        """

        return Image.alpha_composite(self._background.convert("RGBA"), self._image).convert("RGB")


SPI_SPEED_MHZ = 80

display = ST7789(
    rotation=90,  # Needed to display the right way up on Pirate Audio
    port=0,       # SPI port
    cs=1,         # SPI port Chip-select channel
    dc=9,         # BCM pin used for data/command
    backlight=13,
    spi_speed_hz=SPI_SPEED_MHZ * 1000 * 1000
)

recordamajig = Recordamajig()

while recordamajig.running:
    display.display(recordamajig.render().resize((240, 240)))

    time.sleep(1.0 / 30)
