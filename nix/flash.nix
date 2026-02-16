# MCU firmware flash script generator
#
# Generates per-MCU shell scripts that flash klipper firmware (and
# optionally katapult bootloader firmware) to MCU boards.
#
# Supports two flash methods:
#   - katapult: Uses katapult's flashtool.py (recommended)
#   - klipper:  Uses klipper's flash_can.py or flash_usb.py
#
# And two device transport types:
#   - can:    CAN bus (requires uuid, optional interface defaulting to can0)
#   - serial: USB serial (requires path like /dev/serial/by-id/...)
#
# Usage:
#   mkFlashScript {
#     name = "leviathan";
#     firmwareConfig = ./klipper.config;
#     device = { type = "can"; id = "abc123def"; };
#     useKatapult = true;
#   }
#
#   => derivation with bin/flash-leviathan
#
# If katapultFirmwareConfig is also provided, additionally produces
# bin/flash-leviathan-bootloader for initial katapult setup.
{
  lib,
  symlinkJoin,
  writeShellApplication,
  klippy,
  katapult-scripts,
  klipper-firmware,
  katapult-firmware ? null,
}: let
  #####################################################################
  #   mkFlashScript - single MCU flash script
  #####################################################################
  mkFlashScript = {
    # Human-readable MCU name (used in script name and messages)
    name,
    # Path to klipper firmware .config file
    firmwareConfig,
    # Device transport: { type = "can"|"serial"; id = "..."; interface? = "can0"; }
    device,
    # Flash method: true = katapult flashtool, false = klipper flash scripts
    useKatapult ? true,
    # Optional katapult bootloader .config (produces a -bootloader script)
    katapultFirmwareConfig ? null,
  }: let
    # Build the klipper firmware for this MCU
    firmware = klipper-firmware {
      mcu = name;
      inherit firmwareConfig;
    };

    # Build katapult bootloader firmware if config provided
    bootloaderFirmware =
      if katapultFirmwareConfig != null
      then
        assert katapult-firmware != null;
          katapult-firmware {
            mcu = name;
            firmwareConfig = katapultFirmwareConfig;
          }
      else null;

    # The flash tool and arguments for klipper firmware
    flashCmd =
      if device.type == "can"
      then
        if useKatapult
        then
          # katapult flashtool: -i <interface> -u <uuid> -f <firmware>
          ''            ${katapult-scripts}/bin/katapult-flash \
                          -i "${device.interface or "can0"}" \
                          -u "${device.id}" \
                          -f "${firmware}/klipper.bin"''
        else
          # klipper flash_can: -i <interface> -u <uuid> -f <firmware>
          ''            ${klippy}/bin/klipper-flash-can \
                          -i "${device.interface or "can0"}" \
                          -u "${device.id}" \
                          -f "${firmware}/klipper.bin"''
      else if device.type == "serial"
      then
        if useKatapult
        then
          # katapult flashtool: -d <device> -f <firmware>
          ''            ${katapult-scripts}/bin/katapult-flash \
                          -d "${device.id}" \
                          -f "${firmware}/klipper.bin"''
        else
          # klipper flash_usb via the wrapper we install in klippy
          ''            ${klippy}/bin/klipper-flash-can \
                          -d "${device.id}" \
                          -f "${firmware}/klipper.bin"''
      else throw "flash.nix: unsupported device type '${device.type}' for MCU '${name}'. Use 'can' or 'serial'.";

    # The flash tool and arguments for katapult bootloader
    bootloaderFlashCmd =
      if device.type == "can"
      then ''        ${katapult-scripts}/bin/katapult-flash \
                    -i "${device.interface or "can0"}" \
                    -u "${device.id}" \
                    -f "${bootloaderFirmware}/katapult.bin"''
      else ''        ${katapult-scripts}/bin/katapult-flash \
                    -d "${device.id}" \
                    -f "${bootloaderFirmware}/katapult.bin"'';

    deviceDesc =
      if device.type == "can"
      then "${device.interface or "can0"}:${device.id}"
      else device.id;

    # Main flash script
    flashScript = writeShellApplication {
      name = "flash-${name}";
      text = ''
        echo "🔧 Flashing klipper firmware to ${name} (${device.type}: ${deviceDesc})..."
        echo "   Firmware: ${firmware}"
        echo "   Method:   ${
          if useKatapult
          then "katapult"
          else "klipper"
        }"
        echo ""
        ${flashCmd}
        echo ""
        echo "✅ ${name} firmware flashed successfully"
      '';
    };

    # Optional bootloader flash script
    bootloaderScript = lib.optionalAttrs (bootloaderFirmware != null) {
      bootloader = writeShellApplication {
        name = "flash-${name}-bootloader";
        text = ''
          echo "🔧 Flashing katapult bootloader to ${name} (${device.type}: ${deviceDesc})..."
          echo "   Firmware: ${bootloaderFirmware}"
          echo ""
          ${bootloaderFlashCmd}
          echo ""
          echo "✅ ${name} katapult bootloader flashed successfully"
        '';
      };
    };

    allScripts =
      [flashScript]
      ++ lib.optional (bootloaderFirmware != null) bootloaderScript.bootloader;
  in
    symlinkJoin {
      name = "flash-scripts-${name}";
      paths = allScripts;

      passthru = {
        # Expose individual scripts for fine-grained access
        inherit flashScript;
        inherit (bootloaderScript) bootloader;
        # Expose firmware derivations
        inherit firmware;
        inherit bootloaderFirmware;
      };

      meta = {
        description = "Flash scripts for ${name} MCU (${device.type}, ${
          if useKatapult
          then "katapult"
          else "klipper"
        })";
        license = lib.licenses.gpl3Only;
        platforms = lib.platforms.linux;
      };
    };

  #####################################################################
  #   mkFlashScripts - combine scripts for multiple MCUs
  #####################################################################
  mkFlashScripts = mcus:
    symlinkJoin {
      name = "flash-scripts";
      paths = map mkFlashScript mcus;

      passthru = {
        # Expose per-MCU script packages for fine-grained access
        scripts = lib.listToAttrs (map (mcu: {
            name = mcu.name;
            value = mkFlashScript mcu;
          })
          mcus);

        # Expose all firmware derivations
        firmwares = lib.listToAttrs (map (mcu: {
            name = mcu.name;
            value = (mkFlashScript mcu).firmware;
          })
          mcus);
      };

      meta = {
        description = "Flash scripts for all MCU boards";
        license = lib.licenses.gpl3Only;
        platforms = lib.platforms.linux;
      };
    };
in {
  inherit mkFlashScript mkFlashScripts;
}
