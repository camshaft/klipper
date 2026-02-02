# Non-Critical MCU Support

## Overview

This feature allows marking certain MCUs as "non-critical", meaning they can disconnect and reconnect without shutting down the printer. This is useful for MCUs that control non-essential components like door sensors, status displays, or other monitoring devices that shouldn't halt a print if they become temporarily unavailable.

## Configuration

To mark an MCU as non-critical, add the `is_non_critical` parameter to the MCU section:

```ini
[mcu door_sensor]
serial: /dev/ttyACM1
is_non_critical: True
reconnect_interval: 2.0
```

### Parameters

- `is_non_critical`: Boolean (default: False). Set to True to mark this MCU as non-critical.
- `reconnect_interval`: Float (default: 2.0). Time in seconds between reconnection attempts when the MCU is disconnected.

### Restrictions

- The primary MCU (named `mcu`) cannot be marked as non-critical
- Non-critical MCUs will automatically attempt to reconnect when disconnected
- Commands sent to a disconnected non-critical MCU will fail gracefully

## Use Cases

### Door Sensor Example

```ini
[mcu]
serial: /dev/ttyACM0

[mcu door_sensor]
serial: /dev/ttyACM1
is_non_critical: True

[output_pin door_status_led]
pin: door_sensor:PA1
value: 0
```

### Status Display Example

```ini
[mcu display_mcu]
serial: /dev/ttyACM2
is_non_critical: True
reconnect_interval: 3.0

[display]
lcd_type: uc1701
cs_pin: display_mcu:PA4
a0_pin: display_mcu:PA5
```

## Behavior

When a non-critical MCU disconnects:
1. A warning is logged indicating the MCU has disconnected
2. The print continues without interruption
3. Automatic reconnection attempts begin at the configured interval
4. Commands to the disconnected MCU will fail with an error message
5. Once reconnected, the MCU resumes normal operation

## Technical Details

- Disconnections are detected through timeout or explicit shutdown messages
- The reconnection logic runs in a background timer
- Clock synchronization is automatically re-established on reconnection
- MCU state is preserved as much as possible during disconnection
