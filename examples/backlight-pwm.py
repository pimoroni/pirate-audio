#!/usr/bin/env python

import time
import math
import RPi.GPIO as GPIO
from ST7789 import ST7789
from PIL import Image, ImageDraw


print("""backlight-pwm.py - Demonstrate the backlight being controlled by PWM
 
This advanced example shows you how to achieve a variable backlight
brightness using PWM.

Instead of providing a backlight pin to ST7789, we set it up using
RPi.GPIO's PWM functionality with a fixed frequency and adjust the
duty cycle to change brightness.

Press Ctrl+C to exit!
""")

SPI_SPEED_MHZ = 90

# Give us an image buffer to draw into
image = Image.new("RGB", (240, 240), (255, 0, 255))
draw = ImageDraw.Draw(image)

# Standard display setup for Pirate Audio, except we omit the backlight pin
st7789 = ST7789(
    rotation=90,     # Needed to display the right way up on Pirate Audio
    port=0,          # SPI port
    cs=1,            # SPI port Chip-select channel
    dc=9,            # BCM pin used for data/command
    backlight=None,  # We'll control the backlight ourselves
    spi_speed_hz=SPI_SPEED_MHZ * 1000 * 1000
)

GPIO.setmode(GPIO.BCM)

# We must set the backlight pin up as an output first
GPIO.setup(13, GPIO.OUT)

# Set up our pin as a PWM output at 500Hz
backlight = GPIO.PWM(13, 500)

# Start the PWM at 100% duty cycle
backlight.start(100)

while True:
    # Using math.sin() we can convert the linear progression of time into
    # a sine wave, shift it up by +1 to eliminate the negative component
    # and divide by two to give us a range of 0.0 - 1.0 which we can then
    # multiply by 100 to get our duty cycle percentage.
    # Of course - this is purely for this demonstration and you'll likely
    # do something much simpler to pick your brightness!
    brightness = ((math.sin(time.time()) + 1) / 2.0) * 100
    backlight.ChangeDutyCycle(brightness)

    draw.rectangle((0, 0, 240, 240), (255, 0, 255))

    # Draw a handy on-screen bar to show us the current brightness
    bar_width = int((220 / 100.0) * brightness)
    draw.rectangle((10, 220, 10 + bar_width, 230), (255, 255, 255))
    
    # Display the resulting image
    st7789.display(image)
    time.sleep(1.0 / 30)

backlight.stop()
