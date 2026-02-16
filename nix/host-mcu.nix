# Klipper Host MCU — NixOS module
#
# Runs a klipper_mcu Linux process that exposes host GPIO pins to
# klipper via a Unix socket (/tmp/klipper_host_mcu).
#
# This lets klipper control GPIO on the host machine (e.g. Raspberry
# Pi) for things like ADXL345 accelerometers, neopixels, or fan
# control without a separate MCU board.
#
# Usage in a NixOS configuration (with the klipper overlay applied):
#
#   imports = [ klipper.nixosModules.host-mcu ];
#
#   services.klipper-mcu = {
#     enable = true;
#     # Optional: override the firmware config
#     # firmwareConfig = ./my-host-mcu.config;
#   };
#
# Then in your klipper printer.cfg:
#
#   [mcu host]
#   serial: /tmp/klipper_host_mcu
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.klipper-mcu;

  # Default firmware config for a Linux host MCU
  defaultFirmwareConfig = pkgs.writeText "host-mcu-klipper.config" ''
    CONFIG_LOW_LEVEL_OPTIONS=y
    CONFIG_MACH_LINUX=y
  '';

  # Build the host MCU firmware
  firmware = pkgs.klipper-firmware {
    mcu = "host";
    firmwareConfig = cfg.firmwareConfig;
  };
in {
  options.services.klipper-mcu = {
    enable = lib.mkEnableOption "Klipper host MCU process";

    firmwareConfig = lib.mkOption {
      type = lib.types.path;
      default = defaultFirmwareConfig;
      description = ''
        Path to the klipper firmware .config file for the host MCU.

        The default config builds a Linux process MCU, which is
        correct for most setups. Override this only if you need
        custom low-level options.
      '';
    };

    socket = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/klipper_host_mcu";
      description = ''
        Path to the Unix socket the host MCU listens on.

        This must match the `serial` value in your klipper
        `[mcu host]` section.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = firmware;
      defaultText = lib.literalExpression "klipper-firmware { mcu = \"host\"; }";
      description = ''
        The host MCU firmware package. Override this if you want
        to provide a pre-built firmware instead of building from
        firmwareConfig.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The host MCU service
    systemd.services.klipper-mcu = {
      description = "Klipper Host MCU";

      # Start before klipper so the socket is ready
      wantedBy = ["multi-user.target"];
      before = ["klipper.service"];

      serviceConfig = {
        ExecStart = "${cfg.package}/klipper.elf -r";
        Restart = "always";
        RestartSec = 10;

        # Hardening
        ProtectHome = true;
        ProtectSystem = "strict";
        PrivateTmp = false; # needs /tmp for the socket
        DeviceAllow = [
          # GPIO access
          "char-gpiochip rw"
          # SPI access (for accelerometers, etc.)
          "char-spidev rw"
          # I2C access
          "char-i2c rw"
        ];
        SupplementaryGroups = [
          "gpio"
          "spi"
          "i2c"
          "dialout"
        ];
      };
    };

    # Clean up stale socket on boot
    systemd.tmpfiles.rules = [
      "r! ${cfg.socket} - - - - -"
    ];
  };
}
