# Filtered source derivations for granular rebuilds
#
# Each component gets its own filtered source that only includes the
# files it needs. This prevents unnecessary rebuilds - changing a nix
# file won't trigger a firmware rebuild, for example.
#
# Components:
#   klipper-src.rust     - Rust sources (Cargo.*, src/, crates/)
#   klipper-src.chelper  - C extension sources (klippy/chelper/)
#   klipper-src.python   - Python sources (klippy/*.py, scripts/, etc.)
#   klipper-src.firmware - Firmware build sources (src/, lib/, Makefile, etc.)
#   klipper-src.full     - Full source (for klipper-genconf, etc.)
{
  lib,
  stdenv,
  src,
}: let
  # Helper to create a filtered source
  mkFilteredSrc = {
    name,
    filter,
    patches ? [],
  }:
    stdenv.mkDerivation {
      pname = "klipper-src-${name}";
      version = "camshaft";

      src = lib.cleanSourceWith {
        inherit src filter;
        name = "klipper-${name}-source";
      };

      inherit patches;

      dontBuild = true;
      dontFixup = true;

      installPhase = ''
        runHook preInstall
        cp -r . $out
        runHook postInstall
      '';
    };

  # Patch files
  patchesDir = ../patches;
  nonCriticalMcuPatch = "${patchesDir}/001-non-critical-mcu/0001-non-critical-mcu.patch";
  neopixelChainPatch = "${patchesDir}/003-neopixel-chain-size/0001-neopixel-increase-MAX_MCU_SIZE-to-768.patch";
  setLedCountPatch = "${patchesDir}/004-set-led-count/0001-led-add-COUNT-parameter-to-SET_LED-command.patch";

  # Python patches (applied to klippy/*.py)
  pythonPatches = [
    nonCriticalMcuPatch
    neopixelChainPatch
    setLedCountPatch
  ];

  # Firmware patches (applied to src/*.c) - none currently
  firmwarePatches = [
  ];
in {
  # Rust sources - only Cargo files and Rust code
  # Changes to Python, firmware, or nix files won't trigger rebuilds
  rust = mkFilteredSrc {
    name = "rust";
    filter = path: type: let
      relPath = lib.removePrefix (toString src + "/") (toString path);
      # Include Cargo files at any level
      isCargoFile = lib.hasSuffix "Cargo.toml" relPath || lib.hasSuffix "Cargo.lock" relPath;
      # Include rust toolchain file
      isToolchain = relPath == "rust-toolchain.toml";
      # Include src/ and crates/ directories and their contents
      isSrcDir = relPath == "src" || lib.hasPrefix "src/" relPath;
      isCratesDir = relPath == "crates" || lib.hasPrefix "crates/" relPath;
      # For files, only include .rs files in src/crates
      isRustCode = (isSrcDir || isCratesDir) && (type == "directory" || lib.hasSuffix ".rs" relPath);
    in
      isCargoFile || isToolchain || isRustCode;
  };

  # Chelper sources - only the C extension code
  chelper = mkFilteredSrc {
    name = "chelper";
    filter = path: type: let
      relPath = lib.removePrefix (toString src + "/") (toString path);
      # Need klippy/ parent directory
      isKlippyDir = relPath == "klippy";
      # Include klippy/chelper/ and all contents
      isChelperDir = relPath == "klippy/chelper" || lib.hasPrefix "klippy/chelper/" relPath;
    in
      isKlippyDir || isChelperDir;
  };

  # Python sources - klippy Python code, scripts, docs, config
  # Excludes chelper (that's separate), firmware (src/), and nix files
  python = mkFilteredSrc {
    name = "python";
    patches = pythonPatches;
    filter = path: type: let
      relPath = lib.removePrefix (toString src + "/") (toString path);
      isKlippyFile = lib.hasPrefix "klippy/" relPath;
      isChelperFile = lib.hasPrefix "klippy/chelper" relPath;
      isScriptsFile = lib.hasPrefix "scripts/" relPath;
      isDocsFile = lib.hasPrefix "docs/" relPath;
      isConfigFile = lib.hasPrefix "config/" relPath;
      isTestFile = lib.hasPrefix "test/" relPath;
      # Include parent directories
      isKlippyDir = relPath == "klippy" || lib.hasPrefix "klippy" relPath;
      isScriptsDir = relPath == "scripts" || lib.hasPrefix "scripts" relPath;
      isDocsDir = relPath == "docs" || lib.hasPrefix "docs" relPath;
      isConfigDir = relPath == "config" || lib.hasPrefix "config" relPath;
      isTestDir = relPath == "test" || lib.hasPrefix "test" relPath;
      # Match the directory itself or files within
      wantedPath = (isKlippyFile && !isChelperFile) || isScriptsFile || isDocsFile || isConfigFile || isTestFile;
      wantedDir = type == "directory" && (isKlippyDir || isScriptsDir || isDocsDir || isConfigDir || isTestDir) && !isChelperFile;
    in
      wantedPath || wantedDir;
  };

  # Firmware sources - MINIMAL set for MCU firmware builds
  # Only includes exactly what's needed to avoid unnecessary rebuilds:
  # - src/      - MCU firmware C code
  # - lib/      - Third-party MCU libraries
  # - Makefile  - Build system
  # - scripts/  - Build scripts (buildcommands.py, kconfig, sconfig)
  # - klippy/msgproto.py - Only Python file needed (imported by buildcommands.py)
  # - klippy/.version    - Version file read by buildcommands.py
  #
  # Changing klippy/*.py (except msgproto.py) will NOT trigger firmware rebuilds!
  firmware = mkFilteredSrc {
    name = "firmware";
    patches = firmwarePatches;
    filter = path: type: let
      relPath = lib.removePrefix (toString src + "/") (toString path);
      # src/ directory - the MCU firmware code
      isSrcDir = relPath == "src" || lib.hasPrefix "src/" relPath;
      # lib/ directory - third-party libraries
      isLibDir = relPath == "lib" || lib.hasPrefix "lib/" relPath;
      # Makefile at root
      isMakefile = relPath == "Makefile";
      # scripts/ directory - build scripts
      isScriptsDir = relPath == "scripts" || lib.hasPrefix "scripts/" relPath;
      # klippy/ parent directory (needed to access msgproto.py)
      isKlippyDir = relPath == "klippy" && type == "directory";
      # Only the specific files buildcommands.py needs from klippy/
      isMsgproto = relPath == "klippy/msgproto.py";
      isVersion = relPath == "klippy/.version";
    in
      isSrcDir || isLibDir || isMakefile || isScriptsDir || isKlippyDir || isMsgproto || isVersion;
  };

  # Full source (for things that need everything, like klipper-genconf)
  # Still applies all patches
  full = mkFilteredSrc {
    name = "full";
    patches = pythonPatches ++ firmwarePatches;
    filter = path: type: let
      relPath = lib.removePrefix (toString src + "/") (toString path);
      # Exclude nix-specific files that don't affect the build
      isNix = lib.hasPrefix "nix/" relPath || relPath == "flake.nix" || relPath == "flake.lock";
      isGit = lib.hasPrefix ".git" relPath;
      isResult = relPath == "result";
      isTarget = lib.hasPrefix "target/" relPath;
    in
      !isNix && !isGit && !isResult && !isTarget;
  };
}
