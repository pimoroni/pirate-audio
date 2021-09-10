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
    def __init__(self, device="mic_out", output_device="default", samplerate=16000):
        self._state = "initial"
        self._clip = 1

        self._vu_left = 0
        self._vu_right = 0

        self._graph = [0 for _ in range(44)]

        self._device = device
        self._out_device = output_device
        self._samplerate = samplerate

        self._image = Image.new("RGBA", (480, 480), (0, 0, 0, 0))
        self._draw = ImageDraw.Draw(self._image)

        self._controls = Image.new("RGBA", (440, 280), (255, 255, 255, 50))
        self._draw_controls = ImageDraw.Draw(self._controls)

        self._background = Image.open(pathlib.Path("background.png"))
        self._controls_mask = Image.open(pathlib.Path("controls.png"))

        self._font = ImageFont.truetype(RobotoMedium, size=62)
        self._font_small = ImageFont.truetype(RobotoMedium, size=47)
        self._font_tiny = ImageFont.truetype(RobotoMedium, size=28)

        self._wave = None

        self._recording = False
        self._confirm_delete = False

        self._written = 0
        self.running = True

        self._clip_exists = False
        self._update_clip()

        self._stream = sounddevice.InputStream(
            device=self._device,  # adau7002",
            dtype="int16",
            channels=2,
            samplerate=self._samplerate,
            callback=self.audio_callback
        )
        self._out_stream = sounddevice.OutputStream(
            device=self._out_device,
            dtype="int16",
            channels=2,
            samplerate=self._samplerate,
            callback=self.audio_playback_callback
        )

    def next(self):
        if not self._clip_exists:
            return
        self._clip += 1
        self._update_clip()

    def _update_clip(self):
        self._clip_exists = self.clipfile.is_file()
        if self._clip_exists and not self._recording:
            self._wave_read = wave.open(str(self.clipfile), "r")
            self._written = self._wave_read.getnframes()
            if not (self._samplerate == self._wave_read.getframerate()):
                raise RuntimeError(f"Invalid samplerate in {self.clipfile}")

    def _playback_stopped(self):
        self._vu_left = 0
        self._vu_right = 0
        self._graph = [0 for _ in range(44)]

    def play(self):
        if self._confirm_delete:
            self._confirm_delete = False
            return False
        if self._recording:
            return False
        if self._out_stream.stopped or not self._out_stream.active:
            self._playback_stopped()
            self._out_stream.stop()
            self._update_clip()
            self._out_stream.start()
            return True
        else:
            self._out_stream.stop()
            self._playback_stopped()
            return False

    def record(self):
        if self._confirm_delete:
            self._confirm_delete = False
            return

        if self._recording:
            self.stop_recording()
        else:
            self.start_recording()
        return self._recording

    def delete(self):
        if self._recording:
            return False
        if self._confirm_delete:
            self._confirm_delete = False
            if self._wave_read is not None:
                self._wave_read.close()
            self.clipfile.unlink()
            if self._clip > 1:
                self._clip -= 1
            self._update_clip()
        else:
            self._confirm_delete = True

    @property
    def recording(self):
        return self._recording

    @property
    def clipfile(self):
        return pathlib.Path(f"clip-{self._clip:02d}.wav")

    def start_recording(self):
        if self._clip_exists:
            return
        self._written = 0
        self._wave = wave.open(str(self.clipfile), "w")
        self._wave.setframerate(self._samplerate)
        self._wave.setsampwidth(2)  # size of the input dtype
        self._wave.setnchannels(2)
        self._recording = True

        self._stream.start()
        self._update_clip()

    def stop_recording(self):
        self._recording = False
        if self._wave is not None:
            self._wave.close()
            self._wave = None
        self._stream.stop()
        self._update_clip()

    def get_duration(self):
        return self._written / self._samplerate

    def audio_callback(self, indata, frames, time, status):
        self._vu_left = numpy.average(numpy.abs(indata[:,0])) / 65535.0 * 10
        self._vu_right = numpy.average(numpy.abs(indata[:,1])) / 65535.0 * 10
        #print(self._vu_left, self._vu_right)

        self._graph.append(min(1.0, max(self._vu_left, self._vu_right)))
        self._graph = self._graph[-44:]

        if self._recording and self._wave is not None:
            self._written += frames
            self._wave.writeframes(indata.tobytes())

    def audio_playback_callback(self, outdata, frames, time, status):
        raw_data = self._wave_read.readframes(frames)
        outframes = len(raw_data) // 4
        data = numpy.frombuffer(raw_data, dtype="int16")
        outdata[:][:outframes] = data.reshape((outframes, 2))

        self._vu_left = numpy.average(numpy.abs(outdata[:,0])) / 65535.0 * 10
        self._vu_right = numpy.average(numpy.abs(outdata[:,1])) / 65535.0 * 10
        self._graph.append(min(1.0, max(self._vu_left, self._vu_right)))
        self._graph = self._graph[-44:]

        if outframes < frames:
            self._playback_stopped()
            raise sounddevice.CallbackStop

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

    def render_controls(self):
        self._draw_controls.rectangle((0, 0, 480, 480), transparent(COLOR_WHITE))
        if self._recording:
            self._draw_controls.rectangle(BUTTON_RECORD, COLOR_RED)
        else:
            if self._confirm_delete:
                self.draw_text(0, 350 - 6, "Delete Clip 1?", font=self._font_small, alignment="center", color=COLOR_RED)
                self._draw_controls.rectangle(BUTTON_DELETE, COLOR_RED)
            else:
                if self._clip_exists:
                    self._draw_controls.rectangle(BUTTON_RECORD, transparent(COLOR_WHITE))
                    self._draw_controls.rectangle(BUTTON_PLAY, COLOR_WHITE)
                    self._draw_controls.rectangle(BUTTON_DELETE, COLOR_WHITE)
                    self._draw_controls.rectangle(BUTTON_NEXT, COLOR_WHITE)
                else:
                    self._draw_controls.rectangle(BUTTON_RECORD, COLOR_WHITE)

        # Using the controls image as an alpha mask,
        # paste the "controls" image, which gives our buttons colour
        self._image.paste(self._controls, (20, 115), self._controls_mask)

    def stop(self):
        self.stop_recording()

        self.running = False

    def render(self):
        # Clear the canvas
        self._draw.rectangle((0, 0, 480, 480), (0, 0, 0, 0))

        self.render_controls()

        if self._clip_exists:
            # Clip length bar
            self._draw.rectangle((20, 175, 460, 335), transparent(COLOR_WHITE))

            bar_x = 20
            bar_y = 0
            bar_color = COLOR_WHITE

            if self._confirm_delete:
                bar_color = transparent(COLOR_WHITE)

            for bar in range(44):
                scale = self._graph[bar]
                bar_w = 5
                bar_h = 160 * scale
                if bar_h % 1:  # Odd height bars wont look gud!
                    bar_h += 1
                bar_y = (175 + 80)  # Middle of bar graph
                bar_y -= (bar_h // 2)
                self._draw.rectangle((bar_x, bar_y, bar_x + bar_w - 1, bar_y + bar_h - 1), bar_color)
                bar_x += 10  # 5px bar, 5px gap

            duration_seconds = self.get_duration()
            duration_minutes = duration_seconds // 60
            duration_seconds %= 60

            duration_minutes = int(duration_minutes)
            duration_seconds = int(duration_seconds)

            color = COLOR_WHITE
            if self._confirm_delete:
                color = transparent(COLOR_WHITE)
            self.draw_text(0, 35 - 12, f"Clip {self._clip}", font=self._font, alignment="center", color=color)
            self.draw_text(0, 115 - 12, f"{duration_minutes:02d}:{duration_seconds:02d}", font=self._font, alignment="center", color=color)

        else:
            if self._clip == 1:
                self.draw_text(0, 175, "Press A to record", h=160, font=self._font_small, alignment="center", vertical_alignment="center")
            else:
                self.draw_text(0, 35 - 12, f"Clip {self._clip}", font=self._font, alignment="center", color=transparent(COLOR_WHITE))
            self.draw_text(0, 115 - 12, "00:00", font=self._font, alignment="center", color=transparent(COLOR_WHITE))


        color = COLOR_WHITE
        if not self._clip_exists or self._confirm_delete:
            color = transparent(COLOR_WHITE)

        self.draw_text(20, 405, "L", font=self._font_tiny, color=color)
        self.draw_text(20, 435, "R", font=self._font_tiny, color=color)

        bar_x = 65
        vu_left = int(self._vu_left * 40)
        vu_right = int(self._vu_right * 40)
        for bar in range(40):
            bar_w = 5
            bar_h = 20
            bar_y = 410
            
            color = transparent(COLOR_WHITE)

            if vu_left > bar:
                if self._confirm_delete:
                    color = transparent(COLOR_GREEN)
                else:
                    color = COLOR_GREEN

            self._draw.rectangle((bar_x, bar_y, bar_x + bar_w - 1, bar_y + bar_h - 1), color)
            
            bar_y = 440
            
            color = transparent(COLOR_WHITE)

            if vu_right > bar:
                if self._confirm_delete:
                    color = transparent(COLOR_GREEN)
                else:
                    color = COLOR_GREEN


            self._draw.rectangle((bar_x, bar_y, bar_x + bar_w - 1, bar_y + bar_h - 1), color)
            bar_x += 10

        return Image.alpha_composite(self._background.convert("RGBA"), self._image).convert("RGB")

# window = tkinter.Tk()
# window.geometry("480x480")
# window.resizable(False, False)
# window.title("Recordamajig")

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

def handle_keydown(e):
    char = getattr(e, "char", e)
    print("Key {}".format(char))
    if char in ("r", 5):   # A button
        recordamajig.record()
        if recordamajig.recording:
            print("Start recording...")
        else:
            print("Stop recording...")
    if char in ("d", 24):  # Y button
        recordamajig.delete()
    if char in ("n", 6):       # B button
        recordamajig.next()
    if char in ("p", 16):      # X button
        if recordamajig.play():
            print("Start playing...")
        else:
            print("Stop playing...")


GPIO.setmode(GPIO.BCM)
GPIO.setup(BUTTONS, GPIO.IN, pull_up_down=GPIO.PUD_UP)
for pin in BUTTONS:
    GPIO.add_event_detect(pin, GPIO.FALLING, handle_keydown, bouncetime=250)


# window.protocol("WM_DELETE_WINDOW", recordamajig.stop)
# window.bind("<KeyPress>", handle_keydown)

while recordamajig.running:
    # imagetk = ImageTk.PhotoImage(recordamajig.render())
    display.display(recordamajig.render().resize((240, 240)))

    # label = tkinter.Label(
    #    window,
    #    image=imagetk
    # )

    # label.place(x=0, y=0, width=480, height=480)

    # window.update()

    time.sleep(1.0 / 30)
