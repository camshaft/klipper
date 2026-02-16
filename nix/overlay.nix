# Klipper overlay
#
# Adds klipper-src, klippy, firmware builders, katapult, flash script
# generators, klipper-genconf, and klipperFormat to nixpkgs.
#
# System-agnostic: craneLib is constructed from `final` (the consumer's
# pkgs), so this overlay works on any architecture. Requires rust-overlay
# to be applied first (composeManyExtensions handles this automatically
# when using overlays.default or lib.mkOverlay).
#
# Usage from a consuming flake:
#   overlays = [ klipper.overlays.default ];
#   # or with plugins:
#   overlays = [
#     (klipper.lib.mkOverlay {
#       plugins = [
#         { name = "led-effect"; src = klipper-led-effect; files = [ "src/led_effect.py" ]; }
#       ];
#     })
#   ];
{
  self,
  craneMkLib,
  katapult-src,
  plugins ? [],
  extraPythonPackages ? ps: [],
}: final: prev: let
  # Construct craneLib from final — inherits the consumer's system
  rustToolchain = final.rust-bin.fromRustupToolchainFile (self + "/rust-toolchain.toml");
  craneLib = (craneMkLib final).overrideToolchain rustToolchain;

  katapultPkgs = final.callPackage ./katapult.nix {
    inherit katapult-src;
  };
in {
  # Patched klipper source (for firmware builds and klippy)
  klipper-src = final.callPackage ./source.nix {
    src = self;
  };

  # Klippy host software (Rust + Python)
  klippy = final.callPackage ./klippy.nix {
    inherit craneLib plugins extraPythonPackages;
    klipper-src = final.klipper-src;
  };

  # Override the nixpkgs klipper package with ours
  klipper = final.klippy;

  # Klipper MCU firmware builder
  klipper-firmware = final.callPackage ./firmware.nix {
    klipper-src = final.klipper-src;
  };

  # Katapult bootloader package and flashing scripts
  katapult = katapultPkgs.katapult;
  katapult-scripts = katapultPkgs.scripts;

  # Katapult bootloader firmware builder
  katapult-firmware = final.callPackage ./katapult-firmware.nix {
    inherit katapult-src;
  };

  # Flash script generators
  #
  # mkFlashScript: Generate a flash script for a single MCU
  # mkFlashScripts: Generate flash scripts for multiple MCUs
  #
  # Usage:
  #   pkgs.mkFlashScript {
  #     name = "leviathan";
  #     firmwareConfig = ./klipper.config;
  #     device = { type = "can"; id = "abc123def"; };
  #     useKatapult = true;
  #   }
  inherit
    (final.callPackage ./flash.nix {
      inherit (final) klippy katapult-scripts klipper-firmware katapult-firmware;
    })
    mkFlashScript
    mkFlashScripts
    ;

  # Fixed klipper-genconf that uses our patched source
  #
  # The nixpkgs klipper-genconf uses `klipper.src` which doesn't work
  # with our custom klippy package. This override points directly at
  # our patched source tree so `make menuconfig` works.
  klipper-genconf = final.writeShellApplication {
    name = "klipper-genconf";
    runtimeInputs = with final; [python3 gnumake];
    text = ''
      CURRENT_DIR=$(pwd)
      TMP=$(mktemp -d)
      make -C ${final.klipper-src} OUT="$TMP" KCONFIG_CONFIG="$CURRENT_DIR/config" menuconfig
      rm -rf "$TMP" config.old
      printf "\nYour firmware configuration for klipper:\n\n"
      cat config
    '';
  };

  # Klipper-specific INI format for printer.cfg generation
  #
  # Drop-in replacement for pkgs.formats.ini that handles:
  #   - Python-style booleans (True/False instead of true/false)
  #   - Multiline gcode values with proper indentation
  #   - Colon separator (:) instead of equals (=)
  #
  # Usage in a NixOS module:
  #   format = pkgs.klipperFormat;
  klipperFormat = import ./format.nix {
    inherit (final) lib;
    pkgs = final;
  };
}
