# Katapult bootloader package and flashing scripts
#
# Katapult is a bootloader for MCU firmware updates, providing a safer
# and more reliable alternative to klipper's built-in flash mechanisms.
#
# Provides:
#   - katapult: The Katapult source tree (for firmware builds)
#   - katapult-scripts: Wrapped Python scripts for flashing
#     - katapult-flash: Main flashtool.py utility
#     - katapult-flash-can: CAN bus flashing (flash_can.py)
#     - katapult-flash-usb: USB/serial flashing (flashtool.py -d)
{
  lib,
  stdenv,
  makeWrapper,
  python3,
  katapult-src,
}: let
  # Python environment with all dependencies for Katapult scripts
  pythonEnv = python3.withPackages (ps: [
    ps.pyserial
    ps.python-can
    ps.packaging
    ps.intelhex
  ]);

  # The Katapult source tree package
  katapult = stdenv.mkDerivation {
    pname = "katapult";
    version = "unstable";
    src = katapult-src;

    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/katapult
      cp -r . $out/lib/katapult/
      runHook postInstall
    '';

    passthru.src = katapult-src;

    meta = {
      description = "Katapult bootloader for Klipper MCU firmware updates";
      homepage = "https://github.com/Arksine/katapult";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  };

  # Wrapped flashing scripts with proper Python dependencies
  scripts = stdenv.mkDerivation {
    pname = "katapult-scripts";
    version = "unstable";

    dontUnpack = true;

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin

      # flashtool.py - Main flashing utility
      makeWrapper ${pythonEnv}/bin/python3 $out/bin/katapult-flash \
        --add-flags "${katapult}/lib/katapult/scripts/flashtool.py"

      # flash_can.py - CAN bus flashing
      makeWrapper ${pythonEnv}/bin/python3 $out/bin/katapult-flash-can \
        --add-flags "${katapult}/lib/katapult/scripts/flash_can.py"

      # flash_usb.py - USB/serial flashing
      makeWrapper ${pythonEnv}/bin/python3 $out/bin/katapult-flash-usb \
        --add-flags "${katapult}/lib/katapult/scripts/flashtool.py" \
        --add-flags "-d"

      runHook postInstall
    '';

    meta = {
      description = "Katapult flashing scripts with Python dependencies";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  };
in {
  inherit katapult scripts;
}
