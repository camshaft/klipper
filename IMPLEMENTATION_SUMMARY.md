# Implementation Summary: Non-Critical MCU Support

## Overview

This implementation adds support for marking MCUs as "non-critical" in Klipper, allowing them to disconnect and reconnect without shutting down the printer. This feature is particularly useful for door sensors, status displays, and other monitoring devices that should not halt a print if they become temporarily unavailable.

## Changes Made

### 1. Core MCU Support (`klippy/mcu.py`)

**New Configuration Options:**
- `is_non_critical`: Boolean flag to mark an MCU as non-critical (default: False)
- `reconnect_interval`: Time in seconds between reconnection attempts (default: 2.0)

**New MCU Class Members:**
- `_is_non_critical`: Stores the non-critical status
- `_non_critical_disconnected`: Tracks current disconnection state
- `_reconnect_timer`: Timer for automatic reconnection attempts
- `_reconnect_interval`: Interval between reconnection attempts
- `_reactor`: Reference to the event reactor

**New Methods:**
- `is_non_critical()`: Returns whether the MCU is marked as non-critical
- `is_non_critical_disconnected()`: Returns current disconnection state
- `_reconnect_event()`: Timer callback that attempts to reconnect the MCU
- `_handle_non_critical_disconnect()`: Handles disconnection of non-critical MCU

**Modified Methods:**

In `MCUConnectHelper`:
- `_handle_shutdown()`: Skip shutdown notification for non-critical MCUs
- `_handle_starting()`: Skip spontaneous restart notification for non-critical MCUs
- `check_timeout()`: Handle timeouts differently for non-critical MCUs

### 2. Clock Synchronization Support (`klippy/clocksync.py`)

**New Class Constant:**
- `DISCONNECTED_QUERIES_PENDING = 999999`: Marker value for disconnected state

**New Methods:**
- `disconnect()`: Cleanly disconnects the clock synchronization by:
  - Setting queries_pending to DISCONNECTED_QUERIES_PENDING
  - Canceling the periodic get_clock timer

### 3. Documentation

**User Documentation (`docs/Non_Critical_MCU.md`):**
- Overview of the feature
- Configuration parameters and examples
- Use cases (door sensors, displays)
- Behavior during disconnect/reconnect
- Technical details

**Patches Documentation (`patches/README.md`):**
- Purpose of the patches directory
- Documentation of current patches
- Guidelines for future patches
- Reference to Kalico PR #339

### 4. Example Configuration

Created `test_non_critical_mcu.cfg` demonstrating:
- Primary MCU configuration
- Non-critical MCU configuration
- Example peripheral on non-critical MCU

## Technical Implementation Details

### Disconnection Flow

1. MCU timeout or shutdown message detected
2. `is_non_critical()` check determines if MCU is non-critical
3. For non-critical MCUs:
   - Log informational message
   - Call `_handle_non_critical_disconnect()`
   - Disconnect clocksync
   - Schedule reconnection timer
   - Return without invoking printer shutdown

### Reconnection Flow

1. Timer fires at configured interval
2. `_reconnect_event()` attempts to:
   - Reattach serial connection
   - Reconnect clock synchronization
   - Reset shutdown/timeout flags
   - Mark MCU as connected
3. On success: Log success and cancel timer
4. On failure: Log debug message and reschedule timer

### Safety Features

- Primary MCU cannot be marked as non-critical (enforced with config error)
- Proper exception handling during reconnection
- Clock sync properly disconnected to prevent stale data
- Automatic retry with configurable interval

## Testing Considerations

The implementation has been:
- Syntax checked with Python 3
- Code reviewed for best practices
- Security scanned with CodeQL (0 alerts)

For full testing, a physical setup with:
- Primary MCU (e.g., printer controller)
- Secondary MCU (e.g., door sensor)
- Ability to disconnect/reconnect the secondary MCU

Would be needed to verify:
- Reconnection works correctly
- Print continues during disconnection
- Commands to disconnected MCU fail gracefully
- Reconnection restores full functionality

## References

- Based on Kalico (formerly Danger Klipper) PR #339
- Adapted for current Klipper architecture
- Implements similar functionality with cleaner integration

## Future Enhancements

Possible improvements:
- Event hooks for disconnect/reconnect notifications
- Statistics tracking for connection reliability
- Configuration option to disable auto-reconnection
- Support for graceful degradation of features using the MCU
