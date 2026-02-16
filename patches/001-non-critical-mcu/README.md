# Non-Critical MCU Support

## Overview

This patch adds support for marking MCUs as "non-critical" (by setting `is_critical: False`), meaning they can disconnect and reconnect without shutting down the printer. This is useful for MCUs that control non-essential components like door sensors, status displays, or other monitoring devices that shouldn't halt a print if they become temporarily unavailable.

## Problem

In standard Klipper, any MCU disconnection or timeout results in an immediate printer shutdown. This is appropriate for critical components (steppers, heaters, etc.), but overly strict for monitoring devices. Users need a way to mark certain MCUs as optional so prints can continue even if they disconnect.

## Solution

This patch adds a new `is_critical` configuration parameter (defaults to True) for MCU sections. Non-critical MCUs (is_critical: False) can:
- Disconnect without halting the printer
- Automatically attempt reconnection at a configurable interval
- Send events to the UI when they disconnect/reconnect

## Configuration

To mark an MCU as non-critical, set `is_critical: False`:

```ini
[mcu door_sensor]
serial: /dev/ttyACM1
is_critical: False
reconnect_interval: 2.0
```

### Parameters

- `is_critical`: Boolean (default: True). Set to False to mark this MCU as non-critical.
- `reconnect_interval`: Float (default: 2.0). Time in seconds between reconnection attempts when the MCU is disconnected.

### Restrictions

- The primary MCU (named `mcu`) must always be critical
- Non-critical MCUs will automatically attempt to reconnect when disconnected
- Commands sent to a disconnected non-critical MCU will fail gracefully

## Use Cases

### Door Sensor Example

```ini
[mcu]
serial: /dev/ttyACM0

[mcu door_sensor]
serial: /dev/ttyACM1
is_critical: False

[output_pin door_status_led]
pin: door_sensor:PA1
value: 0
```

### Status Display Example

```ini
[mcu display_mcu]
serial: /dev/ttyACM2
is_critical: False
reconnect_interval: 3.0

[display]
lcd_type: uc1701
cs_pin: display_mcu:PA4
a0_pin: display_mcu:PA5
```

## Behavior

When a non-critical MCU disconnects:
1. A warning is logged indicating the MCU has disconnected
2. An event is sent to notify the UI (klippy:mcu_disconnected)
3. The print continues without interruption
4. Automatic reconnection attempts begin at the configured interval
5. Commands to the disconnected MCU will fail with an error message
6. Once reconnected, the MCU resumes normal operation and an event is sent (klippy:mcu_reconnected)

## Technical Details

- Disconnections are detected through timeout or explicit shutdown messages
- The reconnection logic runs in a background timer
- Clock synchronization is automatically re-established on reconnection
- MCU state is preserved as much as possible during disconnection
- Events are sent via `printer.send_event()` for UI integration

## Files Modified

- `klippy/mcu.py`: Core MCU class with is_critical support
- `klippy/clocksync.py`: Added disconnect() method for clean disconnection

## Reference

Based on similar functionality in Kalico (formerly Danger Klipper), specifically PR #339, adapted for current Klipper architecture.
