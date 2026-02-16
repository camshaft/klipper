# SET_LED COUNT Parameter Patch

## Purpose

Adds a `COUNT` parameter to the `SET_LED` command, allowing multiple
consecutive LEDs to be set to the same color in a single command.

## Problem

The default `SET_LED` command can only set:

- A single LED by index: `SET_LED LED=strip RED=1.0 INDEX=5`
- All LEDs at once: `SET_LED LED=strip RED=1.0`

There's no efficient way to set a range of LEDs (e.g., LEDs 1-10) without
either issuing multiple commands or setting the entire strip.

## Solution

Add a `COUNT` parameter that specifies how many consecutive LEDs to set,
starting from `INDEX`.

### Usage

```gcode
# Set LEDs 1-10 to red
SET_LED LED=strip RED=1.0 INDEX=1 COUNT=10

# Set LEDs 50-60 to blue
SET_LED LED=strip BLUE=1.0 INDEX=50 COUNT=11

# Single LED (default COUNT=1)
SET_LED LED=strip GREEN=1.0 INDEX=5

# All LEDs (COUNT ignored when INDEX not specified)
SET_LED LED=strip WHITE=0.5
```

## Affected Files

- `klippy/extras/led.py`

## Backwards Compatibility

Fully backwards compatible. The `COUNT` parameter defaults to 1, so
existing configurations and macros continue to work unchanged.
