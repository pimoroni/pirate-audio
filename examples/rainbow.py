#!/usr/bin/env python

import time
from colorsys import hsv_to_rgb
from PIL import Image, ImageDraw
from ST7789 import ST7789


print("""rainbow.py - Display a rainbow on the Pirate Audio LCD

This example should demonstrate how to:
1. set up the Pirate Audio LCD,
2. create a PIL image to use as a buffer,
3. draw something into that image,
4. and display it on the display

You should see the display change colour.

Press Ctrl+C to exit!

""")

SPI_SPEED_MHZ = 80

image = Image.new("RGB", (240, 240), (0, 0, 0))
draw = ImageDraw.Draw(image)


st7789 = ST7789(
    rotation=90,  # Needed to display the right way up on Pirate Audio
    port=0,       # SPI port
    cs=1,         # SPI port Chip-select channel
    dc=9,         # BCM pin used for data/command
    backlight=13,
    spi_speed_hz=SPI_SPEED_MHZ * 1000 * 1000
)

while True:
    # By using "time.time()" as the source of our hue value,
    # rather than incrementing a counter, we make sure the colour
    # transition effect speed is independent from the display framerate.
    hue = time.time() / 10

    # "hsv_to_rgb" converts our hue, saturation and value numbers
    # into the RGB colourspace needed for PIL's ImageDraw.
    # Since it returns floats from 0.0 to 1.0, we multiply them by 255
    # to get the RGB value range we're used to.
    r, g, b = [int(c * 255) for c in hsv_to_rgb(hue, 1.0, 1.0)]

    # We're just going to fill the whole screen with our colour.
    draw.rectangle((0, 0, 240, 240), (r, g, b))

    st7789.display(image)

    time.sleep(1.0 / 30)
