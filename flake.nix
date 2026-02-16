{
  description = "Klipper 3D printer firmware - Rust + Python host software";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    crane.url = "github:ipetkov/crane";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Katapult bootloader for MCU firmware updates
    katapult = {
      url = "github:Arksine/katapult/master";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    rust-overlay,
    katapult,
    ...
  }: let
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Create pkgs + craneLib for a given system
    mkPkgs = system:
      import nixpkgs {
        inherit system;
        overlays = [rust-overlay.overlays.default];
      };

    mkCraneLib = system: let
      pkgs = mkPkgs system;
      rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
    in
      (crane.mkLib pkgs).overrideToolchain rustToolchain;
  in {
    #####################################################################
    #   Packages
    #####################################################################

    packages = forAllSystems (
      system: let
        pkgs = mkPkgs system;
        craneLib = mkCraneLib system;

        katapultPkgs = pkgs.callPackage ./nix/katapult.nix {
          katapult-src = katapult;
        };
      in {
        default = self.packages.${system}.klippy;

        klippy = pkgs.callPackage ./nix/klippy.nix {
          inherit craneLib;
          klipper-src = self.packages.${system}.klipper-src;
        };

        klipper-src = pkgs.callPackage ./nix/source.nix {
          src = self;
        };

        # Katapult bootloader and flashing scripts
        inherit (katapultPkgs) katapult scripts;
        katapult-scripts = katapultPkgs.scripts;
      }
    );

    #####################################################################
    #   Overlay
    #
    #   Usage from a consuming flake:
    #     nixpkgs.overlays = [ klipper.overlays.default ];
    #####################################################################

    overlays.default = nixpkgs.lib.composeManyExtensions [
      rust-overlay.overlays.default
      (import ./nix/overlay.nix {
        inherit self;
        craneMkLib = crane.mkLib;
        katapult-src = katapult;
      })
    ];

    #####################################################################
    #   Library functions for downstream consumers
    #
    #   Usage:
    #     klipper.lib.mkOverlay {
    #       plugins = [
    #         { name = "led-effect"; src = led-effect-src; files = [ "src/led_effect.py" ]; }
    #         { name = "tmc-autotune"; src = tmc-src; files = [ "autotune_tmc.py" "motor_constants.py" "motor_database.cfg" ]; }
    #       ];
    #     }
    #####################################################################

    lib = {
      # Create an overlay with custom plugins
      #
      # System-agnostic: the overlay derives architecture from the
      # consumer's pkgs. No need to specify system.
      mkOverlay = {
        plugins ? [],
        extraPythonPackages ? ps: [],
      }:
        nixpkgs.lib.composeManyExtensions [
          rust-overlay.overlays.default
          (import ./nix/overlay.nix {
            inherit self plugins extraPythonPackages;
            craneMkLib = crane.mkLib;
            katapult-src = katapult;
          })
        ];

      # Build klippy with custom plugins for a specific system
      mkKlippy = {
        system,
        plugins ? [],
        extraPythonPackages ? ps: [],
      }: let
        pkgs = mkPkgs system;
        craneLib = mkCraneLib system;
      in
        pkgs.callPackage ./nix/klippy.nix {
          inherit craneLib plugins extraPythonPackages;
          klipper-src = self.packages.${system}.klipper-src;
        };

      # Build klipper MCU firmware
      mkFirmware = {
        system,
        mcu ? "mcu",
        firmwareConfig,
      }: let
        pkgs = mkPkgs system;
      in
        (pkgs.callPackage ./nix/firmware.nix {
          klipper-src = self.packages.${system}.klipper-src;
        }) {inherit mcu firmwareConfig;};

      # Build katapult bootloader firmware
      mkKatapultFirmware = {
        system,
        mcu ? "mcu",
        firmwareConfig,
      }: let
        pkgs = mkPkgs system;
      in
        (pkgs.callPackage ./nix/katapult-firmware.nix {
          katapult-src = katapult;
        }) {inherit mcu firmwareConfig;};

      # Generate a flash script for a single MCU
      #
      # Produces a derivation with bin/flash-<name> (and optionally
      # bin/flash-<name>-bootloader if katapultFirmwareConfig is set).
      #
      # Usage:
      #   klipper.lib.mkFlashScript {
      #     name = "leviathan";
      #     firmwareConfig = ./boards/leviathan.config;
      #     device = { type = "can"; id = "abc123def"; };
      #     useKatapult = true;
      #     # katapultFirmwareConfig = ./boards/leviathan-katapult.config;
      #   }
      mkFlashScript = {system, ...} @ args: let
        pkgs = mkPkgs system;
        craneLib = mkCraneLib system;
        flashLib = pkgs.callPackage ./nix/flash.nix {
          klippy = pkgs.callPackage ./nix/klippy.nix {
            inherit craneLib;
            klipper-src = self.packages.${system}.klipper-src;
          };
          katapult-scripts =
            (pkgs.callPackage ./nix/katapult.nix {
              katapult-src = katapult;
            })
            .scripts;
          klipper-firmware = pkgs.callPackage ./nix/firmware.nix {
            klipper-src = self.packages.${system}.klipper-src;
          };
          katapult-firmware = pkgs.callPackage ./nix/katapult-firmware.nix {
            katapult-src = katapult;
          };
        };
      in
        flashLib.mkFlashScript (builtins.removeAttrs args ["system"]);

      # Generate flash scripts for multiple MCUs
      #
      # Produces a combined derivation with flash scripts for all MCUs.
      #
      # Usage:
      #   klipper.lib.mkFlashScripts {
      #     mcus = [
      #       { name = "leviathan"; firmwareConfig = ./boards/leviathan.config;
      #         device = { type = "can"; id = "abc123"; }; useKatapult = true; }
      #       { name = "chamber"; firmwareConfig = ./boards/chamber.config;
      #         device = { type = "can"; id = "def456"; }; useKatapult = true; }
      #     ];
      #   }
      mkFlashScripts = {
        system,
        mcus,
      }: let
        pkgs = mkPkgs system;
        craneLib = mkCraneLib system;
        flashLib = pkgs.callPackage ./nix/flash.nix {
          klippy = pkgs.callPackage ./nix/klippy.nix {
            inherit craneLib;
            klipper-src = self.packages.${system}.klipper-src;
          };
          katapult-scripts =
            (pkgs.callPackage ./nix/katapult.nix {
              katapult-src = katapult;
            })
            .scripts;
          klipper-firmware = pkgs.callPackage ./nix/firmware.nix {
            klipper-src = self.packages.${system}.klipper-src;
          };
          katapult-firmware = pkgs.callPackage ./nix/katapult-firmware.nix {
            katapult-src = katapult;
          };
        };
      in
        flashLib.mkFlashScripts mcus;

      # Create a Klipper-compatible INI format for a given pkgs set
      #
      # The standard pkgs.formats.ini is broken for Klipper:
      #   - Booleans: "true"/"false" instead of "True"/"False"
      #   - No multiline gcode support
      #   - Wrong separator ("=" instead of ":")
      #
      # Usage in a NixOS module:
      #   format = klipper.lib.mkKlipperFormat pkgs;
      mkKlipperFormat = pkgs:
        import ./nix/format.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

      # Build klipper host MCU firmware (Linux process MCU)
      #
      # The host MCU runs as a Linux process and exposes host GPIO
      # to klipper via /tmp/klipper_host_mcu.
      #
      # Usage:
      #   klipper.lib.mkHostFirmware { }
      #   klipper.lib.mkHostFirmware { firmwareConfig = ./my-host.config; }
      mkHostFirmware = {
        system,
        firmwareConfig ? null,
      }: let
        pkgs = mkPkgs system;
        defaultConfig = pkgs.writeText "host-mcu-klipper.config" ''
          CONFIG_LOW_LEVEL_OPTIONS=y
          CONFIG_MACH_LINUX=y
        '';
      in
        (pkgs.callPackage ./nix/firmware.nix {
          klipper-src = self.packages.${system}.klipper-src;
        }) {
          mcu = "host";
          firmwareConfig =
            if firmwareConfig != null
            then firmwareConfig
            else defaultConfig;
        };
    };

    #####################################################################
    #   NixOS Modules
    #####################################################################

    nixosModules = {
      # Klipper host MCU service
      #
      # Runs a klipper_mcu Linux process that exposes host GPIO.
      #
      # Usage:
      #   imports = [ klipper.nixosModules.host-mcu ];
      #   services.klipper-mcu.enable = true;
      host-mcu = ./nix/host-mcu.nix;
    };

    #####################################################################
    #   Dev Shell
    #####################################################################

    devShells = forAllSystems (
      system: let
        pkgs = mkPkgs system;
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

        pythonEnv = pkgs.python3.withPackages (ps:
          with ps;
            [
              # Runtime dependencies
              cffi
              greenlet
              jinja2
              markupsafe
              numpy
              pyserial
              python-can
              # Dev/test dependencies
              matplotlib
              scipy
            ]
            ++ pkgs.lib.optionals (pkgs.lib.versionAtLeast pkgs.python3.version "3.9") [
              msgspec
            ]);
      in {
        default = pkgs.mkShell {
          name = "klipper-dev";

          nativeBuildInputs = [
            # Rust
            rustToolchain

            # Python
            pythonEnv
            pkgs.uv

            # C toolchain (for chelper and firmware)
            pkgs.gcc
            pkgs.gnumake
            pkgs.pkg-config

            # Nix tools
            pkgs.nil
            pkgs.nixfmt

            # Utilities
            pkgs.git
          ];

          # pyo3 build configuration
          PYO3_PYTHON = "${pythonEnv.interpreter}";
          LD_LIBRARY_PATH = "${pkgs.python3}/lib";
          PYTHONPATH = "klippy";

          shellHook = ''
            echo "🖨️  Klipper dev shell"
            echo "   Rust:   $(rustc --version)"
            echo "   Python: $(python3 --version)"
            echo "   uv:     $(uv --version)"
            echo ""
            echo "   cargo build        - Build the Rust klippy binary"
            echo "   nix build          - Build the full klippy package"
            echo "   nix flake check    - Run flake checks"
          '';
        };

        # Fully-built runtime shell
        #
        # Everything is pre-compiled and installed — the Rust binary,
        # chelper, Python deps, utility scripts, and katapult tools.
        #
        # Usage:
        #   nix develop .#runtime
        runtime = let
          klippy = self.packages.${system}.klippy;
          katapultScripts = self.packages.${system}.katapult-scripts;
        in
          pkgs.mkShell {
            name = "klipper-runtime";

            packages = [
              klippy
              katapultScripts
              klippy.pythonEnv

              # Nix tools
              pkgs.nil
              pkgs.nixfmt

              # Utilities
              pkgs.git
              pkgs.can-utils
            ];

            shellHook = ''
              echo "🖨️  Klipper runtime shell"
              echo "   Python:   $(python3 --version)"
              echo ""
              echo "   Available commands:"
              echo "     klipper                    - Run klipper"
              echo "     klipper-calibrate-shaper   - Calibrate input shaper"
              echo "     klipper-canbus-query       - Query CAN bus devices"
              echo "     klipper-flash-can           - Flash firmware via CAN"
              echo "     katapult-flash             - Flash via katapult"
              echo "     katapult-flash-can          - Flash via katapult CAN"
            '';
          };
      }
    );

    #####################################################################
    #   Checks
    #####################################################################

    checks = forAllSystems (system: {
      # Verify the package builds
      klippy = self.packages.${system}.klippy;
      klipper-src = self.packages.${system}.klipper-src;
    });
  };
}
