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
  in {
    #####################################################################
    #   Packages
    #####################################################################

    packages = forAllSystems (
      system: let
        # Create pkgs with overlay applied
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
      in {
        default = pkgs.klippy;

        # Granular klippy packages
        inherit (pkgs) klippy klippy-bin klippy-chelper klippy-python;

        # Source packages
        klipper-src = pkgs.klipper-src.full;

        # Firmware (pre-built host MCU firmware)
        inherit (pkgs) klipper-host-firmware;

        # Katapult bootloader and flashing scripts
        inherit (pkgs) katapult katapult-scripts;

        # Utilities
        inherit (pkgs) klipper-genconf;

        # Note: klipper-firmware, katapult-firmware (builder functions),
        # and klipperFormat (attribute set) are available via the overlay
        # but are not derivations, so they cannot be exposed as packages.
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
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (self.lib.mkOverlay {inherit plugins extraPythonPackages;})
          ];
        };
      in
        pkgs.klippy;

      # Build klipper MCU firmware
      mkFirmware = {
        system,
        mcu ? "mcu",
        firmwareConfig,
      }: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
      in
        pkgs.klipper-firmware {inherit mcu firmwareConfig;};

      # Build katapult bootloader firmware
      mkKatapultFirmware = {
        system,
        mcu ? "mcu",
        firmwareConfig,
      }: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
      in
        pkgs.katapult-firmware {inherit mcu firmwareConfig;};

      # Generate a flash script for a single MCU
      mkFlashScript = {system, ...} @ args: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
      in
        pkgs.mkFlashScript (builtins.removeAttrs args ["system"]);

      # Generate flash scripts for multiple MCUs
      mkFlashScripts = {
        system,
        mcus,
      }: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
      in
        pkgs.mkFlashScripts mcus;

      # Create a Klipper-compatible INI format for a given pkgs set
      mkKlipperFormat = pkgs:
        import ./nix/format.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

      # Build klipper host MCU firmware (Linux process MCU)
      mkHostFirmware = {
        system,
        firmwareConfig ? null,
      }: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
        defaultConfig = pkgs.writeText "host-mcu-klipper.config" ''
          CONFIG_LOW_LEVEL_OPTIONS=y
          CONFIG_MACH_LINUX=y
        '';
      in
        pkgs.klipper-firmware {
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
        pkgs = import nixpkgs {
          inherit system;
          overlays = [rust-overlay.overlays.default];
        };
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
              echo "     klipper-console            - MCU debugging console"
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
