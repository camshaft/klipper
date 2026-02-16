# Klipper overlay
#
# Adds klipper-src, klippy (with granular sub-packages), firmware builders,
# katapult, flash script generators, klipper-genconf, and klipperFormat.
#
# Granular build structure with filtered sources:
#   klipper-src.rust     - Only Rust sources (Cargo.*, src/, crates/)
#   klipper-src.chelper  - Only C extension sources (klippy/chelper/)
#   klipper-src.python   - Only Python sources (klippy/*.py, scripts/, etc.)
#   klipper-src.firmware - Only firmware sources (src/, lib/, Makefile, etc.)
#   klipper-src.full     - Full source (for klipper-genconf)
#
# Each filtered source only includes files needed for that build, so:
#   - Changing nix/ won't rebuild firmware
#   - Changing klippy/*.py won't rebuild Rust binary
#   - Changing src/*.c won't rebuild chelper
#
# Klippy packages:
#   klippy-bin     - Rust binary only (expensive, ~2min)
#   klippy-chelper - C extension modules (moderate, ~1min)
#   klippy-python  - Python sources (fast, just copies)
#   klippy         - Assembled klippy (fast, links above)
#
# Plugins are installed via klippy.withPlugins [...] which is very fast
# since it only creates symlinks - no rebuilding of klippy components!
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

  # Filtered source packages - each only includes what it needs
  klipperSrc = final.callPackage ./source.nix {
    src = self;
  };
in {
  # Filtered klipper sources for granular rebuilds
  klipper-src = klipperSrc;

  #####################################################################
  # Granular klippy packages
  #
  # Each uses a filtered source so changes to unrelated files don't
  # trigger rebuilds.
  #####################################################################

  # Rust binary - most expensive to build (~2min)
  # Only rebuilds when Cargo.*, src/, or crates/ change
  klippy-bin = final.callPackage ./klippy/bin.nix {
    inherit craneLib;
    klipper-src = klipperSrc.rust;
  };

  # Chelper C extensions (~1min)
  # Only rebuilds when klippy/chelper/ changes
  klippy-chelper = final.callPackage ./klippy/chelper.nix {
    klipper-src = klipperSrc.chelper;
  };

  # Python sources (fast - just copies)
  # Only rebuilds when klippy/*.py, scripts/, docs/, config/ change
  klippy-python = final.callPackage ./klippy/python.nix {
    klipper-src = klipperSrc.python;
  };

  # Assembled klippy (fast - links components)
  # Use klippy.withPlugins [...] to add plugins without rebuilding!
  klippy = let
    base = final.callPackage ./klippy {
      inherit extraPythonPackages;
      inherit (final) klippy-bin klippy-chelper klippy-python;
    };
  in
    if plugins == []
    then base
    else base.withPlugins plugins;

  # Override the nixpkgs klipper package with ours
  klipper = final.klippy;

  # Klipper MCU firmware builder
  # Only rebuilds when src/, lib/, Makefile, or scripts/kconfig change
  klipper-firmware = final.callPackage ./firmware.nix {
    klipper-src = klipperSrc.firmware;
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
  # Made overridable so nixpkgs klipper module can call:
  #   pkgs.klipper-genconf.override { klipper = cfg.package; }
  # The `klipper` argument is accepted but ignored since we always
  # use klipper-src for menuconfig (which matches our klippy build).
  klipper-genconf = final.lib.makeOverridable (
    {klipper ? final.klippy}:
      assert klipper != null;
        final.writeShellApplication {
          name = "klipper-genconf";
          runtimeInputs = with final; [python3 gnumake];
          text = ''
            CURRENT_DIR=$(pwd)
            TMP=$(mktemp -d)
            make -C ${klipperSrc.full} OUT="$TMP" KCONFIG_CONFIG="$CURRENT_DIR/config" menuconfig
            rm -rf "$TMP" config.old
            printf "\nYour firmware configuration for klipper:\n\n"
            cat config
          '';
        }
  ) {};

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

  # Build klipper host MCU firmware (Linux process MCU)
  #
  # The host MCU runs as a Linux process and exposes host GPIO
  # to klipper via /tmp/klipper_host_mcu.
  klipper-host-firmware = let
    defaultConfig = final.writeText "host-mcu-klipper.config" ''
      CONFIG_LOW_LEVEL_OPTIONS=y
      CONFIG_MACH_LINUX=y
    '';
  in
    final.klipper-firmware {
      mcu = "host";
      firmwareConfig = defaultConfig;
    };
}
