# Klipper Patches Directory

This directory contains patches and modifications to the Klipper firmware to add additional features that are not yet in upstream Klipper.

## Purpose

The patches directory allows us to:
1. Easily track changes we've made to Klipper
2. Pull in updates from upstream Klipper while preserving our modifications
3. Maintain a clear separation between upstream code and our custom features
4. Document the rationale for each modification

## Current Patches

### Non-Critical MCU Support

**Files Modified:**
- `klippy/mcu.py`
- `klippy/clocksync.py`

**Description:**
Adds support for marking MCUs as non-critical, allowing them to disconnect and reconnect without shutting down the printer. This is useful for door sensors, status displays, and other monitoring devices that shouldn't halt a print if they become temporarily unavailable.

**Configuration:**
```ini
[mcu sensor]
serial: /dev/ttyACM1
is_non_critical: True
reconnect_interval: 2.0
```

**Reference:**
Based on similar functionality in Kalico (formerly Danger Klipper), specifically PR #339.

## Future Patches

Additional features can be added as patches in this directory. Each patch should include:
- Clear documentation of what it changes
- Configuration examples
- Test cases if applicable
- Reference to any upstream discussions or related implementations

## Applying Patches

Currently, patches are integrated directly into the source code. Future improvements may include:
- Automated patch application during installation
- Git patch files for easier maintenance
- CI/CD integration to verify patches apply cleanly

## Contributing

When adding new patches:
1. Document the feature in a markdown file in the `docs/` directory
2. Update this README with patch details
3. Add example configurations
4. Test thoroughly before committing
