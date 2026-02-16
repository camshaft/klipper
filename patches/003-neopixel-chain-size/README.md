# Neopixel Chain Size Patch

## Purpose

Increases the maximum neopixel chain size from 500 to 768 bytes.

## Problem

The default `MAX_MCU_SIZE = 500` in `klippy/extras/neopixel.py` limits the
total bytes that can be sent to a neopixel chain. This restricts:

- RGB strips (3 bytes/LED): 166 LEDs max
- RGBW strips (4 bytes/LED): 125 LEDs max

Many chamber lighting applications use 144 LED RGBW strips (SK6812), which
require 576 bytes (144 × 4), exceeding the default limit.

## Solution

Increase `MAX_MCU_SIZE` to 768 bytes, allowing:

- RGB strips: 256 LEDs max
- RGBW strips: 192 LEDs max

## Affected Files

- `klippy/extras/neopixel.py`

## Notes

This is a host-side limit only. The MCU firmware does not have a hardcoded
limit - it allocates memory based on the `data_size` parameter sent during
configuration.
