# Katapult bootloader firmware builder
#
# Builds Katapult bootloader firmware for MCUs. Similar to klipper-firmware
# but outputs katapult.bin/elf/uf2 and deployer.bin.
#
# Usage:
#   katapult-firmware { mcu = "leviathan"; firmwareConfig = ./katapult.config; }
{
  stdenv,
  lib,
  python3,
  pkgsCross,
  gcc-arm-embedded,
  bintools-unwrapped,
  libffi,
  libusb1,
  pkg-config,
  katapult-src,
}: {
  mcu ? "mcu",
  firmwareConfig ? null,
}:
assert firmwareConfig != null;
  stdenv.mkDerivation {
    pname = "katapult-firmware-${mcu}";
    version = "unstable";
    src = katapult-src;

    nativeBuildInputs = [
      python3
      pkgsCross.avr.stdenv.cc
      gcc-arm-embedded
      bintools-unwrapped
      libffi
      libusb1
      pkg-config
    ];

    postPatch = ''
      patchShebangs .
    '';

    configurePhase = ''
      runHook preConfigure
      cp ${firmwareConfig} ./.config
      chmod +w ./.config
      make olddefconfig
      runHook postConfigure
    '';

    makeFlags = ["V=1"];

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp ./.config $out/config
      cp out/katapult.bin $out/ || true
      cp out/katapult.elf $out/ || true
      cp out/katapult.uf2 $out/ || true
      cp out/deployer.bin $out/ || true
      runHook postInstall
    '';

    dontFixup = true;

    meta = {
      description = "Katapult bootloader firmware for ${mcu}";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  }
