#!/usr/bin/env python3
import sys
import time

from PIL import Image
from PIL import ImageDraw
from PIL import ImageFont

import ST7789


MESSAGE = "Hello World! How are you today?"

print("""
scrolling-test.py - Display scrolling text.

If you're using Breakout Garden, plug the 1.3" LCD (SPI)
breakout into the front slot.

Usage: {} "<message>" <display_type>

Where <display_type> is one of:

  * square - 240x240 1.3" Square LCD
  * round  - 240x240 1.3" Round LCD (applies an offset)
  * rect   - 240x135 1.14" Rectangular LCD (applies an offset)
  * dhmini - 320x240 2.0" Display HAT Mini
""".format(sys.argv[0]))

try:
    MESSAGE = sys.argv[1]
except IndexError:
    pass

try:
    display_type = sys.argv[2]
except IndexError:
    display_type = "square"


# Create ST7789 LCD display class.

if display_type in ("square", "rect", "round"):
    disp = ST7789.ST7789(
        height=135 if display_type == "rect" else 240,
        rotation=0 if display_type == "rect" else 90,
        port=0,
        cs=ST7789.BG_SPI_CS_FRONT,  # BG_SPI_CS_BACK or BG_SPI_CS_FRONT
        dc=9,
        backlight=19,               # 18 for back BG slot, 19 for front BG slot.
        spi_speed_hz=80 * 1000 * 1000,
        offset_left=0 if display_type == "square" else 40,
        offset_top=53 if display_type == "rect" else 0
    )

elif display_type == "dhmini":
    disp = ST7789.ST7789(
        height=240,
        width=320,
        rotation=180,
        port=0,
        cs=1,
        dc=9,
        backlight=13,
        spi_speed_hz=60 * 1000 * 1000,
        offset_left=0,
        offset_top=0
   )

else:
    print ("Invalid display type!")

# Initialize display.
disp.begin()

WIDTH = disp.width
HEIGHT = disp.height


img = Image.new('RGB', (WIDTH, HEIGHT), color=(0, 0, 0))

draw = ImageDraw.Draw(img)

font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)

size_x, size_y = draw.textsize(MESSAGE, font)

text_x = disp.width
text_y = (disp.height - size_y) // 2

t_start = time.time()

while True:
    x = (time.time() - t_start) * 100
    x %= (size_x + disp.width)
    draw.rectangle((0, 0, disp.width, disp.height), (0, 0, 0))
    draw.text((int(text_x - x), text_y), MESSAGE, font=font, fill=(255, 255, 255))
    disp.display(img)
